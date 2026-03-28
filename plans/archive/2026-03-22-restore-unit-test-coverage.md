# Plan: Restore Unit/Pytest Coverage to Dashboard

- **Date**: 2026-03-22
- **Status**: DONE (2026-03-22)
- **Project(s)**: HomeStructure, workflows, HomeCollector, HomeUI, HomeAPI, HomeAuth, Planner
- **Goal**: Restore coverage display for unit tests (Vitest, pytest) on the dashboard. E2E/Playwright coverage remains removed.

## Context

The previous plan `2026-03-22-remove-coverage-from-e2e-and-prometheus.md` removed the entire coverage pipeline (Pushgateway, workflows, API, UI). The intent was only to remove E2E coverage, but the implementation removed all coverage including backend unit tests. This plan restores coverage for unit/pytest tests only.

## What was restored

### Step 1: HomeStructure — Pushgateway service + Prometheus scrape
- Re-added `pushgateway` service to `monitoring/docker-compose.yaml`
- Re-added `pushgateway` scrape job to `monitoring/prometheus/prometheus.yaml`
- Re-added `pushgateway_data` volume

### Step 2: Workflows — Coverage push steps (unit tests only)
- `python-tests.yml`: Added `pushgateway_url` input + push step (parses coverage.xml, pushes `test_coverage_percentage` gauge)
- `frontend-tests.yml`: Added `pushgateway_url` + `coverage_fail_under` inputs + push step + threshold notification
- `frontend-e2e.yml`: **NOT modified** — E2E coverage stays removed

### Step 3: HomeCollector — Coverage API endpoints
- `app/schemas/system.py`: Restored `CoverageDataPoint`, `ProjectCoverageHistory`, `CoverageHistoryResponse`, `CoverageCurrentEntry`, `CoverageCurrentResponse`
- `app/services/prometheus_service.py`: Restored `get_coverage_metrics()` and `get_coverage_history()`
- `app/routers/system.py`: Restored `GET /coverage/history` and `GET /coverage/current`
- `docs/api/coverage.md`: Restored API documentation

### Step 4: Calling workflows — pushgateway_url re-added
- HomeAPI, HomeAuth, HomeCollector, HomeUI: Added `pushgateway_url: 'http://home-lab:9091'` to deploy.yml test jobs

### Step 5: HomeUI — Dashboard coverage display
- Restored hooks: `useCoverageCurrent`, `useCoverageHistory`, `useCoverageHistoryAll`
- Restored API functions + query options in `monitoring.ts`
- Restored types: `CoverageDataPoint`, `CoverageHistoryResponse`, `CoverageCurrentResponse`, `coverage_percent` on `AllureProjectResult`
- Restored i18n keys: `metrics.covPassing`, `tests.coverage`, updated `tests.subtitle`
- Components restored:
  - `SystemMetricsPanel`: Coverage display in TEST HEALTH pill
  - `AllurePanel`: `coverageMap` prop
  - `AllureProjectCard`: Coverage row display
  - `TestResultsProjectChart`: Coverage line on chart, header badge, tooltip, legend
  - `TestResultsPage`: Coverage stat card, coverage data passed to charts
  - `OverviewPage`: Coverage hooks, coverage passed to SystemMetricsPanel and AllurePanel
- MSW mocks: `coverage_percent` on allure results, `mockCoverageHistory`, handler for `/coverage/history`

### Step 6: Planner — server.md updated
- Re-added Pushgateway port 9091 to server.md

## Post-execution

After committing and pushing all repos:
1. Deploy HomeStructure monitoring stack (start Pushgateway container)
2. Trigger deployments for HomeAPI, HomeAuth, HomeCollector, HomeUI to repopulate coverage data
3. Verify coverage displays on dashboard after first CI runs complete
