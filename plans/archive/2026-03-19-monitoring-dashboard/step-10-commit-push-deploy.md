# Executor Prompt — Step 10: Commit, Push & Deploy

## Role
You are a Technical Executor Agent. This is the final step — validate everything, push both projects, and apply the database migration.

## Projects
- **HomeCollector** — `/Users/gregor/dev/922/HomeCollector`
- **HomeUI** — `/Users/gregor/dev/922/HomeUI`

## Mandatory reads before starting
1. `/Users/gregor/dev/922/Planner/projects/homecollector.md` — pipeline and deployment steps
2. `/Users/gregor/dev/922/Planner/projects/homeui.md` — pipeline and deployment steps
3. `/Users/gregor/dev/922/Planner/server.md` — server access and key commands

---

## Prerequisites check

Before pushing, confirm all previous steps are complete:
- [ ] Step 1 committed in HomeCollector (dynamic GitHub repos)
- [ ] Step 2 committed in HomeCollector (service groups migration)
- [ ] Steps 3–9 committed in HomeUI (all dashboard improvements)

Run a final `git log --oneline -10` in each project to verify all commits are present.

---

## HomeCollector — test, push, migrate

### 1. Run full test suite
```bash
cd /Users/gregor/dev/922/HomeCollector
PYTHONPATH=. pytest tests/ -v --cov=app --cov-report=term-missing --cov-fail-under=70
```
**Stop here if tests fail.** Fix the failure before pushing.

### 2. Check git status
```bash
git status
git log --oneline -5
```
Verify only expected files are modified/staged and all step commits are present.

### 3. Push
```bash
git push origin main
```

### 4. Monitor CI pipeline
Check the GitHub Actions pipeline for the HomeCollector repo (at `github.com/922-Studio/HomeCollector/actions`). Wait for the pipeline to complete.

Expected pipeline stages: `cancel-previous → version → lint → tests → smoke-test → deploy → notify`

The Discord notification will confirm deploy success.

### 5. Apply Alembic migration on the server
After the deploy completes (container is running the new code), apply the migration:
```bash
ssh lab
cd ~/HomeCollector
docker compose exec api alembic upgrade head
```

Verify the migration ran:
```bash
docker compose exec api alembic current
```
Should show the latest migration as the current head.

Spot-check the DB:
```bash
docker compose exec api python -c "
import asyncio
from app.core.database import AsyncSessionLocal
from app.models.service_config import ServiceConfig
from sqlalchemy import select

async def check():
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(ServiceConfig.service_name, ServiceConfig.group))
        for row in result:
            print(row)

asyncio.run(check())
"
```
Verify group values match the expected Pages/Services/Infrastructure assignments.

---

## HomeUI — test, push

### 1. Run full test suite
```bash
cd /Users/gregor/dev/922/HomeUI
npm run test:ci
```
**Stop here if tests fail.** Fix the failure before pushing.

### 2. Check git status
```bash
git status
git log --oneline -10
```
Verify all step commits (3–9) are present.

### 3. Push
```bash
git push origin main
```

### 4. Monitor CI pipeline
Check `github.com/922-Studio/HomeUI/actions`. Wait for all stages to complete.

Expected stages: `cancel-previous → version → tests (70%) → e2e → smoke-test → deploy → notify`

Discord notification confirms deploy success.

---

## Post-deploy verification

Once both pipelines are green, do a quick visual sanity check against the live dashboard at `https://lab.922-studio.com`:

| Check | Expected |
|-------|----------|
| Overview — Network I/O panel | Title "Network I/O" inside the card border |
| Overview — Disk Space panel | Title inside the card border |
| Overview — Docker containers | Sorted by CPU descending |
| Overview — TEST HEALTH pill | Shows both pass rate and coverage % |
| Test Results — stat cards | Coverage card first, shows adoption % (e.g. 50%) |
| Test Results — All Projects chart | Left = oldest, right = newest |
| Test Results — per-project charts | Cyan dashed reference line for coverage |
| GitHub Actions — Commits/Month | Shows commit count (not workflow run count) |
| Usage page — stat cards | "Net RX" and "Net TX" total cards; no "Net↓"/"Net↑" |
| Uptime page — width | Full screen width, no maxWidth cap |
| Uptime page — service grouping | "Pages", "Services", "Infrastructure" section headers |
| Uptime page — 7d range | Heartbeat bar shows 7 segments, not 90 |
| Uptime page — group names | Portfolio/HomeUI/Sweatvalley under Pages; HomeAPI/HomeAuth/HomeCollector/Discord under Services |

---

## Report format
```
=== STEP 10 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 10 - Commit, Push, Deploy
Status: done / blocked / partial
HomeCollector pipeline: green / red
HomeUI pipeline: green / red
Migration: applied / failed (details)
Visual checks: all pass / issues found (list)
Notes: [any issues encountered]
```
