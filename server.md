# Server Infrastructure Reference

**Access**: `ssh lab` (key-based auth, passwordless sudo)
**Hostname**: `home-lab`
**OS**: Ubuntu Server 24.04 LTS
**Tailscale IP**: `100.112.171.16`
**Domain**: `*.922-studio.com` (via Cloudflare Tunnel)

> Full documentation: Read `/Users/gregor/dev/922/HomeStructure/docs/` (MkDocs site)

## Storage

| Device | Size | Mount | Purpose |
|--------|------|-------|---------|
| NVMe SSD | 238 GB | `/` (LVM) | OS + Docker volumes |
| USB HDD | 200 GB NTFS | `/mnt/backups` | Backups |
| USB HDD | 700 GB ext4 | `/mnt/storage` | Storage |

> Details: Read `HomeStructure/docs/config/storage.md`

## Networking

- **LAN**: `192.168.x.x` (ufw blocks inbound)
- **Tailscale**: `100.112.171.16` (full access)
- **Cloudflare Tunnel**: Zero inbound ports, outbound QUIC
- **Firewall**: ufw + DOCKER-USER chain (only Tailscale/LAN/Docker allowed)

> Details: Read `HomeStructure/docs/config/networking.md` and `HomeStructure/docs/config/security.md`

## Public Routes (Cloudflare Tunnel)

| Domain | Target | Service |
|--------|--------|---------|
| `922-studio.com` | Traefik :80 | Redirects → `gregor.922-studio.com` (Portfolio) |
| `gregor.922-studio.com` | Traefik :80 | Portfolio |
| `lab.922-studio.com` | Traefik :80 | HomeUI |
| `lab-auth.922-studio.com` | Traefik :80 | HomeAuth |
| `lab-api.922-studio.com` | Traefik :80 | HomeAPI (with forward_auth) |
| `lab-collector.922-studio.com` | Traefik :80 | HomeCollector |
| `status.922-studio.com` | Traefik :80 | HomeCollector (`/status`) |
| `sweatvalley-bingo.922-studio.com` | Traefik :80 | Sweatvalley Bingo |
| `anime-api.922-studio.com` | Traefik :80 | Anime-API |
| `anime.922-studio.com` | Traefik :80 | Anime-APP |
| `studio.922-studio.com` | Traefik :80 | Studio (Landing Page) |

> Details: Read `HomeStructure/docs/config/cloudflare.md` and `HomeStructure/docs/services/traefik.md`

## All Services & Ports

### Databases & Caching
| Service | Port | Bound to | Used by |
|---------|------|----------|---------|
| PostgreSQL (shared_postgres) | 5432 | 127.0.0.1 | HomeAPI (home_api), HomeAuth (home_auth), HomeCollector (home_collector), Discord Bot (discord_bot), Anime-API (anime_api) |
| Redis (shared_redis) | 6379 | 127.0.0.1 | HomeAPI Celery (DB 0), HomeCollector Celery (DB 1) |

### Application Services
| Service | Port | Container |
|---------|------|-----------|
| HomeAPI | 8080 | `home_api_api` |
| HomeAuth | 8100 | HomeAuth api |
| HomeUI | 8000 | `homeui` |
| HomeCollector | 8011 | `home_collector_api` |
| Discord Bot | — | `discord_bot` |
| Landing Page | 8010 | `landingpage` |
| Portfolio | 3000 (internal) | `portfolio` |
| Anime-API | 8020 | `anime_api` |
| Anime-APP | 8021 | `anime_app` |
| Sweatvalley Bingo | 3001 (internal) | `sweatvalley-bingo` |
| Studio | 3000 (internal) | `studio` |

### Monitoring & Observability
| Service | Port | Container |
|---------|------|-----------|
| Grafana | 3000 | `grafana` |
| Prometheus | 9090 | `prometheus` |
| Pushgateway | 9091 | `pushgateway` |
| cAdvisor | 8081 | `cadvisor` |
| Node Exporter | 9100 | `node_exporter` |
| Allure API | 5050 | `allure-api` |
| Allure UI | 5051 | `allure-ui` |
| Portainer | 9443 | `portainer` |

### Documentation Sites
| Service | Port | Container |
|---------|------|-----------|
| HomeLab Docs | 8002 | `homelab-docs` |
| HomeAPI Docs | 8003 | `home_api_docs` |
| OpenClaw Docs | 8004 | `openclaw-docs` |
| Discord Bot Docs | 8005 | `discord_bot_docs` |
| HomeCollector Docs | 8013 | `home_collector_docs` |

### Background Workers
| Service | Container | Purpose |
|---------|-----------|---------|
| HomeAPI Worker | `home_api_worker` | Celery async tasks |
| HomeAPI Beat | `home_api_beat` | Celery scheduled tasks |
| HomeAPI Flower | `home_api_flower` (:5555) | Celery monitoring |
| HomeCollector Worker | `home_collector_worker` | Uptime polling |
| HomeCollector Beat | `home_collector_beat` | 60s poll schedule |

### Infrastructure Services
| Service | Port/Type | Purpose |
|---------|-----------|---------|
| Traefik | 80 | Reverse proxy for all subdomains (Docker provider) |
| cloudflared | systemd | Cloudflare Tunnel daemon |
| OpenClaw | 18789 (systemd) | AI gateway (11 agents) |
| GitHub Runners | 4x systemd | CI/CD pipeline execution |
| Syncthing | 22000 (systemd) | P2P file sync (Obsidian vault) |

## Docker Networks

| Network | Purpose | Connected services |
|---------|---------|-------------------|
| `proxy` | Traefik routing | Traefik, Portfolio, HomeUI, HomeAuth, HomeAPI, HomeCollector, Sweatvalley Bingo, Anime-API, Anime-APP, Studio |
| `homeapi_default` | HomeAPI + Discord cross-network | HomeAPI, Discord Bot |
| `monitor-net` | Monitoring stack | Prometheus, Grafana, exporters, HomeCollector |
| `infra` | Shared infrastructure | PostgreSQL, Redis, dependent services |

## Key Commands

```bash
# Access server
ssh lab

# Service management
cd ~/HomeStructure && ./scripts/homelab-ctl.sh status
docker compose -f ~/HomeAPI/docker-compose.yaml logs -f
docker compose -f ~/HomeUI/docker-compose.yaml restart

# Database
docker exec -it home_api_db psql -U postgres -d homeapi

# Monitoring
curl http://localhost:9090/api/v1/targets    # Prometheus targets
curl http://localhost:8010/status            # HomeCollector public status

# Deployment (per project)
cd ~/<ProjectName> && ./deploy.sh
```

## For Agents: Context Loading

When a plan involves the server, agents should read:
1. This file (`server.md`) for quick reference
2. `HomeStructure/docs/config/server.md` for server setup details
3. `HomeStructure/docs/config/networking.md` for network topology
4. `HomeStructure/docs/config/security.md` for firewall rules
5. Specific `HomeStructure/docs/services/<name>.md` for service details
6. `HomeStructure/scripts/homelab-ctl.sh` for available management commands
