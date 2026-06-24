# Handover — HomeAuth `/auth/verify` returns 500 (should be 401) on a malformed `sub`

> Paste the fenced block into a fresh Claude Code session launched from `/Users/gregor/dev/922`.
> Self-contained. Small, well-scoped robustness fix to the cluster-wide forward-auth endpoint.

---

```
MISSION
Fix HomeAuth's /auth/verify endpoint so that a token whose `sub` claim is not a valid UUID
(or otherwise can't resolve to a user) returns HTTP 401 Unauthorized — NOT an uncaught 500.
Deliver via the standard worktree -> PR -> dev workflow.

WHY THIS MATTERS
/auth/verify is the endpoint Traefik's shared forward-auth middleware (`auth-verify@file`,
address http://homeauth:8000/auth/verify) calls for EVERY authenticated request across the
whole cluster (dev + prod). When the auth server returns 5xx, Traefik returns a generic 500
to the client instead of a clean 401, so a malformed/garbage token surfaces as a confusing
"Internal Server Error" gateway-wide. Auth failures must be 401, not 500.

ROOT CAUSE (confirmed 2026-06-24)
In HomeAuth `app/routes/auth.py`, the `verify` endpoint (around line 511) does roughly:
    select(User).options(selectinload(User.roles)).where(User.id == uuid.UUID(sub))
`sub` is taken from the decoded JWT. `uuid.UUID(sub)` raises
`ValueError: badly formed hexadecimal UUID string` when `sub` is not a UUID. The ValueError
is uncaught, so FastAPI returns 500. (Discovered because a diagnostic token minted with
sub="diag" produced a 500; a real user token with a UUID sub returns 200.)

REPRODUCE (on antares; lightweight, safe)
  # mint a token with a non-UUID sub using the prod homeauth's JWT secret
  ssh aa 'JWT=$(docker exec homeauth python3 -c "import jwt,time;from config import JWT_SECRET;print(jwt.encode({\"sub\":\"not-a-uuid\",\"jti\":\"x\",\"type\":\"access\",\"exp\":int(time.time())+120},JWT_SECRET,algorithm=\"HS256\"))"); \
    docker exec traefik wget -S -q -O /dev/null --header="Authorization: Bearer $JWT" http://homeauth:8000/auth/verify 2>&1 | grep HTTP'
  # EXPECT today: 500 Internal Server Error. AFTER FIX: 401.
  # Sanity (must stay 200): mint a token whose sub is a real users.id from shared_postgres:
  #   ssh aa 'docker exec shared_postgres psql -U home_auth -d home_auth -tAc "select id from users limit 1;"'

CONTEXT — READ FIRST
- /Users/gregor/dev/922/HomeAuth/app/routes/auth.py  (the `verify` endpoint; grep for `uuid.UUID(sub)`)
- /Users/gregor/dev/922/HomeAuth/app/auth.py and wherever the JWT is decoded / `sub` extracted
  (the cleanest fix may live in the shared token-decode dependency, not only in verify)
- /Users/gregor/dev/922/HomeAuth/CLAUDE.md  (repo conventions)
- server.md (cluster), memory project_cicd_deploy_target_migration (deploy now via CI, not Watchtower)

FIX APPROACH
1. Parse `sub` defensively: wrap `uuid.UUID(sub)` in try/except ValueError (also handle
   sub being None/empty / wrong type) and raise HTTPException(status_code=401, detail="...").
   Prefer fixing this in the shared place that turns a decoded token into a user lookup so
   ALL endpoints (not just verify) are covered — check whether other routes do the same cast.
2. Also confirm the "valid UUID but no such user" path returns 401 (not 500 / not 200) — a
   token for a deleted user must be rejected.
3. Keep the success path unchanged (valid UUID + existing user -> 200 with the
   X-User-* response headers the forward-auth middleware forwards).

TESTS (required — behavior change)
- Add/extend unit tests for /auth/verify: (a) non-UUID sub -> 401, (b) well-formed UUID but
  unknown user -> 401, (c) valid user -> 200 with expected headers. Run in single-run mode
  (pytest, not watch). HomeAuth uses the python-tests reusable in CI.

DEPLOY NOTE
HomeAuth now deploys via CI (deploy-docker reusable, registry-pull, deploy_target=antares) on
push to dev/prod — Watchtower has been retired. Merging to dev auto-deploys dev_homeauth; a
prod rollout needs a push to prod. Verify the reproduce command returns 401 after the dev
deploy lands.

GUARDRAILS
- Do NOT run heavy/batch jobs on antares (16GB, runs all prod) — keep diagnostics lightweight.
- This endpoint gates ALL authenticated traffic cluster-wide; do not change the success-path
  contract or the X-User-* response headers. Smallest reversible change.
- Worktree on a feat/ branch off `dev`; PR into `dev`; English; no Co-Authored-By; remove the
  worktree after capturing the PR URL.

DEFINITION OF DONE
- /auth/verify returns 401 (not 500) for non-UUID sub and for unknown-user; 200 unchanged for
  valid users. Tests added and green. PR opened against dev (URL reported). Reproduce command
  confirmed returning 401 after the dev deploy.
```
