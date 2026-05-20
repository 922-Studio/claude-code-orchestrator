# Plan: Per-Repo Documentation Update

- **Date**: 2026-03-27
- **Project(s)**: All 13 ecosystem projects
- **Goal**: Bring every repository's internal documentation (README, CLAUDE.md, docs/) up to date with current codebase state.
- **Status**: Ready

## Context

Read these files before proceeding:
- `projects/<name>.md` — project mapping with current tech stack and file structure
- `server.md` — infrastructure reference for deployment context
- Each project's existing `README.md`, `CLAUDE.md`, and `docs/` for current state

### Documentation Audit (2026-03-27)

| Tier | Projects | Status |
|------|----------|--------|
| **None** | Anime-API | Zero documentation |
| **Minimal** | Anime-APP, HomeUI, Drafter, Studio, Portfolio | Template README or bare CLAUDE.md only |
| **Good** | HomeAuth, Sweatvalley Bingo | Solid README, partial docs |
| **Comprehensive** | HomeAPI, HomeCollector, HomeStructure, Discord, Workflows | Full README + docs/ + MkDocs |

---

## Steps

---

### Step 1: Anime-API — Create All Documentation From Scratch

- **Project**: Anime-API
- **Directory**: `/Users/gregor/dev/922/Anime-API`
- **Parallel with**: Steps 2–5
- **Description**: This project has zero documentation. Create:
  1. **`README.md`**: Project overview, tech stack (Python 3.13, FastAPI, SQLAlchemy, psycopg2, gunicorn, google-generativeai), setup instructions (Docker + local), API endpoints, environment variables, testing
  2. **`CLAUDE.md`**: Project context for AI agents — key files, conventions, commands, best practices
- **Context files to read**:
  - `Planner/projects/anime-api.md` — project mapping
  - `main.py` — entry point and all routes
  - `models.py` — database models
  - `docker-compose.yaml` — Docker setup
  - `.github/workflows/deploy.yml` — CI/CD pipeline
  - `requirements.txt` or `pyproject.toml` — dependencies
- **Guidelines**:
  - Follow the README style of HomeAPI (comprehensive but concise)
  - Include Docker Compose and local dev setup
  - List all API endpoints with methods and descriptions
  - Document the Gemini AI integration
  - Include environment variables table
- **Acceptance criteria**:
  - [ ] `README.md` created with setup, API docs, environment variables
  - [ ] `CLAUDE.md` created with project context
  - [ ] Both committed and pushed

---

### Step 2: Anime-APP — Replace Template README + Add CLAUDE.md

- **Project**: Anime-APP
- **Directory**: `/Users/gregor/dev/922/Anime-APP`
- **Parallel with**: Steps 1, 3–5
- **Description**: Replace the generic Next.js template README with a project-specific one. Add CLAUDE.md.
  1. **`README.md`**: Replace boilerplate. Add: project overview, tech stack (React 19, Vite 7, Tailwind CSS 4, axios), Docker setup, development instructions, relationship to Anime-API
  2. **`CLAUDE.md`**: Project context — key files (App.jsx, components/), conventions (JSX not TSX), commands
- **Context files to read**:
  - `Planner/projects/anime-app.md` — project mapping
  - `package.json` — dependencies and scripts
  - `src/App.jsx` — main component
  - `src/components/` — component inventory
  - `docker-compose.yaml` — Docker setup
  - `.github/workflows/deploy.yml` — CI/CD
- **Guidelines**:
  - Note this is JavaScript (JSX), not TypeScript
  - Document the Anime-API dependency (API base URL)
  - Keep it concise — this is a simple SPA
- **Acceptance criteria**:
  - [ ] `README.md` replaced with project-specific content
  - [ ] `CLAUDE.md` created
  - [ ] Both committed and pushed

---

### Step 3: HomeUI — Replace Template README

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Steps 1–2, 4–5
- **Description**: Replace the generic Vite template README with comprehensive project documentation.
  1. **`README.md`**: Project overview, tech stack (React 19, TypeScript 5.9, Vite 6, TanStack Query 5, React Router 7, Tailwind CSS 4, Tolgee, Recharts), feature modules (12 listed), Docker setup, development instructions, testing (Vitest + Playwright + MSW), architecture overview
- **Context files to read**:
  - `Planner/projects/homeui.md` — project mapping
  - `package.json` — dependencies and scripts
  - `src/features/` — list all 12 feature modules
  - `src/components/` — shared component inventory
  - `vite.config.*` — build configuration
  - `docker-compose.yaml` — Docker setup
  - `.github/workflows/deploy.yml` — CI/CD
  - `CLAUDE.md` — existing agent context (preserve, don't overwrite)
- **Guidelines**:
  - Document the feature-module architecture pattern (`features/{name}/{pages,components,hooks}/`)
  - List all 12 feature modules with brief descriptions
  - Document the HomeAPI + HomeAuth + HomeCollector dependencies
  - Include environment variables (VITE_API_BASE_URL, VITE_AUTH_URL)
  - Document testing strategy (unit: Vitest+MSW, E2E: Playwright on separate runner)
- **Acceptance criteria**:
  - [ ] `README.md` replaced with comprehensive project docs
  - [ ] Committed and pushed

---

### Step 4: Drafter — Create README

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 1–3, 5
- **Description**: Create a proper README (currently missing — only has CLAUDE.md and docs/MVP-Scope.md).
  1. **`README.md`**: Project overview (social media content management), tech stack (Next.js 16, React 19, TypeScript, Prisma 7, MinIO/S3), Prisma models (Post, Media), app routes, Docker setup (private registry), development instructions, testing, environment variables
- **Context files to read**:
  - `Planner/projects/drafter.md` — project mapping
  - `CLAUDE.md` — existing agent context
  - `package.json` — dependencies and scripts
  - `prisma/schema.prisma` — data models
  - `src/app/` — route structure
  - `docker-compose.yaml` — Docker setup
  - `.github/workflows/deploy.yml` — CI/CD
  - `docs/MVP-Scope.md` — feature scope
- **Guidelines**:
  - Document the internal JWT auth (jose, NOT HomeAuth)
  - Document MinIO/S3 media storage integration
  - Document the private Docker Registry workflow (build → push → Watchtower auto-deploy)
  - Include Prisma commands (migrate, generate, studio)
  - Note: pnpm is the package manager, Node >=22 required
- **Acceptance criteria**:
  - [ ] `README.md` created
  - [ ] Committed and pushed

---

### Step 5: Studio — Create README

- **Project**: Studio
- **Directory**: `/Users/gregor/dev/922/Studio`
- **Parallel with**: Steps 1–4
- **Description**: Create README (currently missing — only bare CLAUDE.md).
  1. **`README.md`**: Project overview (922-Studio landing page), tech stack (Next.js 16, React 19, TypeScript, next-intl, next-mdx-remote, gray-matter, Tailwind CSS 4), content management (MDX), Docker setup, development instructions
  2. **`CLAUDE.md`**: Expand from 2 lines to proper project context
- **Context files to read**:
  - `Planner/projects/studio.md` — project mapping
  - `package.json` — dependencies and scripts
  - `src/app/[locale]/` — locale-based routing
  - `content/` — MDX content directory
  - `docker-compose.yaml` — Docker setup
  - `.github/workflows/deploy.yml` — CI/CD
- **Guidelines**:
  - Document the MDX content pipeline (gray-matter frontmatter → next-mdx-remote rendering)
  - Document locale routing (next-intl, [locale] segments)
  - Document the reading-time integration
  - Note the shared GA4 ID with Portfolio
- **Acceptance criteria**:
  - [ ] `README.md` created
  - [ ] `CLAUDE.md` expanded
  - [ ] Both committed and pushed

---

### Step 6: Portfolio — Replace Template README

- **Project**: Portfolio
- **Directory**: `/Users/gregor/dev/922/Portfolio`
- **Parallel with**: Steps 7–8
- **Depends on**: Steps 1–5 (lower priority batch)
- **Description**: Replace generic Next.js README with project-specific one.
  1. **`README.md`**: Project overview (personal portfolio at gregor.922-studio.com), tech stack (Next.js 16, React 19, next-intl, Tailwind CSS 4), i18n (EN/DE), Docker setup, GA4, testing
- **Context files to read**:
  - `Planner/projects/portfolio.md` — project mapping
  - `package.json` — dependencies
  - `src/app/[locale]/` — locale routing
  - `docker-compose.yaml` — Docker setup
  - `.github/workflows/deploy.yml` — CI/CD
  - `CLAUDE.md` — existing context (preserve)
- **Acceptance criteria**:
  - [ ] `README.md` replaced
  - [ ] Committed and pushed

---

### Step 7: Sweatvalley Bingo — Review and Refresh README

- **Project**: Sweatvalley Bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo`
- **Parallel with**: Steps 6, 8
- **Description**: README exists and is good (German, 162 lines). Update version (0.6.1→0.7.4), verify tech stack versions, check for any new features since last update.
- **Context files to read**:
  - `Planner/projects/sweatvalley-bingo.md` — project mapping
  - `README.md` — current README
  - `server/package.json` + `client/package.json` — current versions
  - `CLAUDE.md` — existing context
- **Acceptance criteria**:
  - [ ] Version updated to 0.7.4
  - [ ] Tech stack versions verified
  - [ ] Committed and pushed (if changed)

---

### Step 8: Update Existing Comprehensive READMEs

- **Project**: HomeAPI, HomeAuth, HomeCollector, Discord Bot, Workflows
- **Directory**: Each project's directory
- **Parallel with**: Steps 6–7
- **Description**: These projects already have good docs. Do a targeted refresh:

#### 8a: HomeAPI (`/Users/gregor/dev/922/HomeAPI`)
- Verify model count (now 19, was 17)
- Verify router count (now 20+)
- Update version if documented
- Check `docs/` content is current
- **Context**: Read `README.md`, `Planner/projects/homeapi.md`

#### 8b: HomeAuth (`/Users/gregor/dev/922/HomeAuth`)
- Verify auth domain is `auth.922-studio.com` (not `lab-auth`)
- Check docs/ integration guides reference correct URLs
- **Context**: Read `README.md`, `docs/HOMEUI_INTEGRATION.md`, `Planner/projects/homeauth.md`

#### 8c: HomeCollector (`/Users/gregor/dev/922/HomeCollector`)
- Verify monitored service count (52 containers now)
- Remove `status.922-studio.com` references (route removed)
- Update domain to `lab-collector.922-studio.com`
- **Context**: Read `README.md`, `Planner/projects/homecollector.md`

#### 8d: Discord Bot (`/Users/gregor/dev/922/discord`)
- Verify version (1.12.11)
- Check CODEBASE_MAP.md is current
- **Context**: Read `README.md`, `CODEBASE_MAP.md`, `Planner/projects/discord.md`

#### 8e: Workflows (`/Users/gregor/dev/922/workflows`)
- Verify all 14 workflows are documented in README
- Check docs/ covers all workflows (currently 6 of 14)
- Note missing docs: cancel-previous-runs, python-lint, python-tests, frontend-tests, frontend-e2e, docker-build, create-issue, send-notification
- **Context**: Read `README.md`, `docs/`, `Planner/projects/workflows.md`

- **Acceptance criteria**:
  - [ ] All 5 projects verified and updated where needed
  - [ ] All committed and pushed

---

### Step 9: HomeStructure — Verify Docs Match After Overhaul

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Depends on**: Step 8 (all other repos done first)
- **Description**: Final pass on HomeStructure README to ensure it references all current services and docs correctly.
- **Context files to read**:
  - `README.md` — current README
  - `docs/index.md` — docs landing page
  - `CLAUDE.md` — existing context
- **Acceptance criteria**:
  - [ ] README references all current services
  - [ ] Committed and pushed if changed

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel — highest priority, creating docs from nothing):
  Step 1: Anime-API — create README + CLAUDE.md      → /Users/gregor/dev/922/Anime-API
  Step 2: Anime-APP — replace README + add CLAUDE.md  → /Users/gregor/dev/922/Anime-APP
  Step 3: HomeUI — replace template README             → /Users/gregor/dev/922/HomeUI
  Step 4: Drafter — create README                      → /Users/gregor/dev/922/Drafter
  Step 5: Studio — create README + expand CLAUDE.md    → /Users/gregor/dev/922/Studio

Wave 2 (parallel — refresh existing docs):
  Step 6: Portfolio — replace template README          → /Users/gregor/dev/922/Portfolio
  Step 7: Sweatvalley Bingo — version/tech refresh     → /Users/gregor/dev/922/sweatvalley_bingo
  Step 8: HomeAPI/Auth/Collector/Discord/Workflows     → 5 repos (targeted updates)

Wave 3 (after Wave 2):
  Step 9: HomeStructure — final verification           → /Users/gregor/dev/922/HomeStructure
```

---

## Agent Execution Guide

Each step can be executed by an agent with this prompt pattern:

```
Read the plan at Planner/plans/2026-03-27-per-repo-documentation-update.md, Step [N].
Read the project mapping at Planner/projects/<name>.md.
Read the project's CLAUDE.md if it exists.
Read all context files listed in the step.
Execute the step — create/update the documentation files as described.
Follow the guidelines in the step.
Commit with message: "docs: [description]"
Push to the project's main/dev branch.
```

**Agent model**: Use Sonnet for all steps (standard executor work).

---

## Post-Execution Checklist
- [ ] All 13 repos have a project-specific README.md
- [ ] All 13 repos have a CLAUDE.md
- [ ] All domain references use `auth.922-studio.com` (not `lab-auth`)
- [ ] All version numbers match Planner project mappings
- [ ] All changes committed and pushed
- [ ] No template/boilerplate READMEs remain
