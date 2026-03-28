# Plan: HomeAPI MCP Server Generation from OpenAPI Spec

- **Date**: 2026-03-20
- **Project(s)**: HomeAPI, OpenClaw (mcporter)
- **Status**: done (2026-03-20)
- **Goal**: Auto-generate per-tag MCP servers from HomeAPI's OpenAPI spec, rebuilt on every deploy, mounted for OpenClaw agents via mcporter.

## Context

Read these files before proceeding:
- `projects/homeapi.md` — project mapping and best practices
- `server.md` — server infrastructure reference
- `/Users/gregor/dev/922/HomeAPI/app/main.py` — router tags and OpenAPI setup
- `/Users/gregor/dev/922/HomeAPI/deploy.sh` — current deploy pipeline

## Architecture Decision

**Tool**: `mcp-generator-3.x` (quotentiroler/mcp-generator-3.x)
- Python-native, generates FastMCP 3.x servers
- Per-tag sub-server splitting (one module per OpenAPI tag → 20 tag-based tools)
- STDIO transport for mcporter integration
- `BACKEND_API_TOKEN` env var for auth forwarding

**Why not runtime proxy?**
- Generated code gives full control, can be versioned
- No runtime dependency on external tool binary
- Matches Python ecosystem (FastAPI → FastMCP)
- Per-tag splitting is built-in (not possible with emcee)

**Flow**:
```
HomeAPI deploy (CI/CD)
  → docker compose up (API live)
  → generate-mcp.sh runs post-deploy
    → curl openapi.json from running API
    → generate-mcp --file openapi.json
    → copy output to /home/lab/openclaw/mcp-servers/homeapi/
  → restart mcporter (or OpenClaw gateway)
  → agents have updated MCP tools
```

## HomeAPI Tags (→ MCP Sub-Servers)

These 20 tags will each become a namespaced MCP tool group:

| Tag | Endpoints | Agent Use Case |
|-----|-----------|----------------|
| `debts` | CRUD debts between people | tracker agent |
| `wellbeing` | Health/mood metrics | tracker agent |
| `ideas` | Idea capture + LLM parse | main, eggdev |
| `todos` | Task management | todos agent |
| `WorkLogs` | Work session logging | tracker agent |
| `memory` | Knowledge base + full-text search | sensei agent |
| `sync` | Google Sheets import/export | main agent |
| `prompts` | LLM prompt templates | main, coexec |
| `tasks` / `celery` | Celery task triggering | main agent |
| `openclaw` | Agent triggers, heartbeat | internal only |
| `settings` | Runtime configuration | main agent |
| `gmail` | Email read/send | main agent |
| `calendar` | Google Calendar | main agent |
| `Activity Log` | Audit logging | usage agent |
| `projects` | Project management | eggdev agent |
| `project-notes` | Notes linked to projects | eggdev agent |
| `Tasks` | Task management (distinct) | todos agent |
| `scheduled-tasks` | One-time future tasks | main agent |
| `quotes` | Quote vault | main agent |
| `cron-jobs` | Recurring scheduled jobs | main agent |

## Steps

### Step 1: Install mcp-generator-3.x on server
- **Project**: Server infrastructure
- **Directory**: `/home/lab/`
- **Parallel with**: Step 2
- **Description**: Clone and install the generator tool on the home lab server.
- **Context files to read**:
  - `server.md` — server access
- **Commands**:
  ```bash
  ssh lab
  cd /home/lab
  git clone https://github.com/quotentiroler/mcp-generator-3.x.git /home/lab/tools/mcp-generator
  cd /home/lab/tools/mcp-generator
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -e .
  # Verify
  generate-mcp --help
  ```
- **Acceptance criteria**:
  - [ ] `generate-mcp` CLI available on server
  - [ ] `fastmcp` importable in the venv

### Step 2: Create MCP config file
- **Project**: HomeAPI / OpenClaw
- **Directory**: `/home/lab/openclaw/mcp-servers/homeapi/`
- **Parallel with**: Step 1
- **Description**: Create config directory structure and auth config file for the generated MCP server.
- **Commands**:
  ```bash
  ssh lab
  mkdir -p /home/lab/openclaw/mcp-servers/homeapi
  ```
- **Config file** (`/home/lab/openclaw/mcp-servers/homeapi/mcp-config.env`):
  ```env
  # HomeAPI MCP Server Configuration
  # Backend API URL (internal Docker network)
  BACKEND_API_URL=http://home_api_api:8080
  # Auth token — obtain from HomeAuth
  # curl -s -X POST https://lab-auth.922-studio.com/auth/login \
  #   -H "Content-Type: application/json" \
  #   -d '{"username":"...","password":"..."}' | jq -r .access_token
  BACKEND_API_TOKEN=<token-here>
  # Transport
  MCP_TRANSPORT=stdio
  ```
- **Acceptance criteria**:
  - [ ] Config directory exists
  - [ ] Config file with auth token placeholder created
  - [ ] Token populated (manually or via script)

### Step 3: Generate MCP servers from OpenAPI spec
- **Project**: HomeAPI
- **Directory**: `/home/lab/openclaw/mcp-servers/homeapi/`
- **Parallel with**: —
- **Dependencies**: Step 1, Step 2
- **Description**: Fetch the live OpenAPI spec from HomeAPI and run the generator. Verify per-tag sub-servers are created.
- **Commands**:
  ```bash
  ssh lab
  # Fetch OpenAPI spec from running HomeAPI
  curl -s http://home_api_api:8080/openapi.json -o /tmp/homeapi-openapi.json
  # If not accessible via Docker network name, use localhost:
  # curl -s http://localhost:8080/openapi.json -o /tmp/homeapi-openapi.json

  # Generate MCP servers
  cd /home/lab/tools/mcp-generator
  source .venv/bin/activate
  generate-mcp --file /tmp/homeapi-openapi.json

  # Copy generated output
  cp -r generated_mcp/* /home/lab/openclaw/mcp-servers/homeapi/
  cp -r generated_openapi /home/lab/openclaw/mcp-servers/homeapi/
  ```
- **Verify**:
  ```bash
  ls /home/lab/openclaw/mcp-servers/homeapi/servers/
  # Expected: one .py file per tag (debts.py, wellbeing.py, gmail.py, etc.)
  ```
- **Acceptance criteria**:
  - [ ] OpenAPI spec successfully fetched
  - [ ] Generator runs without errors
  - [ ] `servers/` directory contains per-tag modules
  - [ ] Main entry point file exists (`*_mcp_generated.py`)

### Step 4: Install Python dependencies for generated server
- **Project**: OpenClaw MCP
- **Directory**: `/home/lab/openclaw/mcp-servers/homeapi/`
- **Parallel with**: —
- **Dependencies**: Step 3
- **Description**: Install the generated server's dependencies (fastmcp, etc.).
- **Commands**:
  ```bash
  ssh lab
  cd /home/lab/openclaw/mcp-servers/homeapi
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -e .
  # Or if no pyproject.toml: pip install fastmcp httpx pydantic
  ```
- **Acceptance criteria**:
  - [ ] All dependencies installed in venv
  - [ ] Server starts without import errors

### Step 5: Test MCP server locally
- **Project**: OpenClaw MCP
- **Directory**: `/home/lab/openclaw/mcp-servers/homeapi/`
- **Parallel with**: —
- **Dependencies**: Step 4
- **Description**: Test the generated MCP server can start and list tools.
- **Commands**:
  ```bash
  ssh lab
  cd /home/lab/openclaw/mcp-servers/homeapi
  source .venv/bin/activate
  export BACKEND_API_TOKEN="<token>"

  # Test 1: Server starts
  python *_mcp_generated.py --transport stdio &
  MCP_PID=$!

  # Test 2: List tools via fastmcp CLI
  fastmcp list-tools *_mcp_generated.py:create_server

  # Test 3: Quick API call test (e.g. list quotes)
  # This will depend on the exact tool names generated

  kill $MCP_PID
  ```
- **Acceptance criteria**:
  - [ ] Server starts without errors
  - [ ] Tools listed show per-tag namespaced operations
  - [ ] At least one tool call succeeds against live HomeAPI

### Step 6: Create build/deploy script
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI/scripts/`
- **Parallel with**: —
- **Dependencies**: Step 5 (confirmed working)
- **Description**: Create `generate-mcp.sh` that rebuilds the MCP server from the latest OpenAPI spec. This script runs as a post-deploy hook.
- **Script** (`/Users/gregor/dev/922/HomeAPI/scripts/generate-mcp.sh`):
  ```bash
  #!/bin/bash
  set -e

  # --- Config ---
  MCP_GENERATOR_DIR="/home/lab/tools/mcp-generator"
  MCP_OUTPUT_DIR="/home/lab/openclaw/mcp-servers/homeapi"
  API_URL="http://localhost:8080"
  CONFIG_FILE="${MCP_OUTPUT_DIR}/mcp-config.env"

  echo "=== HomeAPI MCP Generation ==="

  # 1. Wait for API to be healthy
  echo "Waiting for HomeAPI to be ready..."
  for i in $(seq 1 30); do
    if curl -sf "${API_URL}/health" > /dev/null 2>&1; then
      echo "API is ready."
      break
    fi
    [ "$i" -eq 30 ] && echo "ERROR: API not ready after 30s" && exit 1
    sleep 1
  done

  # 2. Fetch latest OpenAPI spec
  echo "Fetching OpenAPI spec..."
  curl -sf "${API_URL}/openapi.json" -o /tmp/homeapi-openapi.json
  echo "Spec fetched ($(wc -c < /tmp/homeapi-openapi.json) bytes)"

  # 3. Generate MCP servers
  echo "Generating MCP servers..."
  cd "${MCP_GENERATOR_DIR}"
  source .venv/bin/activate

  # Clean previous generation
  rm -rf generated_mcp generated_openapi

  generate-mcp --file /tmp/homeapi-openapi.json

  # 4. Deploy to MCP output directory (preserve config + venv)
  echo "Deploying generated files..."

  # Remove old generated files but keep config and venv
  find "${MCP_OUTPUT_DIR}" -maxdepth 1 \
    ! -name 'mcp-config.env' \
    ! -name '.venv' \
    ! -name '.' \
    -exec rm -rf {} + 2>/dev/null || true

  cp -r generated_mcp/* "${MCP_OUTPUT_DIR}/"
  cp -r generated_openapi "${MCP_OUTPUT_DIR}/"

  # 5. Install/update dependencies
  echo "Installing dependencies..."
  cd "${MCP_OUTPUT_DIR}"
  source .venv/bin/activate
  pip install -e . --quiet 2>/dev/null || pip install fastmcp httpx pydantic --quiet

  # 6. Verify
  echo "Verifying..."
  TOOL_COUNT=$(find "${MCP_OUTPUT_DIR}/servers/" -name "*.py" ! -name "__init__.py" | wc -l)
  echo "Generated ${TOOL_COUNT} MCP sub-servers"

  echo "=== MCP Generation Complete ==="
  ```
- **Acceptance criteria**:
  - [ ] Script runs end-to-end on server
  - [ ] Preserves config file and venv across regenerations
  - [ ] Reports tool count

### Step 7: Integrate into HomeAPI deploy pipeline
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI/`
- **Parallel with**: —
- **Dependencies**: Step 6
- **Description**: Add MCP generation as a post-deploy step in `deploy.sh`.
- **Change to** `deploy.sh`: Add after the `docker compose up -d` block:
  ```bash
  # Generate MCP servers from latest OpenAPI spec
  echo "Regenerating MCP servers..."
  bash ~/HomeAPI/scripts/generate-mcp.sh || echo "WARNING: MCP generation failed (non-blocking)"
  ```
- **Acceptance criteria**:
  - [ ] `deploy.sh` includes MCP generation step
  - [ ] MCP generation failure does NOT block deployment (non-blocking with `||`)

### Step 8: Register in mcporter config
- **Project**: OpenClaw
- **Directory**: `/home/lab/openclaw/workspace/config/`
- **Parallel with**: —
- **Dependencies**: Step 5
- **Description**: Add the HomeAPI MCP server to mcporter.json so agents can use it.
- **Context files to read**:
  - `/home/lab/openclaw/workspace/config/mcporter.json` — existing MCP config
- **Change**: Add to `mcpServers` object:
  ```json
  "homeapi": {
    "command": "/home/lab/openclaw/mcp-servers/homeapi/.venv/bin/python",
    "args": ["/home/lab/openclaw/mcp-servers/homeapi/<entry_point>_mcp_generated.py", "--transport", "stdio"],
    "env": {
      "BACKEND_API_TOKEN": "<token-from-config>"
    }
  }
  ```
  (Replace `<entry_point>` with the actual generated filename after Step 3)
- **Then**: Restart gateway
  ```bash
  systemctl restart openclaw-gateway
  ```
- **Acceptance criteria**:
  - [ ] mcporter.json updated with homeapi server
  - [ ] Gateway restarts cleanly
  - [ ] Agents can discover HomeAPI tools via mcporter

### Step 9: End-to-end test
- **Project**: OpenClaw
- **Directory**: `/home/lab/openclaw/`
- **Parallel with**: —
- **Dependencies**: Step 8
- **Description**: Test that an agent can use the HomeAPI MCP tools through mcporter.
- **Tests**:
  1. Via mcporter CLI: `mcporter call homeapi.quotes_list_quotes`
  2. Via agent: Ask main agent in Discord to "list my quotes using the HomeAPI MCP"
  3. Verify namespaced tools: `mcporter list-tools homeapi`
- **Acceptance criteria**:
  - [ ] mcporter lists HomeAPI tools with tag namespaces
  - [ ] At least one read operation succeeds (e.g. list quotes)
  - [ ] At least one write operation succeeds (e.g. create a test quote, then delete it)

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Install mcp-generator-3.x        → Server @ /home/lab/tools/
  Step 2: Create config directory + env     → Server @ /home/lab/openclaw/mcp-servers/homeapi/

Wave 2 (after wave 1):
  Step 3: Generate MCP from OpenAPI spec    → Server @ /home/lab/openclaw/mcp-servers/homeapi/

Wave 3 (after wave 2):
  Step 4: Install generated server deps     → Server @ /home/lab/openclaw/mcp-servers/homeapi/

Wave 4 (after wave 3):
  Step 5: Test MCP server locally           → Server @ /home/lab/openclaw/mcp-servers/homeapi/

Wave 5 (after wave 4):
  Step 6: Create generate-mcp.sh script     → HomeAPI @ scripts/
  Step 7: Integrate into deploy.sh          → HomeAPI @ deploy.sh
  Step 8: Register in mcporter config       → Server @ /home/lab/openclaw/workspace/config/

Wave 6 (after wave 5):
  Step 9: End-to-end test                   → Server @ /home/lab/openclaw/
```

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Generator doesn't handle all FastAPI response types | Test first, patch generator or simplify spec |
| Auth token expires | Use long-lived service token from HomeAuth, or add token refresh to generate-mcp.sh |
| MCP tool names too long (tag + operation) | Configure name abbreviations in generator's config.py |
| OpenAPI spec not accessible from host network | Fall back to `curl localhost:8080/openapi.json` or fetch from Docker container |
| Generated code breaks on HomeAPI schema changes | generate-mcp.sh runs on every deploy, always matches latest spec |

## Post-Execution Checklist
- [ ] All tests pass
- [ ] generate-mcp.sh committed to HomeAPI repo
- [ ] deploy.sh updated and committed
- [ ] Pipeline green after push
- [ ] mcporter config updated on server
- [ ] Agents can use HomeAPI tools via MCP
