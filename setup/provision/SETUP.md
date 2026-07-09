# SETUP — Auto-provisioning (versioned adoption of setup changes on pull)

**id:** `provision` · **type:** git hook + versioned migration runner (shell) · **platform:** any (needs `bash`, `git`, `python3`)

## What it does
Makes the orchestrator **self-updating** via a **versioned, forward-only migration** model — the same
pattern the ecosystem's projects use (a `version.txt` you compare against). After every `git pull`,
each migration numbered **greater than** the version this machine has applied is run in order, then
the version is bumped. New features/"releases" adopt themselves with no manual step.

- **Migrations** live at `setup/provision/migrations/NNNN-slug/apply.sh` — ordered, zero-padded.
  Each is the versioned unit and must be **idempotent**.
- **`setup/local/version.txt`** (gitignored, per-machine) holds the highest version applied here.
  Missing/0 = fresh machine → all migrations run.
- Migrations run **ascending** and **stop at the first failure** — `version.txt` only advances past
  migrations that succeed, so a broken one can't be silently skipped (Alembic-style forward-only).
- A migration folder may include **`prompt.md`** — a Claude-side step (judgment/interactive) that a
  shell hook can't perform. When such a migration runs, provisioning **queues** a pointer into
  `setup/local/provision-pending.md`; the **announce-pending** SessionStart hook prints that queue to
  Claude at the next session (only when non-empty → zero standing token cost).
- Triggers/plumbing it installs & self-heals each run: `.git/hooks/post-merge` +
  `.git/hooks/post-rewrite` (merge- and rebase-pulls), and the announce-pending SessionStart hook.

## Where it lives
| Path | Purpose |
|---|---|
| `setup/provision/provision.sh` | the versioned migration runner |
| `setup/provision/migrations/NNNN-slug/apply.sh` | a versioned migration (idempotent) |
| `setup/provision/migrations/NNNN-slug/prompt.md` | optional Claude-side step for that version |
| `setup/provision/announce-pending.sh` | SessionStart hook that surfaces queued prompts |
| `setup/local/version.txt` | gitignored: highest version applied on this machine |
| `setup/local/provision-pending.md` | gitignored: queued prompt pointers |
| `setup/local/provision.log` | gitignored: append-only run log |
| `.git/hooks/post-merge`, `post-rewrite` | auto-installed triggers (regenerated each run) |

## Install
One-time bootstrap (also done by `install.sh`). From the repo root:
```bash
bash setup/provision/provision.sh        # installs hooks + announcer, runs all migrations, writes version.txt
```
After this, every `git pull` into the orchestrator re-runs it automatically.

## Verify
```bash
bash setup/provision/provision.sh --list   # installed version + each migration's status (applied/PENDING[+prompt])
cat setup/local/version.txt                # highest applied version here
ls -l .git/hooks/post-merge .git/hooks/post-rewrite   # both present, executable
```
End-to-end: pull a change that adds a migration and confirm its effect landed and `version.txt` rose.

## Shipping a new enhancement (the convention)
Every orchestrator enhancement that needs to land on machines ships a migration:
1. `mkdir setup/provision/migrations/NNNN-slug/` — `NNNN` = next number after the highest present.
2. Add an **idempotent** `apply.sh` (thin wrapper calling a setup's own `apply.sh`, or ad-hoc logic
   like moving a file / editing settings). It runs once per machine but must be safe under `--force`.
3. If a Claude-side step is needed, add `prompt.md` in the same folder — it's queued + surfaced.
4. Commit. On every machine's next pull, provisioning runs it and bumps `version.txt`.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Changes not adopted after pull | Real merge/rebase? (hooks fire only when the pull changes something). Run `bash setup/provision/provision.sh`; check `setup/local/provision.log`. |
| Hooks missing (fresh clone) | Run the Install one-liner once (git can't track `.git/hooks`). |
| A migration failed | Provisioning stopped and did NOT advance `version.txt`. See the `✗ vN … FAILED` log line; fix the migration, re-run. |
| Re-apply everything (self-heal) | `bash setup/provision/provision.sh --force` (re-runs all migrations; idempotent). |
| Skip a machine to an older state | `echo <N> > setup/local/version.txt` (forward-only won't lower it during a run; edit manually to replay). |
| Don't want the session announcer | Remove the `announce-pending` SessionStart entry from `~/.claude/settings.json`. |

## Uninstall
```bash
rm -f .git/hooks/post-merge .git/hooks/post-rewrite      # stop auto-triggering
```
Remove the `announce-pending` SessionStart hook from `~/.claude/settings.json` if desired. Individual
setups are undone via their own `SETUP.md`.
