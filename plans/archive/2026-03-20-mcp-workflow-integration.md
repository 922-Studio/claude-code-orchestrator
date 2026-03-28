# Plan: Reusable MCP Generation Workflow

- **Date**: 2026-03-20
- **Project(s)**: workflows, HomeAPI, OpenClaw
- **Status**: done (2026-03-20)
- **Goal**: Create a templated, reusable GitHub Actions workflow for auto-generating MCP servers from any microservice's OpenAPI spec, integrated into deploy pipelines.

## Context

Read these files before proceeding:
- `projects/homeapi.md` — HomeAPI project mapping
- `server.md` — server infrastructure

## Architecture

```
┌─ HomeAPI/.github/workflows/deploy.yml ─────────────────────┐
│                                                              │
│  cancel → version → lint → tests ─┐                         │
│                    smoke-test ─────┤                         │
│                                    ↓                         │
│                              deploy-docker                   │
│                                    ↓                         │
│                              generate-mcp  ←── NEW JOB      │
│                                    │                         │
│                  uses: 922-Studio/workflows/                 │
│                    .github/workflows/generate-mcp.yml@main   │
│                                    ↓                         │
│                         notify-success/failure               │
└──────────────────────────────────────────────────────────────┘

┌─ 922-Studio/workflows/.github/workflows/generate-mcp.yml ──┐
│  Reusable workflow (workflow_call)                           │
│                                                              │
│  Inputs:                                                     │
│    - service_name: "homeapi"                                 │
│    - api_port: 8080                                          │
│    - openapi_path: "/openapi.json"                           │
│    - auth_url: "http://localhost:8100"                        │
│    - auth_email / auth_password (secrets)                    │
│    - tag_renames: '{"Activity Log":"activity-log"}'          │
│    - mcp_base_dir: "/home/lab/openclaw/mcp-servers"          │
│                                                              │
│  Steps:                                                      │
│    1. Ensure mcp-generator installed (idempotent)           │
│    2. Wait for API health                                    │
│    3. Fetch + normalize OpenAPI spec                         │
│    4. Generate MCP servers                                   │
│    5. Patch API stubs → real httpx calls                     │
│    6. Deploy to output dir (preserve venv/config/token)      │
│    7. Install deps                                           │
│    8. Refresh auth token                                     │
│    9. Register in mcporter (idempotent)                      │
│   10. Smoke test (list tools, optional call)                 │
└──────────────────────────────────────────────────────────────┘
```

## Server Structure (Persistent)

```
/home/lab/tools/mcp-generator/           # Generator tool (git clone, one-time)
  .venv/                                  # Generator dependencies
  patch_api_methods.py                    # Stub → httpx patcher
  api_client_httpx.py                     # httpx ApiClient template

/home/lab/openclaw/mcp-servers/{name}/   # Per-service output
  .venv/                                  # Runtime dependencies
  .api-token                              # Auth token (auto-refreshed)
  run.sh                                  # mcporter wrapper script
  {name}_mcp_generated.py                 # Entry point
  servers/                                # Per-tag modules
  generated_openapi/                      # API client
  middleware/                             # Auth middleware
  fastmcp.json                            # Config
```

## Steps

### Step 1: Clean up server
- **Project**: Server
- **Directory**: `/home/lab/`
- **Description**: Remove the ad-hoc MCP setup from the previous attempt. Keep the generator tool and persistent files.
- **Actions**:
  - Remove MCP generation hook from `/home/lab/HomeAPI/deploy.sh`
  - Remove `/home/lab/HomeAPI/scripts/generate-mcp.sh`
  - Keep `/home/lab/tools/mcp-generator/` (tool + patches)
  - Keep `/home/lab/openclaw/mcp-servers/homeapi/` (working MCP, will be overwritten by workflow)
  - Keep mcporter.json homeapi entry (workflow will update idempotently)
- **Acceptance criteria**:
  - [x] deploy.sh has no MCP references *(2026-03-20)*
  - [x] generate-mcp.sh removed from HomeAPI *(2026-03-20)*
  - [x] Generator tool still functional *(2026-03-20)*

### Step 2: Create reusable workflow
- **Project**: workflows
- **Directory**: `/Users/gregor/dev/922/workflows/.github/workflows/`
- **Description**: Create `generate-mcp.yml` reusable workflow following the repo's conventions (emoji logging, snake_case inputs, workflow_call trigger).
- **Context files to read**:
  - All existing workflows in the repo for pattern reference
- **Inputs**:
  | Input | Type | Required | Default | Description |
  |-------|------|----------|---------|-------------|
  | `service_name` | string | yes | — | Name for the MCP server (e.g. "homeapi") |
  | `api_port` | string | yes | — | Port the API runs on (e.g. "8080") |
  | `openapi_path` | string | no | "/openapi.json" | Path to OpenAPI spec endpoint |
  | `tag_renames` | string | no | "{}" | JSON map of tag renames (e.g. `{"Activity Log":"activity-log"}`) |
  | `mcp_base_dir` | string | no | "/home/lab/openclaw/mcp-servers" | Base dir for MCP output |
  | `generator_dir` | string | no | "/home/lab/tools/mcp-generator" | Path to mcp-generator tool |
  | `mcporter_config` | string | no | "/home/lab/openclaw/workspace/config/mcporter.json" | Path to mcporter config |
  | `auth_url` | string | no | "" | Auth service URL for token refresh (empty = skip) |
- **Secrets**:
  | Secret | Required | Description |
  |--------|----------|-------------|
  | `AUTH_EMAIL` | no | Email for auth token refresh |
  | `AUTH_PASSWORD` | no | Password for auth token refresh |
- **Acceptance criteria**:
  - [x] Workflow follows existing naming/logging conventions *(2026-03-20)*
  - [x] All steps idempotent (safe to re-run) *(2026-03-20)*
  - [x] Works for any service with OpenAPI spec *(2026-03-20)*

### Step 3: Create documentation
- **Project**: workflows
- **Directory**: `/Users/gregor/dev/922/workflows/docs/`
- **Description**: Create `generate-mcp.md` documenting the workflow, inputs, and how to add it to a new microservice.
- **Acceptance criteria**:
  - [x] Doc follows existing docs/ pattern *(2026-03-20)*
  - [x] Includes "Adding to a new service" section *(2026-03-20)*

### Step 4: Integrate into HomeAPI deploy pipeline
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI/.github/workflows/`
- **Description**: Add `generate-mcp` job to `deploy.yml` that triggers after deploy.
- **Change**: Add new job after `deploy`:
  ```yaml
  generate-mcp:
    needs: deploy
    uses: 922-Studio/workflows/.github/workflows/generate-mcp.yml@main
    with:
      service_name: 'homeapi'
      api_port: '8080'
      tag_renames: '{"Activity Log":"activity-log","WorkLogs":"worklogs","Tasks":"tasks-mgmt"}'
      auth_url: 'http://localhost:8100'
    secrets:
      AUTH_EMAIL: ${{ secrets.AUTH_EMAIL }}
      AUTH_PASSWORD: ${{ secrets.AUTH_PASSWORD }}
  ```
- **Also**: Add `AUTH_EMAIL` and `AUTH_PASSWORD` to HomeAPI's GitHub repo secrets
- **Acceptance criteria**:
  - [x] Job triggers after deploy *(2026-03-20)*
  - [x] MCP generation failure does NOT block success notifications *(2026-03-20)*
  - [x] Pipeline stays clean *(2026-03-20 — run 23326118265 green)*

### Step 5: Remove local generate-mcp.sh from HomeAPI
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI/`
- **Description**: Remove the local `scripts/generate-mcp.sh` — the workflow replaces it.
- **Actions**:
  - Delete `scripts/generate-mcp.sh`
  - Revert `deploy.sh` to original (remove MCP generation line)
- **Acceptance criteria**:
  - [x] No MCP-related scripts in HomeAPI *(2026-03-20)*
  - [x] deploy.sh clean *(2026-03-20)*

### Step 6: Test end-to-end
- **Project**: HomeAPI
- **Description**: Trigger the workflow manually and verify MCP regeneration works.
- **Tests**:
  1. Push to HomeAPI main → pipeline runs → MCP regenerated
  2. MCP tools still functional via mcporter
  3. Token refreshed
- **Acceptance criteria**:
  - [x] Workflow completes green *(2026-03-20 — run 23326118265)*
  - [x] 150 tools generated *(22 modules, 150 tools)*
  - [x] mcporter can use homeapi MCP server *(4 servers registered)*

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Clean server (remove ad-hoc setup)        → Server
  Step 5: Remove local scripts from HomeAPI          → HomeAPI

Wave 2 (after wave 1):
  Step 2: Create reusable workflow                   → workflows repo
  Step 3: Create documentation                       → workflows repo

Wave 3 (after wave 2):
  Step 4: Integrate into HomeAPI deploy.yml          → HomeAPI

Wave 4 (after wave 3):
  Step 6: Test end-to-end                            → HomeAPI + Server
```

## Template for New Services

To add MCP generation to any new microservice, add to its deploy workflow:

```yaml
generate-mcp:
  needs: deploy  # or whatever the deploy job is called
  uses: 922-Studio/workflows/.github/workflows/generate-mcp.yml@main
  with:
    service_name: 'my-service'
    api_port: '3000'
    # Optional overrides:
    # openapi_path: '/api/docs/openapi.json'
    # tag_renames: '{"Some Tag":"some-tag"}'
    # auth_url: 'http://localhost:8100'
  secrets:
    AUTH_EMAIL: ${{ secrets.AUTH_EMAIL }}
    AUTH_PASSWORD: ${{ secrets.AUTH_PASSWORD }}
```

Then register in mcporter (one-time, or the workflow does it automatically).

## Post-Execution Checklist
- [x] Server cleaned up *(2026-03-20)*
- [x] Reusable workflow created and pushed *(2026-03-20)*
- [x] Documentation written *(workflows/docs + HomeStructure docs)*
- [x] HomeAPI deploy.yml updated *(2026-03-20)*
- [x] Pipeline green *(run 23326118265 — all jobs passed)*
- [x] MCP tools working *(150 tools, 22 modules, smoke test passed)*
