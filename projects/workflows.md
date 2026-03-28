# Project: Workflows (922-Studio Reusable Workflows)

## Overview
- **Type**: infra
- **Path**: /Users/gregor/dev/922/workflows
- **Status**: active
- **Description**: GitHub Actions reusable workflow library. Single source of truth for CI/CD — all 922-Studio repos reference these workflows via `workflow_call`. Provides versioning (AI-powered via Gemini), deployment, testing, smoke testing, notifications, and utility workflows. Eliminates per-repo CI/CD boilerplate.

## Tech Stack
- **Language(s)**: YAML (GitHub Actions), Python 3.13 (scripts), Bash
- **Framework(s)**: GitHub Actions (`workflow_call` pattern)
- **Key tools**: google-generativeai (Gemini API for versioning), pytest, Vitest
- **Infrastructure**: Self-hosted GitHub Actions runners
- **Integrations**: Google Gemini, Gmail SMTP, Discord API, Allure server

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Code style, naming, workflow contract | Always |
| `README.md` | Overview, available workflows, prerequisites, usage | First time |
| `.github/workflows/versioning.yml` | AI-powered semantic versioning | When touching versioning |
| `.github/workflows/deploy-docker.yml` | Docker service deployment | When touching deployment |
| `.github/workflows/smoke-test.yml` | Pre-deployment smoke testing | When touching testing |
| `.github/workflows/python-tests.yml` | Python test automation | When touching Python CI |
| `.github/workflows/frontend-tests.yml` | Frontend test automation | When touching frontend CI |
| `.github/workflows/send-notification.yml` | Unified email + Discord | When touching notifications |
| `.github/workflows/cancel-previous-runs.yml` | Cancel stale runs | When touching pipeline flow |
| `.github/workflows/create-issue.yml` | CI failure issue creation | When touching error handling |
| `.github/scripts/determine_version.py` | Conventional commit + Gemini versioning | When touching version logic |
| `.github/scripts/send_discord.py` | Discord API notification | When touching notifications |
| `.github/scripts/upload_allure_results.py` | Test result upload | When touching reporting |
| `docs/versioning.md` | Versioning workflow details | For deep understanding |

## Best Practices
- All workflows use `on: workflow_call` with explicit `inputs:`, `secrets:`, `outputs:`
- Called via: `uses: 922-Studio/workflows/.github/workflows/{name}.yml@main`
- Scripts: Python stdlib only (exception: `google-generativeai`)
- Error handling: Critical → exit 1, non-fatal → log+continue, API failure → fallback
- Naming: workflows=kebab-case.yml, scripts=snake_case.py, functions=snake_case, env=UPPER_SNAKE_CASE
- Step names use emoji prefixes for quick scanning
- Type hints throughout Python code
- Graceful degradation: Gemini fails → default to PATCH

## Caller Workflow Naming Convention

All caller workflow `name:` fields follow: **`{RepoName} {Action} [{Subject}]`**

Examples: `HomeUI Deploy`, `HomeUI Run E2E Tests`, `HomeAPI Deploy Documentation`

Full rules and reference table: `HomeStructure/docs/actions/workflow-naming.md`

## E2E Test Dispatch Pattern

Repos with E2E tests decouple them from the deployment pipeline:
- `e2e.yml` in the caller repo: `on: workflow_dispatch`, calls `frontend-e2e.yml@main`
- `deploy.yml`: fires `gh workflow run e2e.yml` after unit tests pass, then continues to smoke+deploy without waiting
- Affected repos: HomeUI, Portfolio

See `HomeStructure/docs/actions/workflow-naming.md` for the full pattern.

## Testing Strategy
- **Unit tests**: `.github/tests/test_determine_version.py` — pytest
- **How to run**: `pytest .github/tests/`
- **Coverage**: Tests cover conventional commit detection, CLI routing, edge cases

## Documentation
- **Where**: `README.md`, `docs/` (versioning, deploy-docker, send-email, smoke-test)
- **Architecture docs**: `.planning/codebase/` (STACK, ARCHITECTURE, CONVENTIONS, TESTING, INTEGRATIONS)
- **Update rule**: Update docs when workflow inputs/outputs change

## Pipeline & Deployment
- **No CI/CD for this repo itself** — it IS the CI/CD
- **Consumers call**: `uses: 922-Studio/workflows/.github/workflows/{name}.yml@main` + `secrets: inherit`
- **Typical chain**: versioning → test → smoke-test → deploy → notify

## Dependencies on Other Projects
- **All projects depend on workflows** for CI/CD
- No upstream dependencies

## Notes
- 14 reusable workflows: cancel-previous-runs, versioning, python-lint, python-tests, smoke-test, deploy-docker, frontend-tests, frontend-e2e, docker-build, generate-mcp, create-issue, send-notification, pr-demo (+ local docs: deploy-docker.md, generate-mcp.md, pr-demo.md, send-email.md, smoke-test.md, versioning.md)
- AI versioning: Gemini 2.5 Flash analyzes commits for semantic versioning
- Default values: Node 20.x, Python 3.13, Allure at http://home-lab:5050
- `[ci skip]` in commit message skips versioning
- All workflows require self-hosted runners
