# Plan: HomeUI — Finance Invoicing UI

- **Date**: 2026-05-20
- **Project(s)**: HomeUI
- **Goal**: Add an Invoices section to the finance tab with a person/date-range form and PDF, XML, and HTML preview download actions backed by the existing HomeAPI `/api/finance/invoices/*` endpoints.

## Context

The HomeAPI backend (plan `2026-05-19-homeapi-finance-invoicing.md`) is fully implemented. The three endpoints exist:

| Endpoint | Response |
|---|---|
| `GET /api/finance/invoices/preview` | `text/html` — rendered invoice |
| `GET /api/finance/invoices/pdf` | `application/pdf` blob download |
| `GET /api/finance/invoices/xml` | `application/xml` blob download |

All three accept: `persons[]` (required, repeatable), `from_date` (optional `YYYY-MM-DD`), `to_date` (optional `YYYY-MM-DD`).

The HomeUI finance feature currently has two nav entries (Overview, Ledger) and no invoice section. The current finance directory structure is:

```
src/features/finance/
├── components/
│   ├── FinanceLayout.tsx
│   └── FinanceNav.tsx
└── pages/
    ├── FinanceOverviewPage.tsx
    └── FinanceOverviewPage.test.tsx
```

Read these files before proceeding:

- `orchestrator/projects/homeui.md` — tech stack, best practices, component patterns
- `HomeUI/CLAUDE.md` — naming conventions, new-feature checklist
- `HomeUI/src/features/finance/components/FinanceNav.tsx` — existing nav shape to extend
- `HomeUI/src/features/finance/components/FinanceLayout.tsx` — layout wrapper pattern
- `HomeUI/src/features/finance/pages/FinanceOverviewPage.tsx` — inline-style + useSuspenseQuery patterns to follow
- `HomeUI/src/api/debts.ts` — queryOptions factory pattern
- `HomeUI/src/types/api/debts.ts` — Zod schema + inferred type pattern
- `HomeUI/src/lib/http.ts` — Axios client (needed for blob responseType)
- `HomeUI/src/App.tsx` — route registration + lazy() pattern

---

## Design Decisions

### No JSON response schemas needed

All three invoice endpoints return non-JSON payloads (HTML string, PDF binary, XML string). There is nothing to parse with Zod. `src/types/api/invoice.ts` holds only the request params type used by the API module and the form.

### Download via Axios (not direct links)

HomeAPI requires auth headers on every request. Constructing raw `<a href>` links would bypass the Axios auth interceptor. Instead:
- PDF and XML: `http.get(..., { responseType: 'blob' })` → create an object URL → trigger programmatic `<a>` click → `URL.revokeObjectURL`.
- HTML preview: `http.get(..., { responseType: 'text' })` → render inside `<iframe srcDoc={html}>` on the same page (sandboxed, no XSS risk via `sandbox` attribute).

### Person list populated from existing summary query

`debtsQueryOptions.summary()` already returns all known persons with balances. The multi-select is populated from this data — no new endpoint needed. The `useSuspenseQuery` call is already present if the page is inside `FinanceLayout` which wraps with Suspense.

### Inline preview, not a new tab

The HTML preview renders in a collapsible `<iframe srcDoc>` section below the form. This keeps the user in-context, avoids popup blockers, and lets them switch between Preview / PDF / XML without leaving the page.

### Loading state per action

Each of the three actions (preview, PDF, XML) has its own `isLoading` boolean in local state. Buttons show a spinner and are disabled while the corresponding request is in flight. Actions are independent — previewing doesn't block downloading.

---

## Steps

### Step 1: Request Params Type

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Description**: Create `src/types/api/invoice.ts`. No Zod schemas needed (no JSON response to parse). Export only the request params type and a helper to serialise it as Axios params.

**Contents:**

```typescript
export interface InvoiceQueryParams {
  persons: string[]
  from_date?: string   // YYYY-MM-DD
  to_date?: string     // YYYY-MM-DD
}
```

- **Context files to read**:
  - `HomeUI/src/types/api/debts.ts` — file structure to mirror
- **Acceptance criteria**:
  - [ ] `src/types/api/invoice.ts` created and exports `InvoiceQueryParams`
  - [ ] `npx tsc --noEmit` exits 0

---

### Step 2: Invoice API Module

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (depends on Step 1)
- **Description**: Create `src/api/invoices.ts`. Three functions — one per endpoint. PDF and XML use `responseType: 'blob'` and trigger a programmatic download. The preview function returns the raw HTML string.

**Functions to implement:**

```typescript
import type { InvoiceQueryParams } from '@/types/api/invoice'
import { http } from '@/lib/http'

// Returns raw HTML string for <iframe srcDoc>
export async function fetchInvoicePreview(params: InvoiceQueryParams): Promise<string>

// Fetches PDF blob and triggers browser download
export async function downloadInvoicePdf(params: InvoiceQueryParams): Promise<void>

// Fetches XML blob and triggers browser download
export async function downloadInvoiceXml(params: InvoiceQueryParams): Promise<void>
```

**Download helper pattern** (shared between PDF and XML):
```typescript
const { data } = await http.get<Blob>('/api/finance/invoices/pdf', {
  params: { persons: params.persons, from_date: params.from_date, to_date: params.to_date },
  responseType: 'blob',
})
const url = URL.createObjectURL(data)
const a = document.createElement('a')
a.href = url
a.download = `invoice-${new Date().toISOString().slice(0, 10)}.pdf`
a.click()
URL.revokeObjectURL(url)
```

Note: Axios serialises repeated query params as `persons[]=Alice&persons[]=Bob` by default. Verify against HomeAPI — if HomeAPI expects `persons=Alice&persons=Bob` (no brackets), use `paramsSerializer` from `qs` or a custom serialiser. Check existing usage in `debts.ts` for the project convention.

- **Context files to read**:
  - `HomeUI/src/lib/http.ts` — Axios instance
  - `HomeUI/src/api/debts.ts` — queryOptions pattern + params usage
  - `HomeUI/src/types/api/invoice.ts` — InvoiceQueryParams (from Step 1)
- **Acceptance criteria**:
  - [ ] `src/api/invoices.ts` created with all three exported functions
  - [ ] Blob download tested manually (or unit tested with mocked Axios) for PDF
  - [ ] `npx tsc --noEmit` exits 0

---

### Step 3: InvoicePage Component + Tests

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (depends on Step 2)
- **Description**: Create `src/features/finance/pages/InvoicePage.tsx` and colocated `InvoicePage.test.tsx`.

**Component behaviour:**

1. **Person multi-select** — populated from `useSuspenseQuery(debtsQueryOptions.summary())`. Renders a list of checkboxes (or a multi-select) with each known `person_name`. At least one must be checked before actions are enabled.
2. **Date range inputs** — two `<input type="date">` fields for `from_date` and `to_date`. Both optional.
3. **Action bar** — three buttons: `Preview`, `Download PDF`, `Download XML`. Each disabled when `persons` is empty or when that action's request is in-flight.
4. **Preview panel** — conditionally rendered `<iframe>` with `srcDoc={previewHtml}` and `sandbox="allow-same-origin"`. Hidden until Preview is triggered. Show a loading skeleton while fetching.
5. **Error handling** — if any action throws, display a brief inline error message below the form (no toast library needed — plain text).

**Styling** — follow the inline-style pattern from `FinanceOverviewPage.tsx`:
- CSS Grid / Flexbox via inline `style` props
- `var(--card)`, `var(--border)`, `var(--muted-foreground)` CSS vars
- JetBrains Mono for monospace values
- No Tailwind spacing classes — use inline `gap`, `padding` etc.
- The preview `<iframe>` should be full-width, min-height 600px, with a `var(--border)` border

**Test cases** (`InvoicePage.test.tsx`):
- Renders with person checkboxes populated from mocked summary
- Action buttons disabled when no person selected
- Buttons enabled after selecting a person
- Clicking "Preview" calls `fetchInvoicePreview` and renders iframe when resolved
- Clicking "Download PDF" calls `downloadInvoicePdf`
- Clicking "Download XML" calls `downloadInvoiceXml`
- Inline error shown when `fetchInvoicePreview` rejects
- Empty state when summary returns no persons

Mock pattern:
```typescript
vi.mock('@/api/invoices')
vi.mock('@/api/debts')  // or mock useSuspenseQuery directly
```

- **Context files to read**:
  - `HomeUI/src/features/finance/pages/FinanceOverviewPage.tsx` — inline-style + useSuspenseQuery patterns
  - `HomeUI/src/features/finance/pages/FinanceOverviewPage.test.tsx` — test patterns to mirror
  - `HomeUI/src/api/invoices.ts` — functions to call (from Step 2)
  - `HomeUI/.claude/HOW-TO-UNIT-TEST.md` — test patterns, renderWithProviders
- **Acceptance criteria**:
  - [ ] `src/features/finance/pages/InvoicePage.tsx` created
  - [ ] `src/features/finance/pages/InvoicePage.test.tsx` created, all cases above covered
  - [ ] `npm run test:ci` passes (new tests green, no regressions)
  - [ ] `npx tsc --noEmit` exits 0

---

### Step 4: Wire Up Route and Nav

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (depends on Step 3)
- **Description**: Register the new page as a route in `App.tsx` and add a nav entry to `FinanceNav.tsx`.

**`App.tsx` change** — add lazy import and nested route under the existing `/finance` layout:
```typescript
const InvoicePage = lazy(() =>
  import('./features/finance/pages/InvoicePage').then(m => ({ default: m.InvoicePage }))
)

// Inside the /finance nested routes:
<Route path="invoices" element={<InvoicePage />} />
```

**`FinanceNav.tsx` change** — add entry after Ledger:
```typescript
{ title: 'Invoices', path: '/finance/invoices', icon: FileText }
```
(`FileText` from `lucide-react` — already available.)

- **Context files to read**:
  - `HomeUI/src/App.tsx` — existing lazy import and route nesting pattern
  - `HomeUI/src/features/finance/components/FinanceNav.tsx` — nav item structure
- **Acceptance criteria**:
  - [ ] `/finance/invoices` route renders `InvoicePage` without errors
  - [ ] "Invoices" nav item appears in the finance section sidebar and highlights when active
  - [ ] Navigating to `/finance/invoices` directly works (no 404)
  - [ ] `npm run type-check` exits 0

---

### Step 5: Quality Gates

- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: — (depends on Step 4)
- **Description**: Full suite pass, lint, type-check.

**Commands:**
```bash
npx tsc --noEmit
npm run lint
npm run test:ci
```

- **Acceptance criteria**:
  - [ ] `tsc --noEmit` exits 0
  - [ ] `npm run lint` exits 0 (no new ESLint errors)
  - [ ] `npm run test:ci` exits 0 (all tests pass, coverage ≥ 70%)
  - [ ] No regressions in existing finance tests

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Invoice request params type   → HomeUI @ src/types/api/invoice.ts

Wave 2 (after Step 1):
  Step 2: Invoice API module            → HomeUI @ src/api/invoices.ts

Wave 3 (after Step 2):
  Step 3: InvoicePage component + tests → HomeUI @ src/features/finance/pages/

Wave 4 (after Step 3):
  Step 4: Route + nav wiring            → HomeUI @ src/App.tsx + FinanceNav.tsx

Wave 5 (after Step 4):
  Step 5: Quality gates                 → HomeUI (tsc + lint + test:ci)
```

---

## Post-Execution Checklist

- [ ] `/finance/invoices` is reachable and shows the person-select form
- [ ] All known persons from the debt summary appear as selectable options
- [ ] Selecting one or more persons enables the three action buttons
- [ ] "Preview" fetches HTML and renders it in an inline iframe
- [ ] "Download PDF" triggers a `.pdf` file download through the browser
- [ ] "Download XML" triggers a `.xml` file download through the browser
- [ ] Date range filters are passed correctly to the API (verified in Network tab)
- [ ] Selecting no persons keeps action buttons disabled
- [ ] API error surfaces as an inline error message (not a silent failure)
- [ ] "Invoices" nav item appears in the finance sidebar and highlights when active
- [ ] `npm run test:ci` green, coverage ≥ 70%
- [ ] `npx tsc --noEmit` exits 0
- [ ] PR opened against `main` referencing this plan
- [ ] CI pipeline green
