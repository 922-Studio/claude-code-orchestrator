# Project: HomeStructure

## Overview
- **Type**: infra
- **Path**: /Users/gregor/dev/922/HomeStructure
- **Status**: active
- **Description**: Home lab server infrastructure and automation platform. Manages the entire containerized server environment including monitoring (Prometheus/Grafana), reverse proxy (Traefik), databases (PostgreSQL/Redis), documentation hosting, test reporting (Allure), and service orchestration. Foundation for all other projects.

## Tech Stack
- **Language(s)**: YAML (Docker Compose, GitHub Actions), Bash, Python (lifecycle scripts)
- **Framework(s)**: Docker Compose, MkDocs Material
- **Infrastructure**: Ubuntu 24.04 LTS, Docker, Traefik, Tailscale VPN, Cloudflare Tunnel
- **Monitoring**: Prometheus, Grafana, Node Exporter, cAdvisor
- **CI/CD**: GitHub Actions (922-Studio/workflows), path-filtered auto-deploy

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` | Naming conventions, patterns, new service checklist | Always |
| `README.md` | Quick start, service overview | First time |
| `.ai/guidelines.md` | AI agent guidelines master reference | When working as agent |
| `.ai/documentation-guidelines.md` | Documentation standards | When writing docs |
| `mkdocs.yml` | MkDocs config with full navigation | When touching docs |
| `scripts/homelab-ctl.sh` | Main control script (status, up, down, deploy-envs) | When managing services |
| `scripts/deploy-envs.sh` | Deploy .env files to server | When touching secrets |
| `infra/docker-compose.yaml` | PostgreSQL, Redis, exporters | When touching databases |
| `monitoring/docker-compose.yaml` | Prometheus, Grafana stack | When touching monitoring |
| `traefik/dynamic/middleware.yaml` | Traefik forward-auth middleware | When touching auth routing |
| `docs/project-info/architecture.md` | System architecture and networking | For understanding system |
| `infra/init-db/01-init-databases.sh` | PostgreSQL user/database creation | When adding new DB |

## Best Practices
- Each service gets own top-level directory with `docker-compose.yaml` + config
- Named Docker networks for isolation (monitor-net, proxy, infra)
- Named volumes for persistence with service-specific naming
- Health checks for HTTP endpoints
- Documentation: commands-first, max 1 sentence per command explanation
- Naming: Python=snake_case, Shell=kebab-case, Docs=kebab-case, Docker services=lowercase
- No `Co-Authored-By` trailers in commits

## Testing Strategy
- **No unit tests in this repo** — infrastructure validation via smoke tests and health checks
- **Downstream testing**: Frontend (Vitest/Playwright), Python (pytest) — results to Allure server

## Documentation
- **Where**: `docs/` (MkDocs at http://astro-antares:8002)
- **Categories**: config/, services/, actions/, ops/
- **Update rule**: Commands-first approach, no prerequisites, no lengthy descriptions

## Pipeline & Deployment
- **CI trigger**: Path-filtered (docs/**, monitoring/**, traefik/**)
- **Deploy**: Each stack has its own workflow, all use `922-Studio/workflows/deploy-docker.yml`
- **Monitor after push**: Discord notification, `docker compose ps`
- **Startup order**: infra → traefik → monitoring → core → allure → app stacks

## Dependencies on Other Projects
- **All projects depend on HomeStructure** for PostgreSQL, Redis, Traefik routing
- **workflows**: Uses reusable CI/CD workflows
- **HomeAuth**: Forward-auth integration via Traefik

## Docker Compose Stacks
- **traefik**: Traefik v3.6 (latest)
- **infra**: postgres:16-alpine, redis:7-alpine, exporters
- **monitoring**: Prometheus, Grafana, cAdvisor, Node Exporter, Pushgateway
- **minio**: MinIO object storage
- **watchtower**: Automatic container updates
- **syncthing**: File sync
- **allure**: Allure test reporting server
- **core**: Portainer
- **registry**: Private Docker registry
- **docs-service**: Documentation hosting

## Notes
- `homelab-ctl.sh`: status, up, down, restart, db:create/list/backup/restore, redis:info, health, deploy-envs, new-service
- Server lifecycle: notify_email.py + systemd service for startup/shutdown with email + Discord notifications
- All docs sites: HomeStructure (:8002), HomeAPI (:8003), OpenClaw (:8004), Discord (:8005)
- Self-hosted GitHub Actions runner on the server
- No CI/CD workflows in this repo — each stack deployed individually
