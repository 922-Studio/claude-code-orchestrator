# Plan: Remove Coverage from E2E Tests & Delete from Prometheus

- **Date**: 2026-03-22
- **Status**: DONE (2026-03-22)
- **Project(s)**: workflows, HomeUI, Portfolio, HomeCollector, HomeStructure + HomeAPI, HomeAuth, HomeSocial, discord, Anime-API, Anime-APP, sweatvalley_bingo
- **Goal**: Remove V8 coverage collection from all E2E tests and delete the entire coverage-in-Prometheus pipeline (pushgateway metrics, HomeCollector endpoints, HomeUI dashboard widgets).

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI project mapping
- `projects/homecollector.md` — HomeCollector project mapping
- `projects/homestructure.md` — HomeStructure project mapping
- `projects/portfolio.md` — Portfolio project mapping

## Scope

**What we're removing:**
1. E2E coverage collection (monocart-reporter) from Playwright configs
2. Coverage push-to-Pushgateway steps from all 3 reusable CI workflows
3. Coverage-related Prometheus queries and API endpoints from HomeCollector
4. Coverage display widgets from HomeUI dashboard
5. Pushgateway service from HomeStructure monitoring stack
6. Pushgateway scrape job from Prometheus config
7. Existing coverage metrics data from Pushgateway persistence

**What we're keeping:**
- Unit/integration test coverage enforcement (pytest `--cov-fail-under=70`, Vitest coverage)
- Coverage reported locally in CI logs (for developer feedback)
- Allure test result reporting (unrelated to coverage metrics)

## Steps

### Step 1: Remove monocart-reporter from HomeUI Playwright config
- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: Steps 2, 3
- **Description**: Remove the `monocart-reporter` entry from the CI reporter array in `playwright.config.ts`. Keep `list` and `allure-playwright` reporters. Remove `monocart-reporter` from `package.json` dependencies. Delete any coverage output dirs if configured (e.g., `coverage/e2e/`).
- **Context files to read**:
  - `playwright.config.ts` — current reporter config
  - `package.json` — monocart dependency
  - `CLAUDE.md` — project conventions
- **Acceptance criteria**:
  - [ ] `monocart-reporter` removed from playwright.config.ts
  - [ ] `monocart-reporter` removed from package.json dependencies
  - [ ] E2E tests still pass without coverage collection (`npm run test:e2e`)
  - [ ] No coverage/e2e/ output directory referenced

### Step 2: Remove monocart-reporter from Portfolio Playwright config
- **Project**: Portfolio
- **Directory**: /Users/gregor/dev/922/portfolio
- **Parallel with**: Steps 1, 3
- **Description**: Same as Step 1 but for Portfolio project. Remove monocart-reporter from playwright config and dependencies.
- **Context files to read**:
  - `playwright.config.ts` — current reporter config
  - `package.json` — monocart dependency
  - `CLAUDE.md` — project conventions
- **Acceptance criteria**:
  - [ ] `monocart-reporter` removed from playwright.config.ts
  - [ ] `monocart-reporter` removed from package.json dependencies
  - [ ] E2E tests still pass without coverage collection

### Step 3: Remove coverage push steps from all reusable workflows
- **Project**: workflows
- **Directory**: /Users/gregor/dev/922/workflows
- **Parallel with**: Steps 1, 2
- **Description**: Remove coverage-push-to-Pushgateway steps from all three reusable workflows. Also remove the `pushgateway_url` input parameter and any coverage threshold/Discord notification logic tied to Pushgateway.
  - `frontend-e2e.yml` — Remove coverage extraction, Pushgateway push (lines ~299-379), coverage Discord alert, and `pushgateway_url` input
  - `frontend-tests.yml` — Remove coverage Pushgateway push (lines ~220-282) and `pushgateway_url` input
  - `python-tests.yml` — Remove coverage Pushgateway push (lines ~229-256) and `pushgateway_url` input
- **Context files to read**:
  - `.github/workflows/frontend-e2e.yml` — E2E workflow
  - `.github/workflows/frontend-tests.yml` — frontend unit test workflow
  - `.github/workflows/python-tests.yml` — Python test workflow
- **Acceptance criteria**:
  - [ ] No references to `pushgateway_url` in any workflow
  - [ ] No curl commands to Pushgateway in any workflow
  - [ ] Coverage threshold check in `frontend-e2e.yml` removed (no more Discord alerts for coverage)
  - [ ] `coverage_fail_under` input removed from `frontend-e2e.yml` if it was only used for Pushgateway logic
  - [ ] Workflow files are valid YAML

### Step 4: Remove pushgateway_url from all calling workflows
- **Project**: HomeUI, Portfolio, HomeAPI, HomeAuth, HomeCollector
- **Directory**: Multiple — all projects that pass `pushgateway_url` to reusable workflows
- **Parallel with**: — (after Step 3)
- **Description**: After removing `pushgateway_url` input from reusable workflows, remove the parameter from all calling workflows that pass it. Search all `.github/workflows/deploy.yml` and `.github/workflows/e2e.yml` files across projects for `pushgateway_url` references.
- **Context files to read**:
  - Each project's `.github/workflows/deploy.yml`
  - Each project's `.github/workflows/e2e.yml` (if exists)
- **Acceptance criteria**:
  - [ ] No `pushgateway_url` references in any project's workflow files
  - [ ] All workflows still valid YAML

### Step 5: Remove coverage endpoints and Prometheus queries from HomeCollector
- **Project**: HomeCollector
- **Directory**: /Users/gregor/dev/922/HomeCollector
- **Parallel with**: Step 6
- **Description**: Remove the coverage pipeline from HomeCollector:
  - `app/services/prometheus_service.py` — Delete `get_coverage_metrics()` (lines ~216-237) and `get_coverage_history()` (lines ~239-300)
  - `app/routers/system.py` — Delete `/api/monitoring/coverage/current` and `/api/monitoring/coverage/history` endpoints
  - `app/schemas/system.py` — Delete coverage-related schemas: `CoverageDataPoint`, `ProjectCoverageHistory`, `CoverageHistoryResponse`, `CoverageCurrentEntry`, `CoverageCurrentResponse`
  - `docs/api/coverage.md` — Delete coverage API documentation
  - Remove any tests for coverage endpoints
- **Context files to read**:
  - `CLAUDE.md` — project conventions
  - `app/services/prometheus_service.py` — coverage methods
  - `app/routers/system.py` — coverage routes
  - `app/schemas/system.py` — coverage schemas
  - `docs/api/coverage.md` — coverage docs
- **Acceptance criteria**:
  - [ ] No coverage endpoints in system router
  - [ ] No coverage methods in prometheus_service.py
  - [ ] No coverage schemas in system.py
  - [ ] Coverage API docs deleted
  - [ ] Related tests removed/updated
  - [ ] All remaining tests pass (`PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70`)

### Step 6: Remove coverage widgets from HomeUI dashboard
- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: Step 5
- **Description**: Remove coverage display from the dashboard:
  - Overview page: Remove `coverage_percent` from TEST HEALTH pill in SystemMetricsPanel
  - Test Results page: Remove coverage adoption stat card, coverage reference lines on charts
  - API types: Remove `coverage_percent` from `AllureProjectResult` type (if it was added for this)
  - API hooks: Remove any queries to `/api/monitoring/coverage/*` endpoints
  - Check for any other coverage-related components/utilities
- **Context files to read**:
  - `CLAUDE.md` — project conventions
  - Search for "coverage" across src/ to find all references
- **Acceptance criteria**:
  - [ ] No coverage display on Overview page
  - [ ] No coverage stat card or reference lines on Test Results page
  - [ ] No API calls to coverage endpoints
  - [ ] No coverage-related types/schemas
  - [ ] Unit tests pass (`npm run test:ci`)
  - [ ] E2E tests pass (`npm run test:e2e`)

### Step 7: Remove Pushgateway from monitoring stack
- **Project**: HomeStructure
- **Directory**: /Users/gregor/dev/922/HomeStructure
- **Parallel with**: — (after Steps 3-6, last step)
- **Description**: Remove Pushgateway entirely from the monitoring infrastructure:
  - `monitoring/docker-compose.yaml` — Remove pushgateway service (lines ~78-90)
  - `monitoring/prometheus/prometheus.yaml` — Remove pushgateway scrape job (lines ~17-23)
  - SSH into server: stop and remove pushgateway container, delete persistent volume (`/data/pushgateway.db`)
  - Update any documentation referencing Pushgateway
  - Update `server.md` in Planner repo to remove Pushgateway port (9091) reference
- **Context files to read**:
  - `monitoring/docker-compose.yaml` — pushgateway service definition
  - `monitoring/prometheus/prometheus.yaml` — scrape config
  - `CLAUDE.md` — project conventions
  - `docs/` — any docs referencing pushgateway
- **Acceptance criteria**:
  - [ ] Pushgateway service removed from docker-compose.yaml
  - [ ] Pushgateway scrape job removed from prometheus.yaml
  - [ ] Pushgateway container stopped and removed on server
  - [ ] Pushgateway volume cleaned up
  - [ ] Prometheus still scrapes other targets correctly
  - [ ] server.md updated (remove port 9091)
  - [ ] Pipeline green after push

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Remove monocart-reporter from HomeUI        → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 2: Remove monocart-reporter from Portfolio      → Portfolio @ /Users/gregor/dev/922/portfolio
  Step 3: Remove coverage push from reusable workflows → workflows @ /Users/gregor/dev/922/workflows

Wave 2 (after wave 1):
  Step 4: Remove pushgateway_url from calling workflows → Multiple projects

Wave 3 (parallel, after wave 2):
  Step 5: Remove coverage from HomeCollector API       → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 6: Remove coverage from HomeUI dashboard        → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 4 (after wave 3):
  Step 7: Remove Pushgateway from infra + server       → HomeStructure @ /Users/gregor/dev/922/HomeStructure
```

## Post-Execution Checklist
- [ ] All tests pass across all affected projects
- [ ] Documentation updated (server.md, coverage.md deleted)
- [ ] All pipelines green after pushes
- [ ] Pushgateway container removed from server
- [ ] No remaining references to pushgateway_url, test_coverage_percentage, or monocart-reporter across the ecosystem
