# Plan: Anime-API & Anime-APP Infrastructure Setup

**Date**: 2026-03-21
**Status**: pending
**Goal**: Onboard Anime-API and Anime-APP into the home lab ecosystem — full CI/CD pipeline (templated workflows), Allure test reporting, Traefik routing, server deployment on push to main.

---

## Context

Read before executing:
- `Planner/server.md` — ports, networks, container naming
- `Planner/projects/anime-api.md` — project mapping (created in this plan)
- `Planner/projects/anime-app.md` — project mapping (created in this plan)
- `/Users/gregor/dev/922/HomeContent/docker-compose.yaml` — reference for Traefik labels (no auth middleware pattern)
- `/Users/gregor/dev/922/HomeContent/deploy.sh` — reference deploy script
- `/Users/gregor/dev/922/HomeContent/.github/workflows/deploy.yml` — reference CI workflow
- `/Users/gregor/dev/922/HomeUI/.github/workflows/deploy.yml` — reference frontend CI workflow

## Port & Container Assignments

| Resource | Value |
|---|---|
| Anime-API app port (host) | **8020** |
| Anime-API PostgreSQL port (host, 127.0.0.1) | **5435** |
| Anime-APP port (host) | **8021** |
| Anime-API app container | `anime_api` |
| Anime-API DB container | `anime_api_db` |
| Anime-APP container | `anime_app` |
| Anime-API Docker network (internal) | `anime_api_net` (bridge, internal to compose) |
| Anime-API Traefik router | `anime-api` |
| Anime-APP Traefik router | `anime-app` |
| Anime-API Allure project ID | `anime-api` |
| Anime-APP Allure project ID | `anime-app` |

---

## Steps

### Step 1: Anime-API — Infrastructure Files
**Project**: Anime-API
**Directory**: `/Users/gregor/dev/922/Anime-API`
**Parallel with**: Step 4 (Anime-APP infra)

Create the following files:

#### `docker-compose.yaml`
```yaml
services:
  db:
    image: postgres:16-alpine
    container_name: anime_api_db
    environment:
      POSTGRES_USER: ${DB_USER:-anime_api}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME:-anime_api}
    ports:
      - "127.0.0.1:5435:5432"
    volumes:
      - anime_api_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-anime_api}"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped
    networks:
      - anime_api_net

  api:
    build:
      context: .
      dockerfile: dockerfile
    container_name: anime_api
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql://${DB_USER:-anime_api}:${DB_PASSWORD}@db:5432/${DB_NAME:-anime_api}
    ports:
      - "${API_PORT:-8020}:8020"
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8020/health', timeout=4)"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - proxy
      - anime_api_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.anime-api.rule=Host(`anime-api.922-studio.com`)"
      - "traefik.http.routers.anime-api.entrypoints=web"
      - "traefik.http.services.anime-api.loadbalancer.server.port=8020"

networks:
  proxy:
    external: true
  anime_api_net:

volumes:
  anime_api_db_data:
```

#### `docker-compose.ci.yaml`
Override for smoke tests — isolated container with own DB:
```yaml
services:
  db:
    image: postgres:16-alpine
    container_name: ci_anime_api_db
    environment:
      POSTGRES_USER: anime_api
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: anime_api
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U anime_api"]
      interval: 5s
      timeout: 3s
      retries: 5

  api:
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://anime_api:postgres@db:5432/anime_api
    networks: !override []
    labels: !override []
```

#### `deploy.sh`
Copy pattern from `/Users/gregor/dev/922/HomeContent/deploy.sh`, change:
- `cd ~/HomeContent` → `cd ~/Anime-API`

Make executable: `chmod +x deploy.sh`

#### `.env.example`
```
DB_USER=anime_api
DB_PASSWORD=changeme
DB_NAME=anime_api
API_PORT=8020
```

---

### Step 2: Anime-API — Code Updates
**Project**: Anime-API
**Directory**: `/Users/gregor/dev/922/Anime-API`
**Runs after**: Step 1 (parallel possible but cleaner sequential)

#### 2a. Update `main.py`
Replace the hardcoded SQLite setup with environment-based PostgreSQL:

- Replace:
  ```python
  SQLALCHEMY_DATABASE_URL = "sqlite:///./anime.db"
  engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
  ```
  With:
  ```python
  import os
  SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./anime.db")
  engine = create_engine(SQLALCHEMY_DATABASE_URL)
  ```
  (Remove `check_same_thread` — it's SQLite-only)

- Add `/health` endpoint after the `get_db()` function:
  ```python
  @app.get("/health")
  def health():
      return {"status": "ok"}
  ```

- Change the Gunicorn bind port in `dockerfile` CMD to `0.0.0.0:8020`

#### 2b. Update `dockerfile`
- Change Python version: `python:3.11-slim` → `python:3.13-slim`
- Change CMD bind port: `--bind 0.0.0.0:8000` → `--bind 0.0.0.0:8020`

#### 2c. Update `requirements.txt`
- Add `psycopg2-binary` (sync PostgreSQL driver)
- Fix the broken line: `python-dotenvgunicorn` → `python-dotenv` + `gunicorn` on separate lines

---

### Step 3: Anime-API — Test Scaffold
**Project**: Anime-API
**Directory**: `/Users/gregor/dev/922/Anime-API`
**Runs after**: Step 2

The python-tests workflow requires a working pytest setup. Create a minimal test scaffold so CI passes.

#### `requirements-test.txt`
```
pytest
pytest-cov
allure-pytest
httpx
```

#### `tests/__init__.py`
Empty file.

#### `tests/test_health.py`
```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

#### `pytest.ini`
```ini
[pytest]
testpaths = tests
```

Note: `coverage_fail_under` in the workflow is set to `0` initially. Tests will grow separately.

---

### Step 4: Anime-APP — Infrastructure Files
**Project**: Anime-APP
**Directory**: `/Users/gregor/dev/922/Anime-APP`
**Parallel with**: Steps 1-3 (Anime-API)

#### `docker-compose.yaml`
```yaml
services:
  app:
    build:
      context: .
      dockerfile: dockerfile
    container_name: anime_app
    ports:
      - "${APP_PORT:-8021}:80"
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.anime-app.rule=Host(`anime.922-studio.com`)"
      - "traefik.http.routers.anime-app.entrypoints=web"
      - "traefik.http.services.anime-app.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
```

#### `deploy.sh`
Copy pattern from `/Users/gregor/dev/922/HomeContent/deploy.sh`, change:
- `cd ~/HomeContent` → `cd ~/Anime-APP`
- Remove `docker builder prune -f` step is optional but good to keep

Make executable: `chmod +x deploy.sh`

#### `.env.example`
```
APP_PORT=8021
```

---

### Step 5: Anime-APP — Test Scaffold
**Project**: Anime-APP
**Directory**: `/Users/gregor/dev/922/Anime-APP`
**Runs after**: Step 4

The frontend-tests workflow requires `npm run test:coverage`. Add Vitest with minimal config.

#### Update `package.json`
Add to `devDependencies`:
```json
"@testing-library/jest-dom": "^6.x",
"@testing-library/react": "^16.x",
"@testing-library/user-event": "^14.x",
"@vitest/coverage-v8": "^3.x",
"jsdom": "^26.x",
"vitest": "^3.x"
```
Add to `scripts`:
```json
"test": "vitest",
"test:coverage": "vitest run --coverage"
```

#### Update `vite.config.js` (or create `vite.config.ts`)
Add test config block:
```js
test: {
  environment: 'jsdom',
  globals: true,
  setupFiles: './src/test-setup.js',
  coverage: {
    provider: 'v8',
    reporter: ['text', 'json'],
    reportsDirectory: 'reports/coverage',
  },
},
```

#### `src/test-setup.js`
```js
import '@testing-library/jest-dom';
```

#### `src/App.test.jsx`
Minimal smoke test:
```jsx
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import App from './App';

describe('App', () => {
  it('renders without crashing', () => {
    const { container } = render(<App />);
    expect(container).toBeTruthy();
  });
});
```

Note: `coverage_fail_under` in workflow set to `0` initially.

---

### Step 6: Anime-API — GitHub Workflow
**Project**: Anime-API
**Directory**: `/Users/gregor/dev/922/Anime-API`
**Runs after**: Step 3

Create `.github/workflows/deploy.yml`:

```yaml
name: Anime API Deploy

permissions:
  contents: write
  actions: write
  issues: write

on:
  push:
    branches:
      - main
    paths-ignore:
      - '.planning/**'
  workflow_dispatch:

jobs:
  cancel-previous-runs:
    uses: 922-Studio/workflows/.github/workflows/cancel-previous-runs.yml@main

  version:
    needs: cancel-previous-runs
    if: ${{ always() }}
    uses: 922-Studio/workflows/.github/workflows/versioning.yml@main
    with:
      use_ai: false
    secrets: inherit

  lint:
    needs: version
    name: Lint (ruff + mypy)
    uses: 922-Studio/workflows/.github/workflows/python-lint.yml@main
    with:
      python_version: '3.13'
      install_command: 'pip install ruff mypy pydantic -q'
      ruff_format_check: true

  tests:
    needs: [version, lint]
    name: Run tests (pytest + coverage + Allure)
    uses: 922-Studio/workflows/.github/workflows/python-tests.yml@main
    with:
      python_version: '3.13'
      install_command: 'pip install -r requirements.txt -r requirements-test.txt'
      coverage_package: '.'
      coverage_fail_under: 0
      allure_results_dir: 'reports/allure'
      allure_server_url: 'http://home-lab:5050'
      allure_project_id: 'anime-api'
      allure_launch_name: '${{ github.workflow }} #${{ github.run_number }}'
      pushgateway_url: 'http://home-lab:9091'
      env_file_source: '/home/lab/Anime-API/.env'
      api_base_url: 'http://localhost:8020'
      github_owner: '922-Studio'
      github_repo: 'Anime-API'
      database_url: 'postgresql://anime_api:postgres@localhost:5432/anime_api'
    secrets:
      ALLURE_TOKEN: ${{ secrets.ALLURE_TOKEN }}
      GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
      GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
      DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  smoke-test:
    name: Smoke test (isolated containers)
    needs: version
    uses: 922-Studio/workflows/.github/workflows/smoke-test.yml@main
    with:
      repository_path: '/home/lab/Anime-API'
      expected_services: 'api,db'
      healthcheck_endpoints: '{"api":"8020:/health"}'
      pull_code: true
      env_file_source: '/home/lab/Anime-API/.env'
    secrets:
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  create-issue:
    needs: [tests, smoke-test]
    if: failure()
    uses: 922-Studio/workflows/.github/workflows/create-issue.yml@main
    with:
      job_name: 'tests / smoke-test'
      workflow_status: 'failure'
      repository_name: '${{ github.repository }}'
      branch_name: '${{ github.ref_name }}'
      run_number: '${{ github.run_number }}'
      run_url: '${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}'
      run_id: '${{ github.run_id }}'
      triggering_actor: '${{ github.actor }}'
    secrets:
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  deploy:
    name: Deploy backend Docker services
    needs: [tests, smoke-test]
    uses: 922-Studio/workflows/.github/workflows/deploy-docker.yml@main
    with:
      repository_path: '/home/lab/Anime-API'
      boot_script: 'deploy.sh'
      pull_code: false
    secrets:
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  notify-success:
    needs: [version, tests, smoke-test, deploy]
    if: ${{ !failure() && !cancelled() }}
    uses: 922-Studio/workflows/.github/workflows/send-notification.yml@main
    with:
      recipients: '["gregor160505+home-lab@gmail.com"]'
      subject: "✅ Anime API version ${{ needs.version.outputs.new_version }} deployed"
      workflow_status: "success"
      workflow_name: "${{ github.workflow }}"
      repository_name: "${{ github.repository }}"
      run_url: "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
      enable_email: false
      enable_discord: true
    secrets:
      GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
      DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  notify-failure:
    needs: [version, tests, smoke-test, deploy, create-issue]
    if: failure()
    uses: 922-Studio/workflows/.github/workflows/send-notification.yml@main
    with:
      recipients: '["gregor160505+home-lab@gmail.com"]'
      subject: "❌ Anime API workflow failure: ${{ github.workflow }}"
      workflow_status: "failure"
      workflow_name: "${{ github.workflow }}"
      repository_name: "${{ github.repository }}"
      run_url: "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
      enable_email: false
      enable_discord: true
      issue_url: '${{ needs.create-issue.outputs.issue_url }}'
    secrets:
      GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
      DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}
```

---

### Step 7: Anime-APP — GitHub Workflow
**Project**: Anime-APP
**Directory**: `/Users/gregor/dev/922/Anime-APP`
**Runs after**: Step 5
**Parallel with**: Step 6

Create `.github/workflows/deploy.yml`:

```yaml
name: Anime APP Deploy

permissions:
  contents: write
  actions: write
  issues: write

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  cancel-previous-runs:
    uses: 922-Studio/workflows/.github/workflows/cancel-previous-runs.yml@main

  version:
    name: Create new version
    needs: cancel-previous-runs
    uses: 922-Studio/workflows/.github/workflows/versioning.yml@main
    with:
      use_ai: false
    secrets: inherit

  tests:
    name: Run unit tests (Vitest + Allure)
    needs: version
    uses: 922-Studio/workflows/.github/workflows/frontend-tests.yml@main
    with:
      node_version: '20.x'
      install_command: 'npm ci'
      test_command: 'npm run test:coverage'
      build_command: 'npm run build'
      run_build: true
      allure_results_dir: 'reports/allure'
      allure_server_url: 'http://home-lab:5050'
      allure_project_id: 'anime-app'
      allure_launch_name: 'Anime APP Unit Tests'
      coverage_fail_under: 0
      pushgateway_url: 'http://home-lab:9091'
      env_file_source: '/home/lab/Anime-APP/.env'
    secrets:
      GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
      DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  smoke:
    name: Pre-deploy smoke test (isolated)
    needs: tests
    uses: 922-Studio/workflows/.github/workflows/smoke-test.yml@main
    with:
      repository_path: '/home/lab/Anime-APP'
      expected_services: 'app'
      healthcheck_endpoints: '{"app":"8021:/"}'
      max_retries: 24
      retry_delay_seconds: 5
      env_file_source: '/home/lab/Anime-APP/.env'
    secrets:
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  deploy:
    name: Deploy frontend Docker service
    needs: smoke
    uses: 922-Studio/workflows/.github/workflows/deploy-docker.yml@main
    with:
      repository_path: '/home/lab/Anime-APP'
      docker_compose_file: 'docker-compose.yaml'
      service_name: 'app'
      boot_script: 'deploy.sh'
    secrets:
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  create-issue:
    needs: [tests, smoke, deploy]
    if: failure()
    uses: 922-Studio/workflows/.github/workflows/create-issue.yml@main
    with:
      job_name: 'tests / smoke / deploy'
      workflow_status: 'failure'
      repository_name: '${{ github.repository }}'
      branch_name: '${{ github.ref_name }}'
      run_number: '${{ github.run_number }}'
      run_url: '${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}'
      run_id: '${{ github.run_id }}'
      triggering_actor: '${{ github.actor }}'
    secrets:
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  notify-success:
    needs: [version, smoke, deploy]
    if: success()
    uses: 922-Studio/workflows/.github/workflows/send-notification.yml@main
    with:
      recipients: '["gregor160505+home-lab@gmail.com"]'
      subject: '✅ Anime APP version ${{ needs.version.outputs.new_version }} deployed'
      workflow_status: 'success'
      workflow_name: '${{ github.workflow }}'
      repository_name: '${{ github.repository }}'
      run_url: '${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}'
      enable_email: false
      enable_discord: true
    secrets:
      GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
      DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}

  notify-failure:
    needs: [tests, version, smoke, deploy, create-issue]
    if: failure()
    uses: 922-Studio/workflows/.github/workflows/send-notification.yml@main
    with:
      recipients: '["gregor160505+home-lab@gmail.com"]'
      subject: '❌ Anime APP workflow failure: ${{ github.workflow }}'
      workflow_status: 'failure'
      workflow_name: '${{ github.workflow }}'
      repository_name: '${{ github.repository }}'
      run_url: '${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}'
      enable_email: false
      enable_discord: true
      issue_url: '${{ needs.create-issue.outputs.issue_url }}'
    secrets:
      GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
      DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
      PAT_GITHUB: ${{ secrets.PAT_GITHUB }}
```

---

### Step 8: HomeStructure — Cloudflare Tunnel
**Project**: HomeStructure
**Directory**: `/Users/gregor/dev/922/HomeStructure`
**Parallel with**: Steps 6 & 7

Add both new public routes to the Cloudflare Tunnel configuration.

Read `HomeStructure/docs/config/cloudflare.md` for exact file location and format.

Add the following ingress rules (before the catch-all):
```yaml
- hostname: anime-api.922-studio.com
  service: http://localhost:80   # Traefik

- hostname: anime.922-studio.com
  service: http://localhost:80   # Traefik
```

Commit and push — cloudflared restarts automatically via CI/CD or `homelab-ctl.sh`.

---

### Step 9: GitHub Secrets — Both Repos
**Runs after**: Steps 6 & 7 (repos must have workflows committed)
**Parallel with**: Step 8

Copy all secrets from `922-Studio/HomeAPI` to both new repos.

Required secrets:
- `ALLURE_TOKEN`
- `GEMINI_API_KEY`
- `GMAIL_APP_PASSWORD`
- `DISCORD_BOT_TOKEN`
- `PAT_GITHUB`

Use `gh secret set` for each secret in each repo:
```bash
# List source values first (redacted in output, use --json body approach or manual)
gh secret list --repo 922-Studio/HomeAPI

# Copy to Anime-API
for secret in ALLURE_TOKEN GEMINI_API_KEY GMAIL_APP_PASSWORD DISCORD_BOT_TOKEN PAT_GITHUB; do
  value=$(gh secret list --repo 922-Studio/HomeAPI --json name,updatedAt | ...)
  # Fetch value from vault / copy manually
done
```

**Note**: `gh secret list` does not expose values. Values must be copied manually or from a secrets manager. Read `HomeStructure/docs/` for how secrets are managed in this ecosystem, or fetch from the `.env` files on the server (which contain the actual values).

Practical approach:
1. `ssh lab` → read `/home/lab/HomeAPI/.env`
2. Extract the relevant secret values
3. Set via `gh secret set SECRET_NAME --body "value" --repo 922-Studio/Anime-API`
4. Repeat for `922-Studio/Anime-APP`

---

### Step 10: Server — Clone Repos & .env Files
**Runs after**: Steps 6 & 7 (code must be pushed)

On the server (`ssh lab`):

```bash
# Clone both repos
cd ~
git clone git@github.com:922-Studio/Anime-API.git
git clone git@github.com:922-Studio/Anime-APP.git

# Create .env for Anime-API
cat > ~/Anime-API/.env << 'EOF'
DB_USER=anime_api
DB_PASSWORD=<secure-password>
DB_NAME=anime_api
API_PORT=8020
EOF

# Create .env for Anime-APP
cat > ~/Anime-APP/.env << 'EOF'
APP_PORT=8021
EOF
```

Then run first deployment:
```bash
cd ~/Anime-API && ./deploy.sh
cd ~/Anime-APP && ./deploy.sh
```

Verify:
- `curl http://localhost:8020/health` → `{"status":"ok"}`
- `curl http://localhost:8021/` → 200 (HTML)

---

### Step 11: Planner — Registry & Documentation
**Parallel with**: any step
**Creates**:
- `Planner/projects/anime-api.md`
- `Planner/projects/anime-app.md`
- Update `Planner/registry.md` (add entries #11 and #12)
- Update `Planner/server.md` (add ports, routes, containers)

Content for these files is specified in the project mapping files created as part of this plan.

---

## Dependency Graph

```
Steps 1+2+3 (Anime-API infra+code+tests)   ─┐
                                              ├─► Step 6 (Anime-API workflow) ─┐
Steps 4+5   (Anime-APP infra+tests)         ─┘                                 │
                                              ├─► Step 7 (Anime-APP workflow)  ─┼─► Step 9 (Secrets)
Step 8 (Cloudflare) runs parallel with 6+7  ─┘                                 │
Step 10 (Server clone) after 6+7            ──────────────────────────────────► Step 10
Step 11 (Planner docs) anytime
```

## Quality Gates

- [ ] `curl http://localhost:8020/health` returns `{"status":"ok"}` on server
- [ ] `curl http://localhost:8021/` returns 200 on server
- [ ] `anime-api.922-studio.com` resolves via Cloudflare
- [ ] `anime.922-studio.com` resolves via Cloudflare
- [ ] First GitHub Actions run completes green (both repos)
- [ ] Allure results appear at `http://home-lab:5050` for projects `anime-api` and `anime-app`
- [ ] Discord notification received on successful deploy

## Notes

- `coverage_fail_under: 0` is intentional — tests will be expanded in a separate plan
- Anime-API uses **sync** SQLAlchemy (not async) — kept as-is to avoid full refactor
- The `psycopg2-binary` driver is required for sync PostgreSQL with SQLAlchemy
- `anime.db` (SQLite file) can be deleted from repo after PostgreSQL migration confirmed working
- The `bot.py` and Discord-related dependencies in Anime-API appear to be legacy code — leave as-is for now
- `package.json` / `package-lock.json` in Anime-API are likely stale artifacts — leave as-is
