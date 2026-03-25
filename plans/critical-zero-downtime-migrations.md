# Plan: Zero-Downtime Database Migrations Strategy

- **Date**: CRITICAL — no fixed date, implement before first breaking migration
- **Project(s)**: All projects using Docker Registry + Watchtower deployment
- **Goal**: Ensure database migrations never break running containers during rolling deployments.

## Context

Read these files before proceeding:
- `projects/drafter.md` — Drafter project mapping (pilot project)
- `server.md` — server infrastructure reference
- Prisma migration docs: https://www.prisma.io/docs/orm/prisma-migrate/workflows

## The Problem

With Watchtower-based deployments:
1. CI pushes new image to registry
2. Watchtower detects new image digest (polling interval ~30s)
3. Watchtower pulls new image, stops old container, starts new one
4. There is a window where old code is still running

If a migration drops/renames a column, old containers crash during this window.

## Solution: Expand-and-Contract Pattern

Every migration must be split into two categories:

### Safe Migrations (Single Deploy)
These are backward-compatible and can run at container startup:
- Adding new tables
- Adding new columns (with defaults or nullable)
- Adding new indexes
- Inserting seed data

**Flow:**
```
CI: build image → push to registry
Watchtower: pull → start new container
Container entrypoint: prisma migrate deploy (advisory lock)
Health check passes → old container replaced
```

### Breaking Migrations (Two-Phase Deploy)
These require two separate deployments:

**Phase 1 — Expand:**
- Add new column/table alongside the old one
- Update code to write to BOTH old and new
- Deploy (safe, old containers still work)

**Phase 2 — Contract (separate PR, separate deploy):**
- Verify all containers run Phase 1 code
- Remove old column/table
- Update code to only use new schema
- Deploy

**Example — Renaming `user_name` to `display_name`:**

Phase 1 migration:
```sql
ALTER TABLE users ADD COLUMN display_name TEXT;
UPDATE users SET display_name = user_name WHERE display_name IS NULL;
-- Code writes to BOTH user_name AND display_name
-- Code reads from display_name, falls back to user_name
```

Phase 2 migration (separate deploy):
```sql
ALTER TABLE users DROP COLUMN user_name;
-- Code only uses display_name
```

## Implementation for Drafter (Prisma)

### Container Entrypoint Script

Create `entrypoint.sh` in Drafter:
```bash
#!/bin/sh
set -e

echo "Running database migrations..."
npx prisma migrate deploy

echo "Starting application..."
exec node server.js
```

Prisma's `migrate deploy`:
- Acquires a PostgreSQL advisory lock (concurrent-safe)
- Applies only pending migrations
- Is idempotent (safe to run multiple times)
- Fails fast if a migration errors (container won't start, health check fails, Watchtower keeps old container)

### Dockerfile Change

```dockerfile
# In the runtime stage
COPY --from=build /app/prisma ./prisma
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
```

### Health Check Behavior

The health check (`/api/health`) only responds AFTER:
1. Migrations complete successfully
2. Server starts listening on port 3000

If migrations fail → server never starts → health check never passes → Watchtower keeps old container running.

## Rollback Strategy

If a migration causes issues:

1. **Safe migration rollback**: Push previous image version back to the mutable tag
   ```bash
   docker tag registry.922-studio.com/drafter:dev-v1.1.0 registry.922-studio.com/drafter:dev
   docker push registry.922-studio.com/drafter:dev
   ```
   Watchtower picks up the old image. Prisma won't run rollback automatically — you must create a new "down" migration.

2. **Breaking migration rollback**: If Phase 2 was deployed and needs rollback, you still have old columns from Phase 1. Revert code to Phase 1, push image.

## CI Workflow Integration

The CI pipeline should:
1. Build image (includes Prisma schema + migrations)
2. Smoke test (spins up isolated DB, runs `prisma migrate deploy`, verifies health)
3. Run tests
4. Push image to registry
5. Watchtower handles deployment
6. Container entrypoint runs migrations on real DB

**No CI step should run migrations against prod/dev databases directly.**

## Checklist Before Every Migration PR

- [ ] Is this migration backward-compatible? (Can old code work with new schema?)
- [ ] If not: split into Expand + Contract phases
- [ ] Does the smoke test cover this migration? (isolated DB in CI)
- [ ] Has the migration been tested with `prisma migrate deploy` (not `prisma migrate dev`)?
- [ ] Is there a rollback plan documented in the PR?

## References

- Prisma deploy: https://www.prisma.io/docs/orm/prisma-migrate/workflows/deploy
- Expand-and-contract: https://www.prisma.io/dataguide/types/relational/expand-and-contract-pattern
- Advisory locks: PostgreSQL `pg_advisory_lock` (Prisma handles this automatically)
