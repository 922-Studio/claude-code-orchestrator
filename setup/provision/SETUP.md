# SETUP — Auto-provisioning (semver-versioned adoption of setup changes on pull)

**id:** `provision` · **type:** git hook + CI version-bump + migration runner (shell) · **platform:** any (needs `bash`, `git`, `python3`)

## What it does
Makes the orchestrator **self-updating** via a **semver, forward-only migration** model — the same
`version.txt` pattern the ecosystem's projects use.

- **`version.txt`** at the **repo root** is committed and holds the released version `X.Y.Z`. CI
  **patch-bumps** it on every push to `main` (`.github/workflows/version-bump.yml`); a **manual**
  `version.txt` edit in a push is respected (CI skips the auto-bump) — that's how you do a minor/major
  bump, e.g. to activate a `1.1.0` migration.
- **Migrations** live at `setup/provision/migrations/X.Y.Z-slug/apply.sh` — the `X.Y.Z` is the version
  the migration **activates at**. Each must be **idempotent**.
- **`setup/local/.provisioned-version`** (gitignored, per-machine) is the version this machine last
  provisioned to. Missing = `0.0.0` (fresh machine).
- On each pull the hook runs every migration with **`provisioned < X.Y.Z ≤ version.txt`**, in semver
  order, **stopping at the first failure** (the marker only advances past successes). So a migration
  merged early stays **dormant** until the released `version.txt` catches up to its version.
- A migration folder may include **`prompt.md`** — a Claude-side step a shell hook can't do. When that
  migration runs, provisioning **queues** a pointer into `setup/local/provision-pending.md`; the
  **announce-pending** SessionStart hook surfaces it to Claude next session (only when non-empty →
  zero standing token cost).
- Triggers/plumbing it installs & self-heals each run: `.git/hooks/post-merge` +
  `.git/hooks/post-rewrite` (merge- and rebase-pulls), and the announce-pending SessionStart hook.

## Where it lives
| Path | Purpose |
|---|---|
| `version.txt` (repo root) | **committed** released version `X.Y.Z` (CI patch-bumps) |
| `.github/workflows/version-bump.yml` | CI: patch-bump on push, respect manual edits |
| `setup/provision/provision.sh` | the migration runner (semver-gated) |
| `setup/provision/migrations/X.Y.Z-slug/apply.sh` | a migration, activates at `X.Y.Z` (idempotent) |
| `setup/provision/migrations/X.Y.Z-slug/prompt.md` | optional Claude-side step for that version |
| `setup/provision/announce-pending.sh` | SessionStart hook that surfaces queued prompts |
| `setup/local/.provisioned-version` | gitignored: version this machine last provisioned to |
| `setup/local/provision-pending.md` | gitignored: queued prompt pointers |
| `setup/local/provision.log` | gitignored: append-only run log |
| `.git/hooks/post-merge`, `post-rewrite` | auto-installed triggers (regenerated each run) |

## Install
One-time bootstrap (also done by `install.sh`). From the repo root:
```bash
bash setup/provision/provision.sh        # installs hooks + announcer, runs migrations ≤ version.txt, writes .provisioned-version
```
After this, every `git pull` into the orchestrator re-runs it automatically.

## Verify
```bash
bash setup/provision/provision.sh --list   # released + provisioned version + each migration's status
cat version.txt                            # released version (committed)
cat setup/local/.provisioned-version       # what this machine has provisioned to
ls -l .git/hooks/post-merge .git/hooks/post-rewrite   # both present, executable
```
End-to-end: pull a change that adds a migration whose version ≤ `version.txt` and confirm its effect
landed and `.provisioned-version` rose.

## Shipping a new enhancement (the convention)
Every orchestrator change that must land on machines ships a migration:
1. `mkdir setup/provision/migrations/X.Y.Z-slug/` — `X.Y.Z` = the version it should **activate at**.
   For a normal patch, that's the next patch of the current `version.txt` (CI's auto-bump reaches it).
   For a minor/major, do a **manual `version.txt` bump** in the same push so it activates.
2. Add an **idempotent** `apply.sh` (thin wrapper calling a setup's own `apply.sh`, or ad-hoc logic
   like moving a file / editing settings). Safe under `--force`.
3. If a Claude-side step is needed, add `prompt.md` in the same folder — queued + surfaced.
4. Commit + push. CI reconciles `version.txt`; each machine's next pull runs migrations up to it.
   **Never edit a released migration** — append the next-versioned one instead (append-only ledger).

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Changes not adopted after pull | Real merge/rebase? (hooks fire only when the pull changes something). Run `bash setup/provision/provision.sh`; check `setup/local/provision.log`. |
| Migration stuck at `future` | Its version > `version.txt`. Bump `version.txt` (CI patch, or a manual minor/major commit) to reach it. |
| Hooks missing (fresh clone) | Run the Install one-liner once (git can't track `.git/hooks`). |
| A migration failed | Provisioning stopped; `.provisioned-version` did NOT advance past it. See the `✗ vX.Y.Z … FAILED` log line; fix the migration, re-run. |
| Re-apply everything (self-heal) | `bash setup/provision/provision.sh --force` (re-runs all migrations ≤ `version.txt`; idempotent). |
| Replay from an older state | `echo <X.Y.Z> > setup/local/.provisioned-version` then run (forward-only won't lower it during a run). |
| CI bump loops / double-runs | The bump commit carries `[skip ci]`; ensure branch protection allows the `github-actions[bot]` push. |
| Don't want the session announcer | Remove the `announce-pending` SessionStart entry from `~/.claude/settings.json`. |

## Uninstall
```bash
rm -f .git/hooks/post-merge .git/hooks/post-rewrite      # stop auto-triggering
```
Remove the `announce-pending` SessionStart hook from `~/.claude/settings.json` if desired. Individual
setups are undone via their own `SETUP.md`.
