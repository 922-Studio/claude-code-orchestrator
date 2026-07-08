# SETUP — Orchestrator slash-commands

**id:** `orchestrator-commands` · **type:** Claude Code commands · **platform:** any

## What it does
Installs the orchestrator's slash-commands (`/project-new`, `/project-remove`, `/ci-green-sweep`,
and any other `skills/<skill>/commands/*.md`) into `~/.claude/commands/` so Claude Code discovers
them. It **rewrites the absolute orchestrator path** baked into each entry point to wherever this
repo actually lives — so the commands work regardless of clone location or machine.

> Note: `/orchestrator-cleanup` and `/create-handover` are installed the same way if present under
> a skill's `commands/` dir. Command *descriptions* may mention the 922-Studio ecosystem (wording),
> but the installed *paths* are always corrected to the local repo.

## Where it lives
| Path | Purpose |
|---|---|
| `skills/<skill>/commands/*.md` | canonical, version-controlled command entry points |
| `~/.claude/commands/*.md` | where Claude Code reads them (install target) |
| `install.sh` (next to this file) | copies + path-rewrites into place |

## Install
```bash
bash setup/orchestrator-commands/install.sh     # run from the orchestrator root
# or, if cloned elsewhere:
ORCH_ROOT="$(pwd)" bash setup/orchestrator-commands/install.sh
```
Re-run after editing any command file to roll the change out.

## Verify
```bash
ls ~/.claude/commands/
grep -l "$(pwd)" ~/.claude/commands/*.md    # installed files point at THIS repo
```
Expect `project-new.md`, `project-remove.md`, `ci-green-sweep.md` (+ any others) present, and their
internal "Read `.../orchestrator/skills/...`" paths pointing at the current repo. In Claude Code,
`/project-new` etc. autocomplete after a restart.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Command not found in Claude Code | Restart Claude Code; confirm the `.md` exists in `~/.claude/commands/`. |
| Command reads the wrong repo path | Re-run Install from the correct repo root (or set `ORCH_ROOT`). |
| Stale command after editing the skill | Re-run `install.sh` to re-copy. |

## Uninstall
```bash
rm ~/.claude/commands/{project-new,project-remove,ci-green-sweep}.md   # etc.
```
