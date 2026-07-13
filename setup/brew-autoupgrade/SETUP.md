# SETUP — Daily Homebrew auto-upgrade

**id:** `brew-autoupgrade` · **type:** launchd LaunchAgent · **platform:** macOS

## What it does
Runs an unattended `brew update && brew upgrade && brew cleanup` (**formulae only**, no casks) once a day at **07:00 local**. If the Mac was off/asleep at 07:00, launchd runs it once on the next wake/login. Output goes to a log file (auto-trimmed). Fully password-free — `brew upgrade` is non-interactive, so no "y" confirmation is needed; casks are excluded on purpose because some require a sudo password.

## Where it lives
| Path | Purpose |
|---|---|
| `~/.local/bin/brew-autoupgrade.sh` | the upgrade script |
| `~/Library/LaunchAgents/com.orchestrator.brew-autoupgrade.plist` | the schedule (Label `com.orchestrator.brew-autoupgrade`) |
| `~/Library/Logs/brew-autoupgrade.log` | run log (trimmed to last 2000 lines) |
| `~/Library/Logs/brew-autoupgrade.launchd.{out,err}` | launchd-level stdout/stderr |

Canonical copies of the script and plist template live next to this file:
- `brew-autoupgrade.sh`
- `com.orchestrator.brew-autoupgrade.plist.template` (uses `__HOME__` placeholder)

> **Apple Silicon vs Intel:** the script/plist set `PATH` to `/opt/homebrew/bin:/usr/local/bin:...`, which covers both (Apple Silicon brew is `/opt/homebrew`, Intel is `/usr/local`). No change needed across Mac types.

## Install
```bash
SRC="$(pwd)/setup/brew-autoupgrade"   # run from the orchestrator root

# 1. Script
mkdir -p ~/.local/bin ~/Library/Logs
cp "$SRC/brew-autoupgrade.sh" ~/.local/bin/brew-autoupgrade.sh
chmod +x ~/.local/bin/brew-autoupgrade.sh

# 2. LaunchAgent (materialize __HOME__ -> your real home)
sed "s|__HOME__|$HOME|g" "$SRC/com.orchestrator.brew-autoupgrade.plist.template" \
  > ~/Library/LaunchAgents/com.orchestrator.brew-autoupgrade.plist

# 3. Load (and remember as enabled)
launchctl unload ~/Library/LaunchAgents/com.orchestrator.brew-autoupgrade.plist 2>/dev/null
launchctl load -w ~/Library/LaunchAgents/com.orchestrator.brew-autoupgrade.plist
```

## Verify
```bash
# Is it loaded? (label appears; last column is the last exit code, 0 = ok)
launchctl list | grep brew-autoupgrade

# Run it now on demand, then read the log
launchctl start com.orchestrator.brew-autoupgrade
sleep 10 && tail -n 40 ~/Library/Logs/brew-autoupgrade.log
```
Working state: the label is listed, the log shows a recent `brew-autoupgrade <timestamp>` block ending in `--- done ... ---`.

## Fix / troubleshoot
| Symptom | Likely cause → remedy |
|---|---|
| `launchctl list` doesn't show the label | Not loaded → re-run step 3 of **Install**. |
| Log not updating daily | Mac was off at 07:00 and hasn't woken since (expected — runs on next wake), or agent unloaded → check `launchctl list`. |
| `brew: command not found` in log | `PATH` wrong for this machine → confirm `which brew`; ensure the `EnvironmentVariables > PATH` in the plist + the `export PATH` in the script include the right brew dir. |
| Non-zero exit code in `launchctl list` | Read `~/Library/Logs/brew-autoupgrade.log` and `~/Library/Logs/brew-autoupgrade.launchd.err`. |
| Want a different time | Edit `Hour`/`Minute` in the plist, then unload+load (step 3). |

## Uninstall
```bash
launchctl unload -w ~/Library/LaunchAgents/com.orchestrator.brew-autoupgrade.plist
rm ~/Library/LaunchAgents/com.orchestrator.brew-autoupgrade.plist
rm ~/.local/bin/brew-autoupgrade.sh
# logs in ~/Library/Logs/brew-autoupgrade* can be removed too
```
