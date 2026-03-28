# Plan: Multi-Server Cluster Setup (2 New Execution Servers)

- **Date**: 2026-03-27
- **Project(s)**: HomeStructure, Workflows, all deployed services
- **Goal**: Set up 2 new servers as execution nodes, connected to the main server via Docker Swarm, with full security, monitoring, and CI/CD integration.

## Context

Read these files before proceeding:
- `server.md` — current server reference
- `HomeStructure/docs/config/server.md` — server setup details
- `HomeStructure/docs/config/security.md` — firewall & SSH hardening
- `HomeStructure/docs/config/networking.md` — Tailscale + Cloudflare strategy
- `HomeStructure/docs/services/docker.md` — Docker systemd autostart
- `HomeStructure/docs/services/traefik.md` — Traefik reverse proxy config
- `HomeStructure/docs/services/watchtower.md` — auto-deployment via registry
- `HomeStructure/docs/services/registry.md` — self-hosted Docker Registry
- `HomeStructure/docs/services/github-runner.md` — CI/CD runner setup
- `HomeStructure/docs/config/dev-prod-environments.md` — dev/prod split
- `HomeStructure/docs/services/cloudflare-tunnel.md` — tunnel config
- `HomeStructure/docs/neue-services-einrichten.md` — new service checklist

## Architecture Decision: Docker Swarm

**Why Docker Swarm over Kubernetes or manual Docker Compose:**

| Criteria | Docker Swarm | Kubernetes | Manual Compose per Server |
|----------|-------------|------------|--------------------------|
| Learning curve | Minimal — built into Docker | Steep — new tooling (kubectl, helm, etc.) | None |
| Compose compatibility | Native (`docker stack deploy`) | Requires conversion to manifests | Full but no cross-server orchestration |
| Traefik support | Native Swarm provider | Native but different config | Requires manual Traefik → remote servers |
| Rolling updates | Built-in | Built-in | Manual |
| Service discovery | Built-in overlay network | Built-in (kube-dns) | Manual DNS/IPs |
| Resource overhead | ~50 MB per node | ~500 MB+ per node (kubelet, etcd, etc.) | None |
| Fits existing infra | Yes — uses same Docker, compose files | No — complete rewrite | Partially |

**Recommendation: Docker Swarm** — it's the natural next step from your current Docker Compose setup. Minimal changes, same tooling, Traefik has a native Swarm provider, and Watchtower-style deployments can be replaced by Swarm's built-in rolling updates + your registry.

### Target Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Cloudflare Tunnel            │
                    │    *.922-studio.com → home-lab:80    │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │       home-lab (MANAGER NODE)        │
                    │       Ubuntu 24.04 · Tailscale       │
                    │                                      │
                    │  Traefik (Swarm provider, :80)        │
                    │  cloudflared (Tunnel daemon)          │
                    │  shared_postgres / dev_postgres       │
                    │  shared_redis / dev_redis             │
                    │  Docker Registry (:5000)              │
                    │  Monitoring (Prometheus, Grafana)     │
                    │  Portainer                            │
                    │  GitHub Runners 1-2                   │
                    │                                      │
                    │  Swarm Manager · Overlay Networks     │
                    └───────┬──────────────┬──────────────┘
                            │              │
              Tailscale mesh (encrypted)   │
                            │              │
             ┌──────────────▼───┐   ┌──────▼──────────────┐
             │  exec-1 (WORKER) │   │  exec-2 (WORKER)    │
             │  Ubuntu 24.04    │   │  Ubuntu 24.04        │
             │  Tailscale       │   │  Tailscale           │
             │                  │   │                      │
             │  App containers  │   │  App containers      │
             │  (Swarm tasks)   │   │  (Swarm tasks)       │
             │  Node Exporter   │   │  Node Exporter       │
             │  cAdvisor        │   │  cAdvisor            │
             │  GitHub Runner 3 │   │  GitHub Runner 4     │
             └──────────────────┘   └──────────────────────┘

Swarm overlay networks span all 3 nodes:
  • proxy (overlay)  — Traefik routes to containers on any node
  • infra (overlay)  — DB/Redis access from any node
  • monitor-net (overlay) — Prometheus scrapes all nodes
```

### What Stays on Main Server (home-lab)

| Service | Reason |
|---------|--------|
| Traefik | Single entry point, Swarm-aware, routes to all nodes |
| cloudflared | Tunnel runs on main server, all traffic enters here |
| PostgreSQL (shared + dev) | Stateful, single source of truth |
| Redis (shared + dev) | Stateful, low-latency for Celery |
| Docker Registry | Image source, all nodes pull from here |
| Prometheus + Grafana | Central monitoring |
| Portainer | Central management UI |
| Watchtower | Optional — Swarm rolling updates may replace it |

### What Can Move to Execution Servers

| Service | Why |
|---------|-----|
| HomeAPI (api + worker + beat) | Stateless, connects to DB via overlay |
| HomeAuth | Stateless |
| HomeUI | Static frontend |
| HomeCollector (api + worker + beat) | Stateless |
| Drafter (prod + dev) | Stateless |
| Portfolio, Studio, Anime-* | Stateless frontends |
| Sweatvalley Bingo | Stateless |
| Discord Bot | Stateless |
| GitHub Runners | CPU-bound CI, good to distribute |

---

## Phase 1: Hardware Preparation (Both New Servers)

> Do this physically at each server. Boot from USB installer.

### Step 1.1: Create Ubuntu Server USB Installer
- **Where**: Your Mac/PC
- **Description**: Download Ubuntu Server 24.04.x LTS ISO and flash to USB
- **Commands**:
  ```bash
  # Download Ubuntu Server 24.04 LTS
  # https://ubuntu.com/download/server

  # On macOS, flash with:
  # 1. Find the USB device
  diskutil list
  # 2. Unmount
  diskutil unmountDisk /dev/diskN
  # 3. Flash (replace diskN)
  sudo dd if=ubuntu-24.04.x-live-server-amd64.iso of=/dev/rdiskN bs=4M status=progress
  ```
- **Acceptance criteria**:
  - [ ] Bootable USB with Ubuntu Server 24.04 LTS

### Step 1.2: Wipe SSD & Install Ubuntu on exec-1
- **Where**: Physical server exec-1
- **Parallel with**: Step 1.3
- **Description**: Boot from USB, wipe disk, install Ubuntu Server
- **Installation choices** (match existing main server):
  ```
  Language:           English
  Keyboard:           German (or your layout)
  Network:            DHCP (configure static later or use Tailscale)
  Storage:            Use entire disk with LVM (default)
  Server name:        exec-1
  Username:           lab
  Password:           <your standard password>
  SSH:                Install OpenSSH server ✓
  Featured snaps:     Skip all
  ```
- **Post-install first boot**:
  ```bash
  # Update system
  sudo apt update && sudo apt upgrade -y

  # Check if reboot needed
  [ -f /var/run/reboot-required ] && sudo reboot
  ```
- **Acceptance criteria**:
  - [ ] Ubuntu Server 24.04 LTS installed on exec-1
  - [ ] Can login as `lab` user
  - [ ] System fully updated

### Step 1.3: Wipe SSD & Install Ubuntu on exec-2
- **Where**: Physical server exec-2
- **Parallel with**: Step 1.2
- **Description**: Same as Step 1.2 but with hostname `exec-2`
- **Installation choices**: Same as above, but `Server name: exec-2`
- **Acceptance criteria**:
  - [ ] Ubuntu Server 24.04 LTS installed on exec-2
  - [ ] Can login as `lab` user
  - [ ] System fully updated

---

## Phase 2: Base System Configuration (Both Servers)

> Run on each new server. Steps 2.1-2.6 apply to BOTH exec-1 and exec-2.

### Step 2.1: Passwordless Sudo
- **Where**: exec-1 AND exec-2
- **Commands**:
  ```bash
  sudo visudo
  # Add line:
  # lab ALL=(ALL) NOPASSWD: ALL

  # Verify:
  sudo whoami  # should print "root" without password prompt
  ```

### Step 2.2: SSH Key Setup (from Mac to New Servers)
- **Where**: Your Mac → exec-1 AND exec-2
- **Description**: Copy your existing SSH key to both servers, configure SSH aliases
- **Commands (from Mac)**:
  ```bash
  # Copy your key to each server (use LAN IP initially)
  ssh-copy-id -i ~/.ssh/id_ed25519.pub lab@<exec-1-lan-ip>
  ssh-copy-id -i ~/.ssh/id_ed25519.pub lab@<exec-2-lan-ip>

  # Add to ~/.ssh/config:
  Host exec-1
      HostName <exec-1-tailscale-ip>   # Will update after Tailscale install
      User lab
      IdentityFile ~/.ssh/id_ed25519

  Host exec-2
      HostName <exec-2-tailscale-ip>   # Will update after Tailscale install
      User lab
      IdentityFile ~/.ssh/id_ed25519

  # Test
  ssh exec-1
  ssh exec-2
  ```

### Step 2.3: Install Tailscale
- **Where**: exec-1 AND exec-2
- **Description**: Join both servers to the Tailscale network for encrypted mesh connectivity
- **Commands**:
  ```bash
  # Install
  curl -fsSL https://tailscale.com/install.sh | sh

  # Connect (will give you an auth URL to open in browser)
  sudo tailscale up

  # Verify
  tailscale status
  tailscale ip -4  # Note this IP for SSH config
  ```
- **After Tailscale is up**:
  ```bash
  # Update your Mac's ~/.ssh/config with Tailscale IPs:
  # Host exec-1
  #     HostName 100.x.x.x
  # Host exec-2
  #     HostName 100.y.y.y
  ```
- **Acceptance criteria**:
  - [ ] Both servers visible in Tailscale admin console
  - [ ] `ssh exec-1` and `ssh exec-2` work from Mac via Tailscale
  - [ ] All 3 servers can ping each other via Tailscale IPs

### Step 2.4: SSH Hardening
- **Where**: exec-1 AND exec-2
- **Context files to read**: `HomeStructure/docs/config/security.md` (SSH Hardening section)
- **Commands**:
  ```bash
  # Disable password auth in BOTH files:
  sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf

  # Test config and restart
  sudo sshd -t && sudo systemctl restart ssh

  # Verify
  sudo sshd -T | grep passwordauth
  # Expected: passwordauthentication no
  ```

### Step 2.5: Firewall (ufw) Setup
- **Where**: exec-1 AND exec-2
- **Context files to read**: `HomeStructure/docs/config/security.md` (Firewall section)
- **Commands**:
  ```bash
  sudo apt install ufw -y
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 22/tcp comment 'SSH'
  sudo ufw allow in on tailscale0 comment 'Tailscale - full access'
  sudo ufw enable

  # Verify
  sudo ufw status verbose
  ```

### Step 2.6: Install Docker
- **Where**: exec-1 AND exec-2
- **Commands**:
  ```bash
  # Install Docker via official script
  curl -fsSL https://get.docker.com | sh

  # Add lab user to docker group
  sudo usermod -aG docker lab

  # Log out and back in (or: newgrp docker)

  # Verify
  docker --version
  docker compose version
  docker run hello-world
  ```

### Step 2.7: Docker + ufw Bypass Fix (DOCKER-USER chain)
- **Where**: exec-1 AND exec-2
- **Context files to read**: `HomeStructure/docs/config/security.md` (Docker + ufw Bypass section)
- **Description**: Docker bypasses ufw by default. Apply the same DOCKER-USER iptables rules as the main server.
- **Commands**:
  ```bash
  # Edit /etc/ufw/after.rules
  sudo vim /etc/ufw/after.rules

  # Add inside the existing *filter block, BEFORE the final COMMIT:
  # Docker: allow established + Tailscale + localhost + LAN + Docker bridges, drop rest
  -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
  -A DOCKER-USER -i tailscale0 -j RETURN
  -A DOCKER-USER -s 127.0.0.1 -j RETURN
  -A DOCKER-USER -s 192.168.0.0/16 -j RETURN
  -A DOCKER-USER -s 172.16.0.0/12 -j RETURN
  -A DOCKER-USER -j DROP

  # Reload
  sudo ufw reload

  # Create systemd service for reboot persistence (same as main server)
  sudo tee /etc/systemd/system/ufw-docker-fix.service > /dev/null <<'EOF'
  [Unit]
  Description=Reload ufw after Docker to apply DOCKER-USER chain rules
  After=docker.service
  Requires=docker.service

  [Service]
  Type=oneshot
  ExecStart=/usr/sbin/ufw reload
  RemainAfterExit=true

  [Install]
  WantedBy=multi-user.target
  EOF

  sudo systemctl daemon-reload
  sudo systemctl enable ufw-docker-fix.service
  ```
- **Verify**:
  ```bash
  sudo iptables -L DOCKER-USER -n --line-numbers
  # Expected: same 6 rules as main server
  ```

### Step 2.8: SSH Access from Main Server to Workers
- **Where**: home-lab (main server)
- **Description**: The main server needs SSH access to workers for Swarm management and optional deployment
- **Commands**:
  ```bash
  ssh lab  # Connect to main server

  # Generate key if not exists
  [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -C "lab@home-lab" -N ""

  # Copy key to workers (use Tailscale IPs)
  ssh-copy-id -i ~/.ssh/id_ed25519.pub lab@<exec-1-tailscale-ip>
  ssh-copy-id -i ~/.ssh/id_ed25519.pub lab@<exec-2-tailscale-ip>

  # Add SSH config on main server
  cat >> ~/.ssh/config << 'EOF'

  Host exec-1
      HostName <exec-1-tailscale-ip>
      User lab
      IdentityFile ~/.ssh/id_ed25519

  Host exec-2
      HostName <exec-2-tailscale-ip>
      User lab
      IdentityFile ~/.ssh/id_ed25519
  EOF

  chmod 600 ~/.ssh/config

  # Test
  ssh exec-1 hostname  # Should print "exec-1"
  ssh exec-2 hostname  # Should print "exec-2"
  ```

---

## Phase 3: Docker Swarm Cluster Formation

### Step 3.1: Initialize Swarm on Main Server
- **Where**: home-lab (main server)
- **Description**: Initialize Docker Swarm using the Tailscale IP so worker nodes connect over the encrypted mesh
- **Commands**:
  ```bash
  ssh lab

  # Initialize Swarm — advertise on Tailscale IP so workers connect via VPN
  docker swarm init --advertise-addr 100.112.171.16

  # Get the worker join token (save this!)
  docker swarm join-token worker
  # Output: docker swarm join --token SWMTKN-xxx 100.112.171.16:2377
  ```
- **Acceptance criteria**:
  - [ ] `docker info` shows `Swarm: active` on home-lab
  - [ ] Worker join command noted

### Step 3.2: Open Swarm Ports on All Nodes
- **Where**: home-lab, exec-1, exec-2
- **Description**: Swarm needs ports 2377, 7946, 4789 between nodes. Since all traffic goes over Tailscale (already allowed), no extra ufw rules needed. Verify connectivity.
- **Commands (on each server)**:
  ```bash
  # Swarm ports (2377/tcp, 7946/tcp+udp, 4789/udp) travel over tailscale0
  # which is already allowed by ufw. Verify:
  sudo ufw status | grep tailscale
  # Should show: Anywhere on tailscale0   ALLOW  Anywhere
  ```

### Step 3.3: Join Workers to Swarm
- **Where**: exec-1 AND exec-2
- **Parallel**: Yes, both can join simultaneously
- **Commands**:
  ```bash
  # On exec-1:
  docker swarm join --token SWMTKN-xxx 100.112.171.16:2377

  # On exec-2:
  docker swarm join --token SWMTKN-xxx 100.112.171.16:2377
  ```
- **Verify (from main server)**:
  ```bash
  docker node ls
  # Expected:
  # ID        HOSTNAME    STATUS    AVAILABILITY    MANAGER STATUS
  # xxx *     home-lab    Ready     Active          Leader
  # yyy       exec-1      Ready     Active
  # zzz       exec-2      Ready     Active
  ```
- **Acceptance criteria**:
  - [ ] `docker node ls` shows 3 nodes, all Ready/Active

### Step 3.4: Label Nodes for Placement
- **Where**: home-lab (manager)
- **Description**: Add labels to control which services run where
- **Commands**:
  ```bash
  # Label the main server as the infra node
  docker node update --label-add role=manager home-lab
  docker node update --label-add infra=true home-lab

  # Label workers as execution nodes
  docker node update --label-add role=worker exec-1
  docker node update --label-add role=worker exec-2

  # Verify
  docker node inspect exec-1 --format '{{ .Spec.Labels }}'
  docker node inspect exec-2 --format '{{ .Spec.Labels }}'
  ```

### Step 3.5: Create Overlay Networks
- **Where**: home-lab (manager)
- **Description**: Replace the existing bridge networks with overlay networks that span all nodes
- **Commands**:
  ```bash
  # Create overlay networks (attachable = standalone containers can also join)
  docker network create --driver overlay --attachable proxy_overlay
  docker network create --driver overlay --attachable infra_overlay
  docker network create --driver overlay --attachable monitor_overlay
  ```
- **Note**: The existing `proxy`, `infra`, and `monitor-net` bridge networks remain for non-Swarm services. New Swarm stacks use the overlay variants.

---

## Phase 4: Registry Access & Docker Login on Workers

### Step 4.1: Configure Registry Access
- **Where**: exec-1 AND exec-2
- **Description**: Workers need to pull images from registry.922-studio.com
- **Commands**:
  ```bash
  # Login to the self-hosted registry
  docker login registry.922-studio.com
  # Enter: REGISTRY_USERNAME / REGISTRY_PASSWORD

  # Verify pull works
  docker pull registry.922-studio.com/drafter:prod
  docker rmi registry.922-studio.com/drafter:prod  # Clean up test
  ```
- **Acceptance criteria**:
  - [ ] Both workers can pull from registry.922-studio.com

---

## Phase 5: Monitoring on Worker Nodes

### Step 5.1: Deploy Node Exporter + cAdvisor on Workers
- **Where**: exec-1 AND exec-2
- **Description**: Install the same monitoring exporters as the main server so Prometheus can scrape them
- **Commands**:
  ```bash
  # Create directory on each worker
  mkdir -p ~/monitoring

  # Create docker-compose.yaml
  cat > ~/monitoring/docker-compose.yaml << 'EOF'
  services:
    node-exporter:
      image: prom/node-exporter:latest
      container_name: node_exporter
      ports:
        - "9100:9100"
      volumes:
        - /proc:/host/proc:ro
        - /sys:/host/sys:ro
        - /:/rootfs:ro
      command:
        - '--path.procfs=/host/proc'
        - '--path.sysfs=/host/sys'
        - '--path.rootfs=/rootfs'
        - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
      restart: unless-stopped

    cadvisor:
      image: gcr.io/cadvisor/cadvisor:latest
      container_name: cadvisor
      ports:
        - "8081:8080"
      volumes:
        - /:/rootfs:ro
        - /var/run:/var/run:ro
        - /sys:/sys:ro
        - /var/lib/docker/:/var/lib/docker:ro
      restart: unless-stopped
  EOF

  docker compose -f ~/monitoring/docker-compose.yaml up -d
  ```

### Step 5.2: Update Prometheus Scrape Config
- **Where**: home-lab (main server)
- **Context files to read**: `HomeStructure/monitoring/prometheus/prometheus.yaml`
- **Description**: Add scrape targets for the new worker nodes
- **Add to prometheus.yaml**:
  ```yaml
  # Worker node metrics
  - job_name: 'node-exporter-exec-1'
    static_configs:
      - targets: ['<exec-1-tailscale-ip>:9100']
        labels:
          instance: 'exec-1'

  - job_name: 'node-exporter-exec-2'
    static_configs:
      - targets: ['<exec-2-tailscale-ip>:9100']
        labels:
          instance: 'exec-2'

  - job_name: 'cadvisor-exec-1'
    static_configs:
      - targets: ['<exec-1-tailscale-ip>:8081']
        labels:
          instance: 'exec-1'

  - job_name: 'cadvisor-exec-2'
    static_configs:
      - targets: ['<exec-2-tailscale-ip>:8081']
        labels:
          instance: 'exec-2'
  ```
- **Restart Prometheus**:
  ```bash
  docker compose -f ~/HomeStructure/monitoring/docker-compose.yaml restart prometheus
  ```
- **Verify**: `curl http://localhost:9090/api/v1/targets` — all 4 new targets should be UP

---

## Phase 6: GitHub Runners on Workers

### Step 6.1: Install GitHub Runners on Workers
- **Where**: exec-1 AND exec-2
- **Context files to read**: `HomeStructure/docs/services/github-runner.md` (Adding Another Runner section)
- **Description**: Move runners 3-4 (or add new ones) to the worker nodes to distribute CI load
- **Commands (per worker, adjust N)**:
  ```bash
  # Get runner version from main server
  RUNNER_VERSION=2.332.0
  RUNNER_TARBALL=actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

  # Download
  curl -o ~/${RUNNER_TARBALL} -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TARBALL}

  # Extract
  mkdir -p ~/actions-runner
  tar xzf ~/${RUNNER_TARBALL} -C ~/actions-runner

  # Configure (get token from GitHub → 922-Studio org → Actions → Runners)
  cd ~/actions-runner
  ./config.sh \
    --url https://github.com/922-Studio \
    --token <TOKEN> \
    --name <exec-1 or exec-2> \
    --labels self-hosted,Linux,X64 \
    --unattended

  # Install and start as service
  sudo ./svc.sh install lab
  sudo ./svc.sh start
  ```
- **Acceptance criteria**:
  - [ ] Runners visible in GitHub → 922-Studio → Settings → Actions → Runners
  - [ ] Runners show as "Idle" / connected

---

## Phase 7: Migrate First Service to Swarm (Pilot)

> Start with a stateless, low-risk service to validate the setup.

### Step 7.1: Pilot — Deploy Portfolio via Swarm Stack
- **Where**: home-lab (manager)
- **Description**: Convert Portfolio from `docker compose` to `docker stack deploy` as a pilot test
- **Create stack file** `~/portfolio-stack.yaml`:
  ```yaml
  version: "3.8"
  services:
    portfolio:
      image: registry.922-studio.com/portfolio:prod
      networks:
        - proxy_overlay
      deploy:
        replicas: 1
        placement:
          constraints:
            - node.role == worker
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.portfolio.rule=Host(`gregor.922-studio.com`)"
          - "traefik.http.routers.portfolio.entrypoints=web"
          - "traefik.http.services.portfolio.loadbalancer.server.port=3000"

  networks:
    proxy_overlay:
      external: true
  ```
- **Note**: Before this works, Traefik needs to be configured with the Swarm provider (Step 7.2).

### Step 7.2: Update Traefik for Swarm Provider
- **Where**: home-lab
- **Context files to read**: `HomeStructure/traefik/docker-compose.yaml`
- **Description**: Add Swarm provider to Traefik so it discovers services deployed as stacks
- **Additional Traefik command flags**:
  ```
  --providers.swarm=true
  --providers.swarm.exposedbydefault=false
  --providers.swarm.network=proxy_overlay
  ```
- **Important**: Keep the Docker provider active too — non-Swarm services still need it
- **Restart Traefik after config change**

### Step 7.3: Deploy and Verify Pilot
- **Where**: home-lab (manager)
- **Commands**:
  ```bash
  # Deploy the stack
  docker stack deploy -c ~/portfolio-stack.yaml portfolio

  # Verify
  docker stack services portfolio
  docker service ps portfolio_portfolio

  # Check which node it's running on
  docker service ps portfolio_portfolio --format "{{.Node}}"

  # Test via curl
  curl -H "Host: gregor.922-studio.com" http://localhost:80
  ```
- **Acceptance criteria**:
  - [ ] Portfolio running on a worker node
  - [ ] Accessible via gregor.922-studio.com
  - [ ] Traefik routes correctly across the overlay network

---

## Phase 8: Full Service Migration Plan

> After the pilot succeeds, migrate services in waves. Each service needs:
> 1. Image pushed to registry (if not already using Watchtower flow)
> 2. Stack YAML created
> 3. Placement constraints defined
> 4. Old docker-compose service stopped
> 5. Stack deployed
> 6. Verification

### Migration Waves

**Wave 1 — Static Frontends (low risk)**:
- Portfolio ✓ (pilot)
- Studio
- Anime-APP
- Sweatvalley Bingo

**Wave 2 — Standalone APIs**:
- Anime-API
- HomeAuth (prod + dev)

**Wave 3 — Core Services with Workers**:
- HomeAPI (api + worker + beat + flower)
- HomeCollector (api + worker + beat + flower)

**Wave 4 — Complex Services**:
- Drafter (prod + dev + PR previews)
- HomeUI (prod + dev)

**Wave 5 — Remaining**:
- Discord Bot

### Placement Strategy

| Service Type | Placement | Why |
|-------------|-----------|-----|
| Infrastructure (DB, Redis, Registry, Traefik) | `node.labels.infra == true` (home-lab only) | Stateful, needs local volumes |
| Monitoring (Prometheus, Grafana) | `node.labels.infra == true` | Needs access to all scrape targets |
| Application services | `node.role == worker` | Offload compute to execution nodes |
| GitHub Runners | Distributed across workers | Parallel CI |

---

## Phase 9: CI/CD Adaptation

### Step 9.1: Update Deployment Workflows
- **Where**: 922-Studio/workflows repo
- **Description**: Current `deploy-docker.yml` does `git pull + docker compose up` on the server. For Swarm, it needs to push to the registry and let Swarm/Watchtower roll out.
- **New flow**:
  ```
  Current:  Build → Test → SSH → git pull → docker compose up
  New:      Build → Test → Push to Registry → docker service update (or Watchtower)
  ```
- **Option A — Watchtower (keep existing)**:
  - Watchtower already polls the registry and swaps containers
  - Works with Swarm too — each node's Watchtower instance updates local containers
  - **Simplest migration path**

- **Option B — Swarm rolling update via CI**:
  ```yaml
  # In GitHub Actions after image push:
  - name: Deploy to Swarm
    run: |
      ssh lab "docker service update --image registry.922-studio.com/myapp:$TAG myapp_api"
  ```
  - More control over rollout timing
  - Can add health checks and rollback

### Step 9.2: Update deploy-envs.sh
- **Where**: HomeStructure scripts
- **Description**: Deploy .env files to worker nodes too
- **Extend script to SCP envs to exec-1 and exec-2**

---

## Phase 10: Documentation

### Step 10.1: Create Worker Node Setup Guide
- **Where**: `HomeStructure/docs/config/worker-nodes.md`
- **Description**: Repeatable guide for adding new worker nodes in the future
- **Contents**:
  - Hardware requirements
  - Ubuntu installation reference
  - Base setup checklist (copy from Phase 2)
  - Swarm join procedure
  - Registry login
  - Monitoring setup
  - Runner installation
  - Verification checklist

### Step 10.2: Update Existing Docs
- **Where**: HomeStructure/docs/
- **Files to update**:
  - `config/server.md` — Add exec-1 and exec-2 entries
  - `config/networking.md` — Add worker Tailscale IPs
  - `config/security.md` — Note that same rules apply to workers
  - `services/docker.md` — Add Swarm section
  - `services/traefik.md` — Document Swarm provider config
  - `services/github-runner.md` — Update runner table with worker nodes
  - `services/monitoring.md` — Document multi-node scraping
  - `project-info/architecture.md` — Update architecture diagram for 3-node cluster
  - `neue-services-einrichten.md` — Update for Swarm deployment

### Step 10.3: Update Planner References
- **Where**: Planner repo
- **Files to update**:
  - `server.md` — Add exec-1, exec-2 reference
  - `registry.md` — Note Swarm architecture

---

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Phase 1 — Hardware Prep (physical, ~1-2 hours):
  Step 1.1: Create USB installer
  Step 1.2: Install Ubuntu on exec-1       ← parallel
  Step 1.3: Install Ubuntu on exec-2       ← parallel

Phase 2 — Base Config (~30 min per server, parallel on both):
  Step 2.1: Passwordless sudo              ← both servers
  Step 2.2: SSH key setup                  ← from Mac
  Step 2.3: Install Tailscale              ← both servers
  Step 2.4: SSH hardening                  ← both servers
  Step 2.5: Firewall setup                 ← both servers
  Step 2.6: Install Docker                 ← both servers
  Step 2.7: Docker + ufw fix              ← both servers
  Step 2.8: SSH from main → workers        ← home-lab

Phase 3 — Swarm Formation (~15 min):
  Step 3.1: Init Swarm on home-lab
  Step 3.2: Verify Swarm ports
  Step 3.3: Join workers to Swarm
  Step 3.4: Label nodes
  Step 3.5: Create overlay networks

Phase 4 — Registry Access (~5 min):
  Step 4.1: Docker login on both workers

Phase 5 — Monitoring (~20 min):
  Step 5.1: Deploy exporters on workers    ← parallel
  Step 5.2: Update Prometheus config       ← home-lab

Phase 6 — GitHub Runners (~15 min):
  Step 6.1: Install runners on workers     ← parallel

Phase 7 — Pilot Service (~30 min):
  Step 7.1: Create Portfolio stack
  Step 7.2: Update Traefik for Swarm
  Step 7.3: Deploy and verify pilot

Phase 8 — Full Migration (iterative):
  Wave 1: Static frontends
  Wave 2: Standalone APIs
  Wave 3: Core services
  Wave 4: Complex services
  Wave 5: Remaining

Phase 9 — CI/CD (~1-2 hours):
  Step 9.1: Update deployment workflows
  Step 9.2: Update env deployment

Phase 10 — Documentation (~1-2 hours):
  Step 10.1: Worker node setup guide (NEW doc)
  Step 10.2: Update existing docs
  Step 10.3: Update Planner references
```

## Post-Execution Checklist

- [ ] All 3 nodes visible in `docker node ls`
- [ ] Workers secured (ufw, SSH keys only, DOCKER-USER chain)
- [ ] Workers on Tailscale mesh
- [ ] Workers can pull from registry.922-studio.com
- [ ] Monitoring covers all nodes (Prometheus targets UP)
- [ ] Pilot service (Portfolio) running on a worker, accessible via browser
- [ ] GitHub Runners distributed across workers
- [ ] CI/CD deploys to Swarm successfully
- [ ] Documentation updated in HomeStructure
- [ ] `server.md` in Planner updated with new server info

## Rollback Plan

If Swarm causes issues, you can always:
1. `docker swarm leave --force` on workers
2. `docker swarm leave --force` on manager
3. Fall back to the original single-server Docker Compose setup
4. All bridge networks and compose files remain untouched during migration
