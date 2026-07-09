# ⚙️ setup/ — Machine Setup Registry

The **catalog of local-machine setups, automations, and tools** that live *outside* the repos
(Claude Code config, statusline, slash-commands, launchd jobs, scripts, CLIs). It's the source of
truth for environment setup, the way `CLAUDE.md` is for the rules — so the orchestrator can:

1. **"X doesn't work."** → find it here → run its **Verify** → apply its **Fix**.
2. **"I use / set up Y."** → registered? verify & reconcile drift. Not registered? add an entry.
3. **"I'm on a new machine."** → walk the registry → install each setup from its `SETUP.md`.

The actual artifacts (scripts, templates) are stored here so they're **portable across machines**.

---

## Protocol

**Something broke:** scan the Registry → open the matching `SETUP.md` → run **Verify** → apply
**Fix** → report what changed. No match → say so; don't guess at hidden config.

**User describes a setup:** registered → verify against the live machine, reconcile drift.
Not registered → note it's undocumented, offer to add a stub + `SETUP.md` skeleton.

**New machine / fresh pull:** go setup by setup; each **Install** uses generic paths (`~`/`$HOME`)
so it ports across users/machines. Run **Verify** after each.

---

## Conventions

- **One folder per setup:** `setup/<id>/` (kebab-case). Each has a `SETUP.md` + canonical artifacts.
- **Keep paths generic** (`~`, `$HOME`). launchd plists need absolute paths → store as `*.template`
  with a `__HOME__` placeholder and `sed` it in on install.
- **Never store secrets here.** Reference credential files by path; don't copy their contents.
- Add every new setup to the Registry below and keep `overview.md` + `CAPABILITIES.md` in sync.

### `SETUP.md` standard sections
```
# SETUP — <name>
## What it does
## Where it lives        (every path it touches, generic)
## Install               (copy-paste, generic paths)
## Verify                (how to confirm it works)
## Fix / troubleshoot    (failure modes → remedy)
## Uninstall
```

---

## Generic vs. personal setups

- **Generic** setups (useful on any machine) live directly under `setup/<id>/` and are **committed**.
- **Personal / machine- or ecosystem-specific** setups (e.g. a mail-housekeeping job, a work deploy
  digest) live under **`setup/local/<id>/`**, which is **gitignored** — same `SETUP.md` conventions,
  just kept out of the shared framework. The installer imports an old orchestrator's setups here.

## Registry

| Setup | id | Type | Platform | Lives in | Status |
|---|---|---|---|---|---|
| Claude Code settings (model, effort, theme, permissions) | `claude-code-settings` | config file | any | `setup/claude-code-settings/` | ✅ active |
| Context-monitor statusline | `claude-statusline` | Node statusline | any | `setup/claude-statusline/` | ✅ active |
| Orchestrator slash-commands | `orchestrator-commands` | Claude Code commands | any | `setup/orchestrator-commands/` | ✅ active |
| Daily Homebrew auto-upgrade | `brew-autoupgrade` | launchd LaunchAgent | macOS | `setup/brew-autoupgrade/` | 🟡 optional |
| Repo sync (all registry repos) | `repo-sync` | shell script | any | `setup/repo-sync/` | 🟡 optional |
| Periodic reminders (config-driven notifications) | `reminders` | launchd LaunchAgent | macOS | `setup/reminders/` | 🟡 optional |
| *(personal setups)* | — | — | — | `setup/local/` (gitignored) | — |

*Status legend: ✅ active · 🟡 documented/optional · 🔴 broken/needs attention*

> One-shot bootstrap on a new machine: run **`bash install.sh`** from the repo root — it walks these
> setups plus the overlay/config/projects/map, and can migrate from an old orchestrator. See
> `hub/how-to/HOW-TO-install-on-a-new-machine.md`.
