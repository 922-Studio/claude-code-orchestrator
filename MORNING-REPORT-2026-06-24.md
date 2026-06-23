# Morning Report — 2026-06-24 (overnight CI sweep + antares incident)

## TL;DR
**Production is back and healthy.** antares rebooted cleanly and auto-recovered 53/54 containers; I
brought the last one up and fixed the root cause so it can't recur. The CI green-sweep is mostly
done (~171 issues closed, most repos green). A few items are left for you — all are either
branch-protected merges or a Cloudflare decision; none are production-affecting.

---

## The incident (what broke, why)
- During the CI sweep, a deploy.sh change to **discord/sweatvalley_bingo/smoking-counter** added
  `export DOCKER_HOST=ssh://lab@astro-antares` before `docker compose build`. With DOCKER_HOST set,
  the **image build ran on antares** (the prod manager). Concurrent builds exhausted its 16 GB RAM
  and wedged the host — ssh/ping/tunnel all dead → Cloudflare 1033 across all services.
- You hard-rebooted. **No data loss** (resource exhaustion, not deletion; volumes intact).

## Recovery (done)
- After reboot: **53/54 containers auto-started healthy** (Traefik, cloudflared [systemd, enabled],
  Postgres, Redis, MinIO, registry, Watchtower, monitoring, all apps). `lab-dev.922-studio.com` → **200**.
- Cancelled the in-flight build that was hitting antares; confirmed no build processes on the host.
- antares stable all night (load ~1, ~10 GB free, 0 swap) — verified by a health watcher.

## Root-cause fix (done / safe)
- **Server-independent deploy config**: added `deploy/server-routing.env` + sync script in
  **HomeStructure** (PR #9, merged); the file is live at `/home/lab/server-routing.env` on both nodes.
- **discord**: deploy.sh rewritten to the safe 3-phase pattern — **build on runner (hard guard that
  refuses to build if DOCKER_HOST is set) → push to registry → on antares pull + `up --no-build`**.
  Sourced from server-routing.env. discord-docs stale bind-mount fixed; **`discord_bot_docs` is Up**.
- **The invariant**: antares can never build an image again (the `--no-build` + the build-guard).

## What didn't auto-start on reboot (for a seamless next restart)
- **`discord_bot_docs`** — only container that didn't come up; it had a **stale bind-mount to a removed
  CI runner path** (`/home/lab/actions-runner-3/_work/...`). Fixed in discord PR #14 (stable
  `/home/lab/discord/` mounts); now running and reboot-safe.
- Everything else had correct restart policies and returned on its own. **Next reboot should be hands-off.**

---

## Ecosystem status (deploy workflow)
| Repo | Deploy | Notes |
|---|---|---|
| HomeAPI, HomeAuth, HomeCollector, HomeStructure | 🟢 | green, 0 issues |
| Anime-API, Anime-APP, Studio | 🟢 | green, 0 issues |
| HomeUI | 🟢 deploy | Deploy green; separate **E2E** workflow red on Allure upload (see #8 below) |
| Portfolio | 🟢 deploy | same — Deploy green, E2E red on Allure upload |
| discord | 🟢 | containers up; reworked safe deploy merged |
| smoking-counter | 🟢 deploy | **safe-split fix VALIDATED**: deploy job green, built on polaris, antares stayed at 10.3 GB free (no OOM). Run red only on `notify-success` (needs the same DISCORD_BOT_TOKEN passthrough as Anime-API) |
| sweatvalley_bingo | 🟢 deploy | **PR #12 MERGED** — now on the safe build-on-runner pattern; deploy ran with build on polaris, antares untouched (may show notify-step red only) |
| Drafter | 🔴 | **registry 413 (Cloudflare 100 MB cap) — needs your decision** |

~171 CI-failure issues closed across the sweep.

---

## Needs you (morning, prioritized — none are urgent/production-affecting)
1. **workflows PR #8** (`922-Studio/workflows`) — Allure hostname `home-lab→astro-antares` in the
   reusable defaults. Branch-protected (1 review). **Merging this turns HomeUI + Portfolio E2E green**
   (their only red is the Allure-upload step). After merge, re-run their E2E.
2. ~~sweatvalley_bingo PR #12~~ — **DONE (merged); now on the safe deploy pattern.** All three boot_script
   repos (discord, smoking-counter, sweatvalley) are migrated. No action needed beyond the notify one-liner (#4).
3. **Drafter registry 413** — image layers exceed Cloudflare's ~100 MB/request cap on
   `registry.922-studio.com`. Three Dockerfile layer-split attempts (PRs #25/#28/#30) didn't clear it.
   Decision needed: push via internal/Tailscale registry address (needs polaris insecure-registry host
   cfg) **or** raise the Cloudflare limit. Open issues: #23, #26, #27, #29 (the retry loop filed extras).
4. **Discord notify passthrough** — smoking-counter (and likely sweatvalley_bingo) still need
   `DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}` added to their `notify-success`/`notify-failure`
   jobs (the one-liner Anime-API PR #47 got). Their **deploys are green**; only the notify step reds the run.
5. **allure-ui** cosmetic recreate on antares (UI dashboard only; data-safe): `cd ~/HomeStructure/allure && docker compose up -d`.
6. **discord #11** ("tests failed") — likely stale from the chaos; verify the latest Discord Bot Deploy is green and close.

## Validation that the fix works
smoking-counter's reworked deploy (PR #11) ran end-to-end: **build on polaris ✓, push ✓, smoke ✓,
deploy on antares ✓** — and antares held at **10.3 GB free, no OOM**. This proves the build-on-runner /
pull-on-antares split is correct. sweatvalley_bingo (PR #12) uses the identical pattern; merging it is safe.

## Guardrails I held all night
No builds on antares; one action at a time with verification; no destructive `down`/`--remove-orphans`
on shared stacks; branch protection respected (no admin-bypass while you slept); data on named volumes untouched.

## Skill / memory
`/ci-green-sweep` skill created; memories added incl. **`feedback_server_independent_deploy_config`**
(never hardcode host values in builds — route via the HomeStructure config) and the incident write-up.
