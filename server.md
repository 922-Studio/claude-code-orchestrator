# Server Infrastructure Reference

> Last updated: 2026-06-23. **High-level cluster overview only.** Low-level, fast-moving detail
> (routes, ports, per-service config, networks, monitoring, container inventory) is NOT kept here —
> it lives in `HomeStructure/docs/`. See the pointers at the bottom.

## Cluster — 3-node Docker Swarm (`astro-*`)

All nodes are identical hardware: **HP ProDesk 400 G5 SFF · Intel i3-8100 (4 cores) · Ubuntu 24.04**.
Access is key-based with passwordless sudo; all inter-node traffic goes over Tailscale.

| Node | SSH | Tailscale IP | RAM | Disk | Status | Purpose (one-liner) |
|------|-----|--------------|-----|------|--------|---------------------|
| `astro-antares` | `ssh aa` | 100.112.171.16 | 16 GB | 232 GB SSD | Active (Leader) | The center — manager + all production |
| `astro-polaris` | `ssh ap` | 100.94.122.119 | 8 GB | 98 GB SSD | Active | CI/CD — GitHub Actions runners |
| `astro-upsilon` | `ssh au` | 100.100.214.75 | 8 GB | 98 GB SSD | Active | Spare worker + monitoring agents |

## Purpose per node

### `astro-antares` — the center
Swarm **manager (Leader)** and the host for everything stateful and production-facing:
- All production application containers (HomeAPI, HomeUI, HomeAuth, HomeCollector, Studio, Drafter, Portfolio, Anime, Discord bot, …)
- **Databases**: shared PostgreSQL + Redis (prod and dev instances)
- **Object storage**: MinIO
- **Platform services**: Docker registry, Traefik reverse proxy, Cloudflare tunnel, Watchtower (auto-deploy from registry)
- **Backups**

All deploys ultimately run here: polaris builds the image, then runs `docker compose` against antares's Docker daemon via `DOCKER_HOST=ssh://lab@astro-antares`.

### `astro-polaris` — CI/CD
Hosts the **4 GitHub Actions self-hosted runners** (`polaris`, `polaris-2`, `polaris-3`, `polaris-4`; `-4` carries the `e2e` label). Builds Docker images, runs tests, and drives deploys to antares. Lives here (not on the manager) to keep spiky CI load off production. Also a Swarm worker.

### `astro-upsilon` — spare worker
Swarm worker held as **overflow / standby capacity**. Currently runs only monitoring agents (cAdvisor, node-exporter). No dedicated production workload yet — first candidate to absorb services if antares needs relief.

## Access

```bash
ssh aa   # astro-antares (manager / the center)
ssh ap   # astro-polaris (CI runners)
ssh au   # astro-upsilon (spare worker)
```

Key-based, passwordless sudo. Cluster management script on antares: `~/HomeStructure/scripts/homelab-ctl.sh`.

## MCP Servers

| Server | Location | Transport | Status |
|--------|----------|-----------|--------|
| `homeapi` (server-side) | `astro-antares:/home/lab/openclaw/mcp-servers/homeapi/` | stdio via mcporter | Active (prod, v0.64.8 — regenerate on next prod push) |
| `homeapi-dev` (personal local) | `HomeAPI/scripts/mcp/generated/` on Gregor's Mac | stdio, Claude Code user-scope | Set up per README in `HomeAPI/scripts/mcp/` |

### Server-side MCP (`homeapi` on antares)
- **Entry point**: `/home/lab/openclaw/mcp-servers/homeapi/run.sh`
- **Config**: mcporter at `/home/lab/openclaw/workspace/config/mcporter.json`
- **Auth**: reads `HOMEAPI_TOKEN` from `/home/lab/OpenClaw/.env`; `HOMEAPI_ORG_ID` defaulted in `run.sh`
- **Regeneration**: triggered on prod push via `HomeAPI/.github/workflows/deploy.yml` →
  `922-Studio/workflows/.github/workflows/generate-mcp.yml`; support files (`api_client_httpx.py`,
  `patch_api_methods.py`) are now tracked in `922-Studio/workflows/scripts/` — pipeline is
  self-contained (no manual file placement needed)
- **Tools**: 150 tools across all HomeAPI tags; 8 finance/ledger tools

### Personal local MCP (`homeapi-dev` on Mac)
- **Purpose**: direct interaction with HomeAPI (dev or prod) from Claude Code / Claude Desktop
- **Setup**: `HomeAPI/scripts/mcp/README.md` — one-time `.env` fill-in, then `./scripts/mcp/generate.sh`
- **Registration**: `claude mcp add -s user homeapi-dev -- bash HomeAPI/scripts/mcp/generated/run.sh`
- **Auth**: personal bearer token + `X-Org-ID` from `scripts/mcp/.env` (gitignored)
- **Switching env**: re-run `generate.sh prod` to point at port 8080 instead of 8180

## Where the detail lives (`HomeStructure/docs/`)

Everything low-level and fast-changing is documented (and version-controlled) in HomeStructure — read it there rather than duplicating it here:

| Topic | Doc |
|-------|-----|
| Cluster config & node setup | `docs/config/cluster.md`, `docs/guides/worker-node-setup.md` |
| Networking, firewall, Cloudflare tunnel | `docs/config/networking.md`, `docs/config/cloudflare.md` |
| Public routes & reverse proxy | `docs/services/traefik.md` |
| Services & ports (per service) | `docs/services/` |
| Databases & storage | `docs/config/storage.md` |
| Monitoring (Prometheus / Grafana) | `docs/` (monitoring section) |
| GitHub Actions runners | `docs/services/github-runner.md` |
