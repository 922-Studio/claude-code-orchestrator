# SETUP — Periodic reminders (launchd + macOS notifications)

**id:** `reminders` · **type:** launchd job + macOS notifications · **platform:** macOS

## What it does
A generic, config-driven reminder system. A single launchd job runs `remind.sh` once each morning;
the script reads a **local, gitignored** JSON registry and posts a macOS notification for every
reminder **due today**. Add as many recurring reminders as you like (weekly / daily / monthly /
every-N-days) by editing one config file — no new launchd jobs per reminder.

Ships with one enabled entry: a **Monday** nudge to run `/token-diet` (the per-session
token-overhead cleanup, `skills/token-diet/`).

The **mechanism** (script, plist template, installer) is committed framework — reusable on any Mac.
The **reminder entries + timing** live in `setup/local/reminders.config.json`, which is gitignored,
so they stay machine-local.

## Where it lives
| Path | Purpose |
|---|---|
| `setup/reminders/remind.sh` | canonical script: reads the config, fires due notifications |
| `setup/reminders/com.orchestrator.reminders.plist.template` | launchd trigger (daily), `__HOME__`/`__CHECK_HOUR__`/`__CHECK_MINUTE__` placeholders |
| `setup/reminders/reminders.config.example.json` | committed example / schema for the registry |
| `setup/reminders/install.sh` | seeds config, installs script + plist (path/time-rewritten), loads the job |
| `setup/local/reminders.config.json` | **live registry (gitignored)** — your reminders + check time |
| `~/.local/bin/claude-remind.sh` | installed script (config path baked in) |
| `~/Library/LaunchAgents/com.orchestrator.reminders.plist` | installed launchd job |
| `~/.local/state/claude-reminders/*.lastfired` | per-reminder "last fired" state (no double-fire) |
| `~/Library/Logs/claude-reminders.launchd.{out,err}` | launchd run logs |

## Configure
Edit `setup/local/reminders.config.json`:
- **Timing** (`check_hour`, `check_minute`) — when the daily check runs. Baked into the plist, so
  **re-run `install.sh`** after changing these.
- **Reminders** (`reminders[]`) — each `{ id, title, message, frequency, enabled }` plus a
  frequency field: `weekly` → `weekday` (`Mon`..`Sun`); `monthly` → `day` (1..28); `interval` →
  `every_days`; `daily` → none. Editing this list needs **no reinstall** — `remind.sh` reads it
  fresh each run.

## Install
```bash
bash setup/reminders/install.sh                     # run from the orchestrator root
# or, if cloned elsewhere:
ORCH_ROOT="$(pwd)" bash setup/reminders/install.sh
```
On first run it seeds `setup/local/reminders.config.json` from the example (Monday `token-diet`
nudge enabled). Re-run after changing the check time or editing `remind.sh`.

## Verify
```bash
launchctl print "gui/$UID/com.orchestrator.reminders" | head -20   # job loaded, correct schedule
REMINDERS_CONFIG="$(pwd)/setup/local/reminders.config.json" bash ~/.local/bin/claude-remind.sh
launchctl kickstart -k "gui/$UID/com.orchestrator.reminders"       # run the job on demand
```
A `daily`/due reminder should pop a macOS notification. First-run notifications require granting
the delivering app (the Script Editor / `osascript`, or your terminal) notification permission in
**System Settings → Notifications**.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| No notification fires | Check `~/Library/Logs/claude-reminders.launchd.err`; confirm the config path baked into `~/.local/bin/claude-remind.sh` exists; grant notification permission (above). |
| Fires at the wrong time | Edit `check_hour`/`check_minute` in the config, **re-run `install.sh`** (they live in the plist). |
| Reminder never becomes due | Check the `frequency` fields; confirm `enabled: true`; a wrong `weekday` spelling silently never matches (`Mon`..`Sun`). |
| Fired twice in a day | Shouldn't happen — the `*.lastfired` guard blocks it. If it did, check the state dir is writable. |
| Job won't load | `launchctl bootout "gui/$UID/com.orchestrator.reminders"` then re-run `install.sh`. |

## Uninstall
```bash
launchctl bootout "gui/$UID/com.orchestrator.reminders" 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.orchestrator.reminders.plist \
      ~/.local/bin/claude-remind.sh
rm -rf ~/.local/state/claude-reminders
# setup/local/reminders.config.json is yours — delete it manually if you want it gone.
```
