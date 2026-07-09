# 🚀 Orchestrator — Capabilities

**What this scaffold can do.** A living catalog — when a new capability lands (a skill, an
automation, a report, an integration), add a row here in the same session.

> `overview.md` = *where things are* · `CLAUDE.md` = *the rules* · **this** = *what it can do*.

---

## 🗂️ Cross-repo coordination
The core job: author sequenced plans and drive execution across many repos safely.

- **Config-driven behavior** — plan format, execution mode, quality gates, models → `orchestrator.config.json`
- **Worktree + PR discipline**, base-branch policy, quality gates → `CLAUDE.md` + config
- **Reusable agent roles** — planner / executor / reviewer → `prompts/`

## 📋 Planning & handovers
- **Plans** in HTML (design-system styled) or Markdown → `plans/` + `plans/_template.{html,md}`; each leads with a human-only summary and ends with a paste-ready kickoff prompt → `guides/plan-authoring.md`
- **Auto-generated plan index** — one read = status of every plan, works for html *and* md → `plans/INDEX.md` (`python3 scripts/build-plan-index.py`)
- **Session handovers** — pause/resume long work across context limits → `.planning/handover/` + `/create-handover`
- **Cleanup / audit** — classify plans (keep/archive) via the orchestrator-cleanup skill → `scripts/orchestrator-audit.sh`
- **Directory hygiene** — turn-key refresh of this directory → `hub/how-to/HOW-TO-refresh-the-orchestrator.md`

## 🛠️ Skills
Reusable capabilities invoked as slash-commands (installed to `~/.claude/commands/` — see `setup/orchestrator-commands/`):

- **`/project-new` · `/project-remove`** — full project lifecycle (GitHub, infra, monitoring, docs) → `skills/project-lifecycle/`
- **`/ci-green-sweep`** — drive every repo's CI green via sub-agents → `skills/ci-green-sweep/`
- **`/orchestrator-cleanup`** — audit & archive plans, prune deprecated files
- **`/create-handover`** — structured session handoff
- **`/token-diet`** — interactive per-session token-overhead cleanup (MCP servers, CLAUDE.md chain, memory, commands) → `skills/token-diet/`

## ⚙️ Machine setups & automations
Local tooling the orchestrator can install, verify, and fix on its own → `setup/`

| Capability | Lives in |
|---|---|
| 🧰 One-shot new-machine installer (+ migration from an old orchestrator) | `install.sh` |
| 🎛️ Claude Code settings (model, effort, theme, permissions) | `setup/claude-code-settings/` |
| 📊 Context-monitor statusline (model \| effort \| context% \| cost) | `setup/claude-statusline/` |
| ⌨️ Orchestrator slash-commands install | `setup/orchestrator-commands/` |
| 🍺 Daily Homebrew auto-upgrade (launchd) | `setup/brew-autoupgrade/` |
| 🔄 Repo sync — pull every registry repo | `setup/repo-sync/` |
| 🌿 Git freshness hooks — fetch+ff-pull before `worktree add`, safe pull at session start | `setup/git-freshness/` |
| ♻️ Auto-provisioning — semver migrations gated by root `version.txt` (CI patch-bumps) adopt setup changes on every pull via git post-merge/rewrite hooks; Claude-side steps queued as `prompt.md` | `setup/provision/` |
| 🔔 Periodic reminders — config-driven macOS notifications (launchd) | `setup/reminders/` |
| 👤 Personal / machine-specific setups (gitignored) | `setup/local/` |

*Self-service:* say *"X stopped working"* → it finds the setup, runs Verify, applies Fix.
New machine → `bash install.sh`, or reinstall any single piece from its `SETUP.md`.

---

## ➕ Adding a capability
When something new lands, add a row to the right section above — same session.
See `hub/how-to/HOW-TO-change-the-orchestrator.md`.
