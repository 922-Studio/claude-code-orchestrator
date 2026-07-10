# SETUP — session-log (record session ids for crash/close recovery)

**id:** `session-log` · **type:** Claude Code `SessionStart` hook (shell + python3) · **platform:** any (needs `bash`, `python3`)

## What it does
Appends one JSONL record to a machine-global log **every time a Claude session starts**
(including resumes), so that if a tab is closed by accident, the app crashes, or the Mac
reboots, you can find the session id and continue with `claude --resume <id>`.

- Log: `~/.claude/session-log.jsonl` (one line per session start).
- Record fields: `ts`, `session_id`, `cwd`, `source` (`startup`/`resume`/`clear`/`compact`),
  `transcript_path`.
- The hook writes **only** to the log file — nothing to stdout (SessionStart stdout is
  injected into the model's context). Always exits 0; never blocks a session.
- Retention: trims to the last `max_entries` (default 2000) once it grows ~25% past the cap.

## Where it lives
| Path | Purpose |
|---|---|
| `setup/session-log/session-log.sh` | the SessionStart hook wrapper (reads config, calls the py) |
| `setup/session-log/session-log.py` | reads the hook JSON from stdin, appends the record, trims |
| `setup/session-log/recent.sh` | query helper — recent sessions as paste-ready resume commands |
| `setup/session-log/session-log.config.example.json` | committed defaults, seeds the local config |
| `setup/session-log/apply.sh` | idempotent installer (chmod, seed config, wire the hook) |
| `setup/local/session-log.config.json` | gitignored per-machine config |
| `~/.claude/session-log.jsonl` | the log itself (machine-global, outside the repo) |

## Config (`setup/local/session-log.config.json`)
| Key | Default | Meaning |
|---|---|---|
| `enabled` | `true` | set `false` to stop logging without unwiring the hook |
| `log_path` | `""` | override the log location (`~` expands); empty = `~/.claude/session-log.jsonl` |
| `max_entries` | `2000` | retained line cap |

## Install
Idempotent; also run automatically by `setup/provision/provision.sh` on pull:
```bash
bash setup/session-log/apply.sh
```

## Recover a session
```bash
bash setup/session-log/recent.sh            # last 15 sessions, newest first
bash setup/session-log/recent.sh 40         # last 40
bash setup/session-log/recent.sh --here     # only sessions started in the current dir
```
Each row ends with a ready-to-paste `claude --resume <id>`. Copy the one you want.

## Verify
```bash
bash setup/session-log/apply.sh                     # -> "wired ..." then "already current" on re-run
python3 -c 'import json;print("SessionStart hooks OK")' # sanity
# start (or resume) a session, then:
tail -n 3 ~/.claude/session-log.jsonl
```

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| No lines appear | Confirm the hook is in `~/.claude/settings.json` under `SessionStart`; re-run `apply.sh`. `enabled` false? |
| Log in the wrong place | Set `log_path` in the local config. |
| Want it off | `enabled:false` in the local config, or remove the `session-log.sh` entry from `~/.claude/settings.json`. |
| Duplicate entries per start | Expected if both `startup` and a later `resume`/`compact` occur — each is a distinct start; filter by `source` if noisy. |

## Uninstall
Remove the `session-log.sh` entry from the `SessionStart` array in `~/.claude/settings.json`
(and optionally delete `~/.claude/session-log.jsonl`).
