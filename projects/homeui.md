# Project: HomeUI

## Overview
- **Type**: fullstack (frontend)
- **Path**: /Users/gregor/dev/922/HomeUI
- **Status**: active
- **Description**: React/TypeScript SPA dashboard for the home lab ecosystem. Connects to HomeAPI backend. Provides Finance/Ledger (debt tracking at `/finance/ledger`), Health/Sleep (wellbeing at `/health/sleep`), system monitoring, uptime tracking, health status, user management, and settings.

## Tech Stack
- **Language(s)**: TypeScript ~5.9.3, React 19.2.0
- **Framework(s)**: Vite 6.3.5, React Router DOM 7.13.0, TanStack Query 5.90.20, Zod 4.3.6
- **i18n**: Tolgee 6.6.0
- **Charts**: Recharts 3.7.0
- **Styling**: Tailwind CSS 4.1.18, Radix UI, CVA, lucide-react 0.563.0
- **HTTP**: Axios 1.13.4 with auth interceptors
- **Testing**: Vitest 2.1.9, Testing Library 16.3.2, Playwright 1.58.2, MSW 2.12.13
- **Infrastructure**: Docker (Node build → Nginx), Docker Compose
- **CI/CD**: GitHub Actions (922-Studio/workflows), ESLint strict, 70% coverage min

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Architecture, naming, patterns, testing rules, new feature checklist | Always |
| `.claude/BEST-PRACTICES.md` | 18-item scalability checklist | When planning improvements |
| `.claude/HOW-TO-UNIT-TEST.md` | Query priority, mocking patterns, templates | When writing tests |
| `.claude/skills/e2e.md` | E2E patterns, Page Object Model, auth mocking | When writing E2E tests |
| `tech_docs/Index.md` | Navigation hub for all technical docs | For orientation |
| `tech_docs/api_integration.md` | HTTP client, React Query patterns, hooks | When touching data layer |
| `tech_docs/project_structure.md` | Layouts, entry points, theme/colors | When touching structure |
| `src/main.tsx` | React root, providers setup | When touching app shell |
| `src/App.tsx` | Route definitions, lazy loading, loaders | When adding pages |
| `src/lib/http.ts` | Axios client, auth interceptor, 401 handling | When touching API |
| `src/lib/queryClient.ts` | React Query defaults | When touching caching |
| `src/styles/design-system.css` | Home Lab DS — `--hl-*` tokens, `.hl-*` chrome, dark default + `.light` variant | When touching design |
| `src/index.css` | Thin Tailwind/shadcn bridge onto `--hl-*` tokens | When touching design |
| `vite.config.ts` | Build settings, alias, chunks, test config | When touching build |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |
| `bin/setup-worktree.mjs` | Worktree bootstrap: symlinks `.env.local` from primary checkout | Creating a new worktree |

## Best Practices
- Feature-scoped modules: `src/features/{name}/{pages,components,hooks}/`
- API isolation: `src/api/{domain}.ts` with Zod validation + `queryOptions()` factories
- React Query: `onSettled` invalidations (not `onSuccess`), no manual refetch
- Tailwind-first styling, no dynamic class names, `cn()` for class merging
- CVA for component variants
- ESLint strict: no-explicit-any, consistent-type-imports, switch-exhaustiveness-check
- Test user behavior, not internals: `getByRole` > `getByLabel` > `getByText` > `getByTestId`
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **Unit tests**: `src/**/*.test.tsx` colocated — `npm run test:ci`
- **E2E tests**: `e2e/**/*.spec.ts` with Playwright — `npm run test:e2e`
- **Coverage**: 70% minimum, Vitest + @vitest/coverage-v8
- **MSW**: Mock Service Worker for API mocking
- **Reporting**: Allure at `http://astro-antares:5050` (projects: homeui-unit, homeui-e2e)

## Documentation
- **Where**: `tech_docs/`, `CLAUDE.md`, `.claude/`
- **Update rule**: Update tech_docs when architecture or patterns change

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → unit tests → kick-off-e2e → smoke → deploy → notify
- **Deploy**: Docker (Node build → Nginx), Docker Compose, `deploy.sh`
- **Monitor after push**: Check Discord notification, verify http://astro-antares:8000 loads

## Dependencies on Other Projects
- **HomeAPI**: Backend for core domain data (debts, tasks, ideas, wellbeing, memory, worklogs, etc.)
- **HomeAuth**: Authentication (login, register, token management)
- **HomeCollector**: ALL monitoring data — uptime status/history, GitHub Actions, Allure test results, system metrics, overview dashboard
- **HomeStructure**: Traefik routing, infrastructure

## Notes
- Port 8000 behind Traefik (lab.922-studio.com)
- 30+ components, 12 feature modules: auth, content, dashboard, debts, finance, health, management, modules, organisations, projects, settings, users, wellbeing
- Home Lab DS at `src/styles/design-system.css`; showcase at `/design-system` (DEV-only). JetBrains Mono (technical/headings) + Inter (prose), teal `--hl-accent`, semantic-only colors (`--hl-success` / `--hl-error` / `--hl-warning` / `--hl-info`), 6px default radius (`--hl-radius`), dark default + light variant via `.light` on `<html>`.
- Auth tokens stored in localStorage as `homeui.auth.token`
