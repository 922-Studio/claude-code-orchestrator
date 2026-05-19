# Plan: HomeAPI — Fix CI Failure: Register OpenClaw Router in main.py

- **Date**: 2026-05-19
- **Project(s)**: HomeAPI
- **Issue**: [#41](https://github.com/922-Studio/HomeAPI/issues/41) — CI run #390 on `dev`: 13 tests fail, all in `tests/integration/routers/test_openclaw.py`
- **Goal**: Register the fully-implemented OpenClaw router in `app/main.py` so all 13 tests pass and CI goes green.

## Root Cause

All 13 failing tests return HTTP 404 because `app/routers/openclaw.py` was never registered in `app/main.py`. The router, its schemas, services, and tests were committed to `dev` but the wiring was omitted.

Three things are missing from `app/main.py`:

| Missing | Required by |
|---------|-------------|
| `import httpx` | lifespan — creates `AsyncClient` |
| `from app.routers import openclaw` | `app.include_router(...)` call |
| `from config import OPENCLAW_BASE_URL, OPENCLAW_WEBHOOK_TOKEN` | `AsyncClient` constructor |
| Lifespan: create/close `app.state.openclaw_client` | `openclaw_status`, `trigger_agent_endpoint` — both call `request.app.state.openclaw_client` |
| `app.include_router(openclaw.router, ...)` | routes exist at runtime |

## Context

Read before touching anything:

- `app/main.py` — where all changes land
- `app/routers/openclaw.py` — endpoints; `openclaw_status` and `trigger_agent_endpoint` read `request.app.state.openclaw_client`
- `app/services/openclaw_client.py` — `trigger_agent()`, `wake()` consume the async `httpx.AsyncClient`
- `config.py` — `OPENCLAW_BASE_URL`, `OPENCLAW_WEBHOOK_TOKEN` (lines 87–88)
- `tests/conftest.py` — `client` fixture uses `with TestClient(app) as c:` which triggers lifespan
- `tests/integration/routers/test_openclaw.py` — 13 integration tests; all service calls are mocked at the router namespace, so `app.state.openclaw_client` is created by lifespan but never called directly

## Design Decisions

### httpx.AsyncClient lifecycle in lifespan

The `openclaw_client` service functions (`wake`, `trigger_agent`) accept a pre-built `httpx.AsyncClient` rather than creating one per call. This client is created once in the FastAPI lifespan and stored in `app.state`, which is the canonical pattern for shared async resources in FastAPI. The `TestClient` context manager triggers the lifespan, so tests get a properly initialized `app.state.openclaw_client` without any conftest changes.

### No conftest changes needed

All 13 failing tests already mock `wake`, `trigger_agent`, and `_get_sync_redis` at the `app.routers.openclaw.*` namespace, so the real httpx.AsyncClient in `app.state` is never called during tests — it only needs to exist.

### No new env vars

`OPENCLAW_BASE_URL` and `OPENCLAW_WEBHOOK_TOKEN` are already defined in `config.py` (lines 87–88) and present in `.env.example` (lines 83–84). No config changes required.

---

## Steps

### Step 1: Register OpenClaw router in `app/main.py`

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Branch**: `feat/fix-openclaw-router-registration`
- **Worktree**: `HomeAPI/.worktrees/feat/fix-openclaw-router-registration`

**Exact changes to `app/main.py`:**

1. Add `import httpx` (after existing stdlib/third-party imports, before fastapi imports)

2. Add `openclaw` to the existing `from app.routers import (...)` block:
   ```python
   from app.routers import (
       activity_log,
       calendar,
       cron_job,
       gmail,
       idea,
       memory,
       modules,
       openclaw,          # ← add
       project,
       ...
   )
   ```

3. Extend the existing config import:
   ```python
   from config import CORS_ORIGINS, OPENCLAW_BASE_URL, OPENCLAW_WEBHOOK_TOKEN
   ```

4. Replace the existing `lifespan` body:
   ```python
   @asynccontextmanager
   async def lifespan(app: FastAPI):
       """Manage async resources: OpenClaw HTTP client lifecycle."""
       app.state.openclaw_client = httpx.AsyncClient(
           base_url=OPENCLAW_BASE_URL,
           headers={"Authorization": f"Bearer {OPENCLAW_WEBHOOK_TOKEN}"},
           timeout=10.0,
       )
       yield
       await app.state.openclaw_client.aclose()
       await engine.dispose()
   ```

5. Add router registration after `ledger` and `invoices`:
   ```python
   app.include_router(openclaw.router, prefix="/api", tags=["openclaw"])
   ```

**Acceptance criteria:**
- [ ] `import httpx` present in `main.py`
- [ ] `openclaw` imported from `app.routers`
- [ ] `OPENCLAW_BASE_URL`, `OPENCLAW_WEBHOOK_TOKEN` imported from `config`
- [ ] `lifespan` creates `app.state.openclaw_client` on startup and closes it on teardown
- [ ] `app.include_router(openclaw.router, prefix="/api", tags=["openclaw"])` added
- [ ] All 13 tests in `tests/integration/routers/test_openclaw.py` pass locally
- [ ] Full test suite passes (excluding any pre-existing unrelated failures)
- [ ] `ruff check app/main.py` exits 0
- [ ] `mypy app/ --ignore-missing-imports` exits 0

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Single wave — one file, one commit:

  Step 1: Patch app/main.py
    - Project: HomeAPI
    - Directory: /Users/gregor/dev/922/HomeAPI/.worktrees/feat/fix-openclaw-router-registration
    - Parallel: —
    - Files changed: app/main.py only
    - Verify: PYTHONPATH=. pytest tests/integration/routers/test_openclaw.py -v
    - Full suite: PYTHONPATH=. pytest tests/ -x -q --ignore=tests/integration/routers/test_openclaw.py (sanity) + pytest tests/integration/routers/test_openclaw.py
    - Lint: ruff check app/main.py && mypy app/ --ignore-missing-imports
    - PR: against dev, references issue #41
```

---

## Post-Execution Checklist

- [ ] `GET /api/openclaw/status` reachable in OpenAPI `/docs` under tag `openclaw`
- [ ] All 13 `test_openclaw.py` tests pass locally
- [ ] Full CI suite green on PR branch
- [ ] PR opened against `dev`, body references issue #41
- [ ] Worktree removed after PR URL captured
