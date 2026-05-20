# Plan: HomeAPI — Finance Invoicing Feature

- Date: 2026-05-19
- Project(s): HomeAPI
- Goal: Add on-demand invoice generation (PDF, HTML preview, XML) to the finance module, based on existing DebtTransaction data for one or multiple persons.

## Context

Read these files before proceeding:

- `orchestrator/projects/homeapi.md` — tech stack, best practices, test patterns
- `HomeAPI/CLAUDE.md` — architecture rules, naming conventions, new-module checklist
- `HomeAPI/.claude/HOW-TO-PYTEST-TEST.md` — AsyncMock patterns, Allure decorators, factory patterns
- `HomeAPI/app/routers/finance/ledger.py` — existing finance router (patterns to follow)
- `HomeAPI/app/models/debt_transaction.py` — DebtTransaction model (source of invoice data)
- `HomeAPI/app/crud/debt.py` — existing CRUD (get_debt_summary, get_debt_person_history to reuse)
- `HomeAPI/app/schemas/debt.py` — existing schemas (DebtSummary, DebtPersonHistoryResponse)
- `HomeAPI/app/models/settings.py` — Settings singleton (source of issuer/org data)
- `HomeAPI/app/services/resend_service.py` — email send pattern (for future invoice email step)
- `HomeAPI/app/main.py` — router registration (how sub-package routers are included)
- `HomeAPI/tests/integration/routers/finance/test_ledger.py` — integration test patterns to mirror
- `HomeAPI/tests/conftest.py` — shared fixtures (client, mock_db_session)

## Design Decisions

### No new database model (v1)

Invoices are generated on-demand from existing `DebtTransaction` rows. No `Invoice` table is created in v1. This keeps scope tight and avoids migration complexity. A future v2 can add an `Invoice` model for audit history and email tracking if needed.

### Issuer data from Settings singleton

The Settings model stores a JSON `data` document. Org/issuer fields (`org_name`, `org_address`, `org_email`, `org_iban`, `org_vat`) are read from `settings.data` at render time. If a key is missing, the template renders a placeholder. No new config model needed.

### WeasyPrint for PDF

WeasyPrint renders HTML+CSS → PDF. This means the Jinja2 HTML template is the single source of truth for both the HTML preview and the PDF output — zero duplication. WeasyPrint requires no headless browser.

### XML format

Simple custom XML (not ZUGFeRD) for v1. Structure mirrors the HTML template fields. ZUGFeRD compatibility can be added later if needed.

### Query parameters (not path params) for person selection

Endpoints use `persons: list[str]` query params so one URL can address multiple debtors. Date range filters (`from_date`, `to_date`) are optional and delegate to the existing `get_debt_summary` CRUD.

### Endpoints

| Method | Path | Response | Description |
|--------|------|----------|-------------|
| GET | `/api/finance/invoices/preview` | `text/html` | Rendered HTML invoice |
| GET | `/api/finance/invoices/pdf` | `application/pdf` | PDF download |
| GET | `/api/finance/invoices/xml` | `application/xml` | XML export |

All three accept the same query params: `persons[]` (required, repeatable), `from_date` (optional), `to_date` (optional).

---

## Steps

### Step 1: Add Dependencies

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Description**: Add `weasyprint` and `lxml` to `requirements-api.txt`. Verify `Jinja2` is already present (it is, from prior email work); if not, add it. Do NOT install — the CI pipeline handles that on deploy. Confirm the versions are pinned.
- **Acceptance criteria**:
  - [ ] `weasyprint>=62.0` added to `requirements-api.txt`
  - [ ] `lxml>=5.0` added to `requirements-api.txt`
  - [ ] `Jinja2>=3.0` present (add only if missing)
  - [ ] No unpinned (`>=`) versions that would conflict with existing deps

---

### Step 2: Invoice Schemas

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 3, Step 4
- **Description**: Create `app/schemas/invoice.py`. Define request and response schemas following Pydantic V2 conventions (`ConfigDict(from_attributes=True)`). No DB model exists, so these are pure data-transfer schemas.

**Schemas to create:**

```
InvoiceLineItem      — person_name, total_amount (Decimal), transaction_count (int),
                       transactions: list[InvoiceTransactionRow]
InvoiceTransactionRow — date, description, amount (Decimal)
InvoiceRequest       — persons: list[str], from_date: date | None, to_date: date | None
InvoiceData          — invoice_number (str, auto-generated), issued_date (date),
                       issuer: InvoiceIssuer, line_items: list[InvoiceLineItem],
                       total_amount (Decimal), currency (str, default "EUR")
InvoiceIssuer        — name, address, email, iban, vat_id (all str | None)
```

- **Acceptance criteria**:
  - [ ] `app/schemas/invoice.py` created
  - [ ] All schemas use Pydantic V2 (`ConfigDict`, not `class Config`)
  - [ ] `Decimal` used for all monetary fields (never `float`)
  - [ ] Unit test `tests/unit/schemas/test_invoice.py` written covering valid construction, optional field defaults, and Decimal precision

---

### Step 3: Invoice Service

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 2, Step 4
- **Description**: Create `app/services/invoice_service.py`. This is the core rendering layer — no DB access, pure transformation + rendering.

**Functions to implement:**

```python
def build_invoice_data(
    summaries: list[DebtSummary],
    histories: dict[str, list],   # person → transaction rows
    settings_data: dict,          # from Settings.data
    from_date: date | None,
    to_date: date | None,
) -> InvoiceData
    # Assembles InvoiceData from CRUD results + settings
    # Generates invoice_number as "INV-{YYYYMMDD}-{short_uuid}"
    # Reads org_name, org_address, org_email, org_iban, org_vat from settings_data
    # Falls back to None for missing keys

def render_html(invoice: InvoiceData) -> str
    # Renders app/templates/invoice.html.j2 with Jinja2
    # Returns raw HTML string

def render_pdf(invoice: InvoiceData) -> bytes
    # Calls render_html(), passes to WeasyPrint HTML(string=html).write_pdf()
    # Returns raw PDF bytes

def render_xml(invoice: InvoiceData) -> str
    # Builds XML string using lxml.etree
    # Root: <Invoice>, children: <Issuer>, <LineItems> with <LineItem> per person
    # Returns UTF-8 XML string
```

- **Acceptance criteria**:
  - [ ] `app/services/invoice_service.py` created with all four functions
  - [ ] No DB imports — service is pure/stateless
  - [ ] `render_html` uses Jinja2 `Environment(loader=FileSystemLoader("app/templates"))`
  - [ ] `render_pdf` uses WeasyPrint (imported with `from weasyprint import HTML`)
  - [ ] `render_xml` uses `lxml.etree` (not `xml.etree.ElementTree`)
  - [ ] Unit tests in `tests/unit/services/test_invoice_service.py` covering:
    - [ ] `build_invoice_data` assembles correct `InvoiceData` from mock summaries + settings
    - [ ] `build_invoice_data` falls back gracefully when settings keys are missing
    - [ ] `render_html` returns a string containing key invoice fields
    - [ ] `render_pdf` returns non-empty bytes (mock WeasyPrint in unit test)
    - [ ] `render_xml` returns valid XML with expected element names
    - [ ] Invoice number format matches `INV-{YYYYMMDD}-{uuid_prefix}`

---

### Step 4: Jinja2 Invoice Template

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: Step 2, Step 3
- **Description**: Create `app/templates/invoice.html.j2` — a clean, print-ready HTML invoice template. Must render correctly in WeasyPrint (CSS must be inline or embedded, no external CDN links which WeasyPrint cannot resolve).

**Template structure:**
```
Header: 922-Studio logo/name (from invoice.issuer.name), address, email, VAT, IBAN
Invoice meta: Invoice number, issue date, date range (if filtered)
Line items table: Person | Transactions | Total owed
  Per-person sub-rows: Date | Description | Amount
Grand total row
Footer: "This invoice was generated automatically."
```

**Styling constraints:**
- All CSS embedded in `<style>` tag (no external stylesheets)
- Print-safe: avoid fixed widths that break PDF page layout
- Use `@page` CSS rule for PDF page margins
- Currency formatted as `{{ amount | format_currency }}` via Jinja2 custom filter (defined in service)

- **Acceptance criteria**:
  - [ ] `app/templates/` directory created
  - [ ] `app/templates/invoice.html.j2` created with all sections above
  - [ ] Template renders without error when `render_html` is called with a minimal `InvoiceData` fixture
  - [ ] All CSS is inline/embedded (no `<link>` to external URLs)
  - [ ] `@page` CSS rule present for PDF margins

---

### Step 5: Invoice Router

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (depends on Steps 2, 3, 4)
- **Description**: Create `app/routers/finance/invoices.py`. Three endpoints, all `GET`. Each endpoint:
  1. Validates `persons` is non-empty
  2. Fetches `DebtSummary` per person via `crud.get_debt_summary` filtered by person (existing CRUD)
  3. Fetches transaction history per person via `crud.get_debt_person_history` (existing CRUD)
  4. Reads `Settings` singleton from DB to get issuer data
  5. Calls `invoice_service.build_invoice_data()`
  6. Calls the appropriate render function
  7. Returns appropriate `Response` with correct media type and headers

**Endpoint signatures:**

```python
GET /preview
  Query: persons: list[str] = Query(..., min_length=1)
         from_date: date | None = Query(None)
         to_date: date | None = Query(None)
  Returns: HTMLResponse

GET /pdf
  Query: same as above
  Returns: Response(content=bytes, media_type="application/pdf",
             headers={"Content-Disposition": "attachment; filename=invoice-{date}.pdf"})

GET /xml
  Query: same as above
  Returns: Response(content=str, media_type="application/xml",
             headers={"Content-Disposition": "attachment; filename=invoice-{date}.xml"})
```

- **HTTP status**: `200 OK` for all three; `400` if `persons` is empty; `404` if no transactions found for any requested person.
- **Auth**: standard `org_id` from `get_org_id(request)` — same pattern as `ledger.py`

- **Acceptance criteria**:
  - [ ] `app/routers/finance/invoices.py` created with all three endpoints
  - [ ] 400 returned when `persons` list is empty
  - [ ] 404 returned when no debt transactions found for the requested persons
  - [ ] Correct `Content-Disposition` header on PDF and XML responses
  - [ ] `org_id` used in all DB queries (multi-tenancy)
  - [ ] No business logic in router — all delegated to service layer

---

### Step 6: Register Router in main.py

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (depends on Step 5)
- **Description**: Add the invoice router to `app/main.py` following the existing sub-package pattern for finance routers.

**Change to make:**

```python
# Existing (keep):
from app.routers.finance import ledger

# Add:
from app.routers.finance import invoices

# Existing (keep):
app.include_router(ledger.router, prefix="/api/finance/ledger", tags=["finance"])

# Add:
app.include_router(invoices.router, prefix="/api/finance/invoices", tags=["finance"])
```

- **Acceptance criteria**:
  - [ ] Import added for `invoices` module
  - [ ] `include_router` call added with correct prefix and tag
  - [ ] `GET /api/finance/invoices/preview`, `/pdf`, `/xml` appear in `/docs` (OpenAPI)
  - [ ] App starts without import errors (`uvicorn app.main:app --reload` smoke test)

---

### Step 7: Integration Tests — Invoice Router

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: — (depends on Step 6)
- **Description**: Create `tests/integration/routers/finance/test_invoices.py`. Mirror the patterns in `tests/integration/routers/finance/test_ledger.py`: use `TestClient` from `conftest.py`, mock CRUD and service calls, use Allure decorators.

**Test cases to cover:**

```
Preview endpoint (GET /api/finance/invoices/preview):
  - 200 with persons=["Alice"] returns HTML response with Content-Type text/html
  - 200 with multiple persons returns HTML containing all person names
  - 400 when persons param is empty/missing
  - 404 when CRUD returns no transactions for requested persons
  - Date range params are forwarded to CRUD layer (assert mock called with correct dates)
  - Org ID is extracted and passed to CRUD (multi-tenancy)

PDF endpoint (GET /api/finance/invoices/pdf):
  - 200 returns application/pdf content type
  - 200 returns Content-Disposition: attachment header with filename
  - 404 when no transactions found
  - Service render_pdf is called (mock and assert)

XML endpoint (GET /api/finance/invoices/xml):
  - 200 returns application/xml content type
  - 200 returns Content-Disposition: attachment header with filename
  - 404 when no transactions found
  - Service render_xml is called (mock and assert)

Error paths:
  - Settings DB read failure is handled gracefully (falls back to None issuer fields)
  - WeasyPrint/render failure returns 500
```

**Mocking strategy:**
- Mock `app.crud.debt.get_debt_summary` (AsyncMock)
- Mock `app.crud.debt.get_debt_person_history` (AsyncMock)
- Mock `app.services.invoice_service.render_html/render_pdf/render_xml` (MagicMock)
- Mock Settings DB read (AsyncMock returning Settings instance with preset `data`)

- **Acceptance criteria**:
  - [ ] `tests/integration/routers/finance/test_invoices.py` created
  - [ ] All test cases listed above implemented
  - [ ] All tests use Allure decorators (`@allure.feature("Finance")`, `@allure.story("Invoicing")`)
  - [ ] All tests pass: `PYTHONPATH=. pytest tests/integration/routers/finance/test_invoices.py -v`
  - [ ] Coverage ≥ 70% for `app/routers/finance/invoices.py` and `app/services/invoice_service.py`

---

### Step 8: Full Test Suite Pass + Lint

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI`
- **Parallel with**: —
- **Description**: Run full test suite, lint, and type check. Fix any regressions introduced by the new router/imports.

**Commands to run:**

```bash
PYTHONPATH=. pytest tests/ -x -q --tb=short
ruff check app/ tests/
mypy app/ --ignore-missing-imports
```

- **Acceptance criteria**:
  - [ ] All existing tests still pass (no regressions)
  - [ ] New tests pass (Steps 2, 3, 7 output)
  - [ ] Coverage ≥ 70% overall
  - [ ] `ruff check` exits 0
  - [ ] `mypy` exits 0 (no new type errors)

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 — Dependencies (sequential prerequisite):
  Step 1: Add weasyprint + lxml to requirements-api.txt

Wave 2 — Parallel design + scaffolding (after Step 1):
  Step 2: Invoice schemas          (app/schemas/invoice.py)
  Step 3: Invoice service          (app/services/invoice_service.py)
  Step 4: Jinja2 HTML template     (app/templates/invoice.html.j2)

Wave 3 — Router (after Wave 2):
  Step 5: Invoice router           (app/routers/finance/invoices.py)

Wave 4 — Registration (after Step 5):
  Step 6: Register in main.py

Wave 5 — Integration tests + quality gates (after Step 6):
  Step 7: Integration tests        (tests/integration/routers/finance/test_invoices.py)
  Step 8: Full suite + lint        (pytest + ruff + mypy)
```

---

## Post-Execution Checklist

- [ ] `GET /api/finance/invoices/preview?persons[]=Alice` returns styled HTML
- [ ] `GET /api/finance/invoices/pdf?persons[]=Alice&persons[]=Bob` returns a downloadable PDF
- [ ] `GET /api/finance/invoices/xml?persons[]=Alice` returns valid XML
- [ ] 400 returned for missing/empty `persons` param
- [ ] 404 returned for unknown person name
- [ ] Issuer block in invoice populated from Settings (or empty if not configured)
- [ ] All tests pass with `PYTHONPATH=. pytest tests/ -x -q`
- [ ] `ruff check` and `mypy` exit clean
- [ ] Router appears in `/docs` OpenAPI UI under the "finance" tag
- [ ] PR opened against `main` with plan reference in body
- [ ] CI pipeline green (lint → smoke → tests → deploy)
