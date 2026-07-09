# SETUP — Auto-provisioning (adopt setup changes on pull)

**id:** `provision` · **type:** git hook + reconciler (shell) · **platform:** any (needs `bash`, `git`, `python3`)

## What it does
Makes the orchestrator **self-updating**: after every `git pull`, each setup's changes are applied
automatically, so new features/"releases" land on a machine without manual install steps.

- `provision.sh` is an **idempotent reconciler**. It discovers every `setup/<id>/apply.sh`
  (committed + `setup/local/`) and runs each one (**auto-apply-all**), then (re)installs the git
  hooks that re-trigger it.
- It installs **`post-merge`** and **`post-rewrite`** git hooks into the orchestrator's
  `.git/hooks/`, covering both merge-style and rebase-style (`pull.rebase`) pulls. `.git/hooks` is
  not version-controlled, so provisioning owns and refreshes them on every run (self-heals their
  content if a release changes the hook).

**The contract:** a setup opts into auto-adoption by shipping an **idempotent `apply.sh`**. No
`apply.sh` → nothing runs for that setup (it stays manual, per its own `SETUP.md`).

## Where it lives
| Path | Purpose |
|---|---|
| `setup/provision/provision.sh` | the reconciler (run manually, by install.sh, or by the git hooks) |
| `setup/<id>/apply.sh` | per-setup idempotent installer (the adoption unit) |
| `.git/hooks/post-merge`, `.git/hooks/post-rewrite` | auto-installed triggers (regenerated each run) |
| `setup/local/.provision-state` | gitignored: last-provisioned commit + timestamp |
| `setup/local/provision.log` | gitignored: append-only run log |
| `setup/local/provision.skip` | gitignored (optional): setup ids to exclude, one per line |

## Install
One-time bootstrap (also done by `install.sh`, and by the post-install prompt). From the repo root:
```bash
bash setup/provision/provision.sh          # installs the git hooks + applies everything now
```
After this, every `git pull` into the orchestrator re-runs it automatically.

## Verify
```bash
bash setup/provision/provision.sh --list       # what would be applied (respects provision.skip)
ls -l .git/hooks/post-merge .git/hooks/post-rewrite   # both present, executable
cat setup/local/.provision-state               # commit=<sha> after a run
```
End-to-end: pull a change that touches a setup and confirm its `apply.sh` effect landed (e.g. a new
hook shows up in `~/.claude/settings.json`), and `setup/local/provision.log` has a fresh entry.

## Authoring a new auto-adopted setup
1. Add `setup/<id>/apply.sh`, `chmod +x`. Make it **idempotent** — it runs on *every* pull.
2. It should detect "already applied" and no-op (write only on real change; back up before edits).
3. That's it — `provision.sh` discovers it automatically. To keep a setup manual, don't add `apply.sh`.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Changes not adopted after pull | Was it a real merge/rebase (post-merge/post-rewrite fire only when the pull changes something)? Run `bash setup/provision/provision.sh` manually; check `setup/local/provision.log`. |
| Hooks missing (fresh clone) | Run the Install one-liner once; it installs them. They can't ship in git (`.git/hooks` isn't tracked). |
| A setup's apply keeps failing | See the `✗ <id> FAILED — …` line in `provision.log`; run its `apply.sh` directly to debug. |
| Don't want a setup auto-applied | Add its id to `setup/local/provision.skip` (one per line). |
| Provision runs on `git commit --amend` | Expected (post-rewrite). It's idempotent + fast; add noisy setups to `provision.skip` if needed. |

## Uninstall
```bash
rm -f .git/hooks/post-merge .git/hooks/post-rewrite    # stop auto-triggering
```
Individual setups are undone via their own `SETUP.md` **Uninstall**. Removing an `apply.sh` stops
that setup from being re-applied on future pulls.
