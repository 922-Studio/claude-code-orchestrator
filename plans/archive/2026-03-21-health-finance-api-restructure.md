# Plan: Health/Finance API Restructure + Frontend Fix + Test Quality

- **Date**: 2026-03-21
- **Project(s)**: HomeAPI, Discord Bot, HomeUI
- **Goal**: Restructure HomeAPI router files and URL paths to match HomeUI's domain layout (`/api/health/sleep/` and `/api/finance/ledger/`), fix broken frontend data display, and replace false-positive tests with real assertions.

---

## Context

Read these files before proceeding:
- `projects/homeapi.md` — architecture, URL structure, testing strategy
- `projects/homeui.md` — frontend patterns, API integration, test patterns
- `/Users/gregor/dev/922/HomeAPI/CLAUDE.md` — router/CRUD/schema patterns
- `/Users/gregor/dev/922/HomeUI/CLAUDE.md` — feature module patterns, test rules
- `/Users/gregor/dev/922/HomeUI/.claude/HOW-TO-UNIT-TEST.md` — MSW patterns, mock strategy
- `/Users/gregor/dev/922/HomeUI/.claude/skills/e2e.md` — E2E patterns

## Background: What's Broken and Why

### URL Mismatch (root cause)
HomeUI routes were restructured to `/health/sleep` and `/finance/ledger` but HomeAPI still serves:
- `POST/GET /api/wellbeing/...`
- `GET/POST/PATCH/DELETE /api/debts/...`

### Bug 1: Trailing slash missing
`createDebt()` in HomeUI calls `POST /api/debts` (no trailing slash) — HomeAPI expects `/api/debts/`.
After refactor: endpoint will be `/api/finance/ledger/` — must match.

### Bug 2: False-positive tests in HomeUI
MSW default handlers in `src/test/msw/handlers.ts` return empty `[]` for all debts and wellbeing endpoints.
Component tests that don't override handlers still PASS because they only assert on labels/DOM structure, never on rendered data values.
E2E tests mock the old URL patterns (`**/api/wellbeing/entries*`, `**/api/debts/*`) — after the URL change these mocks won't intercept anything, causing E2E tests to fail or hit real API.

### Bug 3: Discord bot URL dependency
`discord/services/homeapi.py` calls:
- `POST {base}/debts/parse`
- `POST {base}/debts/`
- `GET {base}/debts/`
- `GET {base}/debts/summary`
- `POST {base}/wellbeing/ingest`

All five calls must be updated to new paths.

---

## Steps

### Step 1: HomeAPI — Restructure Routers + Update URLs
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (must be first; all other steps depend on these new URLs)
- **Description**:
  1. Read `CLAUDE.md`, `app/main.py`, `app/routers/wellbeing.py`, `app/routers/debt.py`
  2. Create `app/routers/health/__init__.py` (empty)
  3. Move `app/routers/wellbeing.py` → `app/routers/health/sleep.py`
     - Update all internal imports (e.g. `from app.crud import wellbeing`, `from app.schemas import wellbeing`) — imports stay the same, only file location changes
     - The `router = APIRouter()` prefix in this file stays as-is (prefix is set in `main.py`)
  4. Create `app/routers/finance/__init__.py` (empty)
  5. Move `app/routers/debt.py` → `app/routers/finance/ledger.py`
     - Same as above: only file location changes, internal imports unchanged
  6. Update `app/main.py`:
     - Change: `from app.routers import wellbeing` → `from app.routers.health import sleep`
     - Change: `from app.routers import debt` → `from app.routers.finance import ledger`
     - Change router registration:
       - `app.include_router(wellbeing.router, prefix="/api")` → `app.include_router(sleep.router, prefix="/api/health/sleep", tags=["health/sleep"])`
       - `app.include_router(debt.router, prefix="/api")` → `app.include_router(ledger.router, prefix="/api/finance/ledger", tags=["finance/ledger"])`
     - **IMPORTANT**: The routers currently define their own sub-prefixes like `/wellbeing` and `/debts` inside the router file. After moving the prefix to `main.py`, remove the redundant sub-prefix from the router itself. Verify by checking what prefix the `APIRouter()` is instantiated with inside the router files.
  7. Run locally: `PYTHONPATH=. pytest tests/ -x -q` — verify all tests still pass (they will FAIL on integration tests, fix those in Step 2)
- **Context files to read**:
  - `app/main.py` — current router registration (lines 137-156 approx)
  - `app/routers/wellbeing.py` — current router prefix and endpoint paths
  - `app/routers/debt.py` — current router prefix and endpoint paths
- **Acceptance criteria**:
  - [ ] `app/routers/health/__init__.py` and `app/routers/health/sleep.py` exist
  - [ ] `app/routers/finance/__init__.py` and `app/routers/finance/ledger.py` exist
  - [ ] Old files `app/routers/wellbeing.py` and `app/routers/debt.py` deleted
  - [ ] `app/main.py` imports and registers routers with new prefixes
  - [ ] `GET /api/health/sleep/metrics` returns 200 (curl test or manual)
  - [ ] `GET /api/finance/ledger/` returns 200 (curl test or manual)

---

### Step 2: HomeAPI — Update Integration Tests
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (after Step 1)
- **Description**:
  1. Read `tests/integration/routers/test_wellbeing.py` and `tests/integration/routers/test_debt.py` fully
  2. Create `tests/integration/routers/health/__init__.py` (empty)
  3. Move `tests/integration/routers/test_wellbeing.py` → `tests/integration/routers/health/test_sleep.py`
     - Update ALL URL strings: replace every `/api/wellbeing/` with `/api/health/sleep/`
     - Update module imports if any reference `routers.wellbeing` → `routers.health.sleep`
  4. Create `tests/integration/routers/finance/__init__.py` (empty)
  5. Move `tests/integration/routers/test_debt.py` → `tests/integration/routers/finance/test_ledger.py`
     - Update ALL URL strings: replace every `/api/debts/` with `/api/finance/ledger/`
     - Update module imports if any reference `routers.debt` → `routers.finance.ledger`
  6. Delete old test files
  7. Run: `PYTHONPATH=. pytest tests/integration/ -x -q`
  8. Fix any failures until all integration tests pass
  9. Run full suite: `PYTHONPATH=. pytest tests/ -x -q` — all must pass
- **Context files to read**:
  - `tests/integration/routers/test_wellbeing.py` — current URL paths
  - `tests/integration/routers/test_debt.py` — current URL paths
  - `.claude/HOW-TO-PYTEST-TEST.md` — test patterns
- **Acceptance criteria**:
  - [ ] `tests/integration/routers/health/test_sleep.py` exists with all `/api/health/sleep/` paths
  - [ ] `tests/integration/routers/finance/test_ledger.py` exists with all `/api/finance/ledger/` paths
  - [ ] Old integration test files deleted
  - [ ] `PYTHONPATH=. pytest tests/ -x -q` passes with ≥70% coverage
  - [ ] No test references the old paths `/api/wellbeing/` or `/api/debts/`

---

### Step 3: HomeAPI — Commit and Push
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (after Step 2)
- **Description**:
  1. `git add` all changed and new files
  2. Commit: `refactor: restructure routers to health/sleep and finance/ledger domains`
  3. `git push origin main`
  4. Monitor CI pipeline — Discord notification must be green before proceeding
- **Acceptance criteria**:
  - [ ] CI pipeline green
  - [ ] Discord deploy notification received
  - [ ] Live API: `curl https://lab-api.922-studio.com/api/health/sleep/metrics` returns 200

---

### Step 4: Discord Bot — Update API Client URLs
- **Project**: Discord Bot
- **Directory**: `/Users/gregor/dev/922/discord`
- **Parallel with**: Step 5 (HomeUI API layer — both depend only on Step 3 being done)
- **Description**:
  1. Read `services/homeapi.py` fully
  2. Update all URL paths:
     - `{base}/debts/parse` → `{base}/finance/ledger/parse`
     - `{base}/debts/` (POST save_debt) → `{base}/finance/ledger/`
     - `{base}/debts/` (GET list_debts) → `{base}/finance/ledger/`
     - `{base}/debts/summary` → `{base}/finance/ledger/summary`
     - `{base}/wellbeing/ingest` → `{base}/health/sleep/ingest`
  3. If there are any other files in `cogs/` or `services/` that call HomeAPI with old paths, update them too (search for `/debts` and `/wellbeing`)
  4. Test by running the Discord bot locally (if feasible) or verify via integration smoke test
  5. Commit: `fix: update HomeAPI endpoint paths to health/sleep and finance/ledger`
  6. Push and monitor CI
- **Context files to read**:
  - `services/homeapi.py` — all HTTP calls
  - `cogs/debt.py` — how responses are consumed
  - `cogs/wellbeing.py` — how responses are consumed
- **Acceptance criteria**:
  - [ ] No references to `/debts/` or `/wellbeing/` remain in `services/homeapi.py`
  - [ ] All 5 call paths updated to new URLs
  - [ ] CI pipeline green

---

### Step 5: HomeUI — Update API Call URLs + Fix Trailing Slash
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 4
- **Description**:
  1. Read `src/api/debts.ts`, `src/features/wellbeing/api/wellbeing.ts` fully
  2. Update `src/api/debts.ts` — change all paths:
     - `GET /api/debts/` → `GET /api/finance/ledger/`
     - `GET /api/debts/${id}` → `GET /api/finance/ledger/${id}`
     - `POST /api/debts` → `POST /api/finance/ledger/` ← **fix trailing slash bug here**
     - `DELETE /api/debts/${id}` → `DELETE /api/finance/ledger/${id}`
     - `GET /api/debts/summary` → `GET /api/finance/ledger/summary`
     - `POST /api/debts/parse` → `POST /api/finance/ledger/parse`
  3. Update `src/features/wellbeing/api/wellbeing.ts` — change all paths:
     - `GET /api/wellbeing/entries` → `GET /api/health/sleep/entries`
     - `GET /api/wellbeing/metrics` → `GET /api/health/sleep/metrics`
  4. Search the entire `src/` directory for any remaining references to `/api/debts` or `/api/wellbeing` and update them
- **Context files to read**:
  - `src/api/debts.ts` — current URL paths
  - `src/features/wellbeing/api/wellbeing.ts` — current URL paths
  - `CLAUDE.md` — API integration patterns
- **Acceptance criteria**:
  - [ ] No references to `/api/debts` or `/api/wellbeing` remain in `src/`
  - [ ] `createDebt()` calls `POST /api/finance/ledger/` (with trailing slash)
  - [ ] Wellbeing API calls use `/api/health/sleep/`

---

### Step 6: HomeUI — Fix MSW Handlers + Unit Test False Positives
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (after Step 5)
- **Description**:

  **Part A: Fix MSW default handlers** (`src/test/msw/handlers.ts`)
  1. Read `src/test/msw/handlers.ts` fully
  2. Update ALL mock URL patterns from old paths to new paths:
     - `*/api/debts/` → `*/api/finance/ledger/`
     - `*/api/debts/summary` → `*/api/finance/ledger/summary`
     - `*/api/wellbeing/entries` → `*/api/health/sleep/entries`
     - `*/api/wellbeing/metrics` → `*/api/health/sleep/metrics`
  3. Replace empty array `[]` default responses with meaningful mock fixtures that match the real response shapes (`DebtResponseSchema`, `WellbeingEntryResponseSchema`)

  **Part B: Fix LedgerPage unit tests** (`src/features/debts/pages/LedgerPage.test.tsx`)
  1. Read the test file fully
  2. For every test that sets up data state (via hook mocks), add assertions that the actual data VALUES appear in the DOM — not just labels
     - Example: if mock returns `amount: "25.50"` and `person_name: "Alice"`, assert `screen.getByText('25.50')` and `screen.getByText('Alice')` are present
  3. Add a test case: **"shows empty state message when no debts"** — mock hooks return `[]`, assert the empty state element renders
  4. Add a test case: **"shows error state when API fails"** — mock hook returns `isError: true`, assert error UI renders
  5. Ensure at least one test verifies that the `useDebts` hook is actually called (not silently skipped)

  **Part C: Fix WellbeingTrendPage unit tests** (`src/features/wellbeing/pages/WellbeingTrendPage.test.tsx`)
  1. Read the test file fully
  2. Same approach as Part B: add data value assertions to tests that set up data
  3. Verify mock data shapes match `WellbeingEntryResponseSchema` and `WellbeingMetricResponseSchema` exactly (types: `numeric_value` is `string | null`, not `number`)
  4. Add or strengthen: **"shows empty state"** and **"shows error state"** tests

  **Part D: Fix HealthOverviewPage tests** (`src/features/health/pages/HealthOverviewPage.test.tsx`)
  1. Read the test file (if it exists; may need to be created)
  2. Ensure tests verify that wellbeing entry data (metric_key, numeric_value) renders in the table
  3. Mock response must use correct field names from `WellbeingEntryResponseSchema`

- **Context files to read**:
  - `src/test/msw/handlers.ts` — current mock handlers
  - `src/features/debts/pages/LedgerPage.test.tsx` — current assertions
  - `src/features/wellbeing/pages/WellbeingTrendPage.test.tsx` — current assertions
  - `.claude/HOW-TO-UNIT-TEST.md` — MSW patterns, mock strategy
- **Acceptance criteria**:
  - [ ] MSW handlers use new URL patterns (`/api/finance/ledger/`, `/api/health/sleep/`)
  - [ ] MSW default handlers return shaped mock data, not empty arrays
  - [ ] LedgerPage tests assert actual data values in DOM (amounts, person names)
  - [ ] WellbeingTrendPage tests assert actual data values in DOM
  - [ ] Each page has a test that would fail if data was absent (data assertion, not just label assertion)
  - [ ] `npm run test:ci` passes

---

### Step 7: HomeUI — Fix E2E Test URL Mocks
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (after Step 5; can run in parallel with Step 6)
- **Description**:
  1. Read `e2e/wellbeing/wellbeing.spec.ts`, `e2e/ledger/ledger.spec.ts`, `e2e/health/health-overview.spec.ts`
  2. Update ALL mock route patterns in each file:
     - `**/api/wellbeing/entries*` → `**/api/health/sleep/entries*`
     - `**/api/wellbeing/metrics*` → `**/api/health/sleep/metrics*`
     - `**/api/debts/*` → `**/api/finance/ledger/*`
     - `**/api/debts/summary` → `**/api/finance/ledger/summary`
  3. Verify mock response shapes still match updated schemas
  4. For `e2e/ledger/ledger.spec.ts`: confirm route navigation goes to `/finance/ledger` (not old path)
  5. For `e2e/wellbeing/wellbeing.spec.ts`: confirm route navigation goes to `/health/sleep`
  6. Run: `npm run test:e2e` — all E2E tests must pass
  7. Fix any failures
- **Context files to read**:
  - `e2e/wellbeing/wellbeing.spec.ts`
  - `e2e/ledger/ledger.spec.ts`
  - `e2e/health/health-overview.spec.ts`
  - `.claude/skills/e2e.md` — E2E patterns and auth mocking
- **Acceptance criteria**:
  - [ ] No E2E mock references to old URL patterns
  - [ ] E2E tests navigate to correct routes (`/health/sleep`, `/finance/ledger`)
  - [ ] `npm run test:e2e` passes fully

---

### Step 8: HomeUI — Commit and Push
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (after Steps 6 and 7)
- **Description**:
  1. Run `npm run test:ci` one final time — must pass
  2. Run `npm run test:e2e` one final time — must pass
  3. `git add` all changed files
  4. Commit: `fix: update API paths to health/sleep and finance/ledger, fix trailing slash, improve test assertions`
  5. `git push origin main`
  6. Monitor CI pipeline — Discord notification must be green
  7. Verify live at `https://lab.922-studio.com/finance/ledger` and `https://lab.922-studio.com/health/sleep`
- **Acceptance criteria**:
  - [ ] CI pipeline green
  - [ ] Discord deploy notification received
  - [ ] `/finance/ledger` displays debt data (not empty)
  - [ ] `/health/sleep` displays wellbeing trend data (not empty)

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: HomeAPI router restructure + URL change → HomeAPI @ /Users/gregor/dev/922/HomeAPI

Wave 2 (after Step 1):
  Step 2: HomeAPI integration test migration → HomeAPI @ /Users/gregor/dev/922/HomeAPI

Wave 3 (after Step 2):
  Step 3: Commit + push HomeAPI → HomeAPI @ /Users/gregor/dev/922/HomeAPI
          (wait for CI green before Wave 4)

Wave 4 (parallel, after Step 3 CI is green):
  Step 4: Discord Bot URL update → discord @ /Users/gregor/dev/922/discord
  Step 5: HomeUI API URL update + trailing slash fix → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 5 (after Step 5):
  Step 6: HomeUI MSW + unit test quality fix → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 7: HomeUI E2E test URL fix → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 6 (after Steps 6 + 7):
  Step 8: Commit + push HomeUI → HomeUI @ /Users/gregor/dev/922/HomeUI
```

---

## Key URL Mapping Reference

| Old URL | New URL | Consumer(s) |
|---------|---------|-------------|
| `/api/wellbeing/entries` | `/api/health/sleep/entries` | HomeUI, Discord |
| `/api/wellbeing/metrics` | `/api/health/sleep/metrics` | HomeUI |
| `/api/wellbeing/dashboard` | `/api/health/sleep/dashboard` | HomeUI (if used) |
| `/api/wellbeing/ingest` | `/api/health/sleep/ingest` | Discord |
| `/api/wellbeing/parse` | `/api/health/sleep/parse` | HomeUI (if used) |
| `/api/wellbeing/metric-todos` | `/api/health/sleep/metric-todos` | HomeUI (if used) |
| `/api/debts/` | `/api/finance/ledger/` | HomeUI, Discord |
| `/api/debts/summary` | `/api/finance/ledger/summary` | HomeUI, Discord |
| `/api/debts/parse` | `/api/finance/ledger/parse` | HomeUI, Discord |
| `/api/debts/{id}` | `/api/finance/ledger/{id}` | HomeUI |
| `/api/debts/persons/{name}/history` | `/api/finance/ledger/persons/{name}/history` | HomeUI |

## File Restructuring Reference

| Old File | New File |
|----------|----------|
| `app/routers/wellbeing.py` | `app/routers/health/sleep.py` |
| `app/routers/debt.py` | `app/routers/finance/ledger.py` |
| `tests/integration/routers/test_wellbeing.py` | `tests/integration/routers/health/test_sleep.py` |
| `tests/integration/routers/test_debt.py` | `tests/integration/routers/finance/test_ledger.py` |

---

## Post-Execution Checklist
- [ ] All HomeAPI tests pass (`PYTHONPATH=. pytest tests/ -x -q`)
- [ ] HomeUI unit tests pass (`npm run test:ci`)
- [ ] HomeUI E2E tests pass (`npm run test:e2e`)
- [ ] CI pipeline green for HomeAPI (Discord notification)
- [ ] CI pipeline green for HomeUI (Discord notification)
- [ ] Live `/finance/ledger` shows debt data
- [ ] Live `/health/sleep` shows wellbeing trend data
- [ ] Discord bot can still parse and save debts + log wellbeing
- [ ] No test references old URL patterns (`/api/wellbeing/`, `/api/debts/`)
