# Plan: HomeSocial — Social Media Content Management Service

- **Date**: 2026-03-19
- **Project(s)**: HomeSocial (new), HomeAuth, HomeUI, Discord Bot, HomeStructure, Workflows
- **Goal**: Build a dedicated microservice and HomeUI feature module for managing, creating (manual + AI), previewing, and scheduling social media content for Instagram and Facebook — with role-based access control and Discord notifications before scheduled sends.

## Context

Read these files before proceeding:
- `projects/homeauth.md` — Auth architecture, role system exists
- `projects/homeui.md` — Frontend patterns, feature module structure
- `projects/discord.md` — Bot cog structure, HomeAPI integration pattern
- `projects/homeapi.md` — Backend patterns (HomeSocial mirrors this stack)
- `projects/workflows.md` — CI/CD reusable workflows
- `guides/new-service-setup.md` — 10-step infra integration guide
- `server.md` — Server infrastructure reference

## Architecture Overview

```
                     ┌──────────────┐
                     │   HomeUI     │  New feature module: /social
                     │  (React/TS)  │  Role-gated navigation + routes
                     └──────┬───────┘
                            │ HTTP (Bearer JWT)
                  ┌─────────┴─────────┐
                  │                   │
           ┌──────┴──────┐    ┌──────┴──────┐
           │  HomeAuth   │    │ HomeSocial  │
           │ (roles JWT) │    │ (FastAPI)   │
           └─────────────┘    └──────┬──────┘
                                     │
                              ┌──────┴──────┐
                              │ Discord Bot │  Notification cog
                              │ (EggVault)  │  before scheduled send
                              └─────────────┘
```

**Auth flow for HomeSocial:**
1. User logs in → HomeAuth issues JWT with roles in payload (new)
2. HomeUI reads roles from `/auth/me` → shows/hides nav items
3. API calls to HomeSocial go through Traefik forward-auth middleware → X-User-Roles header
4. HomeSocial validates role="social" from header, rejects 403 if missing

**Meta API integration is deferred.** Phase 1 focuses on:
- Content management (CRUD posts, media upload, preview)
- Instagram-like card preview in UI + copy-to-clipboard for manual posting
- Scheduling with Discord notification at scheduled time
- AI-assisted content generation (optional, default off)

## Tech Stack Decision: HomeSocial

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Python 3.13 | Matches ecosystem (HomeAPI, HomeCollector, Discord Bot) |
| Framework | FastAPI + Pydantic V2 | Matches ecosystem, async-first |
| ORM | SQLAlchemy 2.0 (async) + Alembic | Matches ecosystem |
| Database | PostgreSQL 16 (shared_postgres) | Existing infra |
| Cache/Broker | Redis (shared_redis, DB 3) | Next free slot |
| Background | Celery 5.x + Beat | Scheduling, notifications |
| File Storage | Local volume (/mnt/storage/homesocial/) | Media assets |
| AI | Existing LLM setup (Gemini via HomeAPI pattern) | Reuse existing |
| CI/CD | 922-Studio/workflows | Ecosystem standard |
| Linting | ruff + mypy | Ecosystem standard |
| Testing | pytest + pytest-asyncio, 70% coverage min | Ecosystem standard |
| Port | 8012 | Next free after HomeCollector (8011) |
| Domain | lab-social.922-studio.com | Ecosystem naming |

## Data Model: HomeSocial

```
posts
├── id (UUID PK)
├── user_id (UUID, from JWT/header)
├── title (String, optional)
├── content (Text, required)
├── platform (Enum: instagram, facebook, both)
├── status (Enum: draft, scheduled, published, failed)
├── scheduled_at (DateTime, nullable)
├── published_at (DateTime, nullable)
├── ai_generated (Boolean, default=false)
├── ai_prompt (Text, nullable — prompt used for generation)
├── created_at (DateTime)
└── updated_at (DateTime)

media_assets
├── id (UUID PK)
├── post_id (UUID FK → posts, CASCADE)
├── file_path (String)
├── file_name (String)
├── file_type (Enum: image, video)
├── mime_type (String)
├── file_size (Integer, bytes)
├── sort_order (Integer)
├── alt_text (String, nullable)
├── created_at (DateTime)
└── updated_at (DateTime)
```

## Steps

---

### Step 1: HomeAuth — Add roles to JWT payload + verify /auth/me returns roles

- **Project**: HomeAuth
- **Directory**: /Users/gregor/dev/922/HomeAuth
- **Parallel with**: Step 2
- **Description**: Extend JWT access token payload to include user roles. This is the foundation for role-based access across the entire ecosystem. Currently the JWT has `sub, jti, exp, iat, type, pwd_ver` — add `roles: string[]` (list of role names). Also verify that `GET /auth/me` returns roles in its response. This is the first time downstream services will enforce role checks, so testing must be thorough.
- **Context files to read**:
  - `HomeAuth/CLAUDE.md` — coding patterns, security rules
  - `HomeAuth/.claude/HOW-TO-PYTEST-TEST.md` — testing patterns
  - `HomeAuth/app/core/security.py` — JWT creation/decoding (add roles here)
  - `HomeAuth/app/models/user.py` — User model with roles relationship
  - `HomeAuth/app/dependencies/auth.py` — get_current_user dependency (loads roles)
  - `HomeAuth/app/routes/auth.py` — /auth/me endpoint, login endpoint
  - `HomeAuth/app/routes/admin.py` — existing role management (create role, assign to user)
  - `HomeAuth/app/schemas/auth.py` — response schemas
- **Changes**:
  1. `app/core/security.py`: Add `roles: list[str]` parameter to `create_access_token()`, include in JWT payload
  2. `app/routes/auth.py`: In login endpoint, pass user roles to `create_access_token()`
  3. `app/routes/auth.py`: Verify `/auth/me` response includes roles (likely already works via `from_attributes`)
  4. `app/schemas/auth.py`: Ensure `UserResponse` / `MeResponse` includes `roles: list[str]`
  5. `app/routes/auth.py`: In forward-auth `/auth/verify`, roles are already returned as `X-User-Roles` — verify this still works
- **Acceptance criteria**:
  - [ ] JWT access token payload includes `roles: ["social", ...]` when user has roles
  - [ ] JWT access token payload includes `roles: []` when user has no roles
  - [ ] `GET /auth/me` returns `roles` field in response body
  - [ ] `GET /auth/verify` still returns `X-User-Roles` header correctly
  - [ ] Existing token validation in HomeAPI (`app/auth.py`) is not broken (roles field is additive)
  - [ ] All existing tests still pass
  - [ ] New tests for: JWT with roles, JWT without roles, /auth/me roles field, login returns roles in token
  - [ ] Coverage ≥ 85%

---

### Step 2: GitHub Repo — Initialize HomeSocial

- **Project**: HomeSocial (new)
- **Directory**: /Users/gregor/dev/922/HomeSocial
- **Parallel with**: Step 1
- **Description**: Create new GitHub repo under 922-Studio org, clone locally, set up base project structure. Copy secrets from existing repos (JWT_SECRET, Discord webhook, etc.).
- **Context files to read**:
  - `guides/new-service-setup.md` — full setup checklist
  - `server.md` — port allocation, networking
- **Changes**:
  1. Create repo `922-Studio/HomeSocial` on GitHub (private, no template)
  2. Clone to `/Users/gregor/dev/922/HomeSocial`
  3. Initialize Python project structure (see Step 4 for full scaffolding)
  4. Copy GitHub Actions secrets from existing repo (JWT_SECRET, DISCORD_WEBHOOK_URL, SSH keys, etc.)
  5. Add branch protection on `main` (require CI pass)
- **Acceptance criteria**:
  - [ ] Repo exists at github.com/922-Studio/HomeSocial
  - [ ] Cloned locally at /Users/gregor/dev/922/HomeSocial
  - [ ] All required GitHub secrets configured (mirror from HomeAPI)
  - [ ] Branch protection enabled

---

### Step 3: HomeUI — Role-based navigation and route protection

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: — (depends on Step 1)
- **Description**: Implement role-based access control in HomeUI. This is the first role-gating in the frontend — needs thorough testing. Users without the "social" role see only: Overview, Settings, Logout. Users with "social" role additionally see the Social page. The system must be generic (not hardcoded to "social") so future roles can gate other pages.
- **Context files to read**:
  - `HomeUI/CLAUDE.md` — patterns, naming, testing rules
  - `HomeUI/.claude/HOW-TO-UNIT-TEST.md` — testing patterns
  - `HomeUI/src/features/auth/AuthContext.tsx` — auth state, user object
  - `HomeUI/src/features/auth/components/ProtectedRoute.tsx` — route protection
  - `HomeUI/src/components/layout/AppSidebar.tsx` — navigation items (lines 154-161)
  - `HomeUI/src/App.tsx` — route definitions
  - `HomeUI/src/lib/authHttp.ts` — auth HTTP client
  - `HomeUI/src/types/api/` — type definitions pattern
  - `HomeAuth/docs/HOMEUI_INTEGRATION.md` — frontend auth integration guide
- **Changes**:
  1. `src/features/auth/AuthContext.tsx`: Extend `AuthState.user` type to include `roles: string[]`. The `/auth/me` call should already return roles — just add to the type.
  2. `src/features/auth/AuthContext.tsx`: Add helper `hasRole(role: string): boolean` to auth context
  3. `src/components/layout/AppSidebar.tsx`: Add optional `requiredRole?: string` to nav item type. Filter nav items based on `hasRole()`. Items without `requiredRole` are shown to all authenticated users.
  4. `src/components/layout/AppSidebar.tsx`: Update nav items — keep Overview, Monitoring, Ledger, Wellbeing, System Health, Users as-is (no role required). These existing pages stay visible to all users.
  5. `src/features/auth/components/RoleGuard.tsx`: New component — wraps route, checks role, shows 403 page or redirects if role missing
  6. `src/App.tsx`: Add `/social` route wrapped with `RoleGuard` (role="social")
  7. Write comprehensive tests for role-based behavior
- **Acceptance criteria**:
  - [ ] User with no roles sees: Overview, Monitoring, Ledger, Wellbeing, System Health, Users, Settings, Logout (no change from current behavior)
  - [ ] User with "social" role sees all above + "Social" nav item
  - [ ] Navigating to `/social` without role shows 403 / redirects to overview
  - [ ] Navigating to `/social` with role renders the social page
  - [ ] `hasRole()` utility works correctly
  - [ ] Nav filtering is generic (supports any role string, not hardcoded)
  - [ ] Unit tests for: AuthContext with roles, RoleGuard allow/deny, sidebar filtering
  - [ ] Coverage ≥ 70%

---

### Step 4: HomeSocial — Project scaffolding + infra integration

- **Project**: HomeSocial
- **Directory**: /Users/gregor/dev/922/HomeSocial
- **Parallel with**: Step 3
- **Description**: Full project scaffolding following ecosystem patterns (mirrors HomeCollector structure). Database setup, Docker, Traefik, CI/CD, health endpoint — everything from the new-service guide.
- **Context files to read**:
  - `guides/new-service-setup.md` — complete setup checklist (all 10 steps)
  - `server.md` — ports, networks, databases
  - `HomeCollector/CLAUDE.md` — reference for project structure (closest analog)
  - `HomeCollector/docker-compose.yaml` — reference for Docker setup
  - `HomeCollector/docker-compose.ci.yaml` — reference for CI Docker setup
  - `HomeCollector/.github/workflows/deploy.yml` — reference for CI/CD
  - `HomeCollector/app/main.py` — reference for FastAPI app setup
  - `HomeCollector/app/core/database.py` — reference for async DB setup
  - `HomeCollector/config.py` — reference for env config
  - `HomeAPI/app/auth.py` — reference for JWT validation (HomeSocial validates JWT + checks role)
- **Changes**:
  1. Project structure:
     ```
     HomeSocial/
     ├── app/
     │   ├── __init__.py
     │   ├── main.py              # FastAPI app, middleware, lifespan
     │   ├── auth.py              # JWT validation + role check (X-User-Roles or JWT roles claim)
     │   ├── celery_app.py        # Celery instance
     │   ├── core/
     │   │   ├── database.py      # Async SQLAlchemy engine
     │   │   └── config.py        # Pydantic settings
     │   ├── models/
     │   │   ├── base.py          # Declarative base
     │   │   ├── post.py          # Post model
     │   │   └── media_asset.py   # MediaAsset model
     │   ├── schemas/
     │   │   ├── post.py          # Pydantic schemas
     │   │   └── media.py
     │   ├── crud/
     │   │   ├── post.py
     │   │   └── media.py
     │   ├── routers/
     │   │   ├── posts.py         # CRUD + list/filter
     │   │   ├── media.py         # Upload/delete
     │   │   └── health.py        # /health endpoint
     │   ├── services/
     │   │   ├── ai_generator.py  # LLM content generation
     │   │   └── discord_notifier.py  # Discord webhook/bot notification
     │   └── tasks/
     │       └── schedule_tasks.py  # Celery Beat: check scheduled posts, notify
     ├── alembic/
     ├── tests/
     │   ├── unit/
     │   └── integration/
     ├── Dockerfile
     ├── docker-compose.yaml
     ├── docker-compose.ci.yaml
     ├── .github/workflows/deploy.yml
     ├── .env.example
     ├── config.py
     ├── requirements.txt
     ├── CLAUDE.md
     └── README.md
     ```
  2. `app/auth.py`: Dual-mode auth (like HomeCollector):
     - Primary: Read `X-User-ID`, `X-User-Roles` from Traefik forward-auth headers
     - Fallback: Decode JWT directly (for dev/direct access), check `roles` claim
     - Require role "social" → 403 if missing
  3. Database: `homelab-ctl.sh db:create homesocial` on server
  4. Redis: DB 3 for Celery
  5. Docker Compose: api + worker + beat, proxy + infra networks, Traefik labels
  6. CI/CD: `.github/workflows/deploy.yml` using 922-Studio/workflows
  7. Alembic: Initial migration with Post + MediaAsset tables
  8. `/health` endpoint
  9. Cloudflare Tunnel: `lab-social.922-studio.com → http://home-lab:80`
  10. Traefik: HomeSocial routes configured via docker-compose labels
- **Acceptance criteria**:
  - [ ] `docker compose up` starts api + worker + beat successfully
  - [ ] `/health` returns 200
  - [ ] Alembic migration creates posts + media_assets tables
  - [ ] Auth middleware rejects requests without "social" role (403)
  - [ ] Auth middleware accepts requests with "social" role
  - [ ] CI pipeline runs (lint + test + deploy)
  - [ ] `lab-social.922-studio.com/health` accessible via Cloudflare
  - [ ] Tests for auth middleware (role check, missing role, no auth)
  - [ ] Coverage ≥ 70%

---

### Step 5: HomeSocial — Content management API (posts CRUD + media upload)

- **Project**: HomeSocial
- **Directory**: /Users/gregor/dev/922/HomeSocial
- **Parallel with**: — (depends on Step 4)
- **Description**: Implement the core REST API for post management and media upload. Posts can be created as drafts, edited, scheduled, or deleted. Media files (images/video) can be uploaded and attached to posts.
- **Context files to read**:
  - `HomeSocial/CLAUDE.md` — project patterns (created in Step 4)
  - `HomeSocial/app/models/` — data models
  - `HomeAPI/CLAUDE.md` — reference for CRUD patterns, HTTP status codes
  - `HomeAPI/.claude/HOW-TO-PYTEST-TEST.md` — testing patterns
- **Changes**:
  1. `app/routers/posts.py`:
     - `POST /api/posts/` → 201, create draft post
     - `GET /api/posts/` → 200, list posts (filter by status, platform, paginate)
     - `GET /api/posts/{id}` → 200, get single post with media
     - `PATCH /api/posts/{id}` → 200, update post (content, platform, status, schedule)
     - `DELETE /api/posts/{id}` → 204, delete post + cascade media
     - `POST /api/posts/{id}/copy` → 200, return formatted content for clipboard
  2. `app/routers/media.py`:
     - `POST /api/posts/{id}/media` → 201, upload media file(s)
     - `DELETE /api/media/{id}` → 204, delete single media asset
     - `PATCH /api/media/{id}` → 200, update alt_text, sort_order
     - `GET /api/media/{id}/file` → file response (serve the actual file)
  3. `app/crud/post.py`: CRUD operations with async SQLAlchemy
  4. `app/crud/media.py`: CRUD + file system operations
  5. File storage: `/mnt/storage/homesocial/media/{user_id}/{post_id}/` (configurable via env)
  6. Input validation: max file size (10MB images, 100MB video), allowed MIME types
- **Acceptance criteria**:
  - [ ] Full CRUD lifecycle: create → update → schedule → delete
  - [ ] Media upload with file type validation
  - [ ] Media served correctly (correct MIME type)
  - [ ] Posts scoped to authenticated user (user_id from auth)
  - [ ] Pagination works (skip/limit)
  - [ ] Filter by status and platform works
  - [ ] Copy endpoint returns formatted text (title + content + hashtags)
  - [ ] Unit tests for all CRUD operations
  - [ ] Integration tests for all router endpoints
  - [ ] Coverage ≥ 70%

---

### Step 6: HomeSocial — AI content generation endpoint

- **Project**: HomeSocial
- **Directory**: /Users/gregor/dev/922/HomeSocial
- **Parallel with**: Step 7
- **Description**: Add AI-assisted content generation using the existing LLM setup (Gemini, mirroring HomeAPI pattern). Generates post text from a user prompt. AI generation is optional (default off) and clearly marked.
- **Context files to read**:
  - `HomeSocial/CLAUDE.md` — project patterns
  - `HomeAPI/app/services/` — reference for Gemini integration pattern
  - `HomeAPI/config.py` — how GEMINI_API_KEY is configured
- **Changes**:
  1. `app/services/ai_generator.py`: Gemini client for content generation
     - `generate_post_content(prompt: str, platform: str) -> str`
     - System prompt tailored per platform (Instagram: hashtags+short, Facebook: longer form)
     - Configurable: `AI_ENABLED=false` env var (default off)
  2. `app/routers/posts.py`:
     - `POST /api/posts/generate` → 201, generate post from prompt, save as draft with `ai_generated=true`, `ai_prompt=<prompt>`
  3. Config: `GEMINI_API_KEY`, `AI_ENABLED` env vars
- **Acceptance criteria**:
  - [ ] `POST /api/posts/generate` creates AI-generated draft post
  - [ ] Generated post has `ai_generated=true` and stores the prompt
  - [ ] Returns 503 if `AI_ENABLED=false`
  - [ ] Platform-aware generation (different system prompts)
  - [ ] Unit tests with mocked Gemini responses
  - [ ] Coverage ≥ 70%

---

### Step 7: HomeSocial — Scheduling + Discord notifications

- **Project**: HomeSocial, Discord Bot
- **Directory**: /Users/gregor/dev/922/HomeSocial, /Users/gregor/dev/922/discord
- **Parallel with**: Step 6
- **Description**: Implement the scheduling system. Celery Beat checks for posts approaching their scheduled time and sends a Discord notification via the existing bot. Since Meta API is deferred, the notification says "Post X is due — publish it manually" with the content ready to copy.
- **Context files to read**:
  - `HomeSocial/CLAUDE.md` — project patterns
  - `HomeSocial/app/tasks/` — Celery task patterns
  - `discord/config.py` — channel ID configuration
  - `discord/services/homeapi.py` — HTTP client pattern (extend or create homesocial.py)
  - `discord/cogs/debt.py` — cog structure reference
  - `HomeCollector/app/tasks/uptime_tasks.py` — Celery Beat reference
- **Changes (HomeSocial)**:
  1. `app/tasks/schedule_tasks.py`:
     - Celery Beat task running every 5 minutes
     - Query posts where `status=scheduled` and `scheduled_at <= now + 15min`
     - For posts within 15-min window: send Discord notification via bot HTTP endpoint or webhook
     - Update post status to "published" (or "notified" until Meta API exists)
  2. `app/services/discord_notifier.py`:
     - Call Discord bot's HomeSocial endpoint OR use Discord webhook URL directly
     - Message format: post title, content preview, platform, scheduled time, link to UI
  3. `config.py`: `DISCORD_WEBHOOK_URL` or `DISCORD_BOT_URL` env var
- **Changes (Discord Bot)**:
  1. `config.py`: Add `DISCORD_SOCIAL_CHANNEL_ID` env var
  2. `cogs/social.py`: New cog
     - Listens for HTTP notification from HomeSocial (via HomeAPI proxy or direct)
     - Or: HomeSocial uses Discord webhook directly (simpler, no bot changes needed)
     - Posts formatted embed: title, content preview, platform icon, scheduled time
     - `;social` command to list upcoming scheduled posts
  3. `services/homesocial.py`: HTTP client for HomeSocial API (list upcoming posts)
- **Decision**: Use Discord webhook URL directly from HomeSocial for notifications (simpler, no bot dependency for sending). Add bot cog only for the `;social` query command.
- **Acceptance criteria**:
  - [ ] Celery Beat checks scheduled posts every 5 minutes
  - [ ] Discord notification sent 15 minutes before scheduled time
  - [ ] Notification includes: post title, content preview, platform, time
  - [ ] Post status updated after notification
  - [ ] `;social` bot command lists upcoming scheduled posts
  - [ ] Unit tests for scheduling logic (mock datetime)
  - [ ] Unit tests for Discord notification (mock webhook)
  - [ ] Coverage ≥ 70%

---

### Step 8: HomeUI — Social feature module (content management UI)

- **Project**: HomeUI
- **Directory**: /Users/gregor/dev/922/HomeUI
- **Parallel with**: — (depends on Steps 3, 5)
- **Description**: Build the Social feature module in HomeUI. Instagram-like post preview cards, manual content editor, AI generation toggle, media upload, scheduling picker, and copy-to-clipboard functionality.
- **Context files to read**:
  - `HomeUI/CLAUDE.md` — patterns, naming, components
  - `HomeUI/.claude/HOW-TO-UNIT-TEST.md` — testing patterns
  - `HomeUI/src/features/debts/` — reference feature module
  - `HomeUI/src/api/debts.ts` — reference API module pattern
  - `HomeUI/src/hooks/useDebts.ts` — reference hook pattern
  - `HomeUI/src/index.css` — theme variables
  - `HomeUI/tech_docs/api_integration.md` — HTTP + React Query patterns
- **Changes**:
  1. `src/api/social.ts`: API functions + queryOptions factory for HomeSocial endpoints
  2. `src/types/api/social.ts`: Zod schemas for Post, MediaAsset, API responses
  3. `src/hooks/useSocial.ts`: React Query hooks (usePosts, usePost, useCreatePost, useUpdatePost, useDeletePost, useUploadMedia, useGeneratePost)
  4. `src/lib/socialHttp.ts`: Axios instance for HomeSocial API (base URL: `VITE_SOCIAL_URL`)
  5. Feature module structure:
     ```
     src/features/social/
     ├── pages/
     │   └── SocialPage.tsx          # Main page: post list + filters
     ├── components/
     │   ├── PostCard.tsx             # Instagram-like preview card
     │   ├── PostEditor.tsx           # Create/edit form (content, platform, media)
     │   ├── PostPreview.tsx          # Full post preview (Instagram style)
     │   ├── MediaUploader.tsx        # Drag-and-drop media upload
     │   ├── SchedulePicker.tsx       # Date/time picker for scheduling
     │   ├── AiGenerateToggle.tsx     # AI generation prompt input (default hidden)
     │   ├── CopyButton.tsx           # Copy formatted content to clipboard
     │   └── PlatformBadge.tsx        # Instagram/Facebook/Both badge
     └── hooks/
         └── (feature-scoped hooks if needed)
     ```
  6. `src/App.tsx`: Add `/social` route (lazy loaded, RoleGuard wrapped)
  7. `src/components/layout/AppSidebar.tsx`: Add Social nav item with `requiredRole: "social"`
- **UI Design**:
  - Post list: Grid of Instagram-like cards (image + content preview + platform badge + status)
  - Create/Edit: Side panel or modal with rich text area, media upload zone, platform selector, schedule picker
  - AI toggle: Collapsed section, expandable, shows prompt input + generate button
  - Preview: Modal showing exactly how the post would look on Instagram (square image, caption below)
  - Copy: Button on each post that copies formatted content (text + hashtags) to clipboard
- **Acceptance criteria**:
  - [ ] Social page renders with post list (grid layout)
  - [ ] Create post with manual content editor works
  - [ ] Media upload (drag-and-drop) works
  - [ ] Instagram-like preview card renders correctly
  - [ ] Platform selector (Instagram/Facebook/Both) works
  - [ ] Schedule picker sets date/time correctly
  - [ ] AI generation toggle generates content and fills editor
  - [ ] Copy-to-clipboard copies formatted content
  - [ ] Filter posts by status (draft/scheduled/published) works
  - [ ] Edit and delete existing posts works
  - [ ] Page only accessible with "social" role (RoleGuard)
  - [ ] Unit tests for all components
  - [ ] Coverage ≥ 70%

---

### Step 9: Integration testing + Planner updates

- **Project**: All
- **Directory**: Multiple
- **Parallel with**: —  (final step)
- **Description**: End-to-end integration testing, update Planner registry and project mapping, ensure all pipelines green.
- **Context files to read**:
  - `registry.md` — update with HomeSocial
  - `projects/_template.md` — create HomeSocial mapping
- **Changes**:
  1. Create `projects/homesocial.md` — full project mapping
  2. Update `registry.md` — add HomeSocial entry + update dependency graph
  3. Update `server.md` — add HomeSocial port, domain, DB entries
  4. Update `guides/new-service-setup.md` — add HomeSocial to reference table
  5. E2E test: login → assign social role → verify nav appears → create post → schedule → verify Discord notification
  6. Verify all pipelines green across: HomeAuth, HomeUI, HomeSocial, Discord Bot
- **Acceptance criteria**:
  - [ ] Planner registry and project mapping updated
  - [ ] Server reference updated
  - [ ] Full flow works: role assignment → UI access → post creation → scheduling → notification
  - [ ] All pipelines green
  - [ ] Uptime Kuma monitor added for HomeSocial

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: HomeAuth — Add roles to JWT payload       → HomeAuth @ /Users/gregor/dev/922/HomeAuth
  Step 2: GitHub — Initialize HomeSocial repo        → GitHub + /Users/gregor/dev/922/HomeSocial

Wave 2 (after wave 1):
  Step 3: HomeUI — Role-based nav + route protection → HomeUI @ /Users/gregor/dev/922/HomeUI
  Step 4: HomeSocial — Project scaffolding + infra   → HomeSocial @ /Users/gregor/dev/922/HomeSocial

Wave 3 (after wave 2):
  Step 5: HomeSocial — Content management API        → HomeSocial @ /Users/gregor/dev/922/HomeSocial

Wave 4 (after wave 3, parallel):
  Step 6: HomeSocial — AI content generation         → HomeSocial @ /Users/gregor/dev/922/HomeSocial
  Step 7: HomeSocial + Discord — Scheduling + notif  → HomeSocial + Discord Bot
  Step 8: HomeUI — Social feature module UI          → HomeUI @ /Users/gregor/dev/922/HomeUI

Wave 5 (after wave 4):
  Step 9: Integration testing + Planner updates      → All projects
```

## Post-Execution Checklist
- [ ] All tests pass (HomeAuth ≥85%, HomeUI ≥70%, HomeSocial ≥70%)
- [ ] Documentation updated (CLAUDE.md, README, project mappings)
- [ ] All pipelines green (HomeAuth, HomeUI, HomeSocial, Discord Bot)
- [ ] Changes reviewed against best practices in each project mapping
- [ ] Uptime Kuma monitoring active for HomeSocial
- [ ] "social" role can be assigned via HomeAuth admin API
- [ ] Discord notifications working for scheduled posts
