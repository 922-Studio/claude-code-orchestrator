# Server Infrastructure Reference

> Last updated: 2026-06-23 (live server scan + post-rename reconciliation)

## Cluster (3-Node Docker Swarm)

> **Renamed 2026-05 — 2026-06**: cluster renamed from `home-lab` / `home-lab-exec-0` / `home-lab-exec-1` to the `astro-*` scheme below — across OS hostname, Tailscale, SSH config, and all repos. A 4th physical box (HP ProDesk 400 G5 SFF) is not yet provisioned; the name `astro-mebsuta` is reserved for it.

| Node | Hostname | Role | SSH alias | Tailscale IP | Status | Engine |
|------|----------|------|-----------|--------------|--------|--------|
| **astro-antares** (was home-lab) | `astro-antares` | Swarm Manager (Leader) | `ssh antares` | `100.112.171.16` | Active | 29.3.1 |
| **astro-polaris** (was exec-0) | `astro-polaris` | Swarm Worker + **CI runners** | `ssh polaris` | `100.94.122.119` | Active | 29.3.1 |
| **astro-upsilon** (was exec-1) | `astro-upsilon` | Swarm Worker | `ssh upsilon` | `100.100.214.75` | Active | 29.3.1 |

All access is key-based with passwordless sudo. All inter-node traffic goes over Tailscale. SSH aliases are short names (`antares` / `polaris` / `upsilon`) in `~/.ssh/config`.

**Hardware**: all nodes are HP ProDesk 400 G5 SFF. No PC speaker/beeper, and the `r8169` NICs don't support `ethtool -p` LED blink — so physical identification is done by **saturating disk I/O** on one box (`dd if=/dev/urandom … oflag=dsync` in a loop) and watching the front HDD activity LED, cross-checked against the chassis serial sticker (`dmidecode -s system-serial-number`).

**CI runners moved to polaris**: GitHub Actions self-hosted runners now live on `astro-polaris` (not the manager). Deploys run on polaris and target antares's Docker daemon via `DOCKER_HOST=ssh://lab@astro-antares`. The 4 legacy runners on antares (`home-lab`, `home-lab-2/3/4`) are idle and pending deregistration once CI is confirmed green.

**OS**: Ubuntu 24.04.4 LTS (Noble Numbat), kernel 6.8.0-106-generic
**Docker**: 29.3.1, Compose v5.1.1
**Domain**: `*.922-studio.com` (via Cloudflare Tunnel → astro-antares)

> Full documentation: Read `/Users/gregor/dev/922/HomeStructure/docs/` (MkDocs site)
> Cluster docs: Read `HomeStructure/docs/config/cluster.md`
> Worker setup guide: Read `HomeStructure/docs/guides/worker-node-setup.md`

## Storage

| Device | Size | Mount | Used | Purpose |
|--------|------|-------|------|---------|
| NVMe SSD | 232 GB (LVM) | `/` | 76 GB (34%) | OS + Docker volumes |
| NVMe SSD | 2.0 GB | `/boot` | 199 MB (11%) | Boot partition |

> **Note**: No USB HDD currently mounted. All data on NVMe SSD.

> Details: Read `HomeStructure/docs/config/storage.md`

## Networking

- **LAN**: `192.168.x.x` (ufw blocks inbound)
- **Tailscale**: `100.112.171.16` (full access via tailscale0)
- **Cloudflare Tunnel**: Zero inbound ports, all public traffic via cloudflared systemd service
- **Firewall (ufw)**: Default deny incoming, allow outgoing, deny routed
  - SSH 22/tcp: ALLOW from anywhere
  - tailscale0: ALLOW all
  - 18789/tcp from 172.16.0.0/12: Docker → OpenClaw gateway

> Details: Read `HomeStructure/docs/config/networking.md` and `HomeStructure/docs/config/security.md`

## Public Routes (Cloudflare Tunnel)

Config: `/home/lab/.cloudflared/config.yml`

| Domain | Target | Service |
|--------|--------|---------|
| `922-studio.com` | Traefik :80 | Redirects → `gregor.922-studio.com` (Portfolio) |
| `gregor.922-studio.com` | Traefik :80 | Portfolio |
| `lab.922-studio.com` | Traefik :80 | HomeUI (prod) |
| `lab-dev.922-studio.com` | Traefik :80 | HomeUI (dev) |
| `lab-api.922-studio.com` | Traefik :80 | HomeAPI (prod, with auth-verify) |
| `lab-api-dev.922-studio.com` | Traefik :80 | HomeAPI (dev) |
| `auth.922-studio.com` | Traefik :80 | HomeAuth (prod) |
| `auth-dev.922-studio.com` | Traefik :80 | HomeAuth (dev) |
| `lab-collector.922-studio.com` | Traefik :80 | HomeCollector (prod) |
| `lab-collector-dev.922-studio.com` | Traefik :80 | HomeCollector (dev) |
| `anime-api.922-studio.com` | Traefik :80 | Anime-API |
| `anime.922-studio.com` | Traefik :80 | Anime-APP |
| `studio.922-studio.com` | Traefik :80 | Studio |
| `drafter.922-studio.com` | Traefik :80 | Drafter (prod) |
| `drafter-dev.922-studio.com` | Traefik :80 | Drafter (dev) |
| `sweatvalley-bingo.922-studio.com` | Traefik :80 | Sweatvalley Bingo |
| `smoking.922-studio.com` | Traefik :80 | Smoking Counter |
| `registry.922-studio.com` | Traefik :80 | Docker Registry (htpasswd auth) |
| `minio.922-studio.com` | Traefik :80 | MinIO (public read, media serving) |
| `*` (catch-all) | Traefik :80 | Wildcard (PR previews etc.) |

> Details: Read `HomeStructure/docs/config/cloudflare.md` and `HomeStructure/docs/services/traefik.md`

## All Services & Ports

### Databases & Caching
| Service | Image | Port | Bound to | Used by |
|---------|-------|------|----------|---------|
| PostgreSQL (shared_postgres) | postgres:16-alpine (16.11) | 5432 | 127.0.0.1 | HomeAPI (home_api), HomeAuth (home_auth), HomeCollector (home_collector), Discord Bot (discord_bot), Anime-API (anime_api), Drafter (drafter) — **prod only** |
| PostgreSQL (dev_postgres) | postgres:16-alpine | 5433 | 127.0.0.1 | HomeAPI (dev_home_api), HomeAuth (dev_home_auth), HomeCollector (dev_home_collector), Drafter (dev_drafter) — **dev only, mirrored from prod** |
| Redis (shared_redis) | redis:7-alpine (7.4.7) | 6379 | 127.0.0.1 | HomeAPI Celery (DB 0), HomeCollector Celery (DB 1) |
| Redis (dev_redis) | redis:7-alpine | 6380 | 127.0.0.1 | Dev HomeAPI Celery (DB 0), Dev HomeCollector Celery (DB 1) |

> **Database mirroring**: Run `HomeStructure/infra/mirror-prod-to-dev.sh` to sync prod → dev. Supports selective sync: `./mirror-prod-to-dev.sh home_api drafter`

### Application Services
| Service | Port | Container | Image |
|---------|------|-----------|-------|
| HomeAPI (prod) | 8080 | `home_api_api` | homeapi-api |
| HomeAPI (dev) | 8180 | `dev_home_api_api` | homeapi-dev-api |
| HomeAuth (prod) | 8100 | `homeauth` | homeauth-api |
| HomeAuth (dev) | 8200 | `dev_homeauth` | homeauth-dev-api |
| HomeUI (prod) | 8000 | `homeui` | homeui-homeui |
| HomeUI (dev) | 8001 | `dev_homeui` | homeui-dev-homeui |
| HomeCollector (prod) | 8010 | `home_collector_api` | homecollector-api |
| HomeCollector (dev) | 8110 | `dev_home_collector_api` | homecollector-dev-api |
| Discord Bot | — | `discord_bot` | discord-bot |
| Portfolio | 3000 (internal) | `portfolio` | portfolio-portfolio |
| Anime-API | 8020 | `anime_api` | anime-api-api |
| Anime-APP | 8021 | `anime_app` | anime-app-app |
| Sweatvalley Bingo | 3923 | `sweatvalley-bingo` | sweatvalley_bingo-bingo |
| Smoking Counter | 3925 | `smoking-counter` | smoking-counter |
| Studio | 3000 (internal) | `studio` | studio-studio |
| Drafter (prod) | 3000 (internal) | `drafter` | registry.922-studio.com/drafter:dev |
| Drafter (dev) | 3000 (internal) | `drafter_dev` | registry.922-studio.com/drafter:dev |

### Monitoring & Observability
| Service | Port | Container | Image |
|---------|------|-----------|-------|
| Grafana | 3000 | `grafana` | grafana/grafana:latest |
| Prometheus | 9090 | `prometheus` | prom/prometheus:latest |
| Pushgateway | 9091 | `pushgateway` | prom/pushgateway:latest |
| cAdvisor | 8081 | `cadvisor` | gcr.io/cadvisor/cadvisor:latest |
| Node Exporter | 9100 (internal) | `node-exporter` | prom/node-exporter:latest |
| Postgres Exporter | 9187 (internal) | `postgres_exporter` | prometheuscommunity/postgres-exporter:latest |
| Redis Exporter | 9121 (internal) | `redis_exporter` | oliver006/redis_exporter:latest |
| Allure API | 5050 | `allure-api` | frankescobar/allure-docker-service:latest |
| Allure UI | 5051 | `allure-ui` | frankescobar/allure-docker-service-ui:latest |
| Portainer | 9443 | `portainer` | portainer/portainer-ce:latest |

### Documentation Sites
| Service | Port | Container |
|---------|------|-----------|
| HomeLab Docs | 8002 | `homelab-docs` |
| HomeAPI Docs | 8003 | `home_api_docs` |
| OpenClaw Docs | 8004 | `openclaw-docs` |
| Discord Bot Docs | 8005 | `discord_bot_docs` |
| HomeCollector Docs | 8013 | `homecollector_docs` |

### Background Workers
| Service | Container | Purpose |
|---------|-----------|---------|
| HomeAPI Worker (prod) | `home_api_worker` | Celery async tasks |
| HomeAPI Beat (prod) | `home_api_beat` | Celery scheduled tasks |
| HomeAPI Flower (prod) | `home_api_flower` (:5555) | Celery monitoring |
| HomeAPI Worker (dev) | `dev_home_api_worker` | Celery async tasks (dev) |
| HomeAPI Beat (dev) | `dev_home_api_beat` | Celery scheduled tasks (dev) |
| HomeAPI Flower (dev) | `dev_home_api_flower` (:5655) | Celery monitoring (dev) |
| HomeCollector Worker (prod) | `home_collector_worker` | Uptime polling |
| HomeCollector Beat (prod) | `home_collector_beat` | 60s poll schedule |
| HomeCollector Flower (prod) | `homecollector_flower` (:5556) | Celery monitoring |
| HomeCollector Worker (dev) | `dev_home_collector_worker` | Uptime polling (dev) |
| HomeCollector Beat (dev) | `dev_home_collector_beat` | 60s poll schedule (dev) |
| HomeCollector Flower (dev) | `dev_homecollector_flower` (:5656) | Celery monitoring (dev) |

### Infrastructure Services
| Service | Port/Type | Purpose |
|---------|-----------|---------|
| Traefik | 80 (public), 8082 (dashboard, localhost) | Reverse proxy for all subdomains (Docker provider + file provider) |
| cloudflared | systemd | Cloudflare Tunnel daemon (config at `~/.cloudflared/config.yml`) |
| OpenClaw | 18789 (public), 18791/18792 (localhost) | AI gateway (systemd process) |
| GitHub Runners | 4x systemd **on astro-polaris** | `polaris`, `polaris-2`, `polaris-3`, `polaris-4` (polaris-4 has `e2e` label). Labels: `self-hosted,Linux,X64,polaris`. Legacy antares runners (`home-lab*`) idle, pending deregistration. |
| Syncthing | 8384 (Tailscale only), 22000 (sync) | P2P file sync (Obsidian vault) |
| Docker Registry | 5000 (internal) | Self-hosted container image registry (`docker_registry`) |
| MinIO | 9000 (API, internal), 9001 (console, localhost only) | Object storage for media uploads (`minio`) |
| Watchtower | — | Auto-updates labeled containers from registry (`watchtower`) |

## Docker Networks

| Network | Driver | Scope | Purpose | Connected services |
|---------|--------|-------|---------|-------------------|
| `proxy` | bridge | local | Traefik routing | Traefik, all web-facing services (HomeUI, HomeAuth, HomeAPI, HomeCollector, Portfolio, Studio, Drafter, Anime-API, Anime-APP, Sweatvalley Bingo, Docker Registry, MinIO) |
| `infra` | bridge | local | Shared infrastructure | PostgreSQL, Redis, exporters, MinIO, all services needing DB/Redis |
| `monitoring_monitor-net` | bridge | local | Monitoring stack | Prometheus, Grafana, Pushgateway, cAdvisor, Node Exporter, exporters, HomeCollector |
| `core_default` | bridge | local | Core services (Portainer) | Portainer |
| `allure_allure-net` | bridge | local | Allure stack | Allure API, Allure UI |
| `proxy_overlay` | overlay | swarm | Swarm proxy routing (unused) | — |
| `infra_overlay` | overlay | swarm | Swarm infra routing (unused) | — |
| `monitor_overlay` | overlay | swarm | Swarm monitoring (unused) | — |

> **Note**: Overlay networks exist from Swarm setup but all services currently run as docker compose, not Swarm stacks. Per-service default networks also exist (portfolio_default, sweatvalley_bingo_default, etc.).

## Key Commands

```bash
# Access server (manager)
ssh antares   # workers: ssh polaris / ssh upsilon

# Service management
cd ~/HomeStructure && ./scripts/homelab-ctl.sh status
docker compose -f ~/HomeAPI/docker-compose.yaml logs -f
docker compose -f ~/HomeUI/docker-compose.yaml restart

# Database
docker exec -it shared_postgres psql -U home_api -d home_api

# Monitoring
curl http://localhost:9090/api/v1/targets    # Prometheus targets
curl http://localhost:8010/status            # HomeCollector public status

# Deployment (per project)
cd ~/<ProjectName> && ./deploy.sh

# Dev environment
cd ~/dev/<ProjectName> && docker compose up -d
```

## Total Running Containers: 52

| Category | Prod | Dev | Total |
|----------|------|-----|-------|
| Application services | 16 | 14 | 30 |
| Monitoring & Observability | 10 | — | 10 |
| Documentation sites | 5 | — | 5 |
| Infrastructure | 7 | — | 7 |
| **Total** | **38** | **14** | **52** |

## For Agents: Context Loading

When a plan involves the server, agents should read:
1. This file (`server.md`) for quick reference
2. `HomeStructure/docs/config/server.md` for server setup details
3. `HomeStructure/docs/config/networking.md` for network topology
4. `HomeStructure/docs/config/security.md` for firewall rules
5. Specific `HomeStructure/docs/services/<name>.md` for service details
6. `HomeStructure/scripts/homelab-ctl.sh` for available management commands
