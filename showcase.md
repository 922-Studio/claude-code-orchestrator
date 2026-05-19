# 922-Studio — What We've Built

> A solo full-stack engineering studio building production-grade web apps, APIs, games, and infrastructure. Everything self-hosted, everything shipped.

---

## The Studio at a Glance

| Metric | Value |
|--------|-------|
| Active projects | 13 |
| Running containers | 52 (38 prod + 14 dev) |
| Public endpoints | 18 subdomains via Cloudflare Tunnel |
| Backend microservices | 5 FastAPI + 1 Next.js API |
| Frontend apps | 2 React SPAs + 3 Next.js sites |
| Standalone apps | Discord bot, real-time multiplayer game |
| Test coverage enforced | 70–85% across all services |
| CI/CD pipelines | 14 reusable workflows, 4 self-hosted runners |
| Infrastructure | 3-node Docker Swarm cluster, zero cloud dependency |

---

## Infrastructure Story

Before the apps, there's the platform. The entire ecosystem runs on a 3-node Docker Swarm cluster (Ubuntu 24.04.4 LTS, Docker 29.3.1) with zero inbound ports. 52 containers in production, every one monitored, versioned, and deployed automatically.

**What this means in practice:**
- Push to `main` → AI analyzes commits → semantic version bump → tests run → zero-downtime deploy → Discord notification
- 18 public subdomains, all behind Cloudflare Tunnel — no exposed ports
- Traefik reverse proxy with forward-auth middleware handles all routing and authentication
- Full dev/prod environment split with database mirroring
- Prometheus + Grafana for metrics, Allure for test reporting, Flower for Celery task monitoring
- Private Docker Registry for container image distribution
- 4 self-hosted GitHub Actions runners on the lab

**The control plane:** `homelab-ctl.sh` — manages the entire infrastructure: databases, containers, backups, deployments, health checks.

---

## Projects

---

### HomeUI — The Dashboard
**Type:** Frontend SPA · **Stack:** React 19, TypeScript, TanStack Query, Tailwind CSS, shadcn/ui
**URL:** lab.922-studio.com

The main interface for the home lab ecosystem. Finance and debt tracking, health and sleep logging, uptime monitoring, system metrics, user management — all in one place.

- React Query with full cache invalidation strategy
- Feature-scoped module architecture (`features/{name}/{pages,components,hooks}/`)
- Zero-radius design system with JetBrains Mono, dark mode default
- E2E tests with Playwright, unit tests with Vitest + Testing Library
- MSW for API mocking in tests

---

### HomeAPI — The Core Backend
**Type:** Backend microservice · **Stack:** Python 3.13, FastAPI, SQLAlchemy async, PostgreSQL, Celery
**URL:** lab-api.922-studio.com

Multipurpose REST backend with 19 database models across 20+ routers: finance, ledger, health, sleep, tasks, ideas, worklogs, memory, email/calendar, AI prompts, Discord integration, Google Sheets sync, scheduled tasks, cron jobs, modules.

- Async SQLAlchemy with connection pooling
- Celery background workers + beat scheduler
- Google Gemini 2.5 Flash integration for AI features and NLP parsing
- 70%+ test coverage enforced in CI
- Strict layered architecture: routers → crud → models with schemas, services, helpers, tasks

---

### HomeAuth — The Security Layer
**Type:** Backend microservice · **Stack:** Python 3.12, FastAPI, SQLAlchemy async, Argon2id
**URL:** auth.922-studio.com

Self-hosted JWT authentication with forward-auth integration for Traefik. Role-based access control, token rotation with reuse detection, account lockout, CSRF protection.

- 15-minute access tokens, 7-day refresh tokens with rotation
- Account lockout: 5 failed attempts, 15-minute window
- Rate limiting: login ≤5/min, register ≤3/min
- Timing attack prevention (always runs password verification, identical error messages)
- Argon2id password hashing
- 85%+ test coverage — highest in the ecosystem

---

### HomeCollector — Monitoring Hub
**Type:** Backend microservice · **Stack:** Python 3.13, FastAPI, Celery, aiodocker
**URL:** lab-collector.922-studio.com (public status page)

Owns all monitoring and data collection: Docker container uptime via socket, HTTP health polling, GitHub Actions analytics, Allure test results aggregation, system metrics, domain monitoring, disk alerts, sleep reminders.

- 52+ containers monitored automatically
- 60-second polling interval with 90-day retention
- Public status endpoint at lab-collector.922-studio.com/status (no auth)
- Disk alerts and sleep reminders via Discord and email

---

### HomeStructure — The Platform Itself
**Type:** Infrastructure · **Stack:** Docker Compose, Traefik, Prometheus, Grafana, Bash

The infrastructure layer that everything runs on. 52 containerized services across a 3-node Swarm cluster, named Docker networks, shared PostgreSQL 16.11 and Redis 7.4.7, centralized monitoring, automated lifecycle management.

- Zero-inbound-port architecture via Cloudflare Tunnel
- Tailscale VPN for private access
- Path-filtered auto-deployment (docs, monitoring, traefik update independently)
- MkDocs documentation sites for all services

---

### Workflows — CI/CD Library
**Type:** Infrastructure · **Stack:** GitHub Actions YAML, Python, Google Gemini API

Centralized reusable workflow library eliminating boilerplate across all 922-Studio repos.

- AI-powered semantic versioning: Gemini 2.5 Flash analyzes Conventional Commits
- Graceful degradation: Gemini unavailable → defaults to PATCH
- Unified Discord + email notifications
- Zero-downtime Docker deployment workflows
- Smoke testing, Allure reporting, E2E dispatch patterns

---

### Discord Bot — EggVault
**Type:** App · **Stack:** Python 3.13, discord.py, SQLAlchemy async, Pillow

Discord bot combining home lab utility with an idle game. Players collect eggs by chatting, manage inventory, unlock areas, encounter rare golden eggs.

- Pure game logic in `game/` modules — zero discord.py imports, fully testable
- Idle mechanics: energy, encounters, rarity (golden/shiny), milestones
- Utility: debt tracking with NLP, ideas with AI refinement, wellbeing logging — all via HomeAPI
- Cog auto-discovery, async database sessions, Allure test reporting

---

### Anime-API + Anime-APP — Collection Manager
**Type:** Fullstack (Backend + Frontend) · **Stack:** Python/FastAPI + React/Vite
**URLs:** anime-api.922-studio.com · anime.922-studio.com

REST API and React SPA for anime collection management. Proxies Jikan (MyAnimeList) for search. First project with a deliberately simple flat architecture.

---

### Portfolio — gregor.922-studio.com
**Type:** Website · **Stack:** Next.js 16, TypeScript, React 19, next-intl, Tailwind CSS

Personal portfolio with multi-language support (EN/DE), dark/light theme, project carousel, testimonials, CV downloads, Google Analytics.

- Locale-first routing with static generation
- Docker multi-stage build: Node 22-Alpine → Nginx
- E2E tested with Playwright

---

### Sweatvalley Bingo — Real-Time Multiplayer Game
**Type:** App (game) · **Stack:** Node.js, Express, Socket.io, React, Vitest, Jest
**URL:** sweatvalley-bingo.922-studio.com · **Version:** 0.7.4

Real-time multiplayer bingo for classroom observation. Teachers create games, students join via code and get randomized 3x3 or 4x4 grids with teacher behavior items. German word set with difficulty classification.

- Socket.io WebSocket-only (no polling) for Cloudflare Tunnel compatibility
- Synchronized real-time scoring across all players
- Pure game logic in `gameLogic.js` for testability
- Server integration tests: Socket.io round-trip validation

---

### Drafter — Content Management Platform
**Type:** Fullstack monorepo · **Stack:** Next.js 16, React 19, TypeScript, Prisma 7, PostgreSQL, MinIO
**URL:** drafter.922-studio.com · **Version:** 0.3.2

Social media content scheduling and drafting platform. Multi-platform support (Instagram Photo+Reel, TikTok, LinkedIn, Facebook) with S3-compatible media storage via MinIO.

- Prisma ORM with 2 models (Post, Media) and full CRUD API
- Internal JWT auth (jose) — independent from HomeAuth
- S3/MinIO media uploads with pre-signed URLs
- Dev/prod image distribution via private Docker Registry
- Watchtower auto-deploys on registry image push

---

## Technology Overview

### Languages
Python 3.12–3.13 · TypeScript 5.8–5.9 · JavaScript/JSX · YAML · Bash

### Backend
FastAPI · SQLAlchemy (async + sync) · Celery · discord.py · Pydantic V2 · Alembic · Argon2id · slowapi

### Frontend
React 18–19 · Next.js 16 · Vite 6–7 · TanStack Query 5 · Tailwind CSS 4 · shadcn/ui · React Router 7 · Prisma 7

### Infrastructure
Docker 29.3.1 · Docker Compose v5.1.1 · Traefik · Prometheus · Grafana · Redis 7.4.7 · PostgreSQL 16.11 · Cloudflare Tunnel · Tailscale · MinIO · Docker Registry · Watchtower

### Testing
pytest · pytest-asyncio · Vitest · Playwright · Jest · Testing Library · MSW · Allure

### External Integrations
Google Gemini API · GitHub API · Jikan/MyAnimeList API · Discord API · Gmail SMTP · Cloudflare

---

## Changelog

> Key milestones, reverse chronological. Dates are approximate.

### March 2026
- **Drafter MVP launched** *(2026-03-27)* — Social media content management platform at drafter.922-studio.com. Next.js 16, Prisma 7, MinIO for media storage. Dev/prod split with private Docker Registry distribution.
- **MinIO deployed** *(2026-03-27)* — S3-compatible object storage for media uploads, integrated with Drafter
- **Private Docker Registry** *(2026-03-25)* — Self-hosted container registry at registry.922-studio.com with htpasswd auth. Used by Drafter, Portfolio, Studio.
- **Dev/Prod environment split** *(2026-03-24)* — Full environment separation with database mirroring, separate subdomains (lab-dev, lab-api-dev, auth-dev, lab-collector-dev, drafter-dev), 14 dev containers
- **Studio landing page launched** *(2026-03-24)* — 922-Studio public landing page at studio.922-studio.com. Built with Next.js 16, React 19, Tailwind CSS 4, next-intl, MDX.
- **3-server lab expansion** *(2026-03-24, in progress)* — Acquired 3 new servers plus full networking hardware. Multi-server cluster setup in progress.
- **HomeCollector became the monitoring hub** — Replaced Uptime Kuma; now owns all uptime monitoring, GitHub Actions analytics, Allure aggregation, system metrics, domain monitoring
- **Watchtower auto-deployment** — Automatic container updates from private registry for labeled services
- **Workflows naming convention** — Standardized caller workflow naming convention and E2E dispatch pattern across all repos
- **Projects module overhauled** — HomeAPI and HomeUI restructured for cleaner domain grouping
- **Zero-downtime deployments rolled out** — Ecosystem-wide deployment upgrade across all services

### February / March 2026 (estimated)
- **HomeAuth production-hardened** — Token reuse detection, account lockout, timing attack prevention, 85%+ test coverage
- **HomeUI monitoring section** — Full uptime dashboard, GitHub Actions view, Allure test history
- **Discord bot EggVault Phase 2** — Golden Reach expansion: golden eggs, new encounters, inventory system

### 2025 (estimated)
- **HomeCollector introduced** — First version of the centralized monitoring and data collection service
- **Workflows library created** — Centralized CI/CD eliminating per-repo boilerplate; AI versioning with Gemini
- **Anime-API + Anime-APP shipped** — First external-facing project pair
- **Sweatvalley Bingo launched** — Real-time multiplayer game with Socket.io
- **Portfolio launched** — Next.js portfolio with multi-language and E2E tests
- **HomeAPI first release** — Core backend with async SQLAlchemy, Celery, multiple domains

---

## What Makes This Different

**Self-hosted, not cloud-dependent.** Everything runs on owned hardware. Zero vendor lock-in. Cloudflare Tunnel and Tailscale for access without exposing a single port.

**Enterprise practices, solo scale.** 70–85% test coverage enforced in CI. Reusable workflow library. AI-powered versioning. Allure test reporting. Prometheus metrics. MkDocs documentation sites.

**Cohesive ecosystem, not isolated projects.** All services share the same auth layer, notification system, monitoring stack, and CI/CD library. A change to Workflows benefits 10+ repos simultaneously.

**Shipped, running, monitored.** Every project has a public URL, health checks, uptime monitoring, and automated deployments. This isn't demo code.

---

## Coming Next

- Drafter Phase 2 — Meta API integration for direct Instagram/Facebook publishing
- Multi-server cluster expansion — 3 new servers with full networking hardware
- Management frontend improvements — admin UI for all services
- Role system overhaul — more granular RBAC across all services
- White/light mode — complete light theme rollout across HomeUI

---

*Last updated: 2026-03-27 | 922-Studio*
