# SETUP — Repo sync

**id:** `repo-sync` · **type:** shell script · **platform:** any (needs `bash`, `git`)

## What it does
Pulls (or force-resets) every repo listed in the orchestrator's `registry.md` to its current
default branch, in one pass. Generic: the repo list is derived from `registry.md`, not hardcoded —
so it works for any ecosystem once its registry is populated.

## Where it lives
| Path | Purpose |
|---|---|
| `setup/repo-sync/repo-sync.sh` | the script (reads `registry.md`) |
| `~/.local/bin/repo-sync` | optional symlink for convenience |

## Install
```bash
chmod +x setup/repo-sync/repo-sync.sh
# optional: put it on PATH
mkdir -p ~/.local/bin
ln -sf "$(pwd)/setup/repo-sync/repo-sync.sh" ~/.local/bin/repo-sync
```

## Verify
```bash
bash setup/repo-sync/repo-sync.sh --list      # prints the repos it would touch
```
Expect the absolute paths from `registry.md`. If it says "no registry.md", populate the registry
first (via the installer or `/project-new`).

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| "no registry.md" | Create/populate `registry.md` (installer step, or `/project-new`). |
| A repo is skipped | It has uncommitted changes (safe mode). Commit/stash, or use `--reset` to discard. |
| Wrong branch pulled | It pulls the repo's *current* branch; check it out to the intended branch first. |

## Uninstall
```bash
rm -f ~/.local/bin/repo-sync
```
