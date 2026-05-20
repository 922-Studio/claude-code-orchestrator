# Plan: Finance Invoice Overhaul — Branded UI, Receiver Model, Persistence, PDF Fix

- **Date**: 2026-05-20
- **Project(s)**: HomeAPI (backend), HomeUI (frontend)
- **Goal**: Replace the v1 stub invoice flow with a production-grade, **German-first**, branded invoice system: real sender + receiver blocks via a new Person model, persisted invoices, clean in-page layout with a non-scrolling auto-grow preview, working PDF generation, and an "open PDF in new tab" action. Local development runs HomeUI against the deployed `lab-api-dev.922-studio.com`.

## Background

The current state on `origin/feat/finance-invoicing-ui` (HomeUI) + `dev` (HomeAPI, merged in PR #40):

- HomeAPI exposes `GET /api/finance/invoices/{preview,pdf,xml}` — all **computed on demand**, no persistence.
- The Jinja2 template (`HomeAPI/app/templates/invoice.html.j2`) is generic corporate styling (Helvetica, navy header) — no 922-Studio branding, **no receiver block**, sender pulled from `Settings.data` JSON (org_name / org_address / org_email / org_iban / org_vat).
- HomeUI page (`HomeUI/src/features/finance/pages/InvoicePage.tsx`) is a plain form with checkboxes + date inputs + three action buttons. Preview renders inside `<iframe srcDoc>` with `minHeight: 600` → **iframe scrolls internally**, page does not extend.
- No Person/Contact model exists in HomeAPI — debt rows only carry `person_name` strings.
- PDF generation is reported broken; root cause unverified — likely WeasyPrint system-lib gaps in the container, or an empty `Settings.data` causing a template branch to fail.

## Scope of this overhaul

| Area | Change |
|---|---|
| **Receiver source** | New `Person` model in HomeAPI (name, address, email, optional VAT, optional IBAN, optional notes). Replaces free-form `person_name` lookups for invoices. Existing `DebtTransaction.person_name` is **not** renamed — invoices match person by name (case-insensitive) and link to the Person row via `person_id` once selected. |
| **Persistence** | New `Invoice` model: snapshot of sender + receiver + line items + totals at creation time. Created via explicit `POST /api/finance/invoices`. `GET /preview` and `GET /pdf` stay computed-on-the-fly (for un-saved preview); a new `GET /api/finance/invoices/{id}` and `GET /api/finance/invoices/{id}/pdf` serve the saved snapshot. |
| **Branding** | German invoice template with a colored 922-Studio wordmark header (purple→cyan gradient matching `TerminalLogo`), real Absender/Empfänger blocks side-by-side, clean centered transaction table, page-safe typography. |
| **PDF fix** | Diagnose + repair WeasyPrint pipeline. Add a minimal reproducer + Dockerfile audit. |
| **In-page preview** | Replace fixed-height iframe with **auto-grow iframe** (measure `contentDocument.body.scrollHeight` in `onLoad`). Outer page becomes the only scroll container. |
| **Open in new tab** | New "PDF im neuen Tab öffnen" button: fetch PDF blob with auth, `URL.createObjectURL`, `window.open(blobUrl, '_blank')`. No server URL-signing needed. |
| **Language** | All invoice template labels + UI labels in German. A locale toggle is a future v2 item (out of scope here, but template helpers structured for i18n). |
| **Local dev** | HomeUI `npm run dev` on `localhost:8001` with `VITE_API_BASE_URL=https://lab-api-dev.922-studio.com`. No local HomeAPI required. |

## Context

Read these files before proceeding:

### Project context
- `orchestrator/projects/homeapi.md` — HomeAPI tech stack, new-module checklist, test patterns
- `orchestrator/projects/homeui.md` — HomeUI tech stack, component conventions
- `orchestrator/server.md` — DB hosts, container layout, lab-api-dev pointers
- `HomeAPI/CLAUDE.md` — architecture rules, AsyncSession patterns, multi-tenancy via `get_org_id`
- `HomeUI/CLAUDE.md` — naming conventions, Tailwind v4 spacing quirk (inline styles for spacing)

### Existing invoice implementation (must read before touching)
- `HomeAPI/app/routers/finance/invoices.py` — current endpoint shape (lines 1-118)
- `HomeAPI/app/services/invoice_service.py` — current rendering (lines 1-108)
- `HomeAPI/app/templates/invoice.html.j2` — current Jinja template (lines 1-247) — will be **replaced**
- `HomeAPI/app/schemas/invoice.py` — existing schemas (will be extended, not replaced)
- `HomeAPI/app/models/settings.py` — Settings singleton (source of sender data)
- `HomeAPI/app/models/debt_transaction.py` — DebtTransaction (source of line items)
- `HomeAPI/app/crud/debt.py` — `get_debt_summary` / `get_debt_person_history` (reused)
- `HomeAPI/app/main.py` — router registration pattern
- `HomeAPI/alembic/` — migration directory + latest revision for chaining
- `HomeAPI/.claude/HOW-TO-PYTEST-TEST.md` — AsyncMock + Allure patterns

### Existing HomeUI invoice page (must read before redesign)
- `HomeUI/src/features/finance/pages/InvoicePage.tsx` (on `origin/feat/finance-invoicing-ui`) — current 362-line layout to redesign
- `HomeUI/src/api/invoices.ts` — Axios + URLSearchParams pattern (works correctly; extend, don't rewrite)
- `HomeUI/src/types/api/invoice.ts` — current `InvoiceQueryParams` type
- `HomeUI/src/features/finance/components/FinanceNav.tsx` — nav entry to extend
- `HomeUI/src/features/finance/components/FinanceLayout.tsx` — section layout wrapper (defines outer scroll container)
- `HomeUI/src/components/ui/TerminalLogo.tsx` — gradient definitions: chevron `#6366f1→#a855f7`, 922 `#a855f7→#06b6d4`. Reuse the gradient stops in the new branded header.
- `HomeUI/src/index.css` — CSS tokens (`--card`, `--border`, `--foreground`, `--muted-foreground`, `--primary`, `--secondary`)
- `HomeUI/src/lib/http.ts` — Axios client + auth interceptor

### Local-dev pointers
- `HomeUI/.env.example` — copy to `.env.local`, set `VITE_API_BASE_URL=https://lab-api-dev.922-studio.com`
- `HomeUI/package.json` — `npm run dev` (Vite dev server on port 8001)

## Design Decisions

### Person model lives in HomeAPI, not HomeUI
Contacts are a domain concept reused across debts and invoices. Owned by HomeAPI with full CRUD + multi-tenancy via `org_id`. HomeUI gets a small CRUD UI under `/finance/persons` to manage them.

### DebtTransaction is NOT migrated to FK
We keep `DebtTransaction.person_name` as a free-form string for backwards compatibility and because the ledger semantics are name-based. Invoices match by name to find/auto-create the Person row when receivers are picked.

### Invoice snapshot is immutable
On `POST /api/finance/invoices`, we **freeze** the current sender (from Settings), the picked Person (receiver), the matched debt transactions, and the totals into the `Invoice` row as JSON columns. The saved invoice never re-computes. Updating Settings later doesn't change historical invoices. The number is generated server-side: `INV-{YYYYMM}-{seq}` where `seq` is a per-org monotonic counter (4 digits, zero-padded). This replaces the current UUID-suffix scheme — sequential numbers are required for many EU tax regimes.

### Computed preview ≠ saved invoice
`GET /api/finance/invoices/preview` and `GET /api/finance/invoices/pdf` remain **computed** endpoints — they accept query params, never write to DB. The Invoice page calls these for the live preview pane.
`POST /api/finance/invoices` returns the saved invoice (with id + final number); the UI then routes to `/finance/invoices/<id>` which loads from `GET /api/finance/invoices/{id}` and uses `GET /api/finance/invoices/{id}/pdf` for the canonical PDF.

### PDF inline vs. attachment
Computed `GET /pdf` keeps `Content-Disposition: attachment; filename=...`. For "open in new tab" the UI fetches as blob and uses `window.open(URL.createObjectURL(blob))` — blob URLs render PDF inline regardless of the source `Content-Disposition`, so **no server change is required** for the new-tab flow.

### Iframe auto-grow over scroll-inside
Preview iframe uses `sandbox="allow-same-origin"` (already in place). In `onLoad`, read `iframe.contentDocument.body.scrollHeight` and set `iframe.style.height` to match. Add a `ResizeObserver` on the body element to handle dynamic content (re-renders after preview refresh). The iframe itself becomes content-height — outer `SectionLayout` scrolls the whole page.

### No Co-Authored-By, all docs/PRs in English
Universal rule from root CLAUDE.md. Invoice template + UI labels in German; everything else (commits, PRs, code comments, this plan) in English.

## Endpoints (after this plan)

| Method | Path | Purpose | Persistence |
|---|---|---|---|
| GET | `/api/finance/persons` | List persons (org-scoped) | read |
| POST | `/api/finance/persons` | Create person | write |
| GET | `/api/finance/persons/{id}` | Read person | read |
| PATCH | `/api/finance/persons/{id}` | Update person | write |
| DELETE | `/api/finance/persons/{id}` | Soft-delete | write |
| GET | `/api/finance/invoices/preview` | Computed HTML preview | none |
| GET | `/api/finance/invoices/pdf` | Computed PDF | none |
| GET | `/api/finance/invoices/xml` | Computed XML | none |
| POST | `/api/finance/invoices` | **Persist invoice from current state** | write |
| GET | `/api/finance/invoices` | **List saved invoices** | read |
| GET | `/api/finance/invoices/{id}` | **Read saved invoice (JSON)** | read |
| GET | `/api/finance/invoices/{id}/pdf` | **PDF of saved snapshot** | read |
| DELETE | `/api/finance/invoices/{id}` | **Soft-delete (status=cancelled)** | write |

Computed endpoints accept the existing query params (`persons[]`, `from_date`, `to_date`). The persist endpoint takes a JSON body (`{person_id, from_date, to_date, notes}`).

---

## Steps

### Wave 1 — HomeAPI data model + migrations

#### Step 1: Person model + Alembic migration
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 2
- **Description**: Add a `Person` SQLAlchemy model. Generate Alembic migration. Multi-tenant via `org_id`. Soft-delete via `deleted_at`. Indexed on `(org_id, name)` (case-insensitive unique).

  Columns:
  - `id` UUID PK
  - `org_id` str, indexed, NOT NULL
  - `name` str, NOT NULL — matches `DebtTransaction.person_name`
  - `email` str | None
  - `address_line1` str | None
  - `address_line2` str | None
  - `postal_code` str | None
  - `city` str | None
  - `country` str | None (default "DE")
  - `vat_id` str | None
  - `iban` str | None
  - `notes` str | None
  - `created_at` / `updated_at` timestamps (`server_default=func.now()`)
  - `deleted_at` timestamp | None

- **Context files to read**:
  - `HomeAPI/app/models/debt_transaction.py` — column conventions, UUID/timestamp helpers
  - `HomeAPI/app/models/settings.py` — JSON column pattern (not needed here, but for consistency)
  - `HomeAPI/alembic/versions/` — latest revision for `down_revision`
- **Acceptance criteria**:
  - [ ] `app/models/person.py` created
  - [ ] Alembic migration in `alembic/versions/` adds `persons` table with unique index `(org_id, lower(name)) WHERE deleted_at IS NULL`
  - [ ] `alembic upgrade head` runs clean on dev DB (verify by running migration locally against `dev_postgres` over SSH tunnel OR push branch and let CI smoke-test on lab-dev)
  - [ ] Model imported in `app/models/__init__.py`

#### Step 2: Invoice model + Alembic migration
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 1
- **Description**: Add `Invoice` SQLAlchemy model + Alembic migration. Snapshot model — all line items + addresses denormalised.

  Columns:
  - `id` UUID PK
  - `org_id` str, indexed, NOT NULL
  - `number` str, NOT NULL — e.g. `INV-202605-0001` (unique per org)
  - `sequence` int, NOT NULL — monotonic counter per `(org_id, year_month)` for number generation
  - `issued_date` date, NOT NULL
  - `from_date` date | None
  - `to_date` date | None
  - `currency` str, default "EUR"
  - `total_amount` Numeric(12, 2), NOT NULL
  - `person_id` UUID FK → `persons.id`, NOT NULL
  - `sender_snapshot` JSON — `{name, address_line1, address_line2, postal_code, city, country, email, iban, vat_id}`
  - `receiver_snapshot` JSON — same shape, populated from Person at creation
  - `line_items_snapshot` JSON — list of `{date, description, amount}` for full audit trail
  - `notes` str | None — free-form (rendered in invoice footer)
  - `status` enum: `draft | issued | cancelled` (default `issued` on POST; `cancelled` on soft-delete)
  - `created_at` / `updated_at` timestamps
  - `deleted_at` timestamp | None

  Unique constraint: `(org_id, number) WHERE deleted_at IS NULL`.
  Index: `(org_id, issued_date DESC)` for list ordering.

- **Context files to read**:
  - `HomeAPI/app/models/debt_transaction.py` — Numeric + JSON column conventions
  - `HomeAPI/alembic/versions/` — latest revision (chain after Person migration if same wave; pick whichever lands second as the child)
- **Acceptance criteria**:
  - [ ] `app/models/invoice.py` created
  - [ ] Alembic migration adds `invoices` table with constraints above
  - [ ] FK to `persons` is `ON DELETE RESTRICT` (so soft-deleting a Person with invoices doesn't orphan history)
  - [ ] `alembic upgrade head` runs clean
  - [ ] Model imported in `app/models/__init__.py`

#### Step 3: Person + Invoice schemas (Pydantic V2)
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 1, Step 2 (no code dep on the models — schemas are pure)
- **Description**: Extend `app/schemas/`. Decimal for money, ConfigDict (no `class Config`).

  New / changed files:
  - `app/schemas/person.py` — `PersonBase`, `PersonCreate`, `PersonUpdate`, `Person` (response, has id + timestamps)
  - `app/schemas/invoice.py` — **extend** existing file:
    - Keep: `InvoiceTransactionRow`, `InvoiceLineItem`, `InvoiceIssuer`, `InvoiceData`, `InvoiceRequest`
    - Add: `InvoiceRecipient` (same shape as `InvoiceIssuer` plus `address_line2`, `postal_code`, `city`, `country`)
    - Add to `InvoiceData`: `recipient: InvoiceRecipient | None`, `notes: str | None`
    - Add: `InvoiceCreateRequest` — `{person_id: UUID, from_date: date | None, to_date: date | None, notes: str | None}`
    - Add: `Invoice` (DB-backed response: id, org_id, number, issued_date, currency, total_amount, person_id, sender_snapshot, receiver_snapshot, line_items_snapshot, notes, status, created_at, updated_at)
    - Add: `InvoiceListItem` — slim version for list endpoint (id, number, issued_date, person_name, total_amount, status)
- **Context files to read**:
  - `HomeAPI/app/schemas/debt.py` — Decimal handling, optional fields
  - `HomeAPI/app/schemas/invoice.py` — existing shapes
- **Acceptance criteria**:
  - [ ] All schemas use `ConfigDict(from_attributes=True)` where appropriate
  - [ ] No `float` anywhere — `Decimal` for all monetary fields
  - [ ] Unit tests in `tests/unit/schemas/test_person.py` and `tests/unit/schemas/test_invoice.py` covering valid construction, optional defaults, Decimal precision
  - [ ] `ruff check app/schemas/ tests/unit/schemas/` exits 0

---

### Wave 2 — HomeAPI CRUD + service refactor

#### Step 4: Person CRUD + router
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 5
- **Depends on**: Steps 1, 3
- **Description**: New `app/crud/person.py` (list, get, get_by_name, create, update, soft_delete — all org-scoped) and `app/routers/finance/persons.py` (REST endpoints listed above). All endpoints check `org_id = get_org_id(request)` and 403 if missing. List excludes soft-deleted by default; accepts `?include_deleted=true` query.

  `get_by_name(db, org_id, name)` is case-insensitive — used by invoice persistence to resolve the receiver.

- **Context files to read**:
  - `HomeAPI/app/crud/debt.py` — async CRUD patterns with SQLAlchemy 2.x select() syntax
  - `HomeAPI/app/routers/finance/ledger.py` — router + dependency injection + org_id pattern
- **Acceptance criteria**:
  - [ ] `app/crud/person.py` with all six functions
  - [ ] `app/routers/finance/persons.py` with all five endpoints (list/create/get/patch/delete)
  - [ ] Router registered in `app/main.py` at prefix `/api/finance/persons`, tag `finance`
  - [ ] Unit tests for CRUD in `tests/unit/crud/test_person.py` (mock AsyncSession)
  - [ ] Integration tests for router in `tests/integration/routers/finance/test_persons.py` covering list, create, get-404, update, delete, and `org_id` enforcement

#### Step 5: Diagnose + fix PDF generation
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 4
- **Depends on**: — (independent investigation)
- **Description**: Find the actual reason `render_pdf()` fails. Hypotheses, in order of likelihood:

  1. **WeasyPrint system libs missing in container** — WeasyPrint needs `libcairo2`, `libpango-1.0-0`, `libpangoft2-1.0-0`, `libpangocairo-1.0-0`, `libgdk-pixbuf-2.0-0`, `shared-mime-info`, `fonts-liberation` (or any sans-serif font package). The base image may be missing these.
  2. **No fonts installed in container** — WeasyPrint silently renders empty PDFs / errors if no fonts are resolvable.
  3. **Settings.data is empty** — template branches on `{% if invoice.issuer.name %}` etc., so this shouldn't crash, but verify.
  4. **`format_currency` filter on `None` amount** — if a line item has `total_amount=None` somehow.
  5. **Lazy import inside function** — `from weasyprint import HTML` is at function-call time. Import error would surface only on first PDF call.

  Reproducer steps:
  ```bash
  # On lab-dev container (or local with requirements installed):
  python -c "from weasyprint import HTML; print(HTML(string='<html><body>hi</body></html>').write_pdf()[:8])"
  ```
  - If this prints `b'%PDF-1.7\n'` (or similar) → WeasyPrint itself is fine, the template is at fault.
  - If it errors → system libs / fonts missing.

  Fix path:
  - If container: edit `HomeAPI/Dockerfile` (or `Dockerfile.api`) — add the apt packages. Document the change in commit message.
  - If template: identify the failing branch via a unit test that runs the actual `render_pdf()` against a fixture `InvoiceData` and asserts non-empty bytes.

  Add a **CI smoke test** that calls `render_pdf()` with a fixture `InvoiceData` and asserts the result starts with `b'%PDF'`. This prevents silent regressions.

- **Context files to read**:
  - `HomeAPI/Dockerfile` (or `Dockerfile.api`) — current base image + apt installs
  - `HomeAPI/app/services/invoice_service.py` — `render_pdf` definition (lines ~70-75)
  - `HomeAPI/requirements-api.txt` — confirm `weasyprint>=62.0` and `lxml>=5.0` are pinned (already verified present)
- **Acceptance criteria**:
  - [ ] Root cause documented in commit message + step report
  - [ ] Fix applied (Dockerfile, template, or service code as needed)
  - [ ] New test `tests/unit/services/test_invoice_service_pdf.py::test_render_pdf_smoke` runs WeasyPrint for real (NOT mocked), asserts `output.startswith(b'%PDF')`. Skipped only if WeasyPrint import fails at module level (so dev machines without system libs still pass other tests).
  - [ ] Existing `test_invoice_service.py` mocks of WeasyPrint remain green
  - [ ] PDF endpoint manually verified against `lab-api-dev` after deploy (curl with auth → `file invoice.pdf` says PDF)

#### Step 6: Invoice service — sender + receiver snapshots, sequential numbers
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (depends on Steps 3, 4, 5)
- **Description**: Rework `app/services/invoice_service.py`:

  - Rename `build_invoice_data` parameters: takes `summaries`, `histories`, `sender: InvoiceIssuer`, `recipient: InvoiceRecipient | None`, `from_date`, `to_date`, `notes`, `invoice_number` (None → caller passes the persisted number; for preview, generate a `PREVIEW` placeholder).
  - New helper `build_sender_from_settings(settings_data: dict) -> InvoiceIssuer`.
  - New helper `build_recipient_from_person(person: Person) -> InvoiceRecipient`.
  - New helper `generate_invoice_number(db, org_id, issued_date) -> tuple[str, int]` — atomic per-org `INV-{YYYYMM}-{seq:04d}`. Acquires advisory lock on `(org_id, year_month)` to avoid races. Returns `(number, sequence)`.
  - `render_html` / `render_pdf` / `render_xml` signatures unchanged — only the `InvoiceData` they receive gets richer.

  **Important — German labels**: rendering is template-driven, so this service does NOT contain text; only date formatting helpers. Add `format_date_de(d: date) -> str` returning e.g. `20. Mai 2026` (use `babel` if already in deps; otherwise hand-roll a month-name map). Expose as a Jinja filter `date_de`.

- **Context files to read**:
  - `HomeAPI/app/services/invoice_service.py` — current implementation
  - `HomeAPI/app/crud/settings.py` — how settings are read
  - `HomeAPI/app/schemas/invoice.py` — final schemas from Step 3
- **Acceptance criteria**:
  - [ ] `build_invoice_data` accepts `sender` and `recipient` as parameters (no longer reads settings inside)
  - [ ] `generate_invoice_number` is atomic — concurrent test (two coroutines calling it) produces two distinct sequences
  - [ ] Jinja env exposes `date_de` filter
  - [ ] Unit tests cover number generation rollover (next month resets seq to 1)
  - [ ] `mypy app/services/invoice_service.py` exits 0

---

### Wave 3 — HomeAPI invoice router overhaul

#### Step 7: Invoice router — add persistence endpoints, keep computed ones
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Depends on**: Step 6
- **Description**: Rework `app/routers/finance/invoices.py`:

  - Keep existing `GET /preview`, `GET /pdf`, `GET /xml` (computed, query-param driven). Update them to also accept an optional `person_id` query: if provided, resolve recipient from Person; otherwise omit the recipient block (preview without a saved receiver). Sender always comes from Settings.
  - Add `POST /` — body `InvoiceCreateRequest` → resolves person, fetches debts for that person within the date range, generates number, builds `InvoiceData`, **inserts an `Invoice` row with all snapshots**, returns `Invoice` schema.
  - Add `GET /` — list saved invoices (paginated `?limit=50&offset=0`, default sort `issued_date DESC`). Returns `list[InvoiceListItem]`.
  - Add `GET /{id}` — read saved invoice by id (404 if not found or wrong org).
  - Add `GET /{id}/pdf` — re-renders PDF from the saved `Invoice` snapshot (sender_snapshot, receiver_snapshot, line_items_snapshot). Inline preview not needed here; returns `Content-Disposition: attachment`.
  - Add `DELETE /{id}` — soft-delete (`status='cancelled'`, `deleted_at=now()`). 204 on success.

  All endpoints enforce `org_id`. All use `AsyncSession` from `get_db`.

  **Important**: when computing a preview without a `person_id` (legacy flow), the `persons[]` query stays as the source of truth. When `person_id` is given, ignore the `persons[]` param and use the Person's name to match debt rows.

- **Context files to read**:
  - `HomeAPI/app/routers/finance/invoices.py` — current shape
  - `HomeAPI/app/routers/finance/ledger.py` — POST pattern with body + AsyncSession
  - `HomeAPI/app/crud/debt.py` — `get_debt_summary`, `get_debt_person_history`
- **Acceptance criteria**:
  - [ ] All endpoints listed in the "Endpoints" table above present and return correct status codes
  - [ ] POST returns 201 with the created `Invoice`
  - [ ] GET list returns paginated list, sort + filter by status work
  - [ ] DELETE returns 204 and the row is soft-deleted (still queryable with `?include_deleted=true`)
  - [ ] All endpoints respect `org_id` (multi-tenant) — covered by integration tests
  - [ ] OpenAPI docs at `/docs` show all new endpoints under `finance` tag

#### Step 8: Integration tests — Person + Invoice routers
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Depends on**: Step 7
- **Description**: Extend `tests/integration/routers/finance/test_invoices.py` and add `tests/integration/routers/finance/test_persons.py`.

  **Person tests** (already listed in Step 4 acceptance — collected here for tracking):
  - List empty, list with data, sort
  - Create returns 201 + Person body
  - Create duplicate name in same org → 409
  - Create duplicate name in different org → 201
  - Get 200 / 404
  - Patch updates fields, returns updated Person
  - Delete soft-deletes (still exists with `?include_deleted=true`)
  - org_id missing → 403

  **Invoice tests** (new + existing — full matrix):
  - Existing computed endpoints: tests stay green (no regression)
  - POST creates an invoice — assert: number format `INV-YYYYMM-####`, snapshots populated, line items match the source debts
  - POST with non-existent `person_id` → 404
  - POST with no debts in date range → 422 ("no transactions to invoice")
  - Two parallel POST calls for the same month → sequences are 0001 and 0002 (no collision)
  - GET list returns saved invoice
  - GET `/{id}` returns full snapshot
  - GET `/{id}/pdf` returns `application/pdf`, bytes start with `%PDF`
  - DELETE soft-deletes, subsequent GET `/{id}` returns 404 (and 200 with `?include_deleted=true`)
  - Cross-org isolation: org A's POST is not visible to org B

  Mocking strategy: real `AsyncSession` against an in-memory sqlite (existing test infra), OR mock `crud.debt.get_debt_summary` if real DB seeding is too heavy. Follow whatever `test_ledger.py` already does.

- **Context files to read**:
  - `HomeAPI/tests/integration/routers/finance/test_ledger.py` — patterns to mirror
  - `HomeAPI/tests/conftest.py` — fixtures
  - `HomeAPI/.claude/HOW-TO-PYTEST-TEST.md` — Allure decorators + AsyncMock patterns
- **Acceptance criteria**:
  - [ ] `tests/integration/routers/finance/test_persons.py` created, all cases above
  - [ ] `tests/integration/routers/finance/test_invoices.py` extended, all cases above
  - [ ] All Allure-decorated (`@allure.feature("Finance")`, `@allure.story("Invoicing")` / `@allure.story("Persons")`)
  - [ ] `PYTHONPATH=. pytest tests/integration/routers/finance/ -v` all green
  - [ ] Coverage ≥ 70% for `app/routers/finance/{invoices,persons}.py` and `app/crud/person.py`

---

### Wave 4 — HomeAPI template overhaul (German + 922-Studio branding)

#### Step 9: Replace `invoice.html.j2` with branded German template
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (depends on Step 6 for `date_de` filter; can run alongside Steps 7-8)
- **Description**: Full rewrite of `app/templates/invoice.html.j2`. Single file, all CSS embedded (no external CDN — WeasyPrint cannot resolve external `<link>`). German throughout.

  **Layout (top to bottom):**

  1. **Branded header band** — full-width, 60mm tall. Left: the 922-Studio wordmark rendered as **inline SVG with embedded `<linearGradient>`s** matching `TerminalLogo.tsx`:
     - Chevron `>` 16pt, gradient `#6366f1 → #a855f7`
     - Wordmark "922-Studio" 24pt, gradient `#a855f7 → #06b6d4`, JetBrains Mono / Space Mono fallback
     - Tagline below: "Software · Infrastructure · Automation" in 9pt grey
     Right: Document title "**RECHNUNG**" in 28pt, weight 800, dark `#0a0a0f`.
  2. **Sender + Receiver row** — two columns, 50/50 split, 12mm top margin.
     - Left: "**Absender**" label (8pt, uppercase, letterspacing 0.1em, muted) + Sender block (name, address line 1, line 2, postal+city, country, email, VAT, IBAN — only render lines with content).
     - Right: "**Empfänger**" label + Recipient block (same shape). If `recipient is None`, render a "Empfänger nicht ausgewählt" placeholder in italic grey (preview mode only — saved invoices always have a recipient).
  3. **Invoice meta** — 3-column grid (Rechnungsnummer / Rechnungsdatum / Leistungszeitraum):
     - Number: `INV-202605-0001` (or `VORSCHAU` for un-saved preview)
     - Date: `20. Mai 2026` (via `date_de` filter)
     - Period: `1. Mai 2026 – 20. Mai 2026` or `—` if no range
  4. **Transaction table** — centered, max-width 100% of page content, dark header row:
     - Columns: `Datum | Beschreibung | Betrag (EUR)`
     - For each person line item: a subsection header `{{ item.person_name }}` (12pt, semibold), then the table of transactions, then a `Zwischensumme` row.
     - Below all items: a bold `Gesamtbetrag` row spanning the full table, right-aligned, with a thick top border.
  5. **Footer band** — single line, 8pt grey:
     - `Rechnung {{ number }} · Ausgestellt am {{ date_de(issued_date) }} · {{ sender.name }}`
     - Optional `notes` block above the footer if set, in a `Hinweise` callout (light grey background).

  **Typography:**
  - Body font: `'Inter', 'Helvetica Neue', Arial, sans-serif` — readable in PDF, no external load (Inter must be system-available or fall back). For WeasyPrint, prefer a font that's in the container (verify `fc-list` in container has `Liberation Sans` or `DejaVu Sans` as fallback).
  - Numbers + invoice number: `'JetBrains Mono', monospace` — only for monetary values and the invoice number, keeping the 922-Studio code aesthetic in the right places without making the whole document monospace.
  - All sizes in pt, all margins in mm.

  **Colors:**
  - Primary gradient stops: `#6366f1`, `#a855f7`, `#06b6d4` (header SVG only)
  - Body text: `#0a0a0f`
  - Muted/labels: `#6b7280`
  - Borders / dividers: `#e5e7eb`
  - Table header: `#0a0a0f` with white text
  - Total row background: light grey `#f3f4f6`

  **Page layout:**
  - `@page { size: A4; margin: 18mm 18mm 22mm 18mm; }`
  - `@page { @bottom-center { content: counter(page) ' / ' counter(pages); font-size: 8pt; color: #888; } }` — page numbers for multi-page invoices.

- **Context files to read**:
  - `HomeUI/src/components/ui/TerminalLogo.tsx` — gradient stop colors + IDs (copy hex values, not the React component)
  - `HomeAPI/app/templates/invoice.html.j2` — current template (for reference, then overwrite)
  - `HomeAPI/app/services/invoice_service.py` — Jinja filter registrations
- **Acceptance criteria**:
  - [ ] `app/templates/invoice.html.j2` rewritten end-to-end
  - [ ] All labels in German (Rechnung, Absender, Empfänger, Rechnungsnummer, Rechnungsdatum, Leistungszeitraum, Datum, Beschreibung, Betrag, Zwischensumme, Gesamtbetrag, Hinweise)
  - [ ] 922-Studio SVG header renders correctly in both HTML preview AND PDF (WeasyPrint supports inline SVG with gradients)
  - [ ] Visual review against the wireframe (manual: open `GET /preview?...` against lab-api-dev in browser)
  - [ ] Snapshot unit test: `test_render_html_contains_german_labels` asserts presence of `Rechnung`, `Absender`, `Empfänger`, `Gesamtbetrag` strings in the rendered HTML
  - [ ] PDF smoke test from Step 5 still passes (template change didn't break WeasyPrint)

---

### Wave 5 — HomeUI API + types extension

#### Step 10: Extend HomeUI types + API clients
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Depends on**: Steps 7, 9 (HomeAPI must be deployed to lab-api-dev for live testing — but type/client work can start in parallel against the OpenAPI spec)
- **Description**:

  **New files:**
  - `src/types/api/person.ts` — Zod schemas + inferred types for `Person`, `PersonCreate`, `PersonUpdate`
  - `src/api/persons.ts` — Axios CRUD client + TanStack Query `queryOptions` factory:
    - `personsQueryOptions.list()`, `.byId(id)`
    - `createPerson(data)`, `updatePerson(id, data)`, `deletePerson(id)`

  **Extend existing:**
  - `src/types/api/invoice.ts`:
    - Add `Invoice`, `InvoiceListItem`, `InvoiceCreateRequest` Zod schemas + types
  - `src/api/invoices.ts`:
    - Keep existing `fetchInvoicePreview`, `downloadInvoicePdf`, `downloadInvoiceXml`
    - Add `openInvoicePdfInTab(params: InvoiceQueryParams): Promise<void>` — fetch as blob, `URL.createObjectURL`, `window.open(url, '_blank', 'noopener,noreferrer')`. **Important**: `revokeObjectURL` only AFTER the new window has loaded the blob; use a `setTimeout(60_000)` cleanup. Use `URL.createObjectURL(new Blob([data], {type: 'application/pdf'}))` to be explicit about the MIME type.
    - Add `createInvoice(req: InvoiceCreateRequest): Promise<Invoice>` — POST
    - Add `fetchSavedInvoicePreview(id: string): Promise<string>` — GET `/{id}` → reconstruct HTML from snapshot? No — easier: add a `GET /{id}/html` endpoint to HomeAPI. **OR**: render preview client-side from the snapshot. Decision: extend Step 7 to add `GET /{id}/preview` returning rendered HTML from the saved snapshot, AND `GET /{id}/pdf` already returns the PDF. Mirror the computed endpoints.
    - Add `invoicesQueryOptions.list()`, `.byId(id)`
    - Add `downloadSavedInvoicePdf(id: string)` and `openSavedInvoicePdfInTab(id: string)`
- **Context files to read**:
  - `HomeUI/src/api/debts.ts` — queryOptions factory pattern
  - `HomeUI/src/api/invoices.ts` — current shape
  - `HomeUI/src/types/api/debts.ts` — Zod inferred-type pattern
- **Acceptance criteria**:
  - [ ] All new schemas + types pass `npx tsc --noEmit`
  - [ ] Unit tests in `src/api/persons.test.ts` and `src/api/invoices.test.ts` covering all new exported functions (mocked Axios)
  - [ ] Network calls verified manually against lab-api-dev: open Network tab, check that `persons[]` array serializes correctly and Bearer token is attached

  > **Action item for Step 7**: Add `GET /api/finance/invoices/{id}/preview` (HTMLResponse from snapshot) to mirror `/{id}/pdf`. Update Step 7 acceptance criteria + Step 8 tests to cover this endpoint.

---

### Wave 6 — HomeUI UI rebuild

#### Step 11: PersonPage (CRUD for receivers)
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 12
- **Depends on**: Step 10
- **Description**: New page `src/features/finance/pages/PersonPage.tsx` at route `/finance/persons` — list view with inline create/edit. Minimal but functional CRUD. Inline styles (no Tailwind spacing), JetBrains Mono labels, `var(--card)` / `var(--border)` tokens, matches `FinanceOverviewPage.tsx` conventions.

  Sections:
  - Header: "Personen" + small description
  - "Person hinzufügen" button → opens an inline form (or modal — pick one and stay consistent with rest of HomeUI; if there's no modal primitive in the codebase, use an inline expand)
  - Table: Name | Anschrift | E-Mail | USt-IdNr | Aktionen (Bearbeiten / Löschen)
  - Soft-delete confirm: native `window.confirm` is acceptable for v1

  Empty state: "Noch keine Personen — füge eine hinzu, um Rechnungen zu erstellen."

  Tests: `PersonPage.test.tsx` covering list render, create, update, delete, empty state, error display.

- **Context files to read**:
  - `HomeUI/src/features/finance/pages/FinanceOverviewPage.tsx` — inline style + table conventions
  - `HomeUI/src/api/persons.ts` — from Step 10
- **Acceptance criteria**:
  - [ ] `src/features/finance/pages/PersonPage.tsx` created + colocated `.test.tsx`
  - [ ] Renders person list from `useSuspenseQuery(personsQueryOptions.list())`
  - [ ] Create / update / delete trigger mutations + refetch
  - [ ] Tests green: `npm run test:ci -- PersonPage`
  - [ ] `npx tsc --noEmit` exits 0

#### Step 12: InvoicePage redesign — branded, German, auto-grow preview, new-tab action
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 11
- **Depends on**: Step 10
- **Description**: Rewrite `src/features/finance/pages/InvoicePage.tsx`. This is the centerpiece. The route is now `/finance/invoices/new` (the index `/finance/invoices` becomes the list — see Step 13).

  **Layout — outer container is the standard SectionLayout (which has `overflow-y: auto`). Page content stacks vertically and grows; the iframe inside grows with its content (no inner scroll).**

  Top to bottom:

  1. **Branded page header** — same gradient wordmark as the PDF template, rendered as an inline React SVG component `BrandedHeader` (new component in `src/features/finance/components/BrandedHeader.tsx`). Below the wordmark, the page title: "Neue Rechnung erstellen".
  2. **Empfänger card** — select an existing Person from a dropdown (populated from `personsQueryOptions.list()`); below the select, show the resolved Person's address block as a preview. "Person verwalten →" link to `/finance/persons`.
  3. **Leistungszeitraum card** — two `<input type="date">` fields (Von / Bis), both optional. Inline help text: "Leer lassen, um alle Buchungen einzuschließen."
  4. **Hinweise textarea** — free-form notes, rendered into the invoice footer (`notes` field).
  5. **Action bar** — sticky to the top of the form section (NOT fixed-position; just a flex row at the bottom of the form card). Five buttons:
     - **Vorschau aktualisieren** (primary) — calls `fetchInvoicePreview` with `person_id`, populates the preview iframe below
     - **PDF im neuen Tab öffnen** — calls `openInvoicePdfInTab`
     - **PDF herunterladen** — calls `downloadInvoicePdf`
     - **XML herunterladen** — calls `downloadInvoiceXml`
     - **Rechnung erstellen** (primary, right-aligned) — calls `createInvoice`, on success navigates to `/finance/invoices/<id>`
     All disabled until a person is selected. Each has its own loading state.
  6. **Preview pane** — full-width card. Header: "Vorschau" + a small badge "VORSCHAU" (matches the template's placeholder number). Body: an `<iframe srcDoc={previewHtml} sandbox="allow-same-origin">` that **auto-grows**.

  **Iframe auto-grow implementation (critical):**
  ```tsx
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const [iframeHeight, setIframeHeight] = useState<number>(0)

  function handleIframeLoad() {
    const iframe = iframeRef.current
    if (!iframe?.contentDocument) return
    const updateHeight = () => {
      const h = iframe.contentDocument!.body.scrollHeight
      setIframeHeight(h + 4)  // 4px buffer to avoid sub-pixel scrollbar
    }
    updateHeight()
    // Re-measure on dynamic content (e.g. fonts loading inside the iframe)
    const ro = new ResizeObserver(updateHeight)
    ro.observe(iframe.contentDocument.body)
    // Clean up via a ref or effect — store ro to disconnect on unmount
  }
  ```
  Iframe inline style: `{ width: '100%', height: iframeHeight || 600, border: 0, background: 'white', display: 'block' }`. **No** `overflow` styles — the iframe sizes to content.

  **Important UX**: the action bar must remain reachable as the iframe grows. Since the outer scroll container is `SectionLayout`'s div with `overflow-y: auto`, scrolling the page scrolls past the form to the preview. The form card stays where it is; the preview card below grows to its content height. No inner scrolling anywhere except the outer page.

  Tests: `InvoicePage.test.tsx` covering:
  - Empty person list → action buttons disabled + empty-state message
  - Select person → buttons enabled
  - Click "Vorschau aktualisieren" → fetch called with correct params (`person_id`, `from_date`, `to_date`)
  - Preview iframe rendered with `srcDoc`
  - Click "PDF im neuen Tab öffnen" → blob fetch + `window.open` called (mock both)
  - Click "Rechnung erstellen" → POST + navigate to `/finance/invoices/<id>` (mock `useNavigate`)
  - Error from API → inline alert (German message)

- **Context files to read**:
  - Current `HomeUI/src/features/finance/pages/InvoicePage.tsx` (on `feat/finance-invoicing-ui`) — patterns + components to keep / discard
  - `HomeUI/src/components/ui/TerminalLogo.tsx` — gradient hex values (copy into the new SVG)
  - `HomeUI/src/features/finance/pages/FinanceOverviewPage.test.tsx` — test patterns
- **Acceptance criteria**:
  - [ ] `src/features/finance/pages/InvoicePage.tsx` rewritten
  - [ ] `src/features/finance/components/BrandedHeader.tsx` created with inline SVG gradient wordmark
  - [ ] No internal iframe scrollbar — outer page scrolls
  - [ ] "PDF im neuen Tab öffnen" actually opens PDF inline in a new browser tab (manual verification on lab-api-dev)
  - [ ] All UI labels in German
  - [ ] Tests green: `npm run test:ci -- InvoicePage`
  - [ ] `npx tsc --noEmit` exits 0

#### Step 13: Invoice list + detail pages
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: —
- **Depends on**: Step 12
- **Description**: Two new pages:

  - `src/features/finance/pages/InvoiceListPage.tsx` at route `/finance/invoices` (index)
    - Table: Rechnungsnummer | Datum | Empfänger | Gesamtbetrag | Status | Aktionen
    - "+ Neue Rechnung" button → links to `/finance/invoices/new`
    - Row click → `/finance/invoices/<id>`
    - Action column: PDF herunterladen / Im neuen Tab öffnen / Stornieren (soft-delete with confirm)
    - Filter chip: status (Alle / Ausgestellt / Storniert)
  - `src/features/finance/pages/InvoiceDetailPage.tsx` at route `/finance/invoices/:id`
    - Loads `useSuspenseQuery(invoicesQueryOptions.byId(id))`
    - Reuses `BrandedHeader` component at top of page
    - Shows sender + receiver + metadata cards (read-only)
    - Embeds the saved HTML preview via iframe → `GET /api/finance/invoices/{id}/preview` (uses the same auto-grow pattern from Step 12)
    - Action bar: PDF herunterladen / Im neuen Tab öffnen / Stornieren
    - No edit — invoices are immutable once issued

  **Routing change in `src/App.tsx`** (the existing route `path: 'invoices'` element `<InvoicePage />` becomes the list; the `new` child becomes the creation page):
  ```tsx
  {
    path: 'invoices',
    children: [
      { index: true, element: <InvoiceListPage /> },
      { path: 'new', element: <InvoicePage /> },        // creation
      { path: ':id', element: <InvoiceDetailPage /> },  // detail
    ],
  }
  ```

  Update `FinanceNav.tsx`: keep one nav entry "Rechnungen" → `/finance/invoices` (the list). Add a "Personen" entry → `/finance/persons`.

- **Context files to read**:
  - `HomeUI/src/App.tsx` — existing nested-route pattern
  - `HomeUI/src/features/finance/components/FinanceNav.tsx` — nav structure
- **Acceptance criteria**:
  - [ ] List + detail pages render correctly against lab-api-dev
  - [ ] Routing works: index → list, `/new` → create, `/:id` → detail
  - [ ] Nav shows "Rechnungen" and "Personen"
  - [ ] All German labels
  - [ ] Tests for both new pages
  - [ ] `npx tsc --noEmit` + `npm run lint` exit 0

---

### Wave 7 — Local dev guide + manual smoke

#### Step 14: Local dev setup guide
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: —
- **Depends on**: Step 13 deployed to lab-api-dev
- **Description**: Add a short guide `guides/local-dev-invoice.md` (or extend `guides/agent-setup/README.md`) documenting the local-dev workflow for this feature.

  Contents:
  - Pre-req: `lab-api-dev.922-studio.com` must be reachable (it is — Cloudflare-fronted) and your user must have a valid token (login via HomeUI dev or copy from existing `lab-dev.922-studio.com` session).
  - Setup:
    ```bash
    cd /Users/gregor/dev/922/HomeUI
    cp .env.example .env.local
    # In .env.local, set: VITE_API_BASE_URL=https://lab-api-dev.922-studio.com
    npm install
    npm run dev   # serves on http://localhost:8001
    ```
  - CORS note: HomeAPI's dev origin allow-list must include `http://localhost:8001`. If not, add it under `CORS_ORIGINS` in lab-dev env (server-side change, see `HomeStructure/infra/services/home_api/.env.dev`).
  - Token bootstrapping: open `http://localhost:8001/login`, log in against lab-dev — the Bearer token gets stored in `localStorage` and used by the Axios interceptor.
  - Iterating on HomeAPI invoice changes: push to the feature branch, CI deploys to lab-api-dev (~3 min), refresh HomeUI in the browser. The dev DB (`dev_postgres:5433`, `dev_home_api`) is mirrored from prod via `HomeStructure/infra/mirror-prod-to-dev.sh`.

- **Context files to read**:
  - `orchestrator/server.md` — lab-api-dev pointer
  - `HomeStructure/infra/mirror-prod-to-dev.sh` (skim) — to reference the mirror script
- **Acceptance criteria**:
  - [ ] `orchestrator/guides/local-dev-invoice.md` created
  - [ ] CORS allow-list for `http://localhost:8001` verified or added (separate small commit to HomeStructure if needed)

#### Step 15: Manual smoke checklist
- **Project**: HomeUI + HomeAPI
- **Directory**: —
- **Parallel with**: —
- **Depends on**: Step 14 + deploys to lab-api-dev
- **Description**: Run through every flow manually against lab-api-dev. Capture screenshots in the PR description.

  Checklist (each line is a PR comment with screenshot):
  - [ ] HomeUI dev server starts on `localhost:8001`, login flows
  - [ ] `/finance/persons` lists existing persons (after seeding one)
  - [ ] Create a Person — appears in list
  - [ ] `/finance/invoices/new` page shows branded header in correct gradient
  - [ ] Select a Person — Empfänger block populates
  - [ ] Set date range
  - [ ] "Vorschau aktualisieren" — preview iframe renders; **no internal scrollbar**; outer page scrolls
  - [ ] German labels everywhere: Rechnung, Absender, Empfänger, Rechnungsnummer, Leistungszeitraum, Gesamtbetrag
  - [ ] "PDF im neuen Tab öffnen" — new browser tab shows the PDF inline
  - [ ] "PDF herunterladen" — file downloads, opens correctly in OS PDF viewer
  - [ ] "Rechnung erstellen" — POST succeeds, page navigates to `/finance/invoices/<id>`
  - [ ] Detail page shows same content, sequential number `INV-YYYYMM-####`
  - [ ] `/finance/invoices` list shows the new invoice
  - [ ] Stornieren — invoice marked cancelled, still in list with status badge
  - [ ] Visual check: PDF in PDF viewer has correct 922-Studio gradient header (SVG gradient renders in WeasyPrint)

---

### Wave 8 — Quality gates + PRs

#### Step 16: HomeAPI quality gates + PR
- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 17
- **Depends on**: Steps 1-9
- **Description**: Worktree → branch `feat/finance-invoice-overhaul` off `dev` (HomeAPI uses `dev` as the integration branch; PRs target `dev` → eventually merged to `main` via the prod-promotion flow per `HomeAPI/CLAUDE.md`).

  Commands:
  ```bash
  cd /Users/gregor/dev/922/HomeAPI
  PYTHONPATH=. pytest tests/ -x --tb=short
  ruff check app/ tests/
  mypy app/ --ignore-missing-imports
  ```

- **Acceptance criteria**:
  - [ ] All tests green
  - [ ] Coverage ≥ 70% overall
  - [ ] `ruff check` exits 0
  - [ ] `mypy` exits 0
  - [ ] Branch pushed, PR opened against `dev`, body references this plan path: `orchestrator/plans/2026-05-20-finance-invoice-overhaul.md`
  - [ ] CI pipeline green
  - [ ] PR URL reported back as clickable link
  - [ ] Worktree removed after PR URL captured (per root CLAUDE.md universal rule)

#### Step 17: HomeUI quality gates + PR
- **Project**: HomeUI
- **Directory**: `/Users/gregor/dev/922/HomeUI`
- **Parallel with**: Step 16
- **Depends on**: Steps 10-13
- **Description**: Worktree → branch `feat/finance-invoice-overhaul` off **`feat/finance-invoicing-ui`** (not `dev`, since the existing InvoicePage lives on that branch and the overhaul builds on it). After this PR merges to `feat/finance-invoicing-ui`, the parent branch can then be merged to `dev`. Alternatively, rebase onto `dev` first if `feat/finance-invoicing-ui` is too stale — make a call at execution time.

  Commands:
  ```bash
  cd /Users/gregor/dev/922/HomeUI
  npx tsc --noEmit
  npm run lint
  npm run test:ci
  ```

- **Acceptance criteria**:
  - [ ] All tests green, coverage ≥ 70% for changed files
  - [ ] `tsc --noEmit` exits 0
  - [ ] `npm run lint` exits 0
  - [ ] Branch pushed, PR opened, body references this plan
  - [ ] CI pipeline green
  - [ ] PR URL reported back as clickable link
  - [ ] Worktree removed after PR URL captured

#### Step 18: Update orchestrator state
- **Project**: orchestrator
- **Directory**: `/Users/gregor/dev/922/orchestrator`
- **Parallel with**: —
- **Depends on**: Steps 16, 17 merged
- **Description**: After both PRs merge:
  - Move this plan to `plans/archive/` with the merge date appended to the filename: `2026-MM-DD-finance-invoice-overhaul.md` (use actual merge date)
  - Update `projects/homeapi.md` and `projects/homeui.md` if any new conventions emerged (e.g. "Invoices are persisted as immutable snapshots", "Person model is the source of receiver contacts")
  - Note any HomeStructure infra changes (CORS allow-list, Dockerfile apt packages) in the relevant `HomeStructure/docs/` page

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 — HomeAPI data model + schemas (parallel within wave):
  Step 1: Person model + Alembic migration       → HomeAPI @ app/models/person.py
  Step 2: Invoice model + Alembic migration      → HomeAPI @ app/models/invoice.py
  Step 3: Person + Invoice Pydantic schemas      → HomeAPI @ app/schemas/{person,invoice}.py

Wave 2 — HomeAPI CRUD + service (parallel within wave, after Wave 1):
  Step 4: Person CRUD + router                   → HomeAPI @ app/crud/person.py + app/routers/finance/persons.py
  Step 5: Diagnose + fix PDF generation          → HomeAPI @ Dockerfile + app/services/invoice_service.py + tests
  Step 6: Invoice service refactor (sender/recipient snapshots, sequential numbers, date_de filter) → HomeAPI @ app/services/invoice_service.py

Wave 3 — HomeAPI invoice router + tests (after Wave 2):
  Step 7: Invoice router — persist endpoints + extend computed endpoints with person_id + /{id}/preview → HomeAPI @ app/routers/finance/invoices.py
  Step 8: Integration tests for Person + Invoice routers → HomeAPI @ tests/integration/routers/finance/

Wave 4 — HomeAPI template overhaul (can overlap with Wave 3 if Step 6 done):
  Step 9: Replace invoice.html.j2 with German + 922-Studio branding → HomeAPI @ app/templates/invoice.html.j2

(Wave 4.5 — deploy HomeAPI to lab-api-dev so HomeUI can integrate against real endpoints)

Wave 5 — HomeUI API + types (after Step 7 OpenAPI is published; can begin in parallel with Wave 4):
  Step 10: Extend types + API clients (persons, invoices.{create,list,byId,openInTab,savedPdf,savedPreview}) → HomeUI @ src/types/api/, src/api/

Wave 6 — HomeUI UI rebuild (parallel within wave, after Wave 5):
  Step 11: PersonPage CRUD                        → HomeUI @ src/features/finance/pages/PersonPage.tsx
  Step 12: InvoicePage redesign (branded, German, auto-grow preview, new-tab) → HomeUI @ src/features/finance/pages/InvoicePage.tsx
  Step 13: Invoice list + detail pages + route restructure + nav update → HomeUI @ src/features/finance/pages/Invoice{List,Detail}Page.tsx + App.tsx + FinanceNav.tsx

Wave 7 — Local dev + smoke (after Wave 6):
  Step 14: Local dev guide                        → orchestrator @ guides/local-dev-invoice.md
  Step 15: Manual smoke checklist on lab-api-dev  → HomeUI + HomeAPI

Wave 8 — Quality gates + PRs (parallel within wave, after Wave 7):
  Step 16: HomeAPI quality gates + PR             → HomeAPI
  Step 17: HomeUI quality gates + PR              → HomeUI
  Step 18: Update orchestrator state              → orchestrator (after both PRs merge)
```

---

## Post-Execution Checklist

### Functional
- [ ] `/finance/persons` allows full CRUD of receiver contacts
- [ ] `/finance/invoices/new` shows a 922-Studio-branded form with German labels
- [ ] Selecting a Person populates the Empfänger preview
- [ ] "Vorschau aktualisieren" renders the invoice inline; iframe auto-grows; outer page scrolls
- [ ] "PDF im neuen Tab öffnen" opens the PDF inline in a new browser tab
- [ ] "PDF herunterladen" downloads a working PDF (open in macOS Preview without errors)
- [ ] "Rechnung erstellen" persists the invoice; sequential number assigned; navigates to detail
- [ ] `/finance/invoices` lists saved invoices with status filter
- [ ] `/finance/invoices/<id>` shows immutable invoice detail
- [ ] Stornieren soft-deletes (cancelled status)
- [ ] Multi-tenancy: cross-org isolation verified for persons + invoices

### Quality
- [ ] HomeAPI: pytest green, ruff clean, mypy clean, coverage ≥ 70%
- [ ] HomeUI: tsc clean, eslint clean, vitest green, coverage ≥ 70%
- [ ] WeasyPrint PDF smoke test runs against real WeasyPrint in CI (not mocked)
- [ ] No regressions in existing finance endpoints (ledger, debt summary)

### Deployment + Docs
- [ ] Both PRs (HomeAPI + HomeUI) merged
- [ ] Lab-api-dev deploy green; manual smoke checklist completed
- [ ] CORS allow-list updated for `http://localhost:8001` (if it wasn't already)
- [ ] Orchestrator plan archived with merge date
- [ ] `projects/homeapi.md` + `projects/homeui.md` updated with any new conventions
- [ ] German-only is documented as v1 constraint; locale toggle filed as a follow-up plan

### Out of scope (filed as follow-ups, NOT in this plan)
- Locale toggle (DE ↔ EN switch for invoice template + UI)
- Email-send-invoice flow (Resend integration — schema and service hooks left in place for future)
- ZUGFeRD / e-invoicing XML compliance (current XML stays custom)
- Invoice editing (current spec: immutable once issued; edits require cancel + reissue)
- Recurring invoices / templates
- Tax / VAT calculation (current spec: line items are sums of debt amounts; no tax breakdown row)
