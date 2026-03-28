# Plan: Drafter Bugfixes, UI Adjustments & Automated Testing

- **Date**: 2026-03-27
- **Project(s)**: Drafter
- **Goal**: Fix all reported bugs (images, scheduling, draft saving), add version display, disable mock panels and social media linking, implement brand avatar upload, and add comprehensive automated testing.

## Context

Read these files before proceeding:
- `/Users/gregor/dev/922/Drafter/CLAUDE.md`
- `/Users/gregor/dev/922/Drafter/.claude/best-practices.md`
- `/Users/gregor/dev/922/Planner/server.md`

## Issue Summary

| # | Issue | Root Cause |
|---|-------|-----------|
| 1 | Images not displaying | S3 env var name mismatch (`S3_ACCESS_KEY` vs `S3_ACCESS_KEY_ID`), missing `S3_CDN_URL`, `getPublicUrl()` generates broken URLs, `next.config.ts` only allows `localhost:9000` |
| 2 | Schedule post not working | `datetime-local` input format not always valid ISO 8601 for Zod `.datetime()`, no clear error shown to user |
| 3 | Save draft not working | Edit mode immediately redirects to `/posts` after save — user doesn't see confirmation |
| 4 | Brand avatar not uploadable | Avatar is a styled `<div>` with no file input, no onClick, no upload logic |
| 5 | Version display missing | `version.txt` (0.2.7) exists but sidebar doesn't show it |
| 6 | Social media linking shown | Branding page shows connect/disconnect UI that does nothing |
| 7 | Dashboard mock panels | Stats, recent posts, and schedule strip all use hardcoded data |
| 8 | No automated E2E testing | Only unit tests exist (71 tests), no integration or E2E tests |

---

## Steps

### Step 1: Fix S3/Image System

- **Priority**: Critical
- **Parallel with**: —
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/lib/s3.ts`
  - `/Users/gregor/dev/922/Drafter/.env.dev`
  - `/Users/gregor/dev/922/Drafter/.env.prod`
  - `/Users/gregor/dev/922/Drafter/next.config.ts`
  - `/Users/gregor/dev/922/Drafter/src/app/api/media/route.ts` — POST handler uses `getPublicUrl()`
  - `/Users/gregor/dev/922/Drafter/src/app/api/media/upload-url/route.ts`
  - `/Users/gregor/dev/922/Drafter/src/app/(app)/media/page.tsx`
  - `/Users/gregor/dev/922/Drafter/src/components/media-upload-zone.tsx`
  - `/Users/gregor/dev/922/Drafter/src/app/(app)/posts/[id]/page.tsx`
  - `/Users/gregor/dev/922/Planner/server.md` — MinIO service config

**Root causes to fix:**

1. **`src/lib/s3.ts`** — Env var name mismatch:
   - Code uses `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`, but `.env` files define `S3_ACCESS_KEY` and `S3_SECRET_KEY`
   - Fix: Align the code to match the env files, OR align the env files to match the code. **Recommended**: Update `s3.ts` to read `S3_ACCESS_KEY` and `S3_SECRET_KEY` (matching what's in the env files)
   - Also fix `getPublicUrl()`: The CDN_URL fallback generates an AWS URL (`https://bucket.s3.region.amazonaws.com`) but we use MinIO. Fix to use `S3_ENDPOINT/BUCKET/key` pattern for MinIO, or introduce a `S3_PUBLIC_URL` env var

2. **`src/lib/s3.ts`** — Fix `getPublicUrl()` to work with MinIO:
   ```ts
   export function getPublicUrl(key: string): string {
     const publicUrl = process.env.S3_PUBLIC_URL || process.env.S3_ENDPOINT;
     if (publicUrl) {
       return `${publicUrl}/${BUCKET}/${key}`;
     }
     return `https://${BUCKET}.s3.${REGION}.amazonaws.com/${key}`;
   }
   ```

3. **`.env.dev`** — Add `S3_PUBLIC_URL` pointing to the MinIO endpoint accessible from the browser (check server.md for the MinIO URL)

4. **`.env.prod`** — Same: add `S3_PUBLIC_URL` with the production-accessible MinIO/S3 endpoint

5. **`next.config.ts`** — Expand `images.remotePatterns` to include the actual S3/MinIO domain used in production. For flexibility, also allow the dev MinIO endpoint:
   ```ts
   images: {
     remotePatterns: [
       { protocol: "http", hostname: "localhost", port: "9000" },
       { protocol: "https", hostname: "*.922-studio.com" },
     ],
   },
   ```

6. **MinIO bucket policy** — Verify the `drafter-media` bucket exists and has a public read policy (so presigned URLs aren't needed for viewing). Check on the server:
   ```bash
   ssh lab
   docker exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
   docker exec minio mc ls local/drafter-media
   ```
   If bucket doesn't exist, create it and set public read policy.

- **Acceptance criteria**:
  - [ ] S3 credentials work (presigned upload URL succeeds)
  - [ ] Uploaded images are viewable via their URL
  - [ ] Media page shows real image thumbnails
  - [ ] Post detail page shows attached media
  - [ ] Media upload zone shows thumbnail previews after upload
  - [ ] `pnpm type-check` passes

**Tests to add/update:**
  - [ ] `src/lib/s3.test.ts` — Update tests: `getPublicUrl()` returns correct URL with `S3_PUBLIC_URL` env var, returns correct MinIO-style URL with `S3_ENDPOINT` fallback, returns AWS-style URL when neither is set
  - [ ] `src/app/api/media/route.test.ts` — Verify POST creates media record with correct URL

---

### Step 2: Fix Schedule Post

- **Priority**: Critical
- **Parallel with**: Step 1
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/components/post-form.tsx` — schedule button and payload building
  - `/Users/gregor/dev/922/Drafter/src/lib/validators.ts` — `createPostSchema` with `scheduledAt`
  - `/Users/gregor/dev/922/Drafter/src/app/api/posts/route.ts` — POST handler

**Root cause**: The `datetime-local` HTML input produces values like `"2026-03-28T14:30"` without timezone info. The Zod schema uses `.datetime()` which may reject this format depending on version. Even if it passes, the date handling is fragile.

**Fix:**

1. **`src/lib/validators.ts`** — Relax the `scheduledAt` validation:
   ```ts
   // Change from:
   scheduledAt: z.string().datetime().optional().nullable(),
   // To:
   scheduledAt: z.string().optional().nullable(),
   ```
   The string will be parsed to a Date on the server side. Add a `.transform()` or validate in the route handler that it's a parseable date.

2. **`src/app/api/posts/route.ts`** — Add explicit date parsing and validation:
   ```ts
   // After schema validation, before DB insert:
   if (scheduledAt) {
     const parsedDate = new Date(scheduledAt);
     if (isNaN(parsedDate.getTime())) {
       return NextResponse.json({ error: "Invalid schedule date" }, { status: 400 });
     }
     // Use the parsed Date object for Prisma
   }
   ```

3. **`src/components/post-form.tsx`** — Improve the schedule UX:
   - Ensure `scheduledAt` is converted to ISO string before sending: `new Date(scheduleDate).toISOString()` (already done, verify)
   - Show clear error toast if scheduling fails
   - After successful schedule, show toast "Post scheduled for {date}" before redirect

4. **`src/app/api/posts/[id]/route.ts`** — Apply same fix to PATCH handler for rescheduling

- **Acceptance criteria**:
  - [ ] Clicking "Schedule" with a future date creates a SCHEDULED post
  - [ ] Toast confirmation shows "Post scheduled for {date}"
  - [ ] Invalid dates are rejected with clear error
  - [ ] Rescheduling via edit page works

**Tests:**
  - [ ] `src/lib/validators.test.ts` — Update: scheduledAt accepts both ISO 8601 and datetime-local format strings
  - [ ] `src/app/api/posts/route.test.ts` — Add test: POST with SCHEDULED status and scheduledAt creates scheduled post, POST with invalid scheduledAt returns 400

---

### Step 3: Fix Save Draft

- **Priority**: High
- **Parallel with**: Steps 1 + 2
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/components/post-form.tsx` — lines 340-365 (submit handler, redirect logic)

**Root cause**: In edit mode, after saving a draft, the code falls into the `else` branch at line 363 which calls `router.push("/posts")`, redirecting immediately.

**Fix in `src/components/post-form.tsx`**:

1. **Edit mode draft save should stay on page** (same as create mode):
   ```ts
   // After successful save:
   if (status === "DRAFT") {
     setSaved(true);
     toast.success("Draft saved");
     setTimeout(() => setSaved(false), 2000);
     // Stay on page in BOTH create and edit mode
     return;
   }

   if (status === "SCHEDULED") {
     toast.success(`Post scheduled for ${new Date(scheduledAt).toLocaleDateString()}`);
     router.push("/posts");
   }
   ```

2. **In create mode after first draft save**: After the post is created, the URL should update to `/posts/{newId}/edit` so subsequent saves are PATCH requests, not new POST requests. Otherwise, clicking "Save Draft" twice creates two posts.
   ```ts
   if (mode === "create" && status === "DRAFT") {
     // Replace URL to edit mode so next save is a PATCH
     router.replace(`/posts/${createdPost.id}/edit`);
   }
   ```

- **Acceptance criteria**:
  - [ ] Save Draft in create mode: saves, shows "Draft saved" toast, stays on page, URL updates to edit mode
  - [ ] Save Draft in edit mode: saves, shows "Draft saved" toast, stays on page
  - [ ] Saving draft twice in create mode does NOT create duplicate posts
  - [ ] Schedule still redirects to /posts after success

**Tests:**
  - [ ] `src/components/post-form.test.ts` — Add: draft save does not redirect (check router.push is not called), scheduled save does redirect

---

### Step 4: Brand Avatar Upload

- **Priority**: Medium
- **Parallel with**: Steps 1-3 (but depends on Step 1 for S3 working)
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/app/(app)/branding/page.tsx`
  - `/Users/gregor/dev/922/Drafter/src/hooks/use-media-upload.ts`
  - `/Users/gregor/dev/922/Drafter/src/components/media-upload-zone.tsx`

**Current state**: The avatar area is just a styled `<div>` with a camera icon overlay on hover. No file input, no upload logic.

**Fix in `src/app/(app)/branding/page.tsx`**:

1. Add a hidden `<input type="file" accept="image/*">` ref
2. Wire the avatar `<div>` onClick to trigger the file input
3. On file selection, use the `useMediaUpload` hook to upload to S3
4. Store the uploaded avatar URL in local state (for now — no brand profile API exists yet)
5. Display the uploaded avatar image in the avatar circle
6. Show upload progress overlay while uploading
7. Persist avatar URL to localStorage as a simple bridge until a proper brand profile API is built

```tsx
const fileInputRef = useRef<HTMLInputElement>(null);
const { upload, uploading } = useMediaUpload();
const [avatarUrl, setAvatarUrl] = useState<string | null>(() => {
  if (typeof window !== "undefined") return localStorage.getItem("brand-avatar");
  return null;
});

const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
  const file = e.target.files?.[0];
  if (!file) return;
  try {
    const result = await upload(file);
    setAvatarUrl(result.url);
    localStorage.setItem("brand-avatar", result.url);
    toast.success("Avatar updated");
  } catch {
    toast.error("Failed to upload avatar");
  }
};
```

- **Acceptance criteria**:
  - [ ] Clicking avatar opens file picker
  - [ ] Selected image uploads to S3
  - [ ] Avatar circle shows the uploaded image
  - [ ] Upload progress shown during upload
  - [ ] Avatar persists across page reloads (localStorage)

**Tests:**
  - [ ] No specific test needed — relies on existing `useMediaUpload` tests + S3 fix from Step 1

---

### Step 5: Version Display in Sidebar

- **Priority**: Low
- **Parallel with**: All other steps
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/components/sidebar.tsx`
  - `/Users/gregor/dev/922/Drafter/version.txt` — contains `0.2.7`

**Implementation**:

1. **Make version available at build time**: Add to `next.config.ts`:
   ```ts
   import { readFileSync } from "fs";
   const version = readFileSync("version.txt", "utf-8").trim();
   // Add to env:
   env: { NEXT_PUBLIC_APP_VERSION: version },
   ```

2. **Update `src/components/sidebar.tsx`**: Add version at the bottom-left, below the logout button:
   ```tsx
   <span className="text-[10px] text-muted-foreground/50">
     v{process.env.NEXT_PUBLIC_APP_VERSION}
   </span>
   ```
   Position: absolute bottom-left of the sidebar, subtle, non-intrusive.

- **Acceptance criteria**:
  - [ ] Sidebar shows `v0.2.7` (or current version) at the bottom
  - [ ] Version updates when `version.txt` changes (after rebuild)

**Tests:**
  - [ ] No specific test needed — static display

---

### Step 6: Disable Social Media Linking UI

- **Priority**: Medium
- **Parallel with**: All other steps
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/app/(app)/branding/page.tsx` — lines 176-242 (connected accounts section)

**Implementation**: Wrap the "Connected Accounts" section in a conditional or replace it with a "Coming Soon" placeholder. Do NOT delete the code — just disable it.

```tsx
{/* Connected Accounts - Disabled for MVP */}
<div className="rounded-xl border border-border/50 bg-card p-5 opacity-50">
  <div className="mb-4 flex items-center justify-between">
    <h2 className="text-sm font-semibold text-white">Connected Accounts</h2>
    <span className="rounded-full bg-yellow-500/10 px-2 py-0.5 text-[10px] font-medium text-yellow-400">
      Coming Soon
    </span>
  </div>
  <p className="text-xs text-muted-foreground">
    Social media account linking will be available in a future update.
  </p>
</div>
```

Remove the `toggleConnection` function and `INITIAL_ACCOUNTS` state since they're no longer used (but keep the `Account` type and `INITIAL_ACCOUNTS` constant as comments for reference).

- **Acceptance criteria**:
  - [ ] Connected Accounts section shows "Coming Soon" badge
  - [ ] No Connect/Disconnect buttons visible
  - [ ] Section is visually dimmed (opacity-50)
  - [ ] No dead-click handlers

**Tests:**
  - [ ] No specific test needed — UI-only change

---

### Step 7: Disable Dashboard Mock Data Panels

- **Priority**: Medium
- **Parallel with**: All other steps
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/src/app/(app)/dashboard/page.tsx`

**Which panels use mock data:**
1. **Stats cards** (top 4): Total Posts, Total Views, Total Likes, Engagement Rate — all hardcoded
2. **Recent Posts section**: 3 hardcoded posts with non-existent image paths
3. **Weekly Schedule strip**: 7-day strip with hardcoded post indicators

**Implementation**: Disable (don't delete) the mock panels. Replace with disabled/placeholder state:

1. **Stats cards**: Keep the card layout but show "—" values and add "Coming Soon" tooltip or badge. Keep the card structure for future API integration:
   ```tsx
   {STATS.map((stat) => (
     <div key={stat.label} className="rounded-xl border border-border/50 bg-card p-5 opacity-50">
       <p className="text-xs text-muted-foreground">{stat.label}</p>
       <p className="mt-1 text-2xl font-bold text-white">—</p>
       <p className="mt-1 text-[10px] text-muted-foreground">Coming soon</p>
     </div>
   ))}
   ```

2. **Recent Posts section**: Replace with a link to the posts page:
   ```tsx
   <div className="rounded-xl border border-border/50 bg-card p-5">
     <h2 className="text-sm font-semibold text-white">Recent Posts</h2>
     <p className="mt-2 text-xs text-muted-foreground">
       View and manage all your posts in the Posts section.
     </p>
     <Link href="/posts" className="mt-3 inline-flex ...">Go to Posts</Link>
   </div>
   ```

3. **Weekly Schedule strip**: Replace with link to calendar:
   ```tsx
   <div className="rounded-xl border border-border/50 bg-card p-5">
     <h2 className="text-sm font-semibold text-white">Schedule</h2>
     <p className="mt-2 text-xs text-muted-foreground">
       View your content calendar for scheduling.
     </p>
     <Link href="/calendar" className="mt-3 inline-flex ...">Go to Calendar</Link>
   </div>
   ```

4. **Keep Quick Actions** (New Post, View Calendar, View Timeline) — these are functional navigation links.

- **Acceptance criteria**:
  - [ ] Stats cards show "—" values with "Coming soon" label
  - [ ] Stats cards visually dimmed
  - [ ] Recent Posts replaced with link to /posts
  - [ ] Schedule strip replaced with link to /calendar
  - [ ] Quick Action buttons still work
  - [ ] No hardcoded mock data visible
  - [ ] Original code preserved as comments for future activation

**Tests:**
  - [ ] No specific test needed — UI-only change

---

### Step 8: Comprehensive Automated Testing

- **Priority**: High
- **Parallel with**: — (depends on all fixes from Steps 1-7 being complete)
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/vitest.config.ts`
  - `/Users/gregor/dev/922/Drafter/package.json`
  - All existing test files in `src/**/*.test.{ts,tsx}`
  - `/Users/gregor/dev/922/Drafter/src/app/api/posts/route.ts`
  - `/Users/gregor/dev/922/Drafter/src/app/api/media/route.ts`
  - `/Users/gregor/dev/922/Drafter/src/lib/s3.ts`
  - `/Users/gregor/dev/922/Drafter/src/lib/validators.ts`
  - `/Users/gregor/dev/922/Drafter/src/middleware.ts`
  - `/Users/gregor/dev/922/Drafter/src/components/post-form.tsx`

**Goal**: Ensure every component, feature, and API route has real tests that verify the application code works. Target: **80%+ code coverage**.

#### 8a. Install Testing Dependencies

```bash
pnpm add -D @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom @vitejs/plugin-react playwright @playwright/test
```

Update `vitest.config.ts` to support both node (API/lib tests) and jsdom (component tests) environments:
```ts
// Use environment comments in test files:
// @vitest-environment jsdom
// or configure workspace for separate environments
```

#### 8b. Unit Tests — Fill Gaps

Review all existing tests and add missing coverage:

**API Route Tests (ensure these exist and are comprehensive):**

| Test File | Tests to Verify/Add |
|-----------|-------------------|
| `src/app/api/posts/route.test.ts` | GET: pagination, all filter combos, search, sort. POST: all 5 post types, DRAFT status default, SCHEDULED with date, missing fields |
| `src/app/api/posts/[id]/route.test.ts` | GET: with media. PATCH: status transitions, reschedule. DELETE: cascade media |
| `src/app/api/posts/[id]/copy/route.test.ts` | All 5 formats produce correct output, handles missing platformFields |
| `src/app/api/posts/[id]/duplicate/route.test.ts` | Resets metrics, appends "(Copy)", sets DRAFT |
| `src/app/api/posts/bulk-delete/route.test.ts` | Empty array rejected, org scoping |
| `src/app/api/media/route.test.ts` | GET: list with postId filter. POST: creates with correct URL |
| `src/app/api/media/upload-url/route.test.ts` | Image size limit (50MB), video size limit (500MB), allowed types |
| `src/app/api/media/[id]/route.test.ts` | DELETE: removes DB + S3 |
| `src/app/api/media/bulk-delete/route.test.ts` | Deletes multiple |
| `src/app/api/auth/login/route.test.ts` | Success sets cookie, failure forwards error |
| `src/app/api/auth/logout/route.test.ts` | **NEW**: Clears cookie |

**Library Tests:**

| Test File | Tests to Verify/Add |
|-----------|-------------------|
| `src/lib/s3.test.ts` | `getPublicUrl` with S3_PUBLIC_URL, with S3_ENDPOINT fallback, with AWS fallback. `generateS3Key` format |
| `src/lib/validators.test.ts` | All schemas, all edge cases (empty strings, max lengths, enum values) |
| `src/lib/auth.test.ts` | Valid JWT, expired JWT, invalid JWT, wrong secret |
| `src/lib/auth-helpers.test.ts` | Header extraction, dev fallbacks, production throws |
| `src/lib/api-client.test.ts` | All methods, error handling, 204 handling |

**Hook Tests:**

| Test File | Tests to Verify/Add |
|-----------|-------------------|
| `src/hooks/use-posts.test.ts` | Default params, all filter combinations |
| `src/hooks/use-media.test.ts` | List, filter by postId |
| `src/hooks/use-media-upload.test.ts` | Full upload flow, error handling |
| `src/hooks/use-calendar-posts.test.ts` | Groups by day, handles month boundaries |
| `src/hooks/use-timeline-posts.test.ts` | Groups by section, filter param |

**Component Tests (NEW — requires jsdom environment):**

| Test File | Description |
|-----------|-------------|
| `src/components/copy-button.test.tsx` | Verify exists, calls clipboard API |
| `src/components/post-form.test.ts` | POST_TYPES config, field validation, caption limits |
| `src/components/sidebar.test.tsx` | **NEW**: Renders all nav items, shows version, has logout button |

**Middleware Test:**

| Test File | Tests |
|-----------|-------|
| `src/middleware.test.ts` | Public paths, protected redirect, API 401, valid token header injection |

#### 8c. Integration Tests — API Route Tests Against Real Schemas

Create `src/__tests__/integration/` directory with tests that validate the full request→response cycle using mocked Prisma but real Zod validation:

- `posts-crud.integration.test.ts`:
  - Create post → verify response shape matches schema
  - Create → Get → verify fields match
  - Create → Update → verify changes persisted
  - Create → Delete → Get returns 404
  - Create → Duplicate → verify copy has different ID
  - Bulk delete → verify all deleted

- `media-crud.integration.test.ts`:
  - Request upload URL → verify response shape
  - Confirm upload → verify media record
  - Delete → verify removed

#### 8d. E2E Tests with Playwright

Install and configure Playwright for end-to-end browser testing.

1. **`playwright.config.ts`** at project root:
   ```ts
   import { defineConfig } from "@playwright/test";
   export default defineConfig({
     testDir: "./e2e",
     webServer: {
       command: "pnpm dev",
       port: 3000,
       reuseExistingServer: true,
     },
     use: {
       baseURL: "http://localhost:3000",
     },
   });
   ```

2. **`e2e/` directory** with test files:

   - `e2e/navigation.spec.ts`:
     - Visit each page (dashboard, posts, timeline, media, branding, calendar)
     - Verify page loads without errors
     - Verify sidebar navigation works
     - Verify version number visible in sidebar

   - `e2e/posts-crud.spec.ts`:
     - Navigate to /posts/new
     - Select post type (IG Photo)
     - Fill in title and caption
     - Click "Save Draft" → verify toast, verify stays on page
     - Navigate to /posts → verify post appears in list
     - Click post → verify detail page shows content
     - Click Edit → verify form pre-filled
     - Click Delete → verify post removed from list

   - `e2e/posts-schedule.spec.ts`:
     - Navigate to /posts/new
     - Fill in title, caption, set schedule date to tomorrow
     - Click "Schedule" → verify toast, verify redirect to /posts
     - Verify post shows "Scheduled" status in list
     - Navigate to calendar → verify post appears on correct day

   - `e2e/media-upload.spec.ts`:
     - Navigate to /media
     - Upload a test image file
     - Verify image appears in grid
     - Switch to list view → verify image appears
     - Select image → bulk delete → verify removed

   - `e2e/branding.spec.ts`:
     - Navigate to /branding
     - Verify "Coming Soon" badge on Connected Accounts
     - Click avatar → upload image → verify avatar displays

   - `e2e/dashboard.spec.ts`:
     - Navigate to /dashboard
     - Verify stats show "—" (disabled)
     - Verify Quick Actions buttons navigate correctly
     - Verify "Go to Posts" and "Go to Calendar" links work

3. **Add scripts to `package.json`**:
   ```json
   "test:e2e": "playwright test",
   "test:e2e:ui": "playwright test --ui",
   "test:all": "pnpm test && pnpm test:e2e"
   ```

- **Acceptance criteria**:
  - [ ] All existing unit tests still pass
  - [ ] New unit tests added for gaps (auth/logout, sidebar, component tests)
  - [ ] Integration tests verify full CRUD flows
  - [ ] E2E tests cover: navigation, post CRUD, scheduling, media upload, branding, dashboard
  - [ ] `pnpm test` passes (unit + integration)
  - [ ] `pnpm test:e2e` passes (Playwright)
  - [ ] Code coverage >= 80%
  - [ ] `pnpm type-check` passes
  - [ ] `pnpm build` succeeds

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel — independent fixes):
  Step 1: Fix S3/Image system → src/lib/s3.ts, .env files, next.config.ts, API routes
  Step 2: Fix schedule post → validators.ts, post-form.tsx, API route
  Step 3: Fix save draft → post-form.tsx redirect logic
  Step 4: Brand avatar upload → branding/page.tsx
  Step 5: Version in sidebar → next.config.ts, sidebar.tsx
  Step 6: Disable social linking → branding/page.tsx
  Step 7: Disable mock panels → dashboard/page.tsx

Wave 2 (after all fixes):
  Step 8: Comprehensive automated testing → unit, integration, E2E
```

## Post-Execution Checklist

- [ ] All images display correctly (upload + view)
- [ ] Schedule post works end-to-end
- [ ] Save draft works (create + edit mode) without redirect
- [ ] Brand avatar upload works
- [ ] Version shown in sidebar
- [ ] Social media linking disabled with "Coming Soon"
- [ ] Dashboard mock panels disabled
- [ ] Unit tests pass (`pnpm test`)
- [ ] E2E tests pass (`pnpm test:e2e`)
- [ ] Type check passes (`pnpm type-check`)
- [ ] Build succeeds (`pnpm build`)
- [ ] Pipeline green after push
- [ ] Code coverage >= 80%
