# Executor Prompt — Step 2: Update Uptime Service Groups + Migration

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeCollector** — `/Users/gregor/dev/922/HomeCollector`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homecollector.md` — architecture, best practices
2. `/Users/gregor/dev/922/HomeCollector/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeCollector/config.py` — full file (DEFAULT_MONITORED_SERVICES definition)
4. `/Users/gregor/dev/922/HomeCollector/app/models/service_config.py` — ServiceConfig model (group field)
5. `/Users/gregor/dev/922/HomeCollector/alembic/env.py` — migration environment setup
6. Look at `alembic/versions/` directory — read the most recent migration to understand naming conventions

---

## What to implement

### Goal
Change the service groups so the Uptime page can show monitors under three clear categories:
- **Pages** — public-facing web UIs
- **Services** — internal APIs and bots
- **Infrastructure** — databases, proxies, monitoring stack

### New group assignments

| service_name | display_name | New group |
|---|---|---|
| portfolio | Portfolio | Pages |
| homeui | HomeUI | Pages |
| sweatvalley-bingo | Sweatvalley Bingo | Pages |
| home_api_api | HomeAPI | Services |
| homeauth | HomeAuth | Services |
| home_collector_api | HomeCollector | Services |
| discord_bot | Discord Bot | Services |
| shared_postgres | PostgreSQL | Infrastructure |
| shared_redis | Redis | Infrastructure |
| traefik | Traefik | Infrastructure |
| prometheus | Prometheus | Infrastructure |
| grafana | Grafana | Infrastructure |

### Change 1: `config.py` — update DEFAULT_MONITORED_SERVICES

Update each entry's `"group"` field to match the table above. The current groups are "Core Services", "Apps", "Infrastructure". Replace them with "Pages", "Services", "Infrastructure" as per the table.

Example diff for one entry:
```python
# Before:
{"service_name": "home_api_api", "display_name": "HomeAPI", "group": "Core Services", ...}
# After:
{"service_name": "home_api_api", "display_name": "HomeAPI", "group": "Services", ...}
```

### Change 2: Alembic migration

The seeding logic uses upsert-on-name and does NOT overwrite existing records (for existing live DB rows, the group won't change from the seed). A migration is needed to update the live database.

Create a new migration:
```bash
cd /Users/gregor/dev/922/HomeCollector
alembic revision -m "update_service_groups_pages_services_infrastructure"
```

In the generated migration file, implement `upgrade()` and `downgrade()`:

```python
from alembic import op

# Group mapping: service_name -> new group
_NEW_GROUPS = {
    "portfolio": "Pages",
    "homeui": "Pages",
    "sweatvalley-bingo": "Pages",
    "home_api_api": "Services",
    "homeauth": "Services",
    "home_collector_api": "Services",
    "discord_bot": "Services",
    "shared_postgres": "Infrastructure",
    "shared_redis": "Infrastructure",
    "traefik": "Infrastructure",
    "prometheus": "Infrastructure",
    "grafana": "Infrastructure",
}

# Old groups for downgrade
_OLD_GROUPS = {
    "portfolio": "Apps",
    "homeui": "Core Services",
    "sweatvalley-bingo": "Apps",
    "home_api_api": "Core Services",
    "homeauth": "Core Services",
    "home_collector_api": "Core Services",
    "discord_bot": "Apps",
    "shared_postgres": "Infrastructure",
    "shared_redis": "Infrastructure",
    "traefik": "Infrastructure",
    "prometheus": "Infrastructure",
    "grafana": "Infrastructure",
}


def upgrade() -> None:
    conn = op.get_bind()
    for service_name, new_group in _NEW_GROUPS.items():
        conn.execute(
            op.inline_literal(
                f"UPDATE service_configs SET \"group\" = '{new_group}' WHERE service_name = '{service_name}'"
            )
        )
    # Use parameterized queries instead — safer:
    for service_name, new_group in _NEW_GROUPS.items():
        conn.execute(
            text("UPDATE service_configs SET \"group\" = :group WHERE service_name = :name"),
            {"group": new_group, "name": service_name},
        )


def downgrade() -> None:
    conn = op.get_bind()
    for service_name, old_group in _OLD_GROUPS.items():
        conn.execute(
            text("UPDATE service_configs SET \"group\" = :group WHERE service_name = :name"),
            {"group": old_group, "name": service_name},
        )
```

Use `from sqlalchemy import text` at the top of the migration file. Do NOT use inline literal string interpolation for SQL — use parameterized queries.

Check how existing migrations are structured (read the latest one in `alembic/versions/`) and follow the same pattern exactly.

### Verify migration works locally
```bash
cd /Users/gregor/dev/922/HomeCollector
# Apply the migration against the local test DB if available
alembic upgrade head
# Check it can roll back
alembic downgrade -1
# Apply again
alembic upgrade head
```

### Tests

Check if there are existing uptime/service_config tests. Update or add tests that verify:
- `DEFAULT_MONITORED_SERVICES` has the correct group values for each service
- The migration file is importable (basic smoke test)

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeCollector
PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70
```

## Commit & Push
```bash
git add config.py alembic/versions/
git commit -m "feat(uptime): update service groups to Pages/Services/Infrastructure

Updates DEFAULT_MONITORED_SERVICES and adds Alembic migration to reclassify
monitored services into three groups: Pages (public UIs), Services (APIs/bots),
Infrastructure (databases, proxy, monitoring stack)."
git push origin main
```

## Report format
```
=== STEP 2 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 2 - Update Uptime Service Groups
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [migration file path, any migration issues]
```
