# Plan: Content Module MVP — Rename + Frontend with Mock Data

- **Date**: 2026-03-21
- **Project(s)**: HomeUI, HomeSocial (→ HomeContent), HomeStructure, Planner, Workflows
- **Goal**: Rename HomeSocial → HomeContent everywhere, build the new Content module UI in HomeUI with mock data matching the Pencil mockups 1:1, and create a tech stack showcase panel.

## Context

Read these files before proceeding:
- `projects/homeui.md` — HomeUI mapping, tech stack, best practices
- `projects/homesocial.md` — HomeSocial mapping (to be renamed)
- `projects/homestructure.md` — Infrastructure: Traefik, Docker, ports
- `server.md` — Server reference

### Design Reference
- Pencil mockups in `pencil-new.pen` (3 screens: Overview, Timeline, Overview + Post Detail Modal)
- Design tokens: bg=#0C0C0C, surface=#111111, elevated=#1A1A1A, border=#1E1E1E
- Section color: **cyan (#06b6d4)**
- Font: JetBrains Mono throughout
- Rounded corners on all cards, badges, modals (8-16px radius)
- Status badges: published=emerald pill, scheduled=indigo pill, draft=amber pill
- Stat cards with border, no fill
- Table pattern matching Finance/Ledger page

### Decisions Made
- Module name: **Content** (sidebar), **HomeContent** (service/repo)
- Status values: `draft`, `scheduled`, `published` (displayed as-is)
- Post detail: modal overlay on current page, not a route
- Timeline: own route at `/content/timeline`
- Search: frontend-only filtering, no API call
- Date picker: calendar with cyan dots on days that have existing posts
- Status picker: dropdown with rounded corners
- Background dims 30% when viewing a post
- Mock data first, API integration later

---

## Steps

### Step 1: Rename HomeSocial → HomeContent (Backend)
- **Project**: HomeSocial
- **Directory**: `/Users/gregor/dev/922/HomeSocial`
- **Parallel with**: Step 2
- **Description**: Rename the service internally. This is the foundation — everything else depends on the new name.
  - Rename all references from `HomeSocial`/`homesocial`/`social` to `HomeContent`/`homecontent`/`content` in:
    - `README.md`, `CLAUDE.md` — project docs
    - `docker-compose.yaml` — service names, container names, volume paths
    - `deploy.sh` — deployment script references
    - `config.py` — CORS origins, service name
    - `app/main.py` — app title, description, docs URL
    - `.github/workflows/deploy.yml` — workflow name, image name, deploy path
    - All Discord notification messages
  - **Do NOT rename** the database name yet (migration risk) — just the service identity
  - **Do NOT rename** the role `social` yet — that's an auth concern across services
  - Update the `MEDIA_STORAGE_PATH` default from `/mnt/storage/homesocial/` to `/mnt/storage/homecontent/`
- **Context files to read**:
  - `HomeSocial/CLAUDE.md` — current conventions
  - `HomeSocial/docker-compose.yaml` — service topology
  - `HomeSocial/.github/workflows/deploy.yml` — CI/CD pipeline
- **Acceptance criteria**:
  - [ ] `docker-compose.yaml` has container names with `homecontent`
  - [ ] Health endpoint returns service name `homecontent`
  - [ ] CI/CD workflow references updated
  - [ ] All tests pass: `PYTHONPATH=. pytest tests/ -v`
  - [ ] No remaining `homesocial` references (except DB name and role)

### Step 2: Rename HomeSocial → HomeContent (Infrastructure)
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: Step 1
- **Description**: Update infrastructure references.
  - Traefik labels: `lab-social.922-studio.com` → `lab-content.922-studio.com`
  - Docker network references if any
  - Monitoring configs if HomeSocial is referenced
  - Storage path: ensure `/mnt/storage/homecontent/media/` exists on server
  - Update Cloudflare tunnel config if applicable
- **Context files to read**:
  - `HomeStructure/docs/` — infra documentation
  - `server.md` — port and service reference
- **Acceptance criteria**:
  - [ ] Traefik route points to new service name
  - [ ] Storage directory exists
  - [ ] Service accessible via new URL after deploy

### Step 3: Rename in HomeUI Frontend
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: None (mock data, no backend dependency)
- **Description**: Rename all social references to content in the frontend.
  - `src/lib/socialHttp.ts` → `src/lib/contentHttp.ts` (rename `VITE_SOCIAL_URL` → `VITE_CONTENT_URL`)
  - `src/api/social.ts` → `src/api/content.ts` (rename `socialQueryOptions` → `contentQueryOptions`, `socialHttp` → `contentHttp`)
  - `src/types/api/social.ts` → `src/types/api/content.ts`
  - `src/hooks/useSocial.ts` → `src/hooks/useContent.ts` (rename all hooks)
  - `src/features/social/` → `src/features/content/` (entire directory)
  - `src/App.tsx` — route from `/social` → `/content`
  - `src/components/layout/AppSidebar.tsx` — nav item label and icon
  - `src/i18n/en.json` and `src/i18n/de.json` — i18n keys from `social.*` → `content.*`
  - `src/test/msw/handlers.ts` — mock handlers
  - `.env` / `.env.example` — `VITE_SOCIAL_URL` → `VITE_CONTENT_URL`
- **Context files to read**:
  - `HomeUI/CLAUDE.md` — architecture rules
  - All files listed above
- **Acceptance criteria**:
  - [ ] No remaining `social`/`Social` references (except role check `hasRole('social')`)
  - [ ] App compiles without errors
  - [ ] Existing tests pass with updated imports

### Step 4: Build Content Overview Page (Mock Data)
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: Step 3
- **Description**: Replace the existing SocialPage with the new Content Overview matching the mockup 1:1.
  - **Layout**: `SectionLayout` with `SectionNav` (label="Content", color="#06b6d4")
    - Nav items: Overview (LayoutGrid icon, `/content`, exact=true), Timeline (GitCommitHorizontal icon, `/content/timeline`)
  - **Sidebar icon** in AppSidebar: `Tag` → replace with appropriate Lucide icon, color cyan
  - **Search bar**: Top-right, rounded corners, frontend filtering with `useMemo` on the mock data — filters by title and content fields
  - **Stat cards**: 4 cards in a row (Total Posts, Scheduled, Drafts, Published) — compute from mock data
  - **Posts table**: Using `DataTable` component pattern from Finance/Ledger
    - Columns: POST (thumbnail + title), PLATFORM, STATUS (colored pill badge), DATE
    - Rows clickable → opens post detail modal
    - Status badges: published=`#10B98120` bg + emerald text, scheduled=`#6366F120` bg + indigo text, draft=`#F59E0B20` bg + amber text, all with `cornerRadius: 20px` (pill shape)
  - **Mock data**: 7-10 posts with varied statuses, platforms, dates, titles
  - **Mock data file**: `src/features/content/data/mockPosts.ts` — typed array of `Post` objects
- **Context files to read**:
  - `HomeUI/src/components/layout/SectionNav.tsx` — nav pattern
  - `HomeUI/src/components/layout/SectionLayout.tsx` — layout wrapper
  - `HomeUI/src/components/ui/DataTable.tsx` — table component
  - `HomeUI/src/features/debts/pages/LedgerPage.tsx` — table usage example
  - `HomeUI/src/components/ui/StatCard.tsx` — stat card pattern
- **Acceptance criteria**:
  - [ ] Overview page renders with sidebar nav, stats, table
  - [ ] Search filters posts in real-time (no API call)
  - [ ] Stat cards show correct counts computed from mock data
  - [ ] Table rows show thumbnail, title, platform, status badge, date
  - [ ] Visual match with Pencil mockup "Overview" screen

### Step 5: Build Post Detail Modal
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: Step 4
- **Description**: Build the post detail modal that opens when clicking a table row.
  - **Overlay**: 30% dimmed background (`rgba(0,0,0,0.3)`)
  - **Modal**: Centered, 560px wide, rounded corners (16px), dark surface (#111111), border (#222222)
  - **Image preview**: Top section, full-width, 240px height, rounded top corners
  - **Metadata row**: 3 fields (Platform, Status, Date) in rounded dark boxes (#161616)
  - **Date field**: Clickable → opens a **calendar picker**
    - Calendar styled to match the dark theme (custom CSS on existing date picker or build custom)
    - Days with existing posts show a **small cyan dot** below the day number
    - Selecting a date updates the mock data locally
  - **Status field**: Clickable → opens a **dropdown** with rounded corners
    - Options: Draft, Scheduled, Published
    - Each option shows the colored dot + label
    - Styled dark (#161616 bg, #222222 border, 8px radius)
  - **Content section**: Full post text
  - **Action buttons**: Delete (rose outline), Edit (neutral outline), Approve (indigo filled)
  - **Close**: X button top-right, click outside closes
- **Context files to read**:
  - `HomeUI/src/components/ui/dialog.tsx` — existing dialog pattern
  - Pencil mockup "Overview + Post Detail" screen
- **Acceptance criteria**:
  - [ ] Modal opens on row click with 30% backdrop dim
  - [ ] Image, metadata, content displayed correctly
  - [ ] Calendar picker opens on date click, shows cyan dots for days with posts
  - [ ] Status dropdown opens on status click, allows selection
  - [ ] Close via X button and outside click
  - [ ] Visual match with Pencil mockup

### Step 6: Build Timeline Page
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: Step 4 (shares mock data and post detail modal)
- **Description**: Build the Timeline page at `/content/timeline`.
  - **Vertical line**: 2px wide, centered horizontally in the content area, full height
  - **Today marker**: Indigo pill badge with dot, positioned on the line at "today" position
  - **Section labels**: "Past" above today, "Upcoming" below today — small pills
  - **Post cards**: Alternating left/right of the center line
    - Connected to line via horizontal connector + colored dot
    - Dot color matches status: published=emerald, scheduled=indigo, draft=amber
    - Card: rounded (10px), dark bg (#111111), border colored by status
    - Contains: thumbnail, title, date, status badge
    - **Clickable** → opens the same post detail modal from Step 5
  - **Scrolling**: Smooth scroll, native CSS `overflow-y: auto` on the timeline container
    - Only scrollable when content exceeds viewport
    - No forced scroll when not enough content
  - **Post ordering**: Published (past, top) → Today → Scheduled (future) → Draft (no date, bottom)
- **Context files to read**:
  - Pencil mockup "Timeline" screen
- **Acceptance criteria**:
  - [ ] Vertical timeline with centered line
  - [ ] Today marker positioned correctly
  - [ ] Posts alternate left/right
  - [ ] Cards clickable → opens post detail modal
  - [ ] Smooth scrolling only when needed
  - [ ] Visual match with Pencil mockup

### Step 7: Build Tech Stack Showcase Panel
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Dependencies**: Step 4
- **Description**: Temporary showcase page/panel for presenting the tech stack and workflow.
  - Accessible via a route or a button in the Content section
  - Shows the 4-step flow: Collect Ideas → AI Generate → Review & Approve → Discord Deliver
  - Tech stack badges: HomeUI (React), HomeContent (FastAPI), Discord (Bot), Claude (AI)
  - Styled to match the dark theme
  - **This is temporary** — for presentation purposes only, not part of final product
  - We will design the mockup for this separately (see below)
- **Acceptance criteria**:
  - [ ] Flow visualization renders
  - [ ] Tech stack displayed
  - [ ] Accessible from Content module

### Step 8: Update Planner Registry & Mappings
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: Step 7
- **Description**: Update all Planner references.
  - `registry.md` — rename HomeSocial → HomeContent
  - `projects/homesocial.md` → `projects/homecontent.md` — rename file and all content
  - `server.md` — update port/service references
  - Update dependency graph
- **Context files to read**:
  - `registry.md`
  - `projects/homesocial.md`
  - `server.md`
- **Acceptance criteria**:
  - [ ] No remaining HomeSocial references in Planner
  - [ ] Registry graph updated
  - [ ] Server mapping updated

### Step 9: Update Workflows
- **Project**: Workflows
- **Directory**: `/Users/gregor/dev/922/workflows`
- **Parallel with**: Step 8
- **Description**: Check if any reusable workflow references HomeSocial by name and update.
- **Acceptance criteria**:
  - [ ] No remaining HomeSocial references in workflows

### Step 10: Rename GitHub Repository
- **Project**: HomeSocial → HomeContent
- **Parallel with**: After all code changes are pushed
- **Description**: Rename the GitHub repository from HomeSocial to HomeContent.
  - Rename on GitHub (Settings → Rename)
  - Update git remote in local clone: `git remote set-url origin ...`
  - Update all CI/CD workflow references to new repo name
  - Update Planner mappings with new path if changed
  - **Requires Gregor's confirmation** before executing
- **Acceptance criteria**:
  - [ ] Repository renamed on GitHub
  - [ ] Local clone points to new remote
  - [ ] CI/CD still works

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Rename backend HomeSocial → HomeContent    → HomeSocial @ /Users/gregor/dev/922/HomeSocial
  Step 2: Rename infra references                     → HomeStructure @ /Users/gregor/dev/922/HomeStructure

Wave 2 (after Wave 1):
  Step 3: Rename frontend social → content            → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 3 (after Step 3):
  Step 4: Build Content Overview page with mock data  → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 4 (after Step 4):
  Step 5: Build Post Detail Modal                     → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 6: Build Timeline Page                         → HomeUI @ /Users/gregor/dev/922/HomeUI (parallel with Step 5)

Wave 5 (after Step 5+6):
  Step 7: Build Tech Stack Showcase Panel             → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 6 (parallel):
  Step 8: Update Planner registry & mappings          → Planner @ /Users/gregor/dev/922/Planner
  Step 9: Update Workflows                            → Workflows @ /Users/gregor/dev/922/workflows

Wave 7 (after all pushed):
  Step 10: Rename GitHub repository                   → GitHub (requires confirmation)
```

## Post-Execution Checklist
- [ ] All HomeUI tests pass (`npm run test:ci`)
- [ ] All HomeSocial tests pass (`PYTHONPATH=. pytest tests/ -v`)
- [ ] HomeUI builds without errors (`npm run build`)
- [ ] No remaining `HomeSocial`/`homesocial`/`social` references across ecosystem (except auth role)
- [ ] Planner documentation updated
- [ ] Pipeline green after push
- [ ] Mock data UI matches Pencil mockups 1:1
- [ ] Search, calendar picker, status dropdown all functional
- [ ] Timeline scrolls smoothly
