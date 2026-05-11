# Plan: Multi-Server Performance Dashboard & Collector

- **Date**: 2026-03-27
- **Project(s)**: HomeCollector, HomeUI, HomeStructure
- **Status**: Done (2026-03-27)
- **Goal**: Enable the performance dashboard and collector to display metrics from all cluster nodes (home-lab, exec-1, exec-2), with a GitHub-style dropdown to select "All Servers" or a specific node.

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI project mapping and best practices
- `server.md` — cluster topology (3 nodes, Tailscale IPs, roles)

### Current State (Single-Server)

| Layer | What exists | Limitation |
|-------|-------------|------------|
| **Prometheus** | Scrapes `node-exporter:9100` on home-lab only | No scrape targets for exec-1/exec-2; no `instance`/`node` labels |
| **HomeCollector API** | `PrometheusService` queries `node_*` metrics without instance filter | Aggregates everything into one server view |
| **HomeCollector schemas** | `SystemMetrics`, `SystemMetricsHistory` — flat, no `server` field | Cannot represent multi-node data |
| **HomeUI dashboard** | `SystemPerformancePage` shows gauges + charts for one server | No server selector; no multi-line comparison charts |
| **Docker monitoring** | Polls local Docker socket only | Cannot see containers on exec-1/exec-2 |

### Cluster Nodes

| Node | SSH Alias | Tailscale IP | Role |
|------|-----------|-------------|------|
| home-lab | `lab` | 100.112.171.16 | Swarm Manager (infra) |
| exec-1 | `exec-1` | 100.94.122.119 | Swarm Worker (apps) |
| exec-2 | `exec-2` | 100.100.214.75 | Swarm Worker (apps) |

Worker nodes already run `node-exporter` on port 9100 (deployed via `~/monitoring/docker-compose.yaml` per worker-node-setup guide).

---

## Steps

### Step 1: Add Prometheus Scrape Targets for Worker Nodes

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Description**: Update `monitoring/prometheus/prometheus.yaml` to scrape node-exporter from all 3 nodes with distinguishing `node` labels.
- **Context files to read**:
  - `monitoring/prometheus/prometheus.yaml` — current scrape config
  - `docs/guides/worker-node-setup.md` — worker monitoring setup reference
  - `docs/config/cluster.md` — Tailscale IPs and node names
- **Changes**:
  - Replace the single `node_exporter` job with per-node jobs:
    ```yaml
    - job_name: 'node-home-lab'
      static_configs:
        - targets: ['node-exporter:9100']
          labels:
            node: 'home-lab'

    - job_name: 'node-exec-1'
      static_configs:
        - targets: ['100.94.122.119:9100']
          labels:
            node: 'exec-1'

    - job_name: 'node-exec-2'
      static_configs:
        - targets: ['100.100.214.75:9100']
          labels:
            node: 'exec-2'
    ```
- **Acceptance criteria**:
  - [ ] Prometheus config has 3 separate node-exporter scrape jobs with `node` label
  - [ ] Config deployed and Prometheus reloaded (`docker service update` or `/-/reload`)
  - [ ] Verify in Prometheus UI: `up{job=~"node-.*"}` returns 3 targets with distinct `node` labels
  - [ ] Historical single-server data still queryable (backward compatible)

---

### Step 2: Add Server List Endpoint to HomeCollector

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 1
- **Description**: Add a new API endpoint that returns the list of known servers from Prometheus. This powers the dropdown in the frontend.
- **Context files to read**:
  - `app/routers/system.py` — existing monitoring router
  - `app/services/prometheus_service.py` — Prometheus client
  - `config.py` — server config reference
- **Changes**:
  1. Add to `app/schemas/system.py`:
     ```python
     class ServerInfo(BaseModel):
         node: str          # "home-lab", "exec-1", "exec-2"
         display_name: str  # "Home Lab", "Exec 1", "Exec 2"
         status: str        # "up" | "down"

     class ServerListResponse(BaseModel):
         servers: list[ServerInfo]
     ```
  2. Add to `PrometheusService`:
     ```python
     async def get_server_list(self) -> list[dict]:
         """Query Prometheus for all nodes with node-exporter targets."""
         # Query: up{job=~"node-.*"}
         # Extract 'node' label and up/down status
     ```
  3. Add endpoint to `app/routers/system.py`:
     ```python
     @router.get("/servers", response_model=ServerListResponse)
     async def get_servers() -> ServerListResponse:
     ```
- **Acceptance criteria**:
  - [ ] `GET /api/monitoring/servers` returns list of servers with node name, display name, status
  - [ ] Response correctly reflects which nodes are up/down
  - [ ] Endpoint is authenticated (same auth as other monitoring endpoints)

---

### Step 3: Add `node` Filter to All System Metrics Endpoints

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 2
- **Description**: Add optional `node` query parameter to `/api/monitoring/system`, `/api/monitoring/system/history`, `/api/monitoring/usage/history`, and `/api/monitoring/docker`. When omitted → aggregate all nodes (backward compatible). When set → filter to that specific node.
- **Context files to read**:
  - `app/routers/system.py` — all endpoint signatures
  - `app/services/prometheus_service.py` — all PromQL queries
  - `app/schemas/system.py` — response models
- **Changes**:
  1. **`PrometheusService.get_system_metrics(node: str | None = None)`**:
     - When `node` is set, inject `{node="<value>"}` label filter into every PromQL query
     - Example: `node_cpu_seconds_total{mode="idle"}` → `node_cpu_seconds_total{mode="idle",node="exec-1"}`
     - When `node` is None, use `avg by()` / `sum by()` across all nodes (current behavior)
  2. **`PrometheusService.get_system_metrics_history(node: str | None = None, ...)`**:
     - Same label injection into range queries
  3. **`PrometheusService.get_usage_metrics_history(node: str | None = None, ...)`**:
     - Same pattern
  4. **`PrometheusService.get_container_metrics(node: str | None = None)`**:
     - When `node` is None → aggregate Docker containers across all nodes
     - When `node` is set → query only that node's Docker socket (via remote Docker API or Prometheus cAdvisor)
     - **Note**: Container metrics currently use local Docker socket. For multi-node:
       - Option A: Query Prometheus `container_*` metrics with `node` label (preferred if cAdvisor works on workers)
       - Option B: Proxy Docker API calls to worker nodes via Tailscale IPs
       - **Decision**: Use Prometheus container metrics where available, fall back to Docker socket for home-lab
  5. **Router updates** — add `node: str | None = None` query parameter to all 4 endpoints
  6. **`/api/monitoring/overview`** — add optional `node` parameter, pass through to all sub-calls
- **Acceptance criteria**:
  - [ ] All endpoints accept optional `?node=home-lab` / `?node=exec-1` / `?node=exec-2`
  - [ ] Omitting `node` returns aggregated data across all nodes (backward compatible)
  - [ ] Per-node queries return metrics scoped to that specific node
  - [ ] PromQL label injection is safe against injection (validate node value against known list)

---

### Step 4: Update Frontend Types & API Client

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 2-3 (can start after schema design is agreed)
- **Description**: Add `node` parameter support to frontend API client and add server list types.
- **Context files to read**:
  - `src/api/monitoring.ts` — monitoring API client
  - `src/types/api/monitoring.ts` — Zod schemas
  - `src/features/dashboard/hooks/useSystemMetrics.ts` — React Query hooks
- **Changes**:
  1. **New Zod schemas** in `src/types/api/monitoring.ts`:
     ```typescript
     export const ServerInfoSchema = z.object({
       node: z.string(),
       display_name: z.string(),
       status: z.string(),
     })
     export const ServerListResponseSchema = z.object({
       servers: z.array(ServerInfoSchema),
     })
     ```
  2. **New API functions** in `src/api/monitoring.ts`:
     ```typescript
     export async function getServers() { ... }
     export async function getSystemMetrics(node?: string) { ... }
     export async function getSystemMetricsRangeHistory(range: string, node?: string) { ... }
     export async function getUsageHistory(range: string, node?: string) { ... }
     export async function getContainerMetrics(node?: string) { ... }
     export async function getOverview(node?: string) { ... }
     ```
  3. **Updated React Query options** — add `node` to query keys so cache is per-server:
     ```typescript
     system: (node?: string) => queryOptions({
       queryKey: ['monitoring', 'system', node ?? 'all'],
       queryFn: () => getSystemMetrics(node),
       ...
     })
     ```
  4. **New hook**: `useServers()` — fetches server list, refetchInterval: 30s
- **Acceptance criteria**:
  - [ ] All monitoring API functions accept optional `node` parameter
  - [ ] React Query keys include `node` to prevent cache collisions
  - [ ] `useServers()` hook returns server list
  - [ ] TypeScript compiles with no errors

---

### Step 5: Build Server Selector Dropdown Component

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4
- **Description**: Create a GitHub-style dropdown component for selecting "All Servers" or a specific node.
- **Context files to read**:
  - `src/features/dashboard/components/TimeRangeFilter.tsx` — reference for existing filter component style
  - `src/features/dashboard/pages/SystemPerformancePage.tsx` — where it will be placed
- **Changes**:
  1. Create `src/features/dashboard/components/ServerSelector.tsx`:
     - GitHub-style dropdown button (icon + label + chevron)
     - Options: "All Servers" (default) + one entry per server from `useServers()`
     - Each server entry shows: name + status dot (green/red)
     - Selected state shown in button label
     - Keyboard accessible (arrow keys, enter, escape)
     - Matches existing UI style (use `var(--card)`, `var(--border)`, etc.)
  2. Visual reference — GitHub repo branch selector style:
     - Rounded button with subtle border
     - Dropdown appears below with search (optional for 3 items) and list
     - Checkmark on selected item
     - Status indicator dot per server
- **Acceptance criteria**:
  - [ ] Component renders with "All Servers" default
  - [ ] Dropdown lists all servers from API with status dots
  - [ ] Selection updates parent state via `onChange` callback
  - [ ] Component matches existing dashboard design language
  - [ ] Accessible: keyboard navigation, focus management

---

### Step 6: Integrate Server Selector into Dashboard Pages

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (depends on Steps 4, 5)
- **Description**: Wire the server selector into `SystemPerformancePage`, `UsagePage`, and `OverviewPage`. All metrics, charts, and gauges update when server selection changes.
- **Context files to read**:
  - `src/features/dashboard/pages/SystemPerformancePage.tsx` — main performance page
  - `src/features/dashboard/pages/UsagePage.tsx` — usage history page
  - `src/features/dashboard/pages/OverviewPage.tsx` — overview dashboard
- **Changes**:
  1. **SystemPerformancePage**:
     - Add `const [selectedNode, setSelectedNode] = useState<string | undefined>(undefined)`
     - Place `<ServerSelector>` next to `<TimeRangeFilter>` in header
     - Pass `selectedNode` to `useSystemMetrics(selectedNode)` and `useSystemMetricsRange(range, selectedNode)`
     - All gauges (CPU, RAM, Disk) and charts update per selection
  2. **UsagePage** (same pattern):
     - Add server selector to header
     - Pass `selectedNode` to `useUsageHistory(range, selectedNode)`
  3. **OverviewPage**:
     - Add server selector to header
     - Pass `selectedNode` to `useOverview(selectedNode)`
     - Stat cards (CPU, RAM, Disk, Uptime) reflect selected server
  4. **UptimePage** — no change needed (uptime checks are service-level, not node-level)
- **Acceptance criteria**:
  - [ ] Server selector visible on SystemPerformancePage, UsagePage, OverviewPage
  - [ ] Selecting a specific server updates all gauges and charts to that server's data
  - [ ] Selecting "All Servers" shows aggregated data (default behavior, backward compatible)
  - [ ] URL state is preserved (optional: `?node=exec-1` query param for shareable links)
  - [ ] No layout shifts or loading flickers on server switch

---

### Step 7: End-to-End Testing — Prometheus to Dashboard

- **Project**: HomeCollector, HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeCollector`, `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (depends on Steps 1-6)
- **Description**: Comprehensive testing to validate the entire pipeline works correctly.
- **Context files to read**:
  - `app/routers/system.py` — endpoints to test
  - `tests/` — existing test structure in both projects

#### 7A: Prometheus Verification (Manual)
- **Test**: SSH into each node, verify node-exporter is running and responding
  ```bash
  # From home-lab
  curl -s http://localhost:9100/metrics | head -5
  curl -s http://100.94.122.119:9100/metrics | head -5   # exec-1
  curl -s http://100.100.214.75:9100/metrics | head -5    # exec-2
  ```
- **Test**: Verify Prometheus targets page shows all 3 nodes as UP
  ```bash
  curl -s http://prometheus:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | startswith("node-")) | {job: .labels.job, node: .labels.node, health: .health}'
  ```
- **Test**: Verify per-node PromQL queries return distinct data
  ```bash
  # CPU should differ between nodes
  curl -s 'http://prometheus:9090/api/v1/query?query=node_load1{node="home-lab"}'
  curl -s 'http://prometheus:9090/api/v1/query?query=node_load1{node="exec-1"}'
  ```
- **Acceptance criteria**:
  - [ ] All 3 node-exporters are reachable from Prometheus
  - [ ] All 3 targets show `health: "up"` in Prometheus targets API
  - [ ] Per-node queries return different values (different hosts = different metrics)

#### 7B: HomeCollector API Tests (Automated)
- **Test**: Unit tests for `PrometheusService` with mocked Prometheus responses
  ```python
  # test_prometheus_service.py
  async def test_get_system_metrics_single_node():
      """Metrics for a specific node only include that node's data."""

  async def test_get_system_metrics_all_nodes():
      """Omitting node returns aggregated metrics."""

  async def test_get_server_list():
      """Server list returns all configured nodes with status."""

  async def test_node_filter_injection_safety():
      """Reject invalid node names (prevent PromQL injection)."""
  ```
- **Test**: Integration tests against running Prometheus
  ```python
  async def test_system_endpoint_with_node_filter():
      """GET /api/monitoring/system?node=home-lab returns home-lab-only data."""

  async def test_system_endpoint_without_node():
      """GET /api/monitoring/system returns aggregated data (backward compat)."""

  async def test_history_endpoint_with_node_filter():
      """GET /api/monitoring/system/history?node=exec-1&range=1h returns exec-1 data."""

  async def test_servers_endpoint():
      """GET /api/monitoring/servers returns all 3 nodes."""
  ```
- **Acceptance criteria**:
  - [ ] All unit tests pass with mocked Prometheus
  - [ ] All integration tests pass against real Prometheus
  - [ ] Node filter validation rejects invalid input
  - [ ] Backward compatibility confirmed (no `node` param = same behavior as before)

#### 7C: Frontend Tests (Automated)
- **Test**: Component tests for ServerSelector
  ```typescript
  // ServerSelector.test.tsx
  it('renders with "All Servers" default')
  it('opens dropdown and lists all servers')
  it('shows status dots for each server')
  it('calls onChange with selected node')
  it('supports keyboard navigation')
  ```
- **Test**: Integration tests for SystemPerformancePage with server selector
  ```typescript
  it('passes selected node to API calls')
  it('updates charts when server selection changes')
  it('defaults to aggregated view')
  ```
- **Acceptance criteria**:
  - [ ] All component tests pass
  - [ ] All integration tests pass
  - [ ] No TypeScript compilation errors

#### 7D: Backtesting — Validate Against Historical Data
- **Test**: After Prometheus has collected multi-node data for at least 1 hour:
  ```bash
  # Verify historical data exists for all nodes
  curl 'http://collector:8010/api/monitoring/system/history?range=1h&node=home-lab'
  curl 'http://collector:8010/api/monitoring/system/history?range=1h&node=exec-1'
  curl 'http://collector:8010/api/monitoring/system/history?range=1h&node=exec-2'

  # Verify aggregated view still works
  curl 'http://collector:8010/api/monitoring/system/history?range=1h'

  # Compare: aggregated CPU should be average of individual nodes
  # Compare: aggregated RAM should show total across nodes
  ```
- **Test**: Verify dashboard visually
  - Open SystemPerformancePage in browser
  - Switch between "All Servers", "home-lab", "exec-1", "exec-2"
  - Verify charts show different data for each server
  - Verify gauges update correctly
  - Verify time range filter still works with server selector
  - Verify "All Servers" aggregation makes sense (not just one server's data)
- **Acceptance criteria**:
  - [ ] Historical data available per node after Prometheus scrape window
  - [ ] Per-node API responses contain different values (different hardware = different metrics)
  - [ ] Aggregated view shows reasonable aggregation (avg CPU, sum RAM, etc.)
  - [ ] Dashboard visually renders all server/time range combinations correctly
  - [ ] No console errors in browser

---

### Step 8: Edge Cases & Resilience Testing

- **Project**: HomeCollector, HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeCollector`, `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 7
- **Description**: Test failure scenarios and edge cases.
- **Tests**:
  1. **Node down**: Stop node-exporter on exec-2, verify:
     - Server list shows exec-2 as "down"
     - Dashboard still works for home-lab and exec-1
     - "All Servers" gracefully handles missing node (partial data, not error)
  2. **Invalid node parameter**: Send `?node=hacked-node` — verify 400 error (not PromQL injection)
  3. **Prometheus unavailable**: Stop Prometheus, verify:
     - All endpoints return 502 (existing behavior)
     - Dashboard shows error state (existing behavior)
  4. **Network partition**: Block Tailscale between home-lab and exec-1:
     - Prometheus stops scraping exec-1 → target goes down
     - Server list reflects exec-1 as down
     - Existing data for exec-1 still queryable in historical views
- **Acceptance criteria**:
  - [ ] Node failure is gracefully handled (partial data, not crash)
  - [ ] Invalid node values are rejected with 400
  - [ ] Dashboard degrades gracefully when data sources are unavailable
  - [ ] Historical data survives node outages

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Prometheus scrape config for 3 nodes     → HomeStructure @ /Users/gregor/dev/922/HomeStructure
  Step 2: Server list API endpoint                  → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 3: Add node filter to all metrics endpoints  → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 2 (after wave 1):
  Step 4: Frontend types & API client update        → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 5: Server selector dropdown component        → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 3 (after wave 2):
  Step 6: Integrate selector into dashboard pages   → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 4 (after wave 3):
  Step 7: End-to-end testing (all layers)           → HomeCollector + HomeUI
  Step 8: Edge cases & resilience testing           → HomeCollector + HomeUI

Estimated agent prompts: 6 (Steps 1-6 each get one prompt; Steps 7-8 are manual/test execution)
```

## Agent Prompt Notes

- Steps 2 + 3 target the same project (HomeCollector) — run sequentially (3 depends on 2's schema)
- Steps 4 + 5 can truly run in parallel (different files, no overlap)
- Step 6 depends on both 4 and 5
- Steps 7 + 8 are partially manual (Prometheus verification, visual testing) and partially automated (unit/integration tests)
- All agent prompts must use **Sonnet model** per user preference

## Post-Execution Checklist

- [ ] All tests pass (HomeCollector unit + integration, HomeUI component + integration)
- [ ] Documentation updated (API docs for new `?node` parameter and `/servers` endpoint)
- [ ] Pipeline green (both HomeCollector and HomeUI CI)
- [ ] Prometheus targets page shows 3 healthy node-exporter targets
- [ ] Dashboard visually confirmed working with server selector
- [ ] Backward compatibility verified (existing API calls without `node` work as before)
- [ ] Server selector tested on mobile viewport (responsive)
