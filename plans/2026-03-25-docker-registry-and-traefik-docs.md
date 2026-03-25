# Plan: Self-Hosted Docker Registry & Traefik/Networking Documentation

- **Date**: 2026-03-25
- **Project(s)**: HomeStructure, Planner
- **Goal**: Deploy a self-hosted Docker Registry (registry:2) with Traefik routing and htpasswd auth, then create comprehensive Traefik networking/security documentation with architecture diagram.

## Context

Read these files before proceeding:
- `Planner/server.md` — server infrastructure quick reference
- `Planner/registry.md` — ecosystem project registry
- `HomeStructure/traefik/docker-compose.yaml` — current Traefik config
- `HomeStructure/traefik/dynamic/middleware.yaml` — Traefik middleware definitions
- `HomeStructure/docs/config/networking.md` — network topology
- `HomeStructure/docs/config/security.md` — firewall and security hardening
- `HomeStructure/docs/config/cloudflare.md` — Cloudflare Tunnel setup and subdomain guide
- `HomeStructure/docs/neue-services-einrichten.md` — 10-step new service guide

## Steps

### Step 1: Create Docker Registry service in HomeStructure
- **Project**: HomeStructure
- **Directory**: `/home/lab/HomeStructure/registry/` (on server via `ssh lab`)
- **Parallel with**: Step 2
- **Description**:
  Create the Docker Registry service with htpasswd basic auth, Traefik routing, and persistent storage.

  **1a. Create the directory and docker-compose.yaml:**
  ```
  ~/HomeStructure/registry/docker-compose.yaml
  ```

  Contents:
  ```yaml
  services:
    registry:
      image: registry:2
      container_name: docker_registry
      environment:
        REGISTRY_AUTH: htpasswd
        REGISTRY_AUTH_HTPASSWD_REALM: "922 Docker Registry"
        REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
        REGISTRY_STORAGE_DELETE_ENABLED: "true"
      volumes:
        - registry_data:/var/lib/registry
        - ./auth:/auth:ro
      healthcheck:
        test: ["CMD", "wget", "--spider", "-q", "http://localhost:5000/v2/"]
        interval: 30s
        timeout: 5s
        retries: 3
        start_period: 10s
      restart: unless-stopped
      networks:
        - proxy
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.registry.rule=Host(`registry.922-studio.com`)"
        - "traefik.http.routers.registry.entrypoints=web"
        - "traefik.http.services.registry.loadbalancer.server.port=5000"

  volumes:
    registry_data:

  networks:
    proxy:
      external: true
  ```

  **1b. Generate htpasswd credentials:**
  ```bash
  mkdir -p ~/HomeStructure/registry/auth
  docker run --rm --entrypoint htpasswd httpd:2 -Bbn gregor "<CHOOSE_PASSWORD>" > ~/HomeStructure/registry/auth/htpasswd
  ```

  **1c. Start the registry:**
  ```bash
  cd ~/HomeStructure/registry
  docker compose up -d
  ```

  **1d. Add Cloudflare Tunnel ingress rule** (before the catch-all):
  Edit `~/.cloudflared/config.yml`:
  ```yaml
  - hostname: registry.922-studio.com
    service: http://localhost:80
  ```

  Then:
  ```bash
  cloudflared tunnel ingress validate
  cloudflared tunnel route dns becd3c5e-5608-4ed2-a913-27ab63660d0d registry.922-studio.com
  sudo systemctl restart cloudflared
  ```

  **1e. Add to systemd docker-compose-services** so it starts on boot:
  Read `HomeStructure/docs/services/docker.md` for the systemd service pattern, then add `~/HomeStructure/registry/docker-compose.yaml` to the service list.

  **1f. Verify:**
  ```bash
  # Health check
  curl -f http://localhost:5000/v2/

  # Auth check (should return 200 with credentials, 401 without)
  curl -u gregor:<PASSWORD> https://registry.922-studio.com/v2/_catalog

  # Docker login
  docker login registry.922-studio.com
  ```

- **Context files to read**:
  - `HomeStructure/traefik/docker-compose.yaml` — Traefik network and label pattern
  - `HomeStructure/docs/config/cloudflare.md` — how to add subdomain + tunnel routing
  - `HomeStructure/docs/services/docker.md` — systemd service registration
  - `HomeStructure/docs/neue-services-einrichten.md` — full 10-step new service guide
- **Acceptance criteria**:
  - [ ] `registry:2` container running with `registry_data` volume
  - [ ] htpasswd auth file generated in `registry/auth/htpasswd`
  - [ ] Traefik routes `registry.922-studio.com` to port 5000
  - [ ] Cloudflare Tunnel ingress rule added and DNS record created
  - [ ] `docker login registry.922-studio.com` works with credentials
  - [ ] `docker push registry.922-studio.com/test:latest` succeeds
  - [ ] Service registered in systemd for auto-start on boot
  - [ ] Registry directory and compose file committed and pushed to HomeStructure repo

### Step 2: Create Traefik & Networking Architecture Documentation
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure/docs/services/`
- **Parallel with**: Step 1
- **Description**:
  Create `traefik.md` in `HomeStructure/docs/services/` documenting the full networking and security stack with an ASCII architecture diagram.

  The document should cover:

  **Sections:**
  1. **Overview** — What Traefik does in the ecosystem (reverse proxy, Docker provider, dynamic config)
  2. **Architecture Diagram** — ASCII diagram showing the full request flow:
     ```
     Internet → Cloudflare (DNS + SSL + DDoS) → Cloudflare Tunnel (QUIC)
       → cloudflared daemon → localhost:80 (Traefik)
         → Docker provider (labels) → Container port
         → File provider (dynamic/) → Middleware (forward-auth, basic-auth)

     Tailscale VPN → 100.112.171.16 → direct container port / Traefik :80

     LAN → 192.168.x.x → ufw DENY (except SSH, tailscale0)
     ```
  3. **Traefik Configuration** — Current command flags, volumes, ports, network
  4. **Docker Provider** — How services register via labels (`traefik.enable=true`, routers, services)
  5. **File Provider** — Dynamic config directory (`/etc/traefik/dynamic/`), middleware definitions
  6. **Middleware** — All defined middlewares:
     - `auth-verify@file` — HomeAuth forward-auth (protected routes)
     - `registry-auth@file` — htpasswd basic auth (Docker Registry) *(new)*
  7. **Routing Patterns** — Examples for:
     - Public service (no auth): Portfolio, Studio
     - Protected service (forward-auth): HomeAPI, Drafter
     - Mixed routes (public + protected): HomeCollector (`/status` public, rest protected)
     - Basic auth service: Docker Registry
  8. **Docker Networks** — Table of all networks and which services connect to which
  9. **Security Layers** — How ufw, DOCKER-USER chain, Cloudflare, and Traefik work together
  10. **Adding a New Service** — Quick reference for Traefik labels pattern
  11. **Dashboard** — How to access Traefik dashboard (`127.0.0.1:8082`)
  12. **Troubleshooting** — Common issues table

  **Architecture Diagram** (include in the doc):
  ```
  ┌──────────────────────────────────────────────────────────────────┐
  │                        INTERNET                                  │
  └────────────────────────────┬─────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │     Cloudflare      │
                    │  DNS + SSL + WAF    │
                    │  *.922-studio.com   │
                    └──────────┬──────────┘
                               │ QUIC (outbound only)
                    ┌──────────▼──────────┐
                    │    cloudflared       │
                    │  (systemd daemon)    │
                    │  Tunnel → localhost  │
                    └──────────┬──────────┘
                               │ :80
  ┌────────────────────────────▼─────────────────────────────────────┐
  │                     TRAEFIK v3.6                                  │
  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
  │  │   Docker     │  │    File      │  │     Entrypoint         │  │
  │  │  Provider    │  │  Provider    │  │     web :80            │  │
  │  │  (labels)    │  │  (dynamic/)  │  │                        │  │
  │  └──────┬───────┘  └──────┬───────┘  └────────────────────────┘  │
  │         │                 │                                       │
  │  ┌──────▼─────────────────▼──────────────────────────────────┐   │
  │  │                    ROUTERS                                 │   │
  │  │  Host(`lab.922-studio.com`)        → HomeUI               │   │
  │  │  Host(`lab-api.922-studio.com`)    → HomeAPI  [auth]      │   │
  │  │  Host(`drafter.922-studio.com`)    → Drafter  [auth]      │   │
  │  │  Host(`registry.922-studio.com`)   → Registry [basic]     │   │
  │  │  Host(`gregor.922-studio.com`)     → Portfolio            │   │
  │  │  ...                                                       │   │
  │  └──────┬────────────────────────────────────────────────────┘   │
  │         │                                                         │
  │  ┌──────▼──────────────────────────────────────────────────┐     │
  │  │                  MIDDLEWARES                              │     │
  │  │  auth-verify@file  → HomeAuth /auth/verify (forward-auth)│     │
  │  │  registry-auth     → htpasswd basic auth                 │     │
  │  └─────────────────────────────────────────────────────────┘     │
  └────────────────────────────┬─────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
  ┌───────▼───────┐  ┌────────▼───────┐  ┌────────▼───────┐
  │  proxy network │  │  infra network │  │  monitor-net   │
  │               │  │               │  │               │
  │  HomeUI       │  │  PostgreSQL   │  │  Prometheus   │
  │  HomeAPI      │  │  Redis        │  │  Grafana      │
  │  HomeAuth     │  │               │  │  cAdvisor     │
  │  Drafter      │  │               │  │  Node Export  │
  │  Portfolio    │  │               │  │               │
  │  Registry     │  │               │  │               │
  │  ...          │  │               │  │               │
  └───────────────┘  └───────────────┘  └───────────────┘
  ```

  Also include a **security layers diagram**:
  ```
  Request Flow & Security Layers:

  Internet → Cloudflare (DDoS, WAF, SSL termination)
    → cloudflared (QUIC tunnel, zero open ports)
      → Traefik (routing + middleware)
        → [auth-verify] → HomeAuth JWT validation
          → Container (application)

  Tailscale → ufw ALLOW on tailscale0
    → Direct port access OR Traefik :80

  Public Internet → ufw DENY incoming
  Docker ports → DOCKER-USER chain → DROP (except Tailscale/LAN/Docker bridge)
  ```

- **Context files to read**:
  - `HomeStructure/traefik/docker-compose.yaml` — Traefik config
  - `HomeStructure/traefik/dynamic/middleware.yaml` — middleware definitions
  - `HomeStructure/docs/config/networking.md` — network topology
  - `HomeStructure/docs/config/security.md` — firewall and security hardening
  - `HomeStructure/docs/config/cloudflare.md` — tunnel architecture
  - `Planner/server.md` — all services, ports, networks overview
- **Acceptance criteria**:
  - [ ] `HomeStructure/docs/services/traefik.md` created
  - [ ] Full architecture diagram showing request flow from internet to container
  - [ ] Security layers diagram showing all defense layers
  - [ ] All middleware documented with usage examples
  - [ ] Docker network topology documented
  - [ ] Routing pattern examples for each auth type (public, forward-auth, basic-auth, mixed)
  - [ ] Troubleshooting table included
  - [ ] File committed and pushed to HomeStructure repo

### Step 3: Add Docker Registry to HomeStructure MkDocs
- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure/docs/services/`
- **Parallel with**: Step 2
- **Description**:
  Create `registry.md` in `HomeStructure/docs/services/` documenting the Docker Registry service:
  - What it is and why self-hosted
  - Docker Compose reference (file pointer to `registry/docker-compose.yaml`)
  - Auth setup (htpasswd generation, adding users)
  - Usage: `docker login`, `docker push`, `docker pull`
  - Garbage collection (scheduled cleanup of unused layers)
  - Storage location (named volume `registry_data`)
  - CI/CD integration (how GitHub Actions can push to registry)
  - Troubleshooting

  Also update `HomeStructure/docs/config/cloudflare.md` to include `registry.922-studio.com` in the Current Services table.

  If MkDocs has a `mkdocs.yml` nav section, add both new pages.

- **Context files to read**:
  - `HomeStructure/docs/services/` — existing service doc format and style
  - `HomeStructure/docs/config/cloudflare.md` — current services table to update
  - `HomeStructure/mkdocs.yml` — navigation structure (if exists)
- **Acceptance criteria**:
  - [ ] `HomeStructure/docs/services/registry.md` created
  - [ ] Cloudflare docs updated with `registry.922-studio.com`
  - [ ] MkDocs nav updated (if applicable)
  - [ ] Committed and pushed to HomeStructure repo

### Step 4: Update Planner documentation
- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner/`
- **Parallel with**: —
- **Description**:
  Update Planner docs to reflect the new Docker Registry service:

  **4a. Update `server.md`:**
  - Add `registry.922-studio.com` to Public Routes table
  - Add Docker Registry to Infrastructure Services table (port 5000, container `docker_registry`)
  - Add `registry_data` as a notable Docker volume if volumes are listed

  **4b. Update `registry.md`:**
  - No new project entry needed (Registry is part of HomeStructure, not a standalone project)
  - But mention in HomeStructure dependencies that it now includes Docker Registry

  **4c. Update `projects/homestructure.md`** (if it exists):
  - Add Docker Registry to the list of infrastructure services managed by HomeStructure

- **Context files to read**:
  - `Planner/server.md` — current server reference to update
  - `Planner/registry.md` — ecosystem registry
  - `Planner/projects/homestructure.md` — HomeStructure project mapping (if exists)
- **Acceptance criteria**:
  - [ ] `server.md` updated with registry route, service, and port
  - [ ] `registry.md` updated to note Docker Registry under HomeStructure
  - [ ] Changes committed and pushed to Planner repo

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Deploy Docker Registry         → HomeStructure @ ssh lab (~/HomeStructure/registry/)
  Step 2: Create Traefik architecture doc → HomeStructure @ /Users/gregor/dev/922/HomeStructure/docs/services/traefik.md
  Step 3: Create Registry service doc     → HomeStructure @ /Users/gregor/dev/922/HomeStructure/docs/services/registry.md

Wave 2 (after wave 1):
  Step 4: Update Planner docs             → Planner @ /Users/gregor/dev/922/Planner/
```

**Notes:**
- Steps 1-3 can all start immediately in parallel
- Step 1 requires SSH access to the server (`ssh lab`)
- Steps 2 and 3 are local doc changes that can be committed together
- Step 4 depends on Step 1 completing (need to confirm the final port, domain, container name)
- After all steps: verify `docker login registry.922-studio.com` works end-to-end

## Agent Prompts

### Agent 1 (Step 1) — Server Deployment
**Model**: sonnet
**Target**: `ssh lab`, then work in `~/HomeStructure/`

> You are deploying a self-hosted Docker Registry (registry:2) on the home lab server.
>
> **Read first:**
> - `~/HomeStructure/traefik/docker-compose.yaml` — Traefik label pattern
> - `~/HomeStructure/docs/neue-services-einrichten.md` — 10-step new service guide
> - `~/HomeStructure/docs/config/cloudflare.md` — how to add a new subdomain
> - `~/HomeStructure/docs/services/docker.md` — systemd service registration
>
> **Tasks:**
> 1. Create `~/HomeStructure/registry/docker-compose.yaml` with registry:2, htpasswd auth, Traefik labels for `registry.922-studio.com`, proxy network, `registry_data` volume, health check
> 2. Generate htpasswd: `mkdir -p ~/HomeStructure/registry/auth && docker run --rm --entrypoint htpasswd httpd:2 -Bbn gregor "<PASSWORD>" > ~/HomeStructure/registry/auth/htpasswd`
> 3. `docker compose up -d` from `~/HomeStructure/registry/`
> 4. Add ingress rule for `registry.922-studio.com` in `~/.cloudflared/config.yml` (before catch-all)
> 5. Validate: `cloudflared tunnel ingress validate`
> 6. Route DNS: `cloudflared tunnel route dns becd3c5e-5608-4ed2-a913-27ab63660d0d registry.922-studio.com`
> 7. Restart cloudflared: `sudo systemctl restart cloudflared`
> 8. Register in systemd docker-compose-services
> 9. Verify: `curl -f http://localhost:5000/v2/` and `docker login registry.922-studio.com`
> 10. Commit and push HomeStructure changes (compose file only, NOT the auth/ directory)

### Agent 2 (Steps 2+3) — Documentation
**Model**: sonnet
**Target**: `/Users/gregor/dev/922/HomeStructure/`

> You are creating Traefik architecture documentation and Docker Registry service documentation.
>
> **Read first:**
> - `HomeStructure/traefik/docker-compose.yaml` — Traefik config
> - `HomeStructure/traefik/dynamic/middleware.yaml` — middleware definitions
> - `HomeStructure/docs/config/networking.md` — network topology
> - `HomeStructure/docs/config/security.md` — firewall rules
> - `HomeStructure/docs/config/cloudflare.md` — tunnel and subdomain setup
> - `HomeStructure/docs/services/cloudflare-tunnel.md` — existing service doc style
> - `Planner/server.md` — full service/port/network reference
>
> **Task 1**: Create `docs/services/traefik.md` — Full Traefik & networking architecture doc with:
> - ASCII architecture diagram (internet → Cloudflare → tunnel → Traefik → container)
> - Security layers diagram
> - Configuration reference
> - Docker + File providers
> - All middlewares
> - Routing patterns (public, forward-auth, basic-auth, mixed)
> - Docker networks table
> - Adding new services checklist
> - Dashboard access
> - Troubleshooting
>
> **Task 2**: Create `docs/services/registry.md` — Docker Registry service doc with:
> - Purpose (self-hosted container image storage)
> - Compose reference (pointer to `registry/docker-compose.yaml`)
> - Auth (htpasswd, adding users)
> - Usage (login, push, pull, tag)
> - Garbage collection
> - CI/CD integration
> - Troubleshooting
>
> **Task 3**: Update `docs/config/cloudflare.md` — Add `registry.922-studio.com` to Current Services table
>
> Commit and push all changes.

### Agent 3 (Step 4) — Planner Updates
**Model**: sonnet
**Target**: `/Users/gregor/dev/922/Planner/`

> You are updating the Planner documentation to include the new Docker Registry service.
>
> **Read first:**
> - `Planner/server.md` — current infrastructure reference
> - `Planner/registry.md` — ecosystem registry
>
> **Tasks:**
> 1. Update `server.md`:
>    - Add `registry.922-studio.com` → Traefik :80 → Docker Registry to Public Routes table
>    - Add Docker Registry (port 5000, container `docker_registry`) to Infrastructure Services table
> 2. Update `registry.md`:
>    - In HomeStructure dependencies, note it now includes Docker Registry (`registry.922-studio.com`)
> 3. Commit and push.

## Post-Execution Checklist
- [ ] All tests pass
- [ ] Documentation updated (HomeStructure docs + Planner docs)
- [ ] Pipeline green (HomeStructure push triggers docs rebuild)
- [ ] Changes reviewed against best practices in project mapping
- [ ] `docker login registry.922-studio.com` works
- [ ] `docker push registry.922-studio.com/<image>:latest` works
- [ ] Registry survives server reboot (systemd registered)
