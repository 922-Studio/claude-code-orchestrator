# Executor Prompt — Step 1: Dynamic GitHub Org Repo Discovery

## Role
You are a Technical Executor Agent. Implement this step precisely, following all project conventions.

## Project
**HomeCollector** — `/Users/gregor/dev/922/HomeCollector`

## Mandatory reads before touching any code
1. `/Users/gregor/dev/922/Planner/projects/homecollector.md` — architecture, best practices, testing strategy
2. `/Users/gregor/dev/922/HomeCollector/CLAUDE.md` — project conventions
3. `/Users/gregor/dev/922/HomeCollector/app/services/github_service.py` — full file (current hardcoded MONITORED_REPOS)
4. `/Users/gregor/dev/922/HomeCollector/app/routers/github.py` — endpoint wiring
5. `/Users/gregor/dev/922/HomeCollector/config.py` — GITHUB_ORG, GITHUB_TOKEN env vars

Read all tests under `tests/` that relate to github to understand the existing test structure before writing new ones:
```
tests/unit/services/test_github_service.py   (if it exists)
tests/integration/routers/test_github.py     (if it exists)
```

---

## What to implement

### Goal
Remove the hardcoded `MONITORED_REPOS` list from `github_service.py`. Replace it with a dynamic lookup that fetches all repos in the configured GitHub org via the GitHub REST API. New repos added to the org automatically appear in monitoring — no code change required.

### Current state
`github_service.py` has a module-level constant:
```python
MONITORED_REPOS = [
    "HomeAPI", "HomeAuth", "HomeUI", "HomeStructure",
    "discord", "portfolio", "sweatvalley_bingo",
]
```
This list is iterated in `get_workflow_runs`, `get_paginated_runs`, `get_workflow_stats`, and `get_workflow_analytics` to fan out parallel requests across repos.

### Changes to `app/services/github_service.py`

**1. Remove `MONITORED_REPOS` constant** (the module-level list).

**2. Add in-process cache fields** to `GitHubService.__init__`:
```python
self._repos_cache: list[str] = []
self._repos_cache_expiry: datetime | None = None
self._repos_cache_ttl: int = 600  # 10 minutes
```

**3. Add private method `_get_org_repos`**:
```python
async def _get_org_repos(self, client: httpx.AsyncClient) -> list[str]:
    """Fetch all repo names in the configured org, with 10-min in-process cache."""
    now = datetime.now(tz=UTC)
    if self._repos_cache and self._repos_cache_expiry and now < self._repos_cache_expiry:
        return self._repos_cache

    repos: list[str] = []
    page = 1
    while True:
        url = f"https://api.github.com/orgs/{self.org}/repos"
        params = {"per_page": 100, "page": page, "type": "all", "sort": "updated"}
        resp = await client.get(url, params=params)
        if resp.status_code != 200:
            logger.warning("Failed to fetch org repos (status %s), using cache", resp.status_code)
            return self._repos_cache  # fall back to previous cache if available
        data = resp.json()
        if not data:
            break
        repos.extend(item["name"] for item in data)
        if len(data) < 100:
            break
        page += 1

    self._repos_cache = repos
    self._repos_cache_expiry = now + timedelta(seconds=self._repos_cache_ttl)
    return repos
```

**4. Replace `MONITORED_REPOS` usages** in every method that fan-outs:
- `get_workflow_runs`: replace `for repo in MONITORED_REPOS` with `repos = await self._get_org_repos(client)`, then `for repo in repos`
- `get_paginated_runs`: same pattern
- `get_workflow_stats`: same pattern
- `get_workflow_analytics`: same pattern

The client is always opened as `async with httpx.AsyncClient(...) as client:` in each method — pass `client` to `_get_org_repos`.

**5. `get_commit_activity` does NOT use `MONITORED_REPOS`** — leave it unchanged.

**6. Error fallback**: if the API call fails AND cache is empty, log a warning and return an empty list. Callers will return empty results gracefully.

### Tests

Update existing GitHub service unit tests (mock `_get_org_repos` instead of `MONITORED_REPOS`). At minimum:
- Test that `_get_org_repos` returns cached results on second call without making another HTTP request
- Test that cache expires after TTL and re-fetches
- Test that all methods that previously used `MONITORED_REPOS` now call `_get_org_repos`
- Test pagination: if first page returns 100 items, second page is fetched

Integration tests: mock the `GET /orgs/{org}/repos` endpoint and verify the full endpoint still works.

---

## Run tests
```bash
cd /Users/gregor/dev/922/HomeCollector
PYTHONPATH=. pytest tests/ -v --cov=app --cov-fail-under=70
```
Fix any failures before reporting done.

## Commit & Push
```bash
git add app/services/github_service.py tests/
git commit -m "feat(github): dynamic org repo discovery with 10-min cache

Removes hardcoded MONITORED_REPOS list. GitHub org repos are now fetched
dynamically via GET /orgs/{org}/repos with in-process caching (TTL 10m).
New repos in 922-Studio org appear in monitoring automatically."
git push origin main
```

## Report format
```
=== STEP 1 COMPLETE ===
Plan: plans/2026-03-19-monitoring-dashboard-improvements.md
Step: 1 - Dynamic GitHub Org Repo Discovery
Status: done / blocked / partial
Changes: [files modified]
Tests: pass / fail (details)
Notes: [anything important]
```
