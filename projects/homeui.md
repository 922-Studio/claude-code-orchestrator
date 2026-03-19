# Project: HomeUI

## Overview
- **Type**: fullstack (frontend)
- **Path**: /Users/gregor/dev/922/HomeUI
- **Status**: active
- **Description**: React/TypeScript SPA dashboard for the home lab ecosystem. Connects to HomeAPI backend. Provides personal finance/debt tracking (Ledger), system monitoring, uptime tracking, health status, user management, settings, and wellbeing tracking.

## Tech Stack
- **Language(s)**: TypeScript 5.9, React 19
- **Framework(s)**: Vite 6.3, React Router 7.13, TanStack React Query 5.90, Zod 4.3
- **Styling**: Tailwind CSS 4.1, shadcn/ui, Radix UI, CVA, Lucide icons
- **HTTP**: Axios 1.13 with auth interceptors
- **Infrastructure**: Docker (Node build → Nginx 1.27), Docker Compose
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
| `src/index.css` | Full CSS variable theme (Indigo primary, dark mode) | When touching design |
| `vite.config.ts` | Build settings, alias, chunks, test config | When touching build |
| `.github/workflows/deploy.yml` | CI/CD pipeline | When pushing changes |

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
- **Reporting**: Allure at `http://home-lab:5050` (projects: homeui-unit, homeui-e2e)

## Documentation
- **Where**: `tech_docs/`, `CLAUDE.md`, `.claude/`
- **Update rule**: Update tech_docs when architecture or patterns change

## Pipeline & Deployment
- **CI trigger**: Push to main
- **Pipeline**: cancel-previous → version → tests (70%) → e2e → smoke-test → deploy → notify
- **Deploy**: Docker (Node build → Nginx), Docker Compose, `deploy.sh`
- **Monitor after push**: Check Discord notification, verify http://home-lab:8000 loads

## Dependencies on Other Projects
- **HomeAPI**: Backend for core domain data (debts, tasks, ideas, wellbeing, memory, worklogs, etc.)
- **HomeAuth**: Authentication (login, register, token management)
- **HomeCollector**: ALL monitoring data — uptime status/history, GitHub Actions, Allure test results, system metrics, overview dashboard
- **HomeStructure**: Traefik routing, infrastructure

## Notes
- Port 8000 behind Traefik (lab.922-studio.com)
- Design system: JetBrains Mono font, no rounded corners (--radius: 0rem), dark/light mode
- Colors: Indigo primary, Emerald success, Rose danger, Amber warning
- Tailwind v4 spacing quirk: use inline styles for spacing, not Tailwind spacing classes
- Auth tokens stored in localStorage as `homeui.auth.token`
