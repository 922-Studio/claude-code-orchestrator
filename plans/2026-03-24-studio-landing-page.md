# Plan: 922-Studio Landing Page

- **Date**: 2026-03-24
- **Project(s)**: Studio (new), HomeCollector (update), Planner (update)
- **Goal**: Create a Next.js studio landing page at `studio.922-studio.com` with blog, collaborators, timeline, achievements, and projects — fully integrated into the existing infrastructure with test suite and Allure reporting.

## Resolved Questions

| # | Question | Answer |
|---|----------|--------|
| Q1 | Iustus's role/title | Junior hobby developer, building anime tracking page "ANIZO" |
| Q2 | i18n | Both EN/DE from the start |
| Q3 | Replace old landing page? | **No** — `922-studio.com` keeps redirecting to portfolio. Studio lives at `studio.922-studio.com` |
| Q4 | Google Analytics | Same ID as portfolio (`G-1GSBD62ZVM`), added as build arg |
| Q5 | Blog | **Yes, from day one** — most important feature |

## Context

Read these files before proceeding:
- `projects/portfolio.md` — tech stack, patterns, CI/CD to mirror
- `server.md` — infrastructure reference, ports, networks, Cloudflare routes
- `guides/new-service-setup.md` — deployment checklist
- `showcase.md` — content source for timeline, projects, achievements

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Next.js 16 + TypeScript + React 19 | Mirror portfolio stack, SSG for performance |
| Styling | Tailwind CSS 4 | Same as portfolio, shared design language |
| i18n | next-intl (EN/DE) | Match portfolio, both languages from start |
| Content | MDX files in `/content` | No CMS, no DB — commit-driven content |
| Port | 3002 (internal) | Next free after portfolio (3000) and sweatvalley (3001) |
| Container | `studio` | Clean, short name |
| Domain | `studio.922-studio.com` | Own subdomain, `922-studio.com` redirect to portfolio stays |
| Repo | `922-Studio/studio` | New GitHub repo under the org |
| Network | `proxy` only | No DB/Redis needed — static content |
| Auth | None | Public page, no forward-auth |
| Unit tests | Vitest + @testing-library/react | Same as portfolio, component + utility testing |
| E2E tests | Playwright (Chrome) | Same as portfolio, page-level validation |
| Test reporting | Allure (studio-unit, studio-e2e) | Two Allure projects, consistent with ecosystem |

## Content Structure

```
content/
  people/
    gregor.mdx          # Name, role, bio, portfolio link, avatar
    iustus.mdx          # Name, role, bio, portfolio link, avatar
  timeline/
    2026-03-server-expansion.mdx
    2026-03-homecontent-shipped.mdx
    2026-03-monitoring-hub.mdx
    2025-xx-workflows-library.mdx
    ... (populated from showcase.md)
  projects/
    homeapi.mdx
    homeui.mdx
    anizo.mdx
    sweatvalley-bingo.mdx
    discord-bot.mdx
    ... (one per project card)
  blog/
    welcome.mdx         # First blog post — "Introducing 922-Studio"
```

## Page Structure

### Home Page (`/`)
1. **Hero** — "922-Studio" branding, tagline, brief intro
2. **Collaborators** — Gregor & Iustus cards with photo/avatar, role, short bio, portfolio link. *This section is prominent — the people come first.*
3. **Timeline / Achievements** — Reverse-chronological milestone feed (sourced from `content/timeline/`). Each entry: date, title, description, tags.
4. **Projects** — Card grid with project name, type badge, one-liner, tech tags, live URL. Filterable by category (Web / API / Infra / Game / App).
5. **Footer** — 922-Studio branding, GitHub link, year

### Blog Page (`/blog`)
- List of blog posts from `content/blog/`, reverse-chronological
- Each post card: title, date, reading time, excerpt, tags
- Prominent on navigation — this is a core feature

### Blog Post Page (`/blog/[slug]`)
- Full MDX rendering with code highlighting
- Author attribution (linked to collaborator)
- Date, reading time, tags
- Previous/next post navigation

## Design Direction

Based on portfolio but adjusted for "studio/collective" feel:
- **Same fonts**: Space Grotesk (headings) + Inter (body)
- **Same dark/light system**: CSS variables, class-based toggle
- **Adjusted accent**: Consider a warmer or more distinctive accent to differentiate from the personal portfolio (e.g. emerald or amber instead of indigo→cyan) — *or keep the same for brand consistency*
- **Dot grid background**: Keep from portfolio
- **Collaborator cards**: Large, prominent — photo/avatar, name, role, short text, link button
- **Timeline**: Vertical line with alternating left/right entries on desktop, stacked on mobile
- **Project cards**: Clean card grid with hover effect, category badge, tech tags
- **Blog list**: Clean card layout with excerpt, date, reading time

## Steps

### Step 1: Create GitHub repo and scaffold Next.js project
- **Project**: Studio (new)
- **Directory**: `/Users/gregor/dev/922/studio`
- **Parallel with**: Step 2
- **Description**:
  1. Create repo `922-Studio/studio` on GitHub
  2. Scaffold Next.js 16 project with TypeScript, Tailwind CSS 4, next-intl
  3. Copy and adapt from portfolio:
     - `next.config.ts` (standalone output, next-intl plugin)
     - `postcss.config.mjs`
     - `src/i18n/` routing setup
     - `src/app/globals.css` (theme tokens — adjust accent color for studio identity)
     - `ThemeProvider`, `ThemeToggle`, `Header`, `Footer` components
  4. Set up MDX processing (`next-mdx-remote` or `@next/mdx`)
  5. Create content directory structure with initial MDX files:
     - People: Gregor + Iustus
     - Timeline: Key milestones from `showcase.md`
     - Projects: All active projects
     - Blog: First post "Introducing 922-Studio"
  6. Implement pages:
     - Home: Hero → Collaborators → Timeline → Projects
     - Blog list: `/blog` with post cards
     - Blog post: `/blog/[slug]` with full MDX rendering
  7. Add `messages/en.json` and `messages/de.json` translation files
  8. Create `version.txt` with `0.1.0`
  9. Create `CLAUDE.md` with project conventions
- **Context files to read**:
  - `portfolio/CLAUDE.md` — conventions
  - `portfolio/src/app/globals.css` — design tokens
  - `portfolio/src/app/[locale]/layout.tsx` — layout structure
  - `portfolio/next.config.ts` — Next.js config
  - `portfolio/package.json` — dependencies to mirror
  - `Planner/showcase.md` — content to populate timeline + projects
- **Acceptance criteria**:
  - [ ] Next.js app runs locally with `npm run dev`
  - [ ] Home page renders: Hero, Collaborators (Gregor + Iustus), Timeline, Projects
  - [ ] Blog list page renders with at least one post
  - [ ] Blog post page renders MDX content correctly
  - [ ] Dark/light theme toggle works
  - [ ] i18n routing works (EN/DE)
  - [ ] MDX content files load and render
  - [ ] Responsive design (mobile, tablet, desktop)

### Step 2: Create test suite with Allure reporting
- **Project**: Studio (new)
- **Directory**: `/Users/gregor/dev/922/studio`
- **Parallel with**: Step 1 (can be scaffolded in parallel, tests written after Step 1 completes)
- **Description**:
  1. Set up **Vitest** + `@testing-library/react` + `@testing-library/jest-dom`:
     - `vitest.config.mts` mirroring portfolio setup
     - Test directory: `src/**/*.test.tsx`
     - Coverage configuration with thresholds
     - Allure results output to `reports/allure`
  2. Write **unit/component tests**:
     - ThemeProvider + ThemeToggle: theme switching
     - Header + Footer: render, navigation links
     - Collaborator card: renders name, role, portfolio link
     - Timeline entry: renders date, title, description
     - Project card: renders name, type badge, tech tags
     - Blog post list: renders posts with dates, excerpts
     - Blog post page: MDX content renders
     - MDX content loading utilities
  3. Set up **Playwright** for E2E:
     - `playwright.config.ts` mirroring portfolio
     - `e2e/` directory with specs
     - Allure results integration
  4. Write **E2E tests**:
     - Home page loads, all sections visible
     - Navigation between pages works
     - Blog list → blog post navigation
     - Theme toggle persists across pages
     - i18n language switching
     - Responsive: mobile menu works
     - All external links (portfolio links) have correct hrefs
  5. Add test scripts to `package.json`:
     - `test` — Vitest run
     - `test:coverage` — Vitest with coverage
     - `test:e2e` — Playwright
  6. Allure reporting setup:
     - `allure-vitest` reporter for unit tests
     - `allure-playwright` reporter for E2E
     - Projects: `studio-unit` and `studio-e2e` on Allure server
- **Context files to read**:
  - `portfolio/vitest.config.mts` — Vitest config to mirror
  - `portfolio/playwright.config.ts` — Playwright config to mirror
  - `portfolio/package.json` — test dependencies
  - `portfolio/e2e/` — E2E test patterns
  - `portfolio/src/components/*.test.tsx` — unit test patterns
- **Acceptance criteria**:
  - [ ] `npm run test` passes with all unit tests green
  - [ ] `npm run test:coverage` shows coverage report
  - [ ] `npm run test:e2e` passes with Playwright
  - [ ] Allure results generated for both unit and E2E
  - [ ] Coverage threshold enforced (70% minimum)

### Step 3: Create Docker + deploy + CI/CD infrastructure
- **Project**: Studio (new)
- **Directory**: `/Users/gregor/dev/922/studio`
- **Parallel with**: —
- **Dependencies**: Steps 1 + 2 (app and tests must be ready)
- **Description**:
  1. Create `Dockerfile` (mirror portfolio: Node 22-Alpine build → Node 22-Alpine standalone runtime)
     - Include `NEXT_PUBLIC_GA_MEASUREMENT_ID` build arg (same as portfolio)
  2. Create `docker-compose.yaml`:
     - Container: `studio`
     - Network: `proxy` (external)
     - Internal Next.js port: 3000 (standard)
     - Build arg: `NEXT_PUBLIC_GA_MEASUREMENT_ID: G-1GSBD62ZVM`
     - Healthcheck: Node fetch to `http://localhost:3000/`
     - Traefik labels:
       - `studio.922-studio.com` → studio service
       - No auth middleware (public)
  3. Create `deploy.sh` following zero-downtime pattern:
     - `SKIP_PULL` support
     - Pre-build cache cleanup
     - Build retry with `--no-cache` fallback
     - `--wait --wait-timeout 120`
     - No `docker compose down`
  4. Create `.github/workflows/deploy.yml`:
     - cancel-previous → version → unit tests → kick-off-e2e → deploy → notify
     - Unit tests use `922-Studio/workflows/.github/workflows/frontend-tests.yml`
     - Allure project ID: `studio-unit`
     - Allure launch name: `Studio Unit Tests`
     - Deploy uses `922-Studio/workflows/.github/workflows/deploy-docker.yml`
     - Repository path: `/home/lab/studio`
     - Service name: `studio`
     - Discord notifications on success/failure
     - Issue creation on failure
  5. Create `.github/workflows/e2e.yml`:
     - Triggered by `workflow_dispatch` (kicked off after unit tests)
     - Playwright Chrome tests with 2 retries
     - Allure project ID: `studio-e2e`
     - Allure launch name: `Studio E2E Tests`
- **Context files to read**:
  - `portfolio/Dockerfile` — build pattern
  - `portfolio/docker-compose.yaml` — Traefik labels pattern (but NOT the redirect labels)
  - `portfolio/deploy.sh` — deployment script
  - `portfolio/.github/workflows/deploy.yml` — CI/CD pipeline
  - `guides/new-service-setup.md` — full checklist
- **Acceptance criteria**:
  - [ ] `docker compose build` succeeds
  - [ ] `docker compose up` serves the site
  - [ ] Traefik labels route `studio.922-studio.com` correctly
  - [ ] `deploy.sh` follows zero-downtime pattern (no `docker compose down`)
  - [ ] GitHub Actions `deploy.yml` uses reusable workflows correctly
  - [ ] GitHub Actions `e2e.yml` dispatches correctly
  - [ ] Allure project IDs are kebab-case (`studio-unit`, `studio-e2e`)

### Step 4: Configure GitHub repo secrets + runner
- **Project**: Studio (GitHub)
- **Directory**: — (`gh` CLI)
- **Parallel with**: —
- **Dependencies**: Step 1 (repo must exist)
- **Description**:
  1. Add repo secrets via `gh secret set`:
     - `PAT_GITHUB` — personal access token (for versioning, dispatch, deploy)
     - `DISCORD_BOT_TOKEN` — for deploy notifications
  2. Enable self-hosted runner access for the `922-Studio/studio` repo
  3. Create Allure projects on the Allure server:
     - `studio-unit`
     - `studio-e2e`
- **Context files to read**:
  - `portfolio/.github/workflows/deploy.yml` — which secrets are referenced
- **Acceptance criteria**:
  - [ ] `PAT_GITHUB` and `DISCORD_BOT_TOKEN` secrets set
  - [ ] Self-hosted runner can pick up jobs for this repo
  - [ ] Allure projects `studio-unit` and `studio-e2e` exist on the server

### Step 5: Deploy studio site to server
- **Project**: Studio
- **Directory**: Server (`ssh lab`)
- **Parallel with**: —
- **Dependencies**: Steps 1–4 all complete
- **Description**:
  1. Clone repo on server: `cd ~ && git clone git@github.com:922-Studio/studio.git`
  2. Build and start: `cd ~/studio && docker compose up -d --build --wait`
  3. Verify Traefik picks up the route for `studio.922-studio.com`
  4. Verify site loads correctly
- **Context files to read**:
  - `guides/new-service-setup.md` — deployment steps
- **Acceptance criteria**:
  - [ ] `studio.922-studio.com` serves the studio landing page
  - [ ] `922-studio.com` still redirects to `gregor.922-studio.com` (unchanged)
  - [ ] `gregor.922-studio.com` still serves the portfolio (unchanged)
  - [ ] Container healthy: `docker ps | grep studio`

### Step 6: Add Cloudflare Tunnel hostname
- **Project**: Cloudflare Dashboard
- **Directory**: — (browser)
- **Parallel with**: Step 5 (do together during deployment)
- **Description**:
  1. Cloudflare Dashboard → Zero Trust → Tunnels → `home-lab`
  2. Add new Public Hostname:
     - **Subdomain**: `studio`
     - **Domain**: `922-studio.com`
     - **Service**: `http://home-lab:80` (Traefik handles routing via Host labels)
  3. Verify HTTPS works
- **Context files to read**:
  - `guides/new-service-setup.md` — Schritt 8 (Cloudflare Tunnel)
- **Acceptance criteria**:
  - [ ] `studio.922-studio.com` resolves via Cloudflare Tunnel → Traefik → studio container
  - [ ] HTTPS works
  - [ ] No impact on other subdomains

### Step 7: Add to HomeCollector monitoring
- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector`
- **Parallel with**: Step 8
- **Dependencies**: Step 5 (site must be deployed)
- **Description**:
  1. Add studio to `HomeCollector/config.py` → `DEFAULT_MONITORED_SERVICES`:
     ```python
     ServiceConfig(
         service_name="studio",
         display_name="922-Studio",
         group="Pages",
         monitor_type="both",
         docker_container_name="studio",
         health_url="http://studio:3000/",
     ),
     ```
  2. Commit and push → CI deploys HomeCollector automatically
  3. New service gets seeded on restart
- **Context files to read**:
  - `HomeCollector/config.py` — existing `DEFAULT_MONITORED_SERVICES` list
  - `guides/new-service-setup.md` — Schritt 10 (Monitoring)
- **Acceptance criteria**:
  - [ ] Studio appears on `status.922-studio.com`
  - [ ] Uptime polling works (Docker + HTTP)
  - [ ] Status shows green

### Step 8: Update Planner documentation
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: Step 7
- **Dependencies**: Step 5 (site must be deployed)
- **Description**:
  1. Create `projects/studio.md` from template with full mapping
  2. Add Studio to `registry.md` (project #13)
  3. Update `server.md`:
     - Add `Studio | 3002 (internal) | studio` to Application Services table
     - Add `studio.922-studio.com` to Public Routes table
  4. Update `showcase.md` changelog with studio launch entry
  5. Update architecture diagram in `registry.md` to include Studio
  6. Update `guides/new-service-setup.md` reference table with Studio entry
- **Context files to read**:
  - `projects/_template.md` — project mapping template
  - `registry.md` — current entries and diagram
  - `server.md` — current infrastructure reference
- **Acceptance criteria**:
  - [ ] `projects/studio.md` exists with full mapping
  - [ ] Registry updated with project #13
  - [ ] Server reference includes new service and route
  - [ ] Architecture diagram shows Studio
  - [ ] New service guide reference table updated

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Scaffold Next.js project + pages + content + blog  → Studio @ /Users/gregor/dev/922/studio
  Step 2: Test suite (Vitest + Playwright + Allure)           → Studio @ /Users/gregor/dev/922/studio

Wave 2 (after wave 1):
  Step 3: Docker + deploy.sh + CI/CD workflows                → Studio @ /Users/gregor/dev/922/studio

Wave 3 (after wave 2):
  Step 4: GitHub secrets + runner + Allure projects           → GitHub (gh CLI) + Allure server

Wave 4 (together):
  Step 5: Deploy to server (clone + docker compose up)        → Server (ssh lab)
  Step 6: Add Cloudflare Tunnel hostname                      → Cloudflare Dashboard

Wave 5 (parallel, after wave 4):
  Step 7: Add to HomeCollector monitoring                     → HomeCollector @ /Users/gregor/dev/922/HomeCollector
  Step 8: Update Planner docs (registry, server, mapping)     → Planner @ /Users/gregor/dev/922/Planner
```

## Post-Execution Checklist
- [ ] `studio.922-studio.com` serves studio landing page
- [ ] `922-studio.com` still redirects to `gregor.922-studio.com` (unchanged)
- [ ] `gregor.922-studio.com` still serves portfolio (no regression)
- [ ] Blog page renders with at least one post
- [ ] Blog post pages render MDX correctly
- [ ] Collaborators section shows Gregor + Iustus with correct portfolio links
- [ ] Timeline populated with key milestones from showcase.md
- [ ] Projects section shows all active projects
- [ ] Dark/light theme works
- [ ] i18n (EN/DE) works
- [ ] Mobile responsive
- [ ] `npm run test` — all unit tests pass
- [ ] `npm run test:e2e` — all E2E tests pass
- [ ] Allure reports uploaded to `studio-unit` and `studio-e2e` projects
- [ ] Studio appears on `status.922-studio.com` with green status
- [ ] GitHub Actions pipeline runs successfully on push
- [ ] Discord notification fires on deploy
- [ ] All documentation updated (registry, server, project mapping)
