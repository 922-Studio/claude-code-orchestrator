# Plan: MinIO Deployment & Drafter Integration

- **Date**: 2026-03-27
- **Project(s)**: HomeStructure, Drafter
- **Goal**: Deploy MinIO as a shared object storage service on the home lab, expose it via Traefik + Cloudflare, integrate with Drafter for media uploads, and verify the full upload flow end-to-end.

## Context

Read these files before proceeding:
- `/Users/gregor/dev/922/Planner/server.md` — server infrastructure reference
- `/Users/gregor/dev/922/Planner/projects/drafter.md` — Drafter project mapping
- `/Users/gregor/dev/922/HomeStructure/infra/docker-compose.yaml` — existing infra pattern (PostgreSQL, Redis)
- `/Users/gregor/dev/922/HomeStructure/traefik/dynamic/middleware.yaml` — Traefik dynamic config
- `/Users/gregor/dev/922/HomeStructure/docs/neue-services-einrichten.md` — new service guide
- `/Users/gregor/dev/922/HomeStructure/scripts/homelab-ctl.sh` — homelab management script

---

## Steps

### Step 1: Create MinIO Docker Compose Stack

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure/minio/`
- **Parallel with**: —
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeStructure/infra/docker-compose.yaml` — pattern for infra services (networks, labels, volumes, healthchecks)
  - `/Users/gregor/dev/922/HomeStructure/traefik/docker-compose.yaml` — how Traefik labels work
  - `/Users/gregor/dev/922/HomeStructure/docs/config/storage.md` — storage layout (MinIO data goes on `/mnt/storage`)

**What to create:**

1. **`/Users/gregor/dev/922/HomeStructure/minio/.env`** with:
   ```
   MINIO_ROOT_USER=<generate a secure username>
   MINIO_ROOT_PASSWORD=<generate a secure 32+ char password>
   ```

2. **`/Users/gregor/dev/922/HomeStructure/minio/docker-compose.yaml`**:
   - Image: `minio/minio:latest`
   - Container name: `minio`
   - Command: `server /data --console-address ":9001"`
   - Env file: `.env`
   - Volume: `/mnt/storage/minio:/data` (persistent storage on the 700GB ext4 drive)
   - Networks: `proxy` (external, for Traefik routing) + `infra` (external, for internal access by Drafter/other services)
   - Healthcheck: `curl -f http://localhost:9000/minio/health/live || exit 1`
   - Labels: `922.group=Infrastructure`
   - Two Traefik router pairs:
     - **API** (`minio.922-studio.com` → port 9000): Public, no auth (MinIO has its own auth for write; public read for serving media)
     - **Console** (`minio-console.922-studio.com` → port 9001): No external access needed — bind console to `127.0.0.1:9001` only, accessible via SSH tunnel
   - Resource limits: 512MB memory
   - Restart policy: `unless-stopped`

   ```yaml
   services:
     minio:
       image: minio/minio:latest
       container_name: minio
       command: server /data --console-address ":9001"
       env_file:
         - .env
       volumes:
         - /mnt/storage/minio:/data
       ports:
         - "127.0.0.1:9001:9001"  # Console (SSH tunnel only)
       networks:
         - proxy
         - infra
       restart: unless-stopped
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
         interval: 10s
         timeout: 5s
         retries: 5
         start_period: 10s
       deploy:
         resources:
           limits:
             memory: 512M
       labels:
         - "922.group=Infrastructure"
         # Traefik: MinIO API (public read for media serving)
         - "traefik.enable=true"
         - "traefik.http.routers.minio.rule=Host(`minio.922-studio.com`)"
         - "traefik.http.routers.minio.entrypoints=web"
         - "traefik.http.services.minio.loadbalancer.server.port=9000"

   networks:
     proxy:
       external: true
     infra:
       external: true
   ```

- **Acceptance criteria**:
  - [ ] `docker-compose.yaml` is valid (`docker compose config` passes)
  - [ ] `.env` contains secure credentials (not default `minioadmin`)
  - [ ] Data directory mapped to `/mnt/storage/minio`
  - [ ] Container joins both `proxy` and `infra` networks

---

### Step 2: Deploy MinIO on Server

- **Project**: HomeStructure (server)
- **Directory**: `ssh lab` → `~/HomeStructure/minio/`
- **Parallel with**: —
- **Depends on**: Step 1
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeStructure/scripts/homelab-ctl.sh` — for startup order
  - `/Users/gregor/dev/922/HomeStructure/docs/config/storage.md` — verify `/mnt/storage` is mounted

**Tasks (run on server via SSH):**

1. **Create storage directory**:
   ```bash
   ssh lab "sudo mkdir -p /mnt/storage/minio && sudo chown 1000:1000 /mnt/storage/minio"
   ```

2. **Push compose + env to server**:
   ```bash
   scp -r ~/dev/922/HomeStructure/minio lab:~/HomeStructure/minio/
   ```

3. **Start MinIO**:
   ```bash
   ssh lab "cd ~/HomeStructure/minio && docker compose up -d"
   ```

4. **Verify container is running and healthy**:
   ```bash
   ssh lab "docker ps --filter name=minio --format '{{.Names}} {{.Status}}'"
   ssh lab "docker logs minio --tail 20"
   ```

5. **Verify internal network access** (from another container on `infra`):
   ```bash
   ssh lab "docker exec drafter_dev curl -s http://minio:9000/minio/health/live"
   ```

- **Acceptance criteria**:
  - [ ] MinIO container running and healthy
  - [ ] `/mnt/storage/minio` exists with correct permissions
  - [ ] MinIO reachable from `infra` network at `minio:9000`
  - [ ] Console accessible via `ssh -L 9001:localhost:9001 lab` → `http://localhost:9001`

---

### Step 3: Configure Cloudflare Tunnel Route

- **Project**: HomeStructure (server)
- **Directory**: `ssh lab`
- **Parallel with**: —
- **Depends on**: Step 2
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeStructure/docs/config/cloudflare.md` — tunnel config location and patterns

**Tasks (run on server via SSH):**

1. **Add tunnel route** to `/etc/cloudflared/config.yml`:
   ```yaml
   - hostname: minio.922-studio.com
     service: http://localhost:80
   ```
   Add this ABOVE the catch-all entry. Since the `*.922-studio.com` wildcard CNAME already exists, no DNS record is needed.

2. **Restart cloudflared**:
   ```bash
   ssh lab "sudo systemctl restart cloudflared"
   ```

3. **Verify public access**:
   ```bash
   curl -s https://minio.922-studio.com/minio/health/live
   ```

- **Acceptance criteria**:
  - [ ] `minio.922-studio.com` resolves and returns MinIO health check
  - [ ] Cloudflared service running without errors

---

### Step 4: Create Bucket & Set Policies

- **Project**: HomeStructure (server)
- **Directory**: `ssh lab`
- **Parallel with**: —
- **Depends on**: Step 3
- **Context files to read**:
  - MinIO client (mc) documentation

**Tasks (run on server via SSH):**

1. **Install MinIO client inside the container** (or use the host):
   ```bash
   ssh lab "docker exec minio mc alias set local http://localhost:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD"
   ```
   Note: The env vars are inside the container, so pass them via docker exec with the env.

   Alternative (using docker exec with env):
   ```bash
   ssh lab "docker exec minio sh -c 'mc alias set local http://localhost:9000 \$MINIO_ROOT_USER \$MINIO_ROOT_PASSWORD'"
   ```

2. **Create the `drafter-media` bucket**:
   ```bash
   ssh lab "docker exec minio sh -c 'mc mb local/drafter-media --ignore-existing'"
   ```

3. **Set public read policy** (so uploaded images are viewable without auth):
   ```bash
   ssh lab "docker exec minio sh -c 'mc anonymous set download local/drafter-media'"
   ```

4. **Verify bucket and policy**:
   ```bash
   ssh lab "docker exec minio sh -c 'mc ls local/drafter-media'"
   ssh lab "docker exec minio sh -c 'mc anonymous get local/drafter-media'"
   ```

5. **Test upload and public access**:
   ```bash
   # Upload a test file
   ssh lab "echo 'test' | docker exec -i minio sh -c 'mc pipe local/drafter-media/test.txt'"
   # Verify public access
   curl -s https://minio.922-studio.com/drafter-media/test.txt
   # Clean up
   ssh lab "docker exec minio sh -c 'mc rm local/drafter-media/test.txt'"
   ```

- **Acceptance criteria**:
  - [ ] `drafter-media` bucket exists
  - [ ] Public read policy set (anonymous download)
  - [ ] Test file uploadable and publicly accessible via `https://minio.922-studio.com/drafter-media/test.txt`
  - [ ] Test file cleaned up

---

### Step 5: Update Drafter Environment Variables

- **Project**: Drafter
- **Directory**: `/Users/gregor/dev/922/Drafter`
- **Parallel with**: —
- **Depends on**: Step 4
- **Context files to read**:
  - `/Users/gregor/dev/922/Drafter/.env.dev`
  - `/Users/gregor/dev/922/Drafter/.env.prod`
  - `/Users/gregor/dev/922/HomeStructure/minio/.env` — for the credentials set in Step 1

**Tasks:**

1. **Update `.env.dev`** — Replace placeholder credentials with actual MinIO credentials from Step 1:
   ```
   # Object Storage
   S3_ENDPOINT=http://minio:9000
   S3_PUBLIC_URL=https://minio.922-studio.com
   S3_ACCESS_KEY=<MINIO_ROOT_USER from Step 1>
   S3_SECRET_KEY=<MINIO_ROOT_PASSWORD from Step 1>
   S3_BUCKET=drafter-media
   S3_REGION=us-east-1
   ```

2. **Update `.env.prod`** — Same credentials:
   ```
   # Object Storage
   S3_ENDPOINT=http://minio:9000
   S3_PUBLIC_URL=https://minio.922-studio.com
   S3_ACCESS_KEY=<MINIO_ROOT_USER from Step 1>
   S3_SECRET_KEY=<MINIO_ROOT_PASSWORD from Step 1>
   S3_BUCKET=drafter-media
   S3_REGION=us-east-1
   ```

3. **Deploy env files to server**:
   ```bash
   scp ~/dev/922/Drafter/.env.dev lab:~/Drafter-dev/.env
   scp ~/dev/922/Drafter/.env.prod lab:~/Drafter/.env
   ```

4. **Restart Drafter containers**:
   ```bash
   ssh lab "cd ~/Drafter-dev && docker compose -f docker-compose.deploy.yaml up -d"
   ssh lab "cd ~/Drafter && docker compose -f docker-compose.deploy.yaml up -d"
   ```

- **Acceptance criteria**:
  - [ ] Both env files have real MinIO credentials (not `minioadmin`)
  - [ ] `S3_ENDPOINT` is `http://minio:9000` (Docker internal)
  - [ ] `S3_PUBLIC_URL` is `https://minio.922-studio.com` (public access)
  - [ ] Drafter containers restarted with new env

---

### Step 6: End-to-End Upload Testing

- **Project**: Drafter
- **Directory**: Browser + server
- **Parallel with**: —
- **Depends on**: Step 5

**Manual test steps:**

1. **Open** `https://drafter-dev.922-studio.com` in browser
2. **Navigate to Media page** → Upload a 640x640 PNG
3. **Verify**:
   - Upload progress bar shows
   - Image appears in the media grid after upload
   - Click image thumbnail → opens full size
   - Image URL is `https://minio.922-studio.com/drafter-media/<orgId>/media/<uuid>.png`
4. **Navigate to Posts** → Create new post → Attach media
5. **Navigate to Branding** → Upload avatar image
6. **Check server-side**:
   ```bash
   ssh lab "docker exec minio sh -c 'mc ls local/drafter-media --recursive'"
   ```
   Verify uploaded files exist in the bucket.
7. **Check Drafter logs for errors**:
   ```bash
   ssh lab "docker logs drafter_dev --tail 50"
   ```

**Automated verification:**
```bash
# Verify MinIO health from Drafter container
ssh lab "docker exec drafter_dev curl -sf http://minio:9000/minio/health/live && echo 'OK'"

# Verify public URL works
curl -sf https://minio.922-studio.com/minio/health/live && echo "Public OK"
```

- **Acceptance criteria**:
  - [ ] Image upload succeeds (no errors in browser console)
  - [ ] Uploaded image displays correctly in Media page
  - [ ] Image URL resolves publicly via `minio.922-studio.com`
  - [ ] Post media attachment works
  - [ ] Brand avatar upload works
  - [ ] Files visible in MinIO bucket
  - [ ] No errors in Drafter container logs

---

### Step 7: Update HomeStructure Documentation

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure/docs/`
- **Parallel with**: —
- **Depends on**: Step 6
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeStructure/docs/` — existing doc structure
  - `/Users/gregor/dev/922/HomeStructure/docs/neue-services-einrichten.md` — service guide

**Tasks:**

1. **Create `/Users/gregor/dev/922/HomeStructure/docs/services/minio.md`** with:
   - Overview (what MinIO provides, who uses it)
   - Container details (image, ports, networks, volumes)
   - Access patterns:
     - Internal: `http://minio:9000` from `infra` network
     - Public: `https://minio.922-studio.com` for media serving
     - Console: `ssh -L 9001:localhost:9001 lab` → `http://localhost:9001`
   - Bucket list and policies (`drafter-media` → public read)
   - Credentials location (`~/HomeStructure/minio/.env`)
   - Backup strategy (data on `/mnt/storage/minio`)
   - Adding new buckets (for future services)
   - Troubleshooting (health check, logs, mc commands)

2. **Update `/Users/gregor/dev/922/HomeStructure/docs/config/storage.md`** — Add MinIO data directory under `/mnt/storage/minio`

3. **Commit and push HomeStructure** docs changes

- **Acceptance criteria**:
  - [ ] `docs/services/minio.md` exists with complete documentation
  - [ ] `docs/config/storage.md` updated with MinIO data path
  - [ ] Changes committed and pushed

---

### Step 8: Update Planner References

- **Project**: Planner
- **Directory**: `/Users/gregor/dev/922/Planner`
- **Parallel with**: Step 7
- **Depends on**: Step 6

**Tasks:**

1. **Update `server.md`** — Add MinIO to:
   - **Public Routes** table: `minio.922-studio.com → Traefik :80 → MinIO (public read)`
   - **All Services & Ports** → Infrastructure Services: `MinIO | 9000 (API), 9001 (console, localhost only) | minio`
   - **Docker Networks** → `infra`: Add MinIO to connected services list

2. **Update `projects/drafter.md`** — Add MinIO to Dependencies section:
   ```
   - **MinIO**: Object storage for media uploads (S3-compatible, `minio:9000` on `infra` network)
   ```

3. **Commit and push Planner** changes

- **Acceptance criteria**:
  - [ ] `server.md` lists MinIO service, port, route, and network
  - [ ] `projects/drafter.md` lists MinIO dependency
  - [ ] Changes committed and pushed

---

### Step 9: Add MinIO to homelab-ctl.sh

- **Project**: HomeStructure
- **Directory**: `/Users/gregor/dev/922/HomeStructure/scripts/`
- **Parallel with**: Steps 7 + 8
- **Depends on**: Step 6
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeStructure/scripts/homelab-ctl.sh` — STACKS and STARTUP_ORDER arrays

**Tasks:**

1. **Update `homelab-ctl.sh`** — Add `minio` to:
   - `STACKS` array (maps stack name to compose directory)
   - `STARTUP_ORDER` array — position after `infra`, before `traefik` (since Traefik needs MinIO to be up for routing)

2. **Update `deploy-envs.sh`** — Add MinIO env file sync:
   ```bash
   scp ~/dev/922/HomeStructure/minio/.env lab:~/HomeStructure/minio/.env
   ```

3. **Commit and push HomeStructure** changes

- **Acceptance criteria**:
  - [ ] `homelab-ctl.sh status` shows MinIO
  - [ ] `homelab-ctl.sh up minio` works
  - [ ] `deploy-envs.sh` syncs MinIO env file

---

### Step 10: Add MinIO to HomeCollector Monitoring

- **Project**: HomeCollector (optional, recommended)
- **Directory**: server config
- **Parallel with**: Steps 7-9
- **Depends on**: Step 6
- **Context files to read**:
  - `/Users/gregor/dev/922/Planner/projects/homeapi.md` — for HomeCollector uptime pattern

**Tasks:**

1. **Verify HomeCollector auto-detects MinIO** — HomeCollector monitors all running Docker containers automatically. Verify `minio` appears in the status dashboard at `https://status.922-studio.com`.

2. **Add uptime check** for `https://minio.922-studio.com/minio/health/live` if not auto-detected.

- **Acceptance criteria**:
  - [ ] MinIO visible on status dashboard
  - [ ] Health endpoint monitored

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Create MinIO docker-compose → HomeStructure @ ~/HomeStructure/minio/

Wave 2 (after Wave 1):
  Step 2: Deploy MinIO on server → ssh lab
  Step 3: Configure Cloudflare tunnel → ssh lab
  Step 4: Create bucket & policies → ssh lab

Wave 3 (after Wave 2):
  Step 5: Update Drafter env files → Drafter @ ~/dev/922/Drafter

Wave 4 (after Wave 3):
  Step 6: End-to-end upload testing → Browser + server

Wave 5 (after Wave 4, parallel):
  Step 7: Update HomeStructure docs → HomeStructure @ ~/HomeStructure/docs/
  Step 8: Update Planner references → Planner @ ~/dev/922/Planner
  Step 9: Add to homelab-ctl.sh → HomeStructure @ ~/HomeStructure/scripts/
  Step 10: Verify HomeCollector monitoring → status dashboard
```

## Post-Execution Checklist

- [ ] MinIO container running and healthy on server
- [ ] `drafter-media` bucket exists with public read policy
- [ ] `minio.922-studio.com` publicly accessible
- [ ] Image upload works end-to-end in Drafter (dev)
- [ ] Image upload works end-to-end in Drafter (prod)
- [ ] Uploaded images display correctly in Media, Posts, and Branding pages
- [ ] HomeStructure docs updated (`docs/services/minio.md`, `docs/config/storage.md`)
- [ ] Planner references updated (`server.md`, `projects/drafter.md`)
- [ ] `homelab-ctl.sh` manages MinIO lifecycle
- [ ] MinIO monitored on status dashboard
- [ ] All changes committed and pushed
- [ ] Pipeline green after push
