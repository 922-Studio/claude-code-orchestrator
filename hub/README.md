# 🧠 hub/ — strategy & meta-maintenance

Big-picture space, distinct from the tactical work in `plans/`.

| Subfolder | Purpose | Naming | Tracked? |
|-----------|---------|--------|----------|
| `hub/how-to/` | reusable guides for recurring work & maintaining this directory | `HOW-TO-<topic>.md` | ✅ committed (framework) |
| `hub/plans/` | strategic proposals & action plans (not tactical per-repo plans) | `PLAN-<topic>.md` | 🔒 gitignored (ecosystem) |
| `hub/learnings/` | post-mortems, decisions, patterns worth keeping | `LEARNING-<topic>.md` | 🔒 gitignored |
| `hub/discussions/` | notes, incidents, captured context | `DISCUSSION-<YYYY-MM-DD>-<topic>.md` | 🔒 gitignored |

Rule of thumb: `plans/` = *one repo's task*; `hub/` = *how we work / strategy*. When unsure, ask
which it is. Keep `CLAUDE.md` lean — long procedures live here as `how-to/` docs, linked by a single
pointer line from `CLAUDE.md`.
