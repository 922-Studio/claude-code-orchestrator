# Neue Services einrichten — Vollständige Anleitung

Diese Anleitung beschreibt Schritt für Schritt, wie ein neuer Microservice in die 922-Studio HomeLab-Infrastruktur integriert wird.

---

## Voraussetzungen

- Zugriff auf den Server: `ssh lab`
- Shared Infra läuft: `shared_postgres`, `shared_redis`, `traefik`
- Docker Networks existieren: `proxy`, `infra`

---

## Schnellstart mit homelab-ctl

```bash
ssh lab
~/HomeStructure/scripts/homelab-ctl.sh new-service
```

Das interaktive Tool fragt nach Service-Name, Port, ob Celery/Redis benötigt wird, und generiert alle Dateien automatisch. Details zu jedem Schritt findest du unten.

---

## Schritt 1: Datenbank anlegen

### Option A: Mit homelab-ctl (empfohlen)

```bash
ssh lab
~/HomeStructure/scripts/homelab-ctl.sh db:create <service_name>
```

Das generiert ein sicheres Passwort, erstellt User + Datenbank und gibt dir die Connection-Details.

### Option B: Manuell

```bash
# Passwort generieren
openssl rand -hex 16
# → z.B. a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6

# User + DB erstellen
ssh lab "docker exec -i shared_postgres psql -U admin -d postgres" <<EOF
CREATE USER new_service WITH PASSWORD 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6';
CREATE DATABASE new_service OWNER new_service;
EOF

# Verifizieren
ssh lab "docker exec shared_postgres psql -U admin -d postgres -c '\l'" | grep new_service
```

---

## Schritt 2: Redis DB-Nummer reservieren (falls Celery benötigt)

Aktuelle Belegung:

| DB Nr | Service        | Verwendung            |
|-------|----------------|-----------------------|
| 0     | HomeAPI        | Celery Broker+Backend |
| 1     | HomeCollector  | Celery Broker+Backend |
| 2     | (reserviert)   | Shared Cache          |
| 3     | HomeContent    | Celery Broker+Backend |
| 4-15  | *verfügbar*    | Nächsten freien nehmen |

Wähle die nächste freie Nummer (z.B. DB 3) und trage sie in die Tabelle oben ein.

---

## Schritt 3: `.env` erstellen

```env
# === Datenbank (shared postgres) ===
DB_USER=new_service
DB_PASSWORD=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
DB_NAME=new_service
DATABASE_URL=postgresql+asyncpg://new_service:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6@shared_postgres:5432/new_service

# === Celery (falls benötigt) ===
CELERY_BROKER_URL=redis://shared_redis:6379/3
CELERY_RESULT_BACKEND=redis://shared_redis:6379/3
CELERY_TIMEZONE=Europe/Berlin

# === Auth (falls API-Endpunkte geschützt) ===
JWT_SECRET=<gleicher Secret wie andere Services>

# === Service-spezifisch ===
API_PORT=8XXX
```

> **Lokale Entwicklung (ohne Docker):** Die `DATABASE_URL` muss `localhost` statt `shared_postgres` verwenden, da der Container-DNS-Name nur innerhalb von Docker funktioniert.

---

## Schritt 4: `docker-compose.yaml` erstellen

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: new_service_api
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql+asyncpg://${DB_USER:-new_service}:${DB_PASSWORD}@shared_postgres:5432/${DB_NAME:-new_service}
    ports:
      - "${API_PORT:-8XXX}:8XXX"
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8XXX/health', timeout=4)"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - proxy
      - infra
    labels:
      - "traefik.enable=true"
      # Hauptroute (mit Auth-Middleware)
      - "traefik.http.routers.new-service.rule=Host(`new-service.922-studio.com`)"
      - "traefik.http.routers.new-service.entrypoints=web"
      - "traefik.http.routers.new-service.middlewares=auth-verify@file"
      - "traefik.http.services.new-service.loadbalancer.server.port=8XXX"
      # Public-Endpunkte (ohne Auth, höhere Priorität)
      - "traefik.http.routers.new-service-public.rule=Host(`new-service.922-studio.com`) && (Path(`/health`) || Path(`/version`) || Path(`/docs`) || PathPrefix(`/docs/`) || Path(`/openapi.json`))"
      - "traefik.http.routers.new-service-public.entrypoints=web"
      - "traefik.http.routers.new-service-public.priority=200"
      - "traefik.http.routers.new-service-public.service=new-service"

  # === Worker (nur falls Celery benötigt) ===
  worker:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: new_service_worker
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql+asyncpg://${DB_USER:-new_service}:${DB_PASSWORD}@shared_postgres:5432/${DB_NAME:-new_service}
      PYTHONPATH: /app
    command: celery -A app.celery_app.celery_app worker -l info
    restart: unless-stopped
    networks:
      - infra

  # === Beat (nur falls Celery-Scheduled-Tasks benötigt) ===
  beat:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: new_service_beat
    env_file:
      - .env
    environment:
      DATABASE_URL: postgresql+asyncpg://${DB_USER:-new_service}:${DB_PASSWORD}@shared_postgres:5432/${DB_NAME:-new_service}
      PYTHONPATH: /app
    command: celery -A app.celery_app.celery_app beat -l info
    restart: unless-stopped
    networks:
      - infra

networks:
  proxy:
    external: true
  infra:
    external: true
```

### Wichtige Regeln für Traefik-Labels

1. **Ein Service pro Container** — definiere nur EINEN `traefik.http.services.<name>.loadbalancer`
2. **Zusätzliche Router referenzieren den Haupt-Service** — z.B. `traefik.http.routers.new-service-public.service=new-service`
3. **Priorität setzen** — spezifischere Router (Public-Pfade) brauchen `priority=200` oder höher
4. **Auth-Middleware** — `auth-verify@file` verweist auf die ForwardAuth-Config in `HomeStructure/traefik/dynamic/middleware.yaml`

### Netzwerk-Zuordnung

| Container braucht... | Networks |
|----------------------|----------|
| Web-Traffic (Traefik) + Datenbank | `proxy` + `infra` |
| Nur Datenbank/Redis (Worker, Beat, Bot) | `infra` |
| Nur Web (statisches Frontend) | `proxy` |

---

## Schritt 5: `docker-compose.ci.yaml` erstellen

Diese Override-Datei stellt isolierte DB + Redis für CI bereit — keine Abhängigkeit auf shared Infra.

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: new_service
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:7-alpine

  api:
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      DATABASE_URL: postgresql+asyncpg://postgres:postgres@db:5432/new_service
      CELERY_BROKER_URL: redis://redis:6379/0
      CELERY_RESULT_BACKEND: redis://redis:6379/0
    networks: []
    labels: []

  worker:
    environment:
      DATABASE_URL: postgresql+asyncpg://postgres:postgres@db:5432/new_service
      CELERY_BROKER_URL: redis://redis:6379/0
      CELERY_RESULT_BACKEND: redis://redis:6379/0
    networks: []
```

**Verwendung in CI:**
```bash
docker compose -f docker-compose.yaml -f docker-compose.ci.yaml up -d
```

---

## Schritt 6: Alembic konfigurieren

```bash
# Im Service-Verzeichnis:
pip install alembic
alembic init alembic

# alembic.ini anpassen:
sqlalchemy.url = postgresql+asyncpg://new_service:<password>@localhost:5432/new_service

# alembic/env.py: target_metadata auf dein SQLAlchemy Base.metadata setzen

# Initiale Migration:
alembic revision --autogenerate -m "initial"
alembic upgrade head
```

---

## Schritt 7: Health- und Version-Endpunkte implementieren

Jeder Service braucht einen `/health`- und `/version`-Endpunkt für:
- Docker Healthcheck (`/health`)
- HomeCollector Uptime-Monitoring (`/health`)
- Traefik-Public-Route (ohne Auth)
- Zentrales Versioning (`/version`)

```python
# FastAPI Beispiel:
from importlib.metadata import version as pkg_version

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/version")
async def version():
    return {
        "service": "new-service",
        "version": pkg_version("new-service"),  # oder aus __version__ / env
    }
```

> **Wichtig:** Beide Endpunkte sind in den Traefik-Public-Labels bereits enthalten (Schritt 4) und erfordern keine Authentifizierung.

---

## Schritt 8: Cloudflare Tunnel konfigurieren (falls extern erreichbar)

Falls der Service über `new-service.922-studio.com` erreichbar sein soll:

1. Cloudflare Dashboard → Zero Trust → Tunnels → `home-lab`
2. Neue Public Hostname hinzufügen:
   - **Subdomain:** `new-service`
   - **Domain:** `922-studio.com`
   - **Service:** `http://home-lab:80` (Traefik)
3. Speichern — Traefik routet anhand des `Host()`-Labels automatisch

---

## Schritt 9: Deployment

### deploy.sh erstellen (Pflicht)

Jeder Service braucht ein `deploy.sh` im Root-Verzeichnis. **Wichtig: Niemals `docker compose down` verwenden** — das verursacht Downtime während des Builds. Stattdessen: Build-First-Strategie (Image bauen während der alte Container noch Traffic bedient).

```bash
#!/bin/bash
set -e

echo "Starting deployment..."

# Navigate to project directory
cd ~/new_service

# Pull latest code from GitHub (skip if SKIP_PULL=true, e.g. when smoke-test already pulled)
if [ "${SKIP_PULL}" != "true" ]; then
  echo "Pulling latest code from GitHub..."
  git pull origin main
else
  echo "Skipping git pull (SKIP_PULL=true)"
fi

# Clean up Docker build cache and unused images BEFORE building
# This prevents BuildKit cache corruption ("parent snapshot does not exist")
echo "Cleaning up Docker build cache and unused images..."
docker builder prune -f
docker image prune -f

# Build new images WHILE old containers are still running (zero-downtime)
echo "Building new images (existing services still running)..."
if ! docker compose build; then
  echo "Build failed, retrying with --no-cache..."
  docker builder prune -af
  docker compose build --no-cache
fi

# Swap: recreate only changed containers with the new images
echo "Swapping to new containers..."
docker compose up -d --wait --wait-timeout 120

# Show container status
echo "Deployment complete!"
echo ""
echo "Container status:"
docker compose ps

echo ""
echo "Recent logs:"
docker compose logs --tail=50
```

**Pflicht-Elemente:**
- `SKIP_PULL` Support — Smoke-Tests pullen bereits, vermeidet Race Conditions
- Pre-Build Cache Cleanup — Verhindert BuildKit "parent snapshot does not exist" Fehler
- Build Retry mit `--no-cache` — Fallback bei korruptem Cache
- `--wait --wait-timeout 120` — Wartet auf Healthcheck statt blind zu starten
- **Kein `docker compose down`** — Alter Container bedient Traffic während des Builds

### Frontend-Services: curl für Healthcheck installieren

Frontend-Services die `nginx:*-alpine` verwenden haben kein zuverlässiges wget. In der Dockerfile `curl` installieren:

```dockerfile
FROM nginx:1.27-alpine
RUN apk add --no-cache curl
```

Healthcheck in `docker-compose.yaml`:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:PORT/"]
  interval: 5s
  timeout: 3s
  retries: 5
  start_period: 10s
```

### ENVs deployen

```bash
~/dev/922/HomeStructure/scripts/deploy-envs.sh
```

### GitHub Actions (empfohlen)

Erstelle `.github/workflows/deploy.yml` basierend auf den bestehenden Workflows in `922-Studio/workflows`. Wichtig:

```yaml
# expected_services ohne db/redis (die kommen vom shared infra)
expected_services: 'api,worker,beat'
```

---

## Schritt 10: Monitoring & Versioning einrichten

### HomeCollector — Uptime Monitoring (Pflicht für APIs)

Neuen Service in `HomeCollector/config.py` → `DEFAULT_MONITORED_SERVICES` eintragen:

```python
# In der passenden Gruppe ("Services" für APIs, "Pages" für UIs)
ServiceConfig(
    service_name="new-service",
    display_name="New Service",
    group="Services",
    monitor_type="both",  # Docker + HTTP Health Check
    docker_container_name="new_service_api",
    health_url="http://new_service_api:8XXX/health",
),
```

Nach dem Eintrag: HomeCollector neu deployen — beim Start werden neue Services automatisch in die DB geseeded.

### HomeAPI — Versioning Endpunkt (Pflicht für APIs)

Neuen Service in HomeAPI's Service-Registry eintragen, damit der zentrale `/version`-Endpunkt alle API-Versionen aggregiert. Siehe `HomeAPI/app/` für die aktuelle Implementierung.

### Prometheus (optional)

Falls der Service einen `/metrics`-Endpunkt hat, füge einen Scrape-Job hinzu:

```yaml
# HomeStructure/monitoring/prometheus/prometheus.yaml
- job_name: 'new-service'
  static_configs:
    - targets: ['new_service_api:8XXX']
```

---

## Schritt 11: Test-Infrastruktur absichern

Neue Services mit Celery + asyncpg haben bekannte CI-Hänger. Diese Fixes gehören in jedes Setup:

### 11a: `tests/conftest.py` — Celery isolieren

Celery-Env-Vars **vor** allen App-Imports setzen, damit kein Worker versucht `shared_redis` zu erreichen:

```python
import os
os.environ["CELERY_BROKER_URL"] = "memory://"
os.environ["CELERY_RESULT_BACKEND"] = "cache+memory://"
```

### 11b: `tests/conftest.py` — asyncpg NullPool

Die asyncpg Engine im Test durch eine NullPool-Variante ersetzen — verhindert hängende Pool-Connections beim Teardown:

```python
from sqlalchemy.pool import NullPool
# Bei Engine-Erstellung: poolclass=NullPool
```

### 11c: `tests/conftest.py` — grpcio atexit-Hang umgehen

grpcio (z.B. von Sentry/OpenTelemetry) blockiert beim `atexit`-Cleanup. Fix:

```python
def pytest_sessionfinish(session, exitstatus):
    os._exit(exitstatus)
```

### 11d: pytest-timeout als Safety-Net

In `requirements-test.txt` und `pyproject.toml`:

```toml
[tool.pytest.ini_options]
timeout = 30
```

### 11e: Workflow-Timeout

In `python-tests.yml` beim pytest-Step:

```yaml
- name: Run tests
  timeout-minutes: 10
```

### 11f: Allure Project-ID

In `deploy.yml` immer **kebab-case** verwenden (z.B. `home-content`, nicht `homecontent`) — muss mit dem Allure-Server-Projekt übereinstimmen.

---

## Checkliste

- [ ] DB-User + Database auf `shared_postgres` angelegt
- [ ] `.env` mit `DB_USER`, `DB_PASSWORD`, `DB_NAME` konfiguriert
- [ ] `docker-compose.yaml` mit `proxy` + `infra` Networks
- [ ] Traefik-Labels korrekt (ein Service, Public-Router referenziert Haupt-Service)
- [ ] `docker-compose.ci.yaml` für CI mit eigener DB/Redis
- [ ] Alembic konfiguriert und initiale Migration erstellt
- [ ] Redis DB-Nummer reserviert (falls Celery)
- [ ] `/health`- und `/version`-Endpunkte implementiert
- [ ] Port-Mapping für lokalen Zugriff
- [ ] Auth-Middleware aktiviert (falls geschützt): `auth-verify@file`
- [ ] Cloudflare Tunnel Hostname hinzugefügt (falls extern)
- [ ] `.env` auf Server deployed via `deploy-envs.sh`
- [ ] `deploy.sh` folgt Zero-Downtime-Pattern (build-first, kein `docker compose down`)
- [ ] Healthcheck in `docker-compose.yaml` definiert (für alle Services mit HTTP-Endpoint)
- [ ] Frontend: `curl` in Dockerfile installiert (für nginx-alpine Healthcheck)
- [ ] HomeCollector `DEFAULT_MONITORED_SERVICES` aktualisiert + deployed
- [ ] HomeAPI Versioning-Registry aktualisiert (falls API)
- [ ] CI/CD Workflow erstellt (optional)
- [ ] `tests/conftest.py`: Celery auf memory://, asyncpg NullPool, grpcio os._exit
- [ ] `pytest-timeout` mit 30s Default konfiguriert
- [ ] Workflow pytest-Step: `timeout-minutes: 10`
- [ ] Allure Project-ID in kebab-case

---

## Referenz: Bestehende Services

| Service        | Port | Domain                          | DB        | Redis DB | Auth |
|----------------|------|---------------------------------|-----------|----------|------|
| HomeUI         | 8000 | lab.922-studio.com              | —         | —        | Nein |
| HomeAPI        | 8080 | lab-api.922-studio.com          | home_api  | 0        | Ja   |
| HomeAuth       | 8100 | lab-auth.922-studio.com         | home_auth | —        | Nein |
| HomeCollector  | 8010 | lab-collector.922-studio.com    | home_collector | 1   | Ja   |
| Discord Bot    | —    | — (kein Web)                    | discord_bot | —      | —    |
| Portfolio      | 3000 | portfolio.922-studio.com        | —         | —        | Nein |
| SweatValley    | —    | sweatvalley-bingo.922-studio.com| —         | —        | Nein |
| HomeContent    | 8012 | lab-content.922-studio.com      | homecontent | 3      | Ja   |
| Studio         | 3000 | studio.922-studio.com           | —         | —        | Nein |

## Referenz: Management-Tool

```bash
homelab-ctl.sh status          # Alle Container + Netzwerke anzeigen
homelab-ctl.sh up              # Alles in richtiger Reihenfolge starten
homelab-ctl.sh down            # Alles stoppen
homelab-ctl.sh health          # Health-Checks aller Services
homelab-ctl.sh db:create <name># DB + User anlegen
homelab-ctl.sh db:list         # Alle Datenbanken anzeigen
homelab-ctl.sh db:backup       # Alle DBs sichern
homelab-ctl.sh redis:info      # Redis DB-Belegung anzeigen
homelab-ctl.sh new-service     # Interaktiver Service-Generator
```
