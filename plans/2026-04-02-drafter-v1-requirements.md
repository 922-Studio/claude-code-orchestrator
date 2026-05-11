# Drafter v1.0.0 — Requirements

- **Date**: 2026-04-02
- **Project(s)**: Drafter
- **Goal**: Define all requirements for the Drafter v1.0.0 release. This document is the single source of truth for planning execution.

## Context

- Current version: `v0.3.4`
- Current branch: `dev`
- State: Core CRUD works, MinIO deployed, auth works. Missing API key auth, several UI bugs, and several missing features.
- Reference: `plans/2026-03-27-drafter-bugfixes-and-testing.md` — partial execution, UI fixes unverified

---

## Requirement Groups

---

### R1 — Unverified UI Fixes (carry-over from v0.3.x plan)

These were planned in `2026-03-27-drafter-bugfixes-and-testing.md` but execution was not verified against the live app. Must be confirmed working or implemented.

| ID | Requirement | Status |
|----|-------------|--------|
| R1.1 | Brand avatar: clicking the avatar circle opens file picker, uploads to S3, displays result, persists across reload | Unverified |
| R1.2 | Connected Accounts section on Branding page shows "Coming Soon" badge, no connect/disconnect buttons | Unverified |
| R1.3 | Dashboard stats cards (Total Posts/Views/Likes/Engagement) are **removed entirely** — not just dimmed (see R4.1) | To change |
| R1.4 | Version number visible in sidebar bottom-left (`v0.3.4` etc.) | Unverified |
| R1.5 | S3 image display: uploaded images render correctly in Media page, Post detail, and Media upload zone | Unverified |
| R1.6 | Save draft in edit mode: stays on page, shows toast, no redirect | Unverified |
| R1.7 | Schedule post: datetime-local format accepted, toast shown, redirect to /posts | Unverified |

---

### R2 — External API Access (API Key System)

Enable external agent systems (content generation pipeline) to call Drafter's API without a browser session.

| ID | Requirement |
|----|-------------|
| R2.1 | `ApiKey` model in Prisma: `id`, `orgId`, `name`, `keyHash` (bcrypt), `keyPrefix` (first 8 chars for display), `createdAt`, `lastUsedAt`, `active` (bool), `createdBy` |
| R2.2 | `POST /api/keys` — generate a new API key, return the full key **once** (never stored in plaintext) |
| R2.3 | `GET /api/keys` — list all keys for the org (shows prefix + name, never full key) |
| R2.4 | `DELETE /api/keys/[id]` — revoke a key |
| R2.5 | Middleware extended: `X-API-Key` header accepted as auth alternative to JWT. Key is validated by hash lookup. `lastUsedAt` updated on use. |
| R2.6 | API key scoped to org: all requests made with an API key behave as if the org user is authenticated (same data isolation) |
| R2.7 | Settings page shows API key management UI: list keys, generate new key, revoke, copy key on creation |
| R2.8 | API key only valid for `/api/posts` and `/api/media` routes (not `/api/auth`, `/api/keys` themselves require JWT) |

---

### R3 — Settings Page

New page: `/settings` — user and org configuration hub.

| ID | Requirement |
|----|-------------|
| R3.1 | New sidebar entry "Settings" with a gear icon, navigates to `/settings` |
| R3.2 | **Platform Toggles** section: per-user toggle for each platform (Instagram, TikTok, LinkedIn, Facebook, Blog). Only enabled platforms appear in the post editor's platform/post-type selector. Stored in user preferences (new `UserSettings` model or JSON column on user). |
| R3.3 | Default state: all platforms enabled |
| R3.4 | **API Keys** section (from R2.7): list, generate, revoke, copy key |
| R3.5 | Settings persist server-side (not localStorage) via a `UserSettings` table or JSON column |
| R3.6 | `GET /api/settings` — return current user settings |
| R3.7 | `PATCH /api/settings` — update user settings (platform toggles etc.) |

---

### R4 — Dashboard Overhaul

Replace placeholder/mock content with real data.

| ID | Requirement |
|----|-------------|
| R4.1 | **Remove** the 4 stats cards (Total Posts, Total Views, Total Likes, Engagement Rate) entirely from the dashboard — no "Coming soon", no placeholder, just remove the section |
| R4.2 | **Recent Posts** section shows the 5 most recently created or updated posts as real post cards: title, platform badge, status badge, scheduledAt if set, thumbnail if media attached |
| R4.3 | Each Recent Post card links to the post detail page |
| R4.4 | **Upcoming Schedule** section shows the next 5 scheduled posts (status = SCHEDULED, scheduledAt > now), ordered by scheduledAt ascending: title, platform, scheduled date/time |
| R4.5 | Each Upcoming Schedule entry links to the post detail page |
| R4.6 | Both sections fetch from real API (`/api/posts` with appropriate filters/sort/limit) |
| R4.7 | Empty state for both sections when no posts exist |
| R4.8 | Quick Actions (+ New Post, View Calendar, View Timeline) remain as-is |

---

### R5 — Timeline Fix

| ID | Requirement |
|----|-------------|
| R5.1 | Posts with `scheduledAt` in the **past** and status = `SCHEDULED` are automatically displayed as "Posted" in the Timeline view (visual treatment: check icon, muted/green color) |
| R5.2 | The status is **not** mutated in the database — this is a display-only rule: `if status === SCHEDULED && scheduledAt < now → show as PUBLISHED` |
| R5.3 | Timeline sections: Past (scheduledAt < today), Today, Upcoming (scheduledAt > today), Drafts (no scheduledAt) — with correct post placement |
| R5.4 | Timeline shows post title, platform badge, scheduled date |

---

### R6 — Calendar Fix

| ID | Requirement |
|----|-------------|
| R6.1 | Posts display correctly on calendar day cells: title truncated, platform color indicator, status indicator |
| R6.2 | Clicking a post on the calendar navigates to the post detail page |
| R6.3 | Calendar shows posts in the correct day based on `scheduledAt` date |
| R6.4 | DRAFT posts (no scheduledAt) are not shown on the calendar |
| R6.5 | Multiple posts on the same day stack/list correctly without overflow |

---

### R7 — Multi-Platform Posts

Allow a single post to target multiple platforms simultaneously.

| ID | Requirement |
|----|-------------|
| R7.1 | Post model updated: `platforms` field becomes an array (`Platform[]`) — replace single `platform: Platform` with `platforms: Platform[]` |
| R7.2 | `postType` field becomes `postTypes: PostType[]` or is removed in favor of per-platform post types (decision: keep single postType for content structure, platforms is the multi-select target list) |
| R7.3 | Post editor: platform selector becomes a multi-select (checkbox group or multi-toggle). At least 1 platform required. |
| R7.4 | Post list and detail pages show all selected platforms as a badge list |
| R7.5 | API `POST /api/posts` and `PATCH /api/posts/[id]` accept `platforms: Platform[]` |
| R7.6 | Filtering by platform on the Post list still works (post appears if it includes that platform) |
| R7.7 | Platform toggles from Settings (R3.2) control which platforms are available in the multi-select |
| R7.8 | Database migration: rename `platform` → `platforms`, change to array type (PostgreSQL `text[]` via Prisma) |

---

### R8 — Blog Platform

| ID | Requirement |
|----|-------------|
| R8.1 | New platform value: `BLOG` added to `Platform` enum |
| R8.2 | New post type value: `BLOG_POST` added to `PostType` enum |
| R8.3 | Blog platform has its own `platformFields`: `slug` (string), `tags` (string[]), `excerpt` (string, max 300) |
| R8.4 | Post editor shows Blog-specific fields when Blog is selected |
| R8.5 | Blog platform icon/badge uses a document/article icon (distinct from social media platforms) |
| R8.6 | Blog posts included in Settings platform toggle (R3.2) |

---

### R9 — Quick Copy / Quick View

Optimized for mobile and desktop to quickly copy post content for manual posting.

| ID | Requirement |
|----|-------------|
| R9.1 | Post list: each post card has a "Quick Copy" button (clipboard icon) — single click copies the caption to clipboard |
| R9.2 | Post list: each post card has a "Quick View" button or the card is clickable to open a slide-over / bottom-sheet showing: title, full caption, platform badges, scheduled date, attached media thumbnails |
| R9.3 | Quick View includes a prominent "Copy Caption" button |
| R9.4 | Quick View includes a "Copy as [Platform] format" button (uses existing copy-format logic from `/api/posts/[id]/copy`) |
| R9.5 | Quick View is a modal/sheet — no page navigation, works on mobile |
| R9.6 | Quick Copy shows a toast confirmation "Copied!" after copy |
| R9.7 | Keyboard shortcut for Quick Copy: `C` when a post card is focused |

---

### R10 — Branding Page Cleanup

| ID | Requirement |
|----|-------------|
| R10.1 | Remove the stats section from the Branding page entirely (any hardcoded stats, follower counts, engagement metrics) |
| R10.2 | Branding page retains: brand name, brand avatar upload (R1.1), Connected Accounts "Coming Soon" section |

---

### R11 — Sidebar Fix

| ID | Requirement |
|----|-------------|
| R11.1 | Sidebar must never be vertically scrollable. Navigation items must fit within viewport height at all times. |
| R11.2 | If the number of nav items grows, they must shrink or be collapsed — never overflow with a scrollbar |

---

### R12 — UAT & Testing

| ID | Requirement |
|----|-------------|
| R12.1 | `docs/UAT.md` — comprehensive UAT checklist covering every user-facing feature. Organized by page. Includes manual test steps and expected outcomes. |
| R12.2 | Vitest unit tests: all API routes covered (posts CRUD, media CRUD, keys CRUD, settings, auth). Target ≥ 80% coverage. |
| R12.3 | Vitest unit tests: all lib functions (s3, validators, auth, auth-helpers, api-client). |
| R12.4 | Playwright E2E tests: navigation, post CRUD, scheduling, media upload, quick copy/view, settings platform toggle, API key generation |
| R12.5 | `pnpm test` passes. `pnpm test:e2e` passes. `pnpm type-check` passes. `pnpm build` succeeds. |
| R12.6 | CI/CD pipeline runs unit tests on every push to `dev`. E2E tests run on PR. |

---

## Data Model Changes Summary

| Change | Type | Notes |
|--------|------|-------|
| `Post.platform: Platform` → `Post.platforms: Platform[]` | Schema migration | Breaking — requires data migration |
| Add `ApiKey` model | New model | orgId, name, keyHash, keyPrefix, active, lastUsedAt |
| Add `UserSettings` model (or JSON on User) | New model | platformToggles: Platform[] |
| Add `Platform.BLOG` | Enum value | Non-breaking add |
| Add `PostType.BLOG_POST` | Enum value | Non-breaking add |

---

## Definition of Done — v1.0.0

- [ ] All R1.x UI fixes verified working in dev environment
- [ ] External API callable with `X-API-Key` header — posts CRUD + media CRUD
- [ ] API key management UI in Settings page
- [ ] Settings page live with platform toggles and API keys section
- [ ] Dashboard shows real recent posts + upcoming schedule
- [ ] Dashboard stats cards removed
- [ ] Timeline correctly marks past-scheduled posts as "Posted"
- [ ] Calendar displays posts on correct day cells
- [ ] Post editor supports multi-platform selection
- [ ] Blog platform available as option
- [ ] Quick Copy button on post cards (1-click caption copy)
- [ ] Quick View sheet on post cards (mobile-friendly)
- [ ] Branding page stats removed
- [ ] Sidebar never scrollable
- [ ] `docs/UAT.md` complete
- [ ] Unit test coverage ≥ 80%
- [ ] E2E tests pass
- [ ] `pnpm build` succeeds
- [ ] Pipeline green on `dev` branch
- [ ] Version bumped to `1.0.0`
