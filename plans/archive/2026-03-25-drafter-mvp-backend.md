# Plan: Drafter MVP Backend Development

- **Date**: 2026-03-25
- **Project(s)**: Drafter, HomeStructure
- **Goal**: Implement the complete backend layer (database, API routes, data fetching, tests) for all Drafter MVP features, enabling the mockup to operate with real data.

## Context

Read these files before proceeding:
- `projects/drafter.md` — project mapping, tech stack, deployment config
- `/Users/gregor/dev/922/Drafter/CLAUDE.md` — project root conventions
- `/Users/gregor/dev/922/Drafter/.claude/best-practices.md` — coding conventions
- `/Users/gregor/dev/922/Drafter/docs/MVP-Scope.md` — full MVP scope
- `/Users/gregor/dev/922/Planner/server.md` — server infrastructure (DB hosts, ports)
- `/Users/gregor/dev/922/Drafter/.env.dev` / `.env.prod` — environment config

## Scope Decisions

| Item | Decision |
|------|----------|
| Social media API connections | Out of scope |
| Dashboard stat cards (top 4) | Stay as mock data |
| Dashboard recent posts + schedule strip | Stay as mock data (no backend needed) |
| Login / Auth | Last step — connect to HomeAuth |
| Media upload to MinIO | In scope — presigned URL flow |
| Copy-to-clipboard | In scope — platform-specific formatting |
| Calendar, Timeline | Display real data from same Post API |

---

## Steps

### Step 1: Database Setup on Server (dev + prod)

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure`
- **Parallel with**: —
- **Description**: Create the `drafter` and `dev_drafter` databases with dedicated user on the server. The `.env.dev` already references `dev_drafter` on `dev_postgres:5432` and `.env.prod` references `drafter` on `shared_postgres:5432`. Create both databases and users with the credentials from the env files.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/.env.dev` — dev DB credentials
  - `/Users/gregor/dev/922/Drafter/.env.prod` — prod DB credentials
  - `/Users/gregor/dev/922/Planner/server.md` — DB ports and hosts
  - `/Users/gregor/dev/922/HomeStructure/docs/` — database docs
- **Acceptance criteria**:
  - [ ] `dev_drafter` database exists on `dev_postgres` (port 5433)
  - [ ] `drafter` database exists on `shared_postgres` (port 5432)
  - [ ] User `drafter` can connect and has full privileges on both databases
  - [ ] Connection tested from server via `psql`

---

### Step 2: Prisma Schema & Initial Migration

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 1 (can draft schema while DB is being set up)
- **Description**: Create the Prisma schema with all models needed for MVP. Run initial migration against the dev database.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/.claude/best-practices.md` — conventions
  - `/Users/gregor/dev/922/Drafter/.env.dev` — DATABASE_URL
  - `/Users/gregor/dev/922/Drafter/entrypoint.sh` — confirms `prisma migrate deploy` on startup
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/new/page.tsx` — all platform-specific fields
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/page.tsx` — post list fields
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/media/page.tsx` — media file fields

**Prisma Schema Design:**

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Post {
  id            String     @id @default(cuid())
  orgId         String     @map("org_id")
  title         String
  caption       String     @default("")
  postType      PostType   @map("post_type")
  platform      Platform
  status        PostStatus @default(DRAFT)
  scheduledAt   DateTime?  @map("scheduled_at")
  publishedAt   DateTime?  @map("published_at")

  // Platform-specific fields stored as JSON
  // IG: hashtags, location, altText, firstComment, coverTimestamp, audio, shareToFeed
  // TikTok: hashtags, sound, allowDuet, allowStitch
  // LinkedIn: headline, tags, linkUrl, visibility
  // Facebook: linkUrl, tags, feeling, audience
  platformFields Json      @default("{}") @map("platform_fields")

  // Engagement metrics (populated after publish, or manually)
  likes         Int        @default(0)
  comments      Int        @default(0)
  views         Int        @default(0)

  createdAt     DateTime   @default(now()) @map("created_at")
  updatedAt     DateTime   @updatedAt @map("updated_at")
  createdBy     String     @map("created_by")

  media         Media[]

  @@map("posts")
  @@index([orgId, status])
  @@index([orgId, scheduledAt])
  @@index([orgId, createdAt])
}

model Media {
  id          String   @id @default(cuid())
  orgId       String   @map("org_id")
  postId      String?  @map("post_id")
  fileName    String   @map("file_name")
  fileSize    Int      @map("file_size")
  mimeType    String   @map("mime_type")
  width       Int?
  height      Int?
  s3Key       String   @map("s3_key")
  url         String   // presigned or public URL
  createdAt   DateTime @default(now()) @map("created_at")

  post        Post?    @relation(fields: [postId], references: [id], onDelete: SetNull)

  @@map("media")
  @@index([orgId])
  @@index([postId])
}

enum PostType {
  IG_PHOTO
  IG_REEL
  TIKTOK
  LINKEDIN
  FACEBOOK
}

enum Platform {
  INSTAGRAM
  TIKTOK
  LINKEDIN
  FACEBOOK
}

enum PostStatus {
  DRAFT
  SCHEDULED
  PUBLISHED
}
```

- **Acceptance criteria**:
  - [ ] `prisma/schema.prisma` created with Post, Media models, all enums
  - [ ] Initial migration generated and applied to dev DB
  - [ ] `npx prisma generate` produces typed client without errors
  - [ ] `pnpm type-check` passes

**Tests:**
  - [ ] `src/lib/db.test.ts` — Test Prisma client instantiation (singleton pattern)
  - [ ] `src/lib/validators.test.ts` — Test all Zod schemas parse valid/invalid input correctly

---

### Step 3: Shared Types, Validators & DB Client

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: — (depends on Step 2)
- **Description**: Create the shared TypeScript types derived from Prisma, Zod validation schemas for all API inputs, and the Prisma client singleton.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/types/index.ts` — existing types file
  - `/Users/gregor/dev/922/Drafter/.claude/best-practices.md` — strict TS, shared types in `src/types/`

**Files to create:**

1. **`src/lib/db.ts`** — Prisma client singleton (standard Next.js pattern: globalThis cache in dev, single instance in prod)

2. **`src/types/index.ts`** — Shared types:
   - Re-export Prisma-generated types: `Post`, `Media`, `PostType`, `Platform`, `PostStatus`
   - API response wrappers: `ApiResponse<T>`, `PaginatedResponse<T>`, `ApiError`
   - Create/update DTOs: `CreatePostInput`, `UpdatePostInput`
   - Platform-specific field types: `IGPhotoFields`, `IGReelFields`, `TikTokFields`, `LinkedInFields`, `FacebookFields`, union `PlatformFields`
   - Query params: `PostListParams` (status filter, platform filter, search, page, limit, sort)
   - Copy format types: `CopyFormat` (plain, instagram, tiktok, linkedin, facebook)

3. **`src/lib/validators.ts`** — Zod schemas:
   - `createPostSchema` — validates title (required, 1-200 chars), caption (max per platform), postType, platform, scheduledAt (optional, must be future), platformFields (validated per postType)
   - `updatePostSchema` — partial version of create
   - `postListParamsSchema` — validates query params (status enum, platform enum, search string, page >= 1, limit 1-100)
   - `mediaUploadSchema` — validates fileName, fileSize (max 50MB), mimeType (allowed list)

4. **`src/lib/auth-helpers.ts`** — Helper to extract `orgId` and `userId` from request headers (set by middleware):
   ```ts
   export function getAuthContext(headers: Headers): { orgId: string; userId: string }
   ```

- **Acceptance criteria**:
  - [ ] All types compile without errors
  - [ ] Zod schemas validate correct input and reject invalid input
  - [ ] `pnpm type-check` passes
  - [ ] Auth helper extracts headers correctly

**Tests:**
  - [ ] `src/lib/validators.test.ts` — Comprehensive tests for every Zod schema:
    - Valid post creation input (all 5 post types)
    - Reject missing required fields
    - Reject caption exceeding platform max length
    - Reject past scheduledAt dates
    - Reject invalid platformFields for each post type
    - Valid/invalid list params
    - Valid/invalid media upload params
  - [ ] `src/lib/auth-helpers.test.ts` — Test header extraction, missing headers throw

---

### Step 4: Post CRUD API Routes

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: — (depends on Step 3)
- **Description**: Implement all Post API routes. Every route scopes by `org_id` from middleware headers. Use Zod validation on all inputs. Return typed responses.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/.claude/best-practices.md` — API route conventions
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/page.tsx` — what fields the list needs
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/new/page.tsx` — what fields the create form sends
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/dashboard/page.tsx` — recent posts shape

**API Routes:**

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/posts` | GET | List posts (filtered, paginated, sorted) |
| `/api/posts` | POST | Create new post |
| `/api/posts/[id]` | GET | Get single post with media |
| `/api/posts/[id]` | PATCH | Update post |
| `/api/posts/[id]` | DELETE | Delete post |
| `/api/posts/bulk-delete` | POST | Bulk delete by IDs |
| `/api/posts/[id]/duplicate` | POST | Duplicate a post (as new draft) |
| `/api/posts/[id]/copy` | GET | Get copy-to-clipboard formatted content |

**Implementation details:**

`GET /api/posts`:
  - Query params: `status`, `platform`, `search`, `page` (default 1), `limit` (default 20), `sort` (field), `order` (asc/desc)
  - Returns: `PaginatedResponse<Post>` with `{ data, total, page, limit, totalPages }`
  - Search: case-insensitive title + caption LIKE search
  - Always scoped by `org_id`
  - Include media count per post (use `_count`)
  - Single request fetches all visible posts — supports the "fetch all in one request" pattern for the posts list page

`POST /api/posts`:
  - Body: validated by `createPostSchema`
  - If `status === SCHEDULED` and `scheduledAt` is provided, set status to SCHEDULED
  - Returns: created post with 201 status

`GET /api/posts/[id]`:
  - Returns: full post with all media relations
  - 404 if not found or wrong org

`PATCH /api/posts/[id]`:
  - Body: validated by `updatePostSchema` (partial)
  - Handles status transitions: DRAFT → SCHEDULED (requires scheduledAt), SCHEDULED → DRAFT, etc.
  - Returns: updated post

`DELETE /api/posts/[id]`:
  - Soft-deletes or hard-deletes (hard delete for MVP)
  - Also delete associated media from S3 (best effort)
  - Returns: 204

`POST /api/posts/bulk-delete`:
  - Body: `{ ids: string[] }`
  - Validates all IDs belong to org before deleting
  - Returns: `{ deleted: number }`

`POST /api/posts/[id]/duplicate`:
  - Creates a copy with status DRAFT, appended " (Copy)" to title
  - Copies all fields except id, dates, engagement metrics
  - Returns: new post with 201

`GET /api/posts/[id]/copy`:
  - Query param: `format` (plain | instagram | tiktok | linkedin | facebook)
  - Returns: `{ text: string, format: string }` with platform-formatted content
  - Instagram: caption + hashtags separated by line breaks
  - TikTok: description + hashtags
  - LinkedIn: headline + content
  - Facebook: post text
  - Plain: title + caption

- **Acceptance criteria**:
  - [ ] All 8 endpoints created and return correct status codes
  - [ ] All inputs validated with Zod, 400 on invalid
  - [ ] All queries scoped by `org_id`
  - [ ] Pagination works correctly
  - [ ] Search works case-insensitive across title and caption
  - [ ] Copy endpoint formats correctly per platform
  - [ ] `pnpm type-check` passes

**Tests (per route, using Vitest + mocked Prisma):**
  - [ ] `src/app/api/posts/route.test.ts`:
    - GET: returns paginated list, filters by status, filters by platform, searches title, empty result returns empty array
    - POST: creates post with valid input, rejects invalid input (missing title, bad enum), rejects past scheduledAt, returns 201
  - [ ] `src/app/api/posts/[id]/route.test.ts`:
    - GET: returns post with media, returns 404 for non-existent, returns 404 for wrong org
    - PATCH: updates fields, handles status transitions, rejects invalid updates
    - DELETE: deletes post, returns 404 for non-existent
  - [ ] `src/app/api/posts/bulk-delete/route.test.ts`:
    - Deletes multiple posts, rejects empty array, only deletes own org's posts
  - [ ] `src/app/api/posts/[id]/duplicate/route.test.ts`:
    - Creates copy with DRAFT status, appended title, returns 201
  - [ ] `src/app/api/posts/[id]/copy/route.test.ts`:
    - Returns correct format per platform, defaults to plain

---

### Step 5: Media Upload API & MinIO Integration

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 4 (independent API)
- **Description**: Implement media upload/management via presigned URLs to MinIO (S3-compatible). Frontend will request a presigned upload URL, upload directly to MinIO, then confirm the upload to our API.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/.env.dev` — S3 config
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/media/page.tsx` — media fields needed
  - `/Users/gregor/dev/922/Planner/server.md` — MinIO service info

**Files to create:**

1. **`src/lib/s3.ts`** — S3 client wrapper using `@aws-sdk/client-s3` and `@aws-sdk/s3-request-presigner`:
   - `getPresignedUploadUrl(key, contentType, expiresIn)` — returns presigned PUT URL
   - `getPresignedDownloadUrl(key, expiresIn)` — returns presigned GET URL
   - `deleteObject(key)` — deletes object from bucket
   - `deleteObjects(keys)` — bulk delete
   - All keys prefixed with `org_id/` for tenant isolation

2. **Dependencies to install**: `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`

**API Routes:**

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/media/upload-url` | POST | Get presigned upload URL |
| `/api/media` | GET | List media for org |
| `/api/media` | POST | Confirm upload (create DB record) |
| `/api/media/[id]` | DELETE | Delete media file |
| `/api/media/bulk-delete` | POST | Bulk delete media |

`POST /api/media/upload-url`:
  - Body: `{ fileName, fileSize, mimeType }`
  - Validates file type (images: jpg/png/gif/webp, video: mp4/mov/webm)
  - Validates file size (max 50MB images, max 500MB video)
  - Generates S3 key: `{org_id}/{year}/{month}/{cuid}_{fileName}`
  - Returns: `{ uploadUrl, s3Key, expiresAt }`

`GET /api/media`:
  - Returns all media for org, ordered by created_at desc
  - Optional query: `postId` to filter by post

`POST /api/media`:
  - Body: `{ s3Key, fileName, fileSize, mimeType, width?, height?, postId? }`
  - Creates DB record after successful upload
  - Generates download URL
  - Returns: created media with 201

`DELETE /api/media/[id]`:
  - Deletes from DB and S3
  - Returns: 204

`POST /api/media/bulk-delete`:
  - Body: `{ ids: string[] }`
  - Deletes from DB and S3
  - Returns: `{ deleted: number }`

- **Acceptance criteria**:
  - [ ] Presigned upload URL generation works
  - [ ] File type and size validation enforced
  - [ ] S3 keys are org-scoped
  - [ ] Media records created/deleted correctly
  - [ ] `pnpm type-check` passes

**Tests:**
  - [ ] `src/lib/s3.test.ts` — Test S3 client functions with mocked AWS SDK:
    - Presigned URL generation
    - Key prefix includes org_id
    - Delete operations
  - [ ] `src/app/api/media/upload-url/route.test.ts`:
    - Returns presigned URL for valid request
    - Rejects invalid mimeType, oversized files
  - [ ] `src/app/api/media/route.test.ts`:
    - GET: returns org-scoped media list
    - POST: creates media record
  - [ ] `src/app/api/media/[id]/route.test.ts`:
    - DELETE: removes from DB, returns 404 for wrong org
  - [ ] `src/app/api/media/bulk-delete/route.test.ts`:
    - Deletes multiple, only own org

---

### Step 6: Seed Script & Dev Data

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: — (depends on Steps 4 + 5)
- **Description**: Create a Prisma seed script that populates the dev database with realistic sample data matching the mockup content.
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/dashboard/page.tsx` — sample post data
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/calendar/page.tsx` — calendar entries
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/timeline/page.tsx` — timeline entries

**Files to create:**

1. **`prisma/seed.ts`** — Seed script:
   - Creates ~10-15 posts across all platforms and statuses
   - Includes posts matching the mockup data (Spring Collection Launch, Behind the Scenes Video, etc.)
   - Creates associated media records
   - Uses a fixed `org_id` ("dev-org") and `created_by` ("dev-user") for dev environment
   - Idempotent: clears existing data before seeding

2. **Update `package.json`**: Add `prisma.seed` config pointing to seed script

- **Acceptance criteria**:
  - [ ] `pnpm prisma db seed` populates database with realistic data
  - [ ] All post statuses represented (DRAFT, SCHEDULED, PUBLISHED)
  - [ ] All platforms represented (INSTAGRAM, TIKTOK, LINKEDIN, FACEBOOK)
  - [ ] Media records associated with posts
  - [ ] Seed is idempotent (can run multiple times safely)

**Tests:**
  - [ ] No direct test needed — seed script verified by running it

---

### Step 7: Frontend Data Integration — Posts List Page

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: — (depends on Steps 4 + 6)
- **Description**: Connect the Posts List page (`/posts`) to the real API. Replace hardcoded mock data with data fetched from `GET /api/posts`. Implement real filtering, search, pagination, and bulk operations. Use SWR or React Query for client-side data fetching with hot-reloading pattern.
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/page.tsx` — current mockup code
  - `/Users/gregor/dev/922/Drafter/.claude/best-practices.md` — component patterns

**Implementation:**

1. **Install `swr`** for client-side data fetching (lightweight, fits Next.js well)

2. **`src/lib/api-client.ts`** — Typed fetch wrapper:
   - `apiGet<T>(url, params?)` — GET with query params, returns typed response
   - `apiPost<T>(url, body)` — POST with JSON body
   - `apiPatch<T>(url, body)` — PATCH
   - `apiDelete(url)` — DELETE
   - All methods handle errors, return typed responses
   - Automatic revalidation-compatible

3. **`src/hooks/use-posts.ts`** — SWR hook for post list:
   - `usePosts(params: PostListParams)` — returns `{ posts, total, isLoading, error, mutate }`
   - Auto-refetches on param change (tab switch, search, sort)
   - Optimistic updates for delete operations

4. **Update `/posts/page.tsx`**:
   - Replace `useState` mock data with `usePosts()` hook
   - Wire up tab filters → status param
   - Wire up search input → debounced search param
   - Wire up sort → sort params
   - Wire up bulk delete → `apiPost('/api/posts/bulk-delete', { ids })`
   - Wire up per-row delete → `apiDelete('/api/posts/{id}')`
   - Wire up duplicate → `apiPost('/api/posts/{id}/duplicate')`
   - Add loading skeleton states
   - Add error states

- **Acceptance criteria**:
  - [ ] Posts list loads real data from API
  - [ ] Tab filtering works (All, Drafts, Scheduled, Published)
  - [ ] Search filters in real-time (debounced 300ms)
  - [ ] Sort works A-Z / Z-A
  - [ ] Bulk delete works and list refreshes
  - [ ] Single delete works with list refresh
  - [ ] Duplicate creates a copy and shows it in the list
  - [ ] Loading state shows skeletons
  - [ ] Empty state displays correctly

**Tests:**
  - [ ] `src/hooks/use-posts.test.ts` — Test SWR hook with mocked fetch:
    - Returns posts data
    - Passes filter params to API
    - Handles loading state
    - Handles error state
  - [ ] `src/lib/api-client.test.ts` — Test fetch wrapper:
    - Serializes query params correctly
    - Handles 4xx/5xx errors
    - Returns typed data

---

### Step 8: Frontend Data Integration — New Post & Edit Post Pages

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 7 (different pages)
- **Description**: Connect the New Post page to the real API. Implement the full post creation flow including media upload. Build the Edit Post page reusing the same form component.
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/new/page.tsx` — form structure, all platform fields
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/[id]/edit/page.tsx` — edit page stub

**Implementation:**

1. **`src/components/post-form.tsx`** — Shared post form component (used by both new and edit):
   - Post type selector (IG Photo, IG Reel, TikTok, LinkedIn, Facebook)
   - Title input
   - Caption textarea with character counter (limit per platform)
   - Dynamic platform-specific fields (from mockup config)
   - Media upload zone with drag & drop
   - Live preview panel (reuse mockup preview components)
   - Save Draft / Schedule buttons
   - Props: `mode: 'create' | 'edit'`, `initialData?: Post`

2. **`src/hooks/use-media-upload.ts`** — Upload hook:
   - `useMediaUpload()` — returns `{ upload, uploading, progress, error }`
   - `upload(file)`: request presigned URL → upload to S3 → confirm via API → return media record
   - Support multiple file uploads
   - Track progress per file

3. **`src/components/media-upload-zone.tsx`** — Drag & drop upload component:
   - Uses `useMediaUpload` hook
   - Shows upload progress bars
   - Thumbnail preview after upload
   - Delete uploaded media
   - File type validation (client-side check before upload)

4. **Update `/posts/new/page.tsx`**:
   - Use `PostForm` component in create mode
   - On Save Draft: `apiPost('/api/posts', { ...data, status: 'DRAFT' })`
   - On Schedule: `apiPost('/api/posts', { ...data, status: 'SCHEDULED' })`
   - Redirect to `/posts` on success with toast

5. **Build `/posts/[id]/edit/page.tsx`**:
   - Fetch post data via `GET /api/posts/{id}`
   - Use `PostForm` component in edit mode with `initialData`
   - On Save: `apiPatch('/api/posts/{id}', { ...changes })`
   - On Delete: `apiDelete('/api/posts/{id}')` → redirect to `/posts`

- **Acceptance criteria**:
  - [ ] New post form creates a post in the database
  - [ ] All 5 post types work with their specific fields
  - [ ] Caption character counter shows correct limit per platform
  - [ ] Media upload works (drag & drop → presigned URL → S3 → confirm)
  - [ ] Edit page loads existing post data
  - [ ] Edit page saves changes
  - [ ] Save Draft sets status to DRAFT
  - [ ] Schedule sets status to SCHEDULED with date
  - [ ] Form validation shows errors (client-side Zod)
  - [ ] Redirect after save/delete

**Tests:**
  - [ ] `src/components/post-form.test.tsx` — Component tests with Vitest + React Testing Library:
    - Renders correct fields per post type
    - Shows character counter with correct limit
    - Validates required fields
    - Calls onSubmit with correct data
  - [ ] `src/hooks/use-media-upload.test.ts`:
    - Requests presigned URL
    - Handles upload failure
    - Tracks progress
  - [ ] `src/components/media-upload-zone.test.tsx`:
    - Renders drop zone
    - Shows uploaded files
    - Triggers delete

---

### Step 9: Frontend Data Integration — Post Detail Page

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Step 8
- **Description**: Build the Post Detail page showing full post content, media gallery, metadata, and copy-to-clipboard feature.
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/[id]/page.tsx` — current stub
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/posts/new/page.tsx` — preview components to reuse

**Implementation:**

1. **Build `/posts/[id]/page.tsx`** (full detail page):
   - Fetch post with media via `GET /api/posts/{id}`
   - Header: title, status badge, platform badge, created date, edit button
   - Content section: caption text, platform-specific fields displayed
   - Media gallery: thumbnails grid, lightbox preview on click
   - Engagement metrics (if published): likes, comments, views
   - Scheduling info (if scheduled): scheduled date/time
   - Copy-to-clipboard section:
     - Buttons per format: "Copy for Instagram", "Copy for TikTok", etc.
     - One-click copy using `GET /api/posts/{id}/copy?format=...`
     - Toast feedback on copy success
   - Action buttons: Edit, Duplicate, Delete (with confirmation modal)
   - Follow the design patterns from the mockup (dark theme, card layout, border-border/50)

2. **`src/components/copy-button.tsx`** — Reusable copy-to-clipboard component:
   - Fetches formatted content from API
   - Uses `navigator.clipboard.writeText()`
   - Shows success/error state with icon transition

- **Acceptance criteria**:
  - [ ] Full post details displayed
  - [ ] Media gallery shows all attached images/videos
  - [ ] Copy-to-clipboard works for all platforms
  - [ ] Edit button navigates to edit page
  - [ ] Duplicate creates a copy
  - [ ] Delete with confirmation removes the post
  - [ ] 404 page for non-existent posts
  - [ ] Follows existing mockup design patterns

**Tests:**
  - [ ] `src/components/copy-button.test.tsx`:
    - Copies text to clipboard
    - Shows success state
    - Handles clipboard API failure

---

### Step 10: Frontend Data Integration — Calendar & Timeline Pages

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 8 + 9
- **Description**: Connect Calendar and Timeline pages to real data. Both pages consume the same `GET /api/posts` endpoint with different query params.
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/calendar/page.tsx` — calendar mockup
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/timeline/page.tsx` — timeline mockup

**Implementation:**

1. **`src/hooks/use-calendar-posts.ts`** — Hook for calendar:
   - `useCalendarPosts(year, month)` — fetches posts for the month range
   - Uses `GET /api/posts?scheduledAfter={startOfMonth}&scheduledBefore={endOfMonth}&limit=200`
   - Also fetches published posts in the date range
   - Returns posts grouped by day

2. **Update `/calendar/page.tsx`**:
   - Replace `MARCH_POSTS` mock data with `useCalendarPosts` hook
   - Dynamic month navigation fetches new data
   - Day detail panel shows real posts
   - "Add post" button in day panel → navigates to `/posts/new?scheduleDate={date}`
   - Loading states on month change

3. **`src/hooks/use-timeline-posts.ts`** — Hook for timeline:
   - `useTimelinePosts(filter)` — fetches posts grouped by status
   - Uses `GET /api/posts?sort=scheduledAt&order=desc&limit=50`
   - Groups into Today / Upcoming / Published sections

4. **Update `/timeline/page.tsx`**:
   - Replace `ALL_ENTRIES` mock data with `useTimelinePosts` hook
   - Wire up filter tabs (All, Drafts, Scheduled, Published)
   - Expanded card actions: Edit → navigate, Schedule → navigate, View Analytics → placeholder
   - Context menu actions: Edit, Duplicate, Delete (real API calls)
   - Loading states

- **Acceptance criteria**:
  - [ ] Calendar shows real posts on correct dates
  - [ ] Month navigation loads new data
  - [ ] Day detail panel shows posts for selected day
  - [ ] "Add post" pre-fills schedule date
  - [ ] Timeline groups posts correctly (Today / Upcoming / Published)
  - [ ] Filter tabs work
  - [ ] Context menu actions (Edit, Duplicate, Delete) work

**Tests:**
  - [ ] `src/hooks/use-calendar-posts.test.ts`:
    - Fetches correct date range
    - Groups posts by day
  - [ ] `src/hooks/use-timeline-posts.test.ts`:
    - Groups into correct sections
    - Filters work

---

### Step 11: Frontend Data Integration — Media Library Page

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: Steps 8-10
- **Description**: Connect the Media Library page to real data. Implement upload, display, selection, and deletion of media files.
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner-Mockup/src/app/(app)/media/page.tsx` — media page mockup

**Implementation:**

1. **`src/hooks/use-media.ts`** — SWR hook for media list:
   - `useMedia()` — returns `{ files, isLoading, error, mutate }`
   - Fetches from `GET /api/media`

2. **Update `/media/page.tsx`**:
   - Replace `INITIAL_FILES` with `useMedia()` hook
   - Wire up Upload button → file picker → `useMediaUpload()` hook
   - Wire up bulk delete → `apiPost('/api/media/bulk-delete', { ids })`
   - Wire up single delete (from list view)
   - Lightbox preview uses real presigned URLs
   - Grid and list views show real file data
   - Copy button copies the S3 URL to clipboard
   - Loading skeletons

- **Acceptance criteria**:
  - [ ] Media library shows real uploaded files
  - [ ] Upload works (via presigned URL flow)
  - [ ] Grid and list views display correctly
  - [ ] Lightbox preview works
  - [ ] Bulk delete works
  - [ ] Copy URL works

**Tests:**
  - [ ] `src/hooks/use-media.test.ts`:
    - Returns media list
    - Handles empty list

---

### Step 12: Application Optimization & Error Handling

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: — (depends on Steps 7-11)
- **Description**: Add application-wide error handling, loading states, toast notifications, and performance optimizations.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/app/(app)/layout.tsx` — app layout

**Implementation:**

1. **Install `sonner`** for toast notifications (lightweight, styled)

2. **`src/components/toast-provider.tsx`** — Toast setup in app layout

3. **`src/app/(app)/error.tsx`** — Error boundary for app routes:
   - Catches unhandled errors
   - Shows user-friendly error message with retry button

4. **`src/app/(app)/loading.tsx`** — Global loading state

5. **`src/lib/api-client.ts` updates**:
   - Add retry logic (1 retry on network failure)
   - Add request deduplication (SWR handles this)
   - Add error toast integration

6. **Performance optimizations**:
   - `next.config.ts`: Configure image optimization for S3 URLs (add MinIO host to `images.remotePatterns`)
   - SWR global config: `revalidateOnFocus: true`, `dedupingInterval: 5000`
   - Add `loading.tsx` skeletons for each route group

7. **`src/middleware.ts`** — Uncomment and finalize auth middleware:
   - Verify JWT from Authorization header or cookie
   - Set `x-org-id` and `x-user-id` headers
   - Redirect to `/login` if unauthenticated
   - But keep middleware disabled (return NextResponse.next()) until Step 13

- **Acceptance criteria**:
  - [ ] Toast notifications show on create, update, delete, copy, upload
  - [ ] Error boundary catches crashes gracefully
  - [ ] Loading skeletons appear during data fetches
  - [ ] Images from S3 load through Next.js image optimization
  - [ ] SWR revalidates on focus

**Tests:**
  - [ ] `src/components/toast-provider.test.tsx` — Toast renders
  - [ ] `src/app/(app)/error.test.tsx` — Error boundary renders fallback

---

### Step 13: Authentication — HomeAuth Integration (LAST STEP)

- **Project**: Drafter, HomeAuth
- **Directory**: `/Users/gregor/dev/922/Drafter`, `/Users/gregor/dev/922/HomeAuth`
- **Parallel with**: — (depends on all previous steps)
- **Description**: Connect to the production HomeAuth service. Create a new "app login" flow for Drafter. Enable the auth middleware.
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/middleware.ts` — prepared auth middleware
  - `/Users/gregor/dev/922/Drafter/src/lib/auth.ts` — JWT verification
  - `/Users/gregor/dev/922/Drafter/.env.prod` — JWT_SHARED_SECRET
  - `/Users/gregor/dev/922/HomeAuth/` — HomeAuth project (read how app auth works)
  - `/Users/gregor/dev/922/Drafter/docker-compose.yaml` — Traefik forward-auth config

**Implementation:**

1. **HomeAuth configuration** (research needed):
   - Check how HomeAuth handles app-specific logins
   - Either add Drafter as a registered app in HomeAuth, or use the existing JWT flow
   - The JWT must include `sub` (user ID) and `org_id` (organization ID)

2. **Update `/login/page.tsx`**:
   - Implement real login form submission
   - POST to HomeAuth login endpoint (or redirect-based SSO flow)
   - Store JWT in httpOnly cookie (`auth-token`)
   - Redirect to `/dashboard` on success
   - Show error messages on failure

3. **Enable `src/middleware.ts`**:
   - Uncomment the full auth logic
   - JWT verification via `jose.jwtVerify()`
   - Extract and forward `x-org-id`, `x-user-id` to all routes
   - Redirect to `/login` on invalid/missing token

4. **Add logout**:
   - Add logout button to sidebar (bottom)
   - Clear the `auth-token` cookie
   - Redirect to `/login`

5. **Update `.env.prod` and `.env.dev`**:
   - Set real `JWT_SHARED_SECRET` (must match HomeAuth's secret)

- **Acceptance criteria**:
  - [ ] Login form authenticates against HomeAuth
  - [ ] JWT stored in httpOnly cookie
  - [ ] Middleware protects all `/api/*` and `/(app)/*` routes
  - [ ] Unauthenticated users redirected to `/login`
  - [ ] `x-org-id` and `x-user-id` available in all API routes
  - [ ] Logout clears session and redirects
  - [ ] App works end-to-end with real auth

**Tests:**
  - [ ] `src/middleware.test.ts`:
    - Allows public paths without token
    - Redirects to login without token
    - Sets org/user headers with valid token
    - Redirects with expired token
  - [ ] `src/lib/auth.test.ts`:
    - Verifies valid JWT
    - Rejects invalid JWT
    - Rejects expired JWT

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Database setup on server → HomeStructure @ ssh lab
  Step 2: Prisma schema design → Drafter @ /Users/gregor/dev/922/Drafter

Wave 2 (after Wave 1):
  Step 3: Types, validators, DB client → Drafter @ /Users/gregor/dev/922/Drafter

Wave 3 (after Wave 2, parallel):
  Step 4: Post CRUD API routes → Drafter @ /Users/gregor/dev/922/Drafter
  Step 5: Media upload API + MinIO → Drafter @ /Users/gregor/dev/922/Drafter

Wave 4 (after Wave 3):
  Step 6: Seed script → Drafter @ /Users/gregor/dev/922/Drafter

Wave 5 (after Wave 4, parallel):
  Step 7:  Posts List page integration → Drafter @ /Users/gregor/dev/922/Drafter
  Step 8:  New Post + Edit Post integration → Drafter @ /Users/gregor/dev/922/Drafter
  Step 9:  Post Detail page → Drafter @ /Users/gregor/dev/922/Drafter
  Step 10: Calendar + Timeline integration → Drafter @ /Users/gregor/dev/922/Drafter
  Step 11: Media Library integration → Drafter @ /Users/gregor/dev/922/Drafter

Wave 6 (after Wave 5):
  Step 12: Optimization + error handling → Drafter @ /Users/gregor/dev/922/Drafter

Wave 7 (LAST — after Wave 6):
  Step 13: HomeAuth login integration → Drafter + HomeAuth
```

## Test Summary

| Area | Test File | Tests |
|------|-----------|-------|
| DB Client | `src/lib/db.test.ts` | Singleton pattern |
| Validators | `src/lib/validators.test.ts` | All Zod schemas (5 post types, list params, media) |
| Auth Helpers | `src/lib/auth-helpers.test.ts` | Header extraction |
| S3 Client | `src/lib/s3.test.ts` | Presigned URLs, delete ops |
| Post List API | `src/app/api/posts/route.test.ts` | GET (pagination, filters, search), POST (create, validation) |
| Post Detail API | `src/app/api/posts/[id]/route.test.ts` | GET, PATCH, DELETE |
| Post Bulk Delete | `src/app/api/posts/bulk-delete/route.test.ts` | Bulk delete |
| Post Duplicate | `src/app/api/posts/[id]/duplicate/route.test.ts` | Duplicate |
| Post Copy | `src/app/api/posts/[id]/copy/route.test.ts` | Format per platform |
| Media Upload URL | `src/app/api/media/upload-url/route.test.ts` | Presigned URL, validation |
| Media CRUD | `src/app/api/media/route.test.ts` | GET, POST |
| Media Delete | `src/app/api/media/[id]/route.test.ts` | DELETE |
| Media Bulk Delete | `src/app/api/media/bulk-delete/route.test.ts` | Bulk delete |
| API Client | `src/lib/api-client.test.ts` | Fetch wrapper |
| usePosts Hook | `src/hooks/use-posts.test.ts` | SWR hook |
| useMedia Hook | `src/hooks/use-media.test.ts` | SWR hook |
| useCalendarPosts | `src/hooks/use-calendar-posts.test.ts` | Date range, grouping |
| useTimelinePosts | `src/hooks/use-timeline-posts.test.ts` | Grouping, filters |
| useMediaUpload | `src/hooks/use-media-upload.test.ts` | Upload flow |
| PostForm | `src/components/post-form.test.tsx` | Dynamic fields, validation |
| MediaUploadZone | `src/components/media-upload-zone.test.tsx` | Drop zone, preview |
| CopyButton | `src/components/copy-button.test.tsx` | Clipboard API |
| Auth Middleware | `src/middleware.test.ts` | Public paths, token verify, redirects |
| Auth Lib | `src/lib/auth.test.ts` | JWT verify/reject |

**Target: 70%+ code coverage** (project standard from `projects/drafter.md`)

## Dependencies to Install

```bash
pnpm add prisma @prisma/client zod @aws-sdk/client-s3 @aws-sdk/s3-request-presigner swr sonner
pnpm add -D @testing-library/react @testing-library/jest-dom jsdom tsx
```

## Post-Execution Checklist

- [ ] All tests pass (`pnpm test`)
- [ ] Type checking passes (`pnpm type-check`)
- [ ] Lint passes (`pnpm lint`)
- [ ] Build succeeds (`pnpm build`)
- [ ] Seed script works (`pnpm prisma db seed`)
- [ ] Dev environment works end-to-end
- [ ] Documentation updated (`docs/MVP-Scope.md` checklist items marked)
- [ ] Pipeline green after push
- [ ] Coverage >= 70%
