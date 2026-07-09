# 🧭 Orchestrator — Map

Reusable planning + execution scaffold for Claude Code across many repos.
*(Framework is committed; ecosystem data lives in gitignored overlays — see `README.md`.)*

```
orchestrator/
│
├── 🧰 install.sh ............... interactive bootstrap for a new machine (+ migration)
├── 📖 CLAUDE.md ................. the rules (ecosystem-agnostic)          → start here
├── ⚙️  orchestrator.config.json . behavior switches (read at session start)
├── 👤 CLAUDE.local.md .......... (gitignored) your ecosystem/machine overlay
│
├── 🚀 CAPABILITIES.md .......... what the orchestrator can do
│
├── 📁 plans/ ................... the work — one file per plan (html or md)
│        ├─ 📋 INDEX.md ......... auto-generated status of every plan (build-plan-index.py)
│        ├─ 🧩 _template.html ... canonical plan template
│        └─ 🗄️  archive/ ........ completed / superseded plans (gitignored)
│
├── 🗂️  projects/ ............... (gitignored) per-project mappings
├── 📇 registry.md · server.md .. (gitignored) project registry + server infra
│
├── 🧠 hub/ .................... strategy + meta-maintenance
│        ├─ how-to/ ............ reusable guides (change/refresh this directory)
│        └─ plans·learnings·discussions/ (gitignored) big-picture notes
│
├── 🛠️  prompts/ · skills/ · scripts/  agent prompts, skills, helper scripts
├── 🎨 pages-design-system.{css,html}  shared design system for html plans
│
├── ⚙️  setup/ ................. Machine Setup Registry (portable local tooling)
│        └─ per-setup Install / Verify / Fix → reproduce on any machine
│
├── 📚 guides/ ................. long-form how-tos
└── 🔄 .planning/handover/ ..... (gitignored) resume a paused session → check here first
```

---

| Need… | Go to |
|---|---|
| 📋 status of every plan at a glance | `plans/INDEX.md` |
| ⚙️ change how the orchestrator behaves | `orchestrator.config.json` |
| 🧹 clean up / refresh this directory | `hub/how-to/HOW-TO-refresh-the-orchestrator.md` |
| 🏗️ reshape this directory's structure | `hub/how-to/HOW-TO-change-the-orchestrator.md` |
| ⏸️ continue last session | `.planning/handover/` |
| 🧰 set up a new machine (or migrate one) | `install.sh` · `hub/how-to/HOW-TO-install-on-a-new-machine.md` |
| 🔧 a setup broke | `setup/` |
| 🚀 see what it can do | `CAPABILITIES.md` |
| 📖 the rules | `CLAUDE.md` (+ `CLAUDE.local.md`) |

> Keep this map live: any structural change updates this file the same session
> (`hub/how-to/HOW-TO-change-the-orchestrator.md`).
