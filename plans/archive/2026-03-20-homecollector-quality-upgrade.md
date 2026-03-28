# Plan: HomeCollector Code Quality & Testing Upgrade

- **Date**: 2026-03-20
- **Project(s)**: HomeCollector
- **Goal**: Elevate HomeCollector from 8.1/10 to 9+/10 by fixing code quality issues, closing test gaps, and tightening tooling.

## Context

Read these files before proceeding:
- `projects/homecollector.md` — project mapping and best practices
- `/Users/gregor/dev/922/HomeCollector/CLAUDE.md` — architecture, conventions, testing strategy
- `/Users/gregor/dev/922/HomeCollector/pyproject.toml` — tooling configuration

## Steps

### Step 1: Tooling & Config Hardening
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 2
- **Description**: Tighten linting, typing, and build config.
- **Context files to read**:
  - `pyproject.toml` — current ruff/mypy/pytest config
  - `.pre-commit-config.yaml` — current hooks
- **Tasks**:
  1. Add `pythonpath = ["."]` to `[tool.pytest.ini_options]` in pyproject.toml
  2. Add ruff rules: `C901` (complexity), `S` (bandit/security) to lint select
  3. Enable stricter mypy: `disallow_untyped_defs = true`, `disallow_incomplete_defs = true`, `no_implicit_optional = true`, `warn_unreachable = true`
  4. Create `.dockerignore` (exclude venv, caches, tests, docs, .git)
  5. Fix all resulting mypy/ruff errors across the codebase (add missing type annotations, fix security warnings)
- **Acceptance criteria**:
  - [ ] `ruff check .` passes with new rules
  - [ ] `mypy app/` passes with stricter config
  - [ ] `.dockerignore` exists
  - [ ] `pytest` runs without `PYTHONPATH=.` prefix

### Step 2: Code Quality Fixes
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 1
- **Description**: Fix error handling, type hints, and code duplication issues found in analysis.
- **Context files to read**:
  - `app/services/docker_monitor.py` — bare except clauses
  - `app/services/http_monitor.py` — bare except clauses
  - `app/tasks/uptime_tasks.py` — bare except clauses
  - `app/helpers/responses.py` — missing return types
  - `app/routers/uptime.py` — range parsing helper
  - `app/routers/system.py` — duplicated range parsing
- **Tasks**:
  1. Replace bare `except Exception` with specific exceptions:
     - `docker_monitor.py`: catch `aiodocker.DockerError`, `asyncio.TimeoutError`
     - `http_monitor.py`: catch `httpx.HTTPError`, `httpx.TimeoutException`
     - `uptime_tasks.py`: catch `sqlalchemy.exc.SQLAlchemyError`
  2. Add missing return type annotations:
     - `helpers/responses.py`: `api_response() -> dict[str, Any]`, `not_found() -> NoReturn`
     - Any other functions flagged by stricter mypy (from Step 1)
  3. Extract duplicated range-parsing logic into `app/helpers/parsing.py`
  4. Add `raise ... from e` pattern where HTTPException wraps service errors (routers/github.py, allure.py, system.py)
  5. Unify service instantiation pattern in routers (use module-level singletons consistently)
- **Acceptance criteria**:
  - [ ] No bare `except Exception` in services or tasks
  - [ ] All helpers have return type annotations
  - [ ] Range parsing extracted to shared helper
  - [ ] Exception chaining used in routers
  - [ ] All existing tests still pass

### Step 3: Unit Tests — Notification Services
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 4
- **Description**: Add missing unit tests for Discord, Gmail, and OpenClaw services.
- **Context files to read**:
  - `app/services/discord.py` — Discord notification logic
  - `app/services/gmail_service.py` — Email composition and sending
  - `app/services/openclaw_client.py` — OpenClaw webhook client
  - `tests/conftest.py` — existing fixtures
  - `tests/unit/services/` — existing service test patterns
- **Tasks**:
  1. Create `tests/unit/services/test_discord.py`:
     - Test `build_embed()` output structure and field mapping
     - Test `send_discord_embed()` with mocked httpx (success, failure, timeout)
  2. Create `tests/unit/services/test_gmail_service.py`:
     - Test `_build_raw_message()` MIME construction, encoding, recipients
     - Test `send_message()` with mocked Google API client (success, failure)
     - Test `send_bulk_messages()` with partial failures
  3. Create `tests/unit/services/test_openclaw_client.py`:
     - Test webhook call construction (headers, payload)
     - Test retry/backoff behavior
     - Test timeout handling
- **Acceptance criteria**:
  - [ ] All 3 new test files exist and pass
  - [ ] Each service has happy path + error path + timeout tests
  - [ ] Mocking follows existing patterns (AsyncMock, httpx mock)
  - [ ] Allure decorators on all tests

### Step 4: Unit Tests — Core Infrastructure
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 3
- **Description**: Add tests for app startup, helpers, and schemas.
- **Context files to read**:
  - `app/main.py` — lifespan, middleware, service seeding
  - `app/helpers/responses.py` — utility helpers
  - `app/schemas/allure.py` — Allure response schemas
  - `app/schemas/github.py` — GitHub response schemas
  - `app/schemas/system.py` — System metrics schemas
  - `tests/conftest.py` — existing fixtures
- **Tasks**:
  1. Create `tests/unit/test_main.py`:
     - Test lifespan context manager (service seeding called)
     - Test middleware setup (request ID propagation)
     - Test auth exemption for public paths
  2. Create `tests/unit/helpers/test_responses.py`:
     - Test `api_response()` wraps data correctly
     - Test `not_found()` raises HTTPException with 404
  3. Expand schema tests:
     - `tests/unit/schemas/test_github.py` — validate all GitHub response models
     - `tests/unit/schemas/test_system.py` — validate system metric models
     - Expand `tests/unit/schemas/test_allure.py` — cover all Allure response types
- **Acceptance criteria**:
  - [ ] main.py lifespan tested
  - [ ] Helper functions tested
  - [ ] All schema modules have dedicated test files
  - [ ] Tests pass

### Step 5: Test Hardening — Negative Cases & Parametrize
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Description**: Add parametrized tests, negative validation cases, and error path coverage.
- **Context files to read**:
  - `tests/integration/routers/` — all integration test files
  - `tests/unit/services/` — all service test files
  - `tests/unit/tasks/` — all task test files
- **Tasks**:
  1. Add `@pytest.mark.parametrize` to tests with repeated patterns:
     - Enum value validation (monitor_type, status values)
     - Range parameter variations (1h, 24h, 7d, 30d, 90d)
     - HTTP status codes for error scenarios
  2. Add negative/validation tests to integration routers:
     - Invalid request bodies → 422 responses
     - Missing required fields → 422 responses
     - Invalid query parameters → 400/422 responses
  3. Add error path tests to tasks:
     - Partial failure scenarios (one service fails during batch poll)
     - `SoftTimeLimitExceeded` handling verification
  4. Add auth edge case tests:
     - Expired JWT tokens
     - Malformed JWT tokens
     - Missing both X-User-ID and Bearer token
- **Acceptance criteria**:
  - [ ] At least 10 new parametrized test cases
  - [ ] All POST endpoints have negative validation tests
  - [ ] Task error paths tested
  - [ ] Auth edge cases covered
  - [ ] Coverage ≥ 80%

### Step 6: Final Validation & CI Run
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: —
- **Description**: Run full quality suite, verify everything passes, commit and push.
- **Context files to read**:
  - `pyproject.toml` — verify final config
  - `.github/workflows/deploy.yml` — CI pipeline expectations
- **Tasks**:
  1. Run `ruff check .` — must pass clean
  2. Run `mypy app/` — must pass clean
  3. Run `pytest tests/ -v --cov=app --cov-fail-under=80` — target 80% coverage
  4. Verify Docker build still works: `docker compose build api`
  5. Review all changes against project best practices in `projects/homecollector.md`
  6. Commit all changes (separate commits per step for clean history)
  7. Push to main and monitor CI pipeline
- **Acceptance criteria**:
  - [ ] All linting passes
  - [ ] All type checks pass
  - [ ] All tests pass with ≥ 80% coverage
  - [ ] Docker builds successfully
  - [ ] CI pipeline green
  - [ ] Discord notification confirms successful deploy

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Tooling hardening (pyproject, mypy strict, ruff rules, .dockerignore)
          → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 2: Code quality fixes (error handling, types, dedup, exception chaining)
          → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 2 (parallel, after Wave 1):
  Step 3: Unit tests for notification services (Discord, Gmail, OpenClaw)
          → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 4: Unit tests for core infra (main.py, helpers, schemas)
          → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 3 (after Wave 2):
  Step 5: Test hardening (parametrize, negative cases, error paths)
          → HomeCollector @ /Users/gregor/dev/922/HomeCollector

Wave 4 (after Wave 3):
  Step 6: Final validation, commit, push, monitor CI
          → HomeCollector @ /Users/gregor/dev/922/HomeCollector
```

## Agent Prompts

### Step 1 Agent Prompt
```
You are working on the HomeCollector project at /Users/gregor/dev/922/HomeCollector.

Read these files first:
- CLAUDE.md (architecture and conventions)
- pyproject.toml (current tooling config)
- .pre-commit-config.yaml (current hooks)

Tasks:
1. In pyproject.toml [tool.pytest.ini_options], add: pythonpath = ["."]
2. In pyproject.toml [tool.ruff.lint], add C901 and S to the select list
3. In pyproject.toml [tool.mypy], add:
   - disallow_untyped_defs = true
   - disallow_incomplete_defs = true
   - no_implicit_optional = true
   - warn_unreachable = true
4. Create .dockerignore with: venv/, .venv/, __pycache__/, .pytest_cache/, .mypy_cache/, .ruff_cache/, .coverage, htmlcov/, *.pyc, .git/, tests/, docs/, .pre-commit-config.yaml, *.md (except CLAUDE.md)
5. Run ruff check . and mypy app/ — fix ALL resulting errors across the codebase

Do NOT add Co-Authored-By trailers to commits.
Verify: ruff check . passes, mypy app/ passes, pytest still passes.
```

### Step 2 Agent Prompt
```
You are working on the HomeCollector project at /Users/gregor/dev/922/HomeCollector.

Read these files first:
- CLAUDE.md (architecture and conventions)
- app/services/docker_monitor.py
- app/services/http_monitor.py
- app/tasks/uptime_tasks.py
- app/helpers/responses.py
- app/routers/uptime.py (look at _parse_range)
- app/routers/system.py (look at duplicated range parsing)
- app/routers/github.py, app/routers/allure.py (exception chaining)

Tasks:
1. Replace bare except Exception with specific exceptions:
   - docker_monitor.py: catch aiodocker.DockerError, asyncio.TimeoutError
   - http_monitor.py: catch httpx.HTTPError, httpx.TimeoutException
   - uptime_tasks.py: catch sqlalchemy.exc.SQLAlchemyError
2. Add missing return type annotations to helpers/responses.py
3. Extract shared range-parsing logic into app/helpers/parsing.py
4. Update uptime.py and system.py to use the shared helper
5. Add "raise ... from e" in routers where HTTPException wraps a service error
6. Run existing tests to verify nothing breaks

Do NOT add Co-Authored-By trailers to commits.
```

### Step 3 Agent Prompt
```
You are working on the HomeCollector project at /Users/gregor/dev/922/HomeCollector.

Read these files first:
- CLAUDE.md (architecture, testing strategy)
- tests/conftest.py (fixtures and patterns)
- tests/unit/services/ (all existing service tests — follow the same patterns)
- app/services/discord.py
- app/services/gmail_service.py
- app/services/openclaw_client.py

Create these test files following the EXACT patterns from existing tests (Allure decorators, AsyncMock, helper builders):

1. tests/unit/services/test_discord.py
   - Test build_embed() output structure
   - Test send_discord_embed() success, failure (HTTPError), timeout
   - Mock httpx.AsyncClient

2. tests/unit/services/test_gmail_service.py
   - Test _build_raw_message() MIME structure, encoding, recipients
   - Test send_message() success, API error
   - Test send_bulk_messages() partial failures
   - Mock Google API client

3. tests/unit/services/test_openclaw_client.py
   - Test webhook call construction
   - Test retry/backoff
   - Test timeout handling
   - Mock httpx.AsyncClient

All tests must: use Allure decorators, follow existing naming patterns, pass when run.
Do NOT add Co-Authored-By trailers to commits.
```

### Step 4 Agent Prompt
```
You are working on the HomeCollector project at /Users/gregor/dev/922/HomeCollector.

Read these files first:
- CLAUDE.md (architecture, testing strategy)
- tests/conftest.py (fixtures)
- app/main.py (lifespan, middleware, auth exemption)
- app/helpers/responses.py
- app/schemas/allure.py, app/schemas/github.py, app/schemas/system.py
- tests/unit/schemas/ (existing schema tests for patterns)

Create these test files:

1. tests/unit/test_main.py
   - Test lifespan() calls upsert_service_configs
   - Test request ID middleware propagation
   - Test auth exemption for /health, /status, /docs, /metrics

2. tests/unit/helpers/test_responses.py
   - Test api_response() wraps data in correct structure
   - Test not_found() raises HTTPException(404)

3. tests/unit/schemas/test_github.py — validate all GitHub response models
4. tests/unit/schemas/test_system.py — validate system metric response models
5. Expand tests/unit/schemas/test_allure.py — cover all Allure response types

All tests must: use Allure decorators, follow existing patterns, pass when run.
Do NOT add Co-Authored-By trailers to commits.
```

### Step 5 Agent Prompt
```
You are working on the HomeCollector project at /Users/gregor/dev/922/HomeCollector.

Read these files first:
- CLAUDE.md
- tests/integration/routers/ (all files)
- tests/unit/services/ (all files)
- tests/unit/tasks/ (all files)
- app/schemas/ (all files — for validation rules)

Tasks:
1. Add @pytest.mark.parametrize where patterns repeat:
   - Enum values (monitor_type, status)
   - Range parameters (1h, 24h, 7d, 30d)
   - Error HTTP status codes
2. Add negative validation tests to integration routers:
   - Invalid POST bodies → 422
   - Missing required fields → 422
   - Invalid query params → 400/422
3. Add task error path tests:
   - Partial failure in batch polling
   - SoftTimeLimitExceeded handling
4. Add auth edge cases:
   - Expired JWT, malformed JWT, missing both auth methods

Target: ≥ 80% overall coverage.
All tests must use Allure decorators and follow existing patterns.
Do NOT add Co-Authored-By trailers to commits.
```

### Step 6 Agent Prompt
```
You are working on the HomeCollector project at /Users/gregor/dev/922/HomeCollector.

Final validation and ship:
1. Run: ruff check .
2. Run: mypy app/
3. Run: PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=80
4. Run: docker compose build api
5. Read projects/homecollector.md and verify all changes align with best practices
6. If everything passes, commit changes with clean, descriptive messages (no Co-Authored-By)
7. Push to main
8. Monitor CI pipeline — check GitHub Actions status

Report: final coverage %, any issues found, CI status.
```

## Post-Execution Checklist
- [ ] All tests pass
- [ ] Coverage ≥ 80%
- [ ] Documentation updated (CLAUDE.md testing section if coverage target changed)
- [ ] Pipeline green
- [ ] Changes reviewed against best practices in project mapping
