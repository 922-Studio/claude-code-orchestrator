# SETUP — Git freshness hooks

**id:** `git-freshness` · **type:** Claude Code hooks (shell) · **platform:** any (needs `bash`, `git`, `python3`)

## What it does
Keeps local code fresh so work never starts from a stale checkout. Two Claude Code hooks, both
opt-in and configured per-machine:

- **Worktree freshness** — a `PreToolUse` hook on `Bash`. Before any `git worktree add`, it
  `fetch`es the target repo's `origin` and (when the tree is clean) `pull --ff-only`s the checked-out
  branch. Combined with the CLAUDE.md rule to branch new worktrees off `origin/<base>`, every feature
  branch forks from the remote tip, not a stale local ref. Non-blocking — it never denies a command.
- **Investigation freshness** — a `SessionStart` hook. Once per session (throttled), it runs
  `repo-sync.sh` in safe mode: `git pull` every **clean** repo in `registry.md`, skip dirty ones.
  So every `Read`/`Grep`/`Glob` later in the session sees current code.

Shared capability, individual config: the scripts are committed; each machine enables/tunes them via
a gitignored `setup/local/git-freshness.config.json` and its own `~/.claude/settings.json`.

## Where it lives
| Path | Purpose |
|---|---|
| `setup/git-freshness/worktree-fetch.sh` | PreToolUse hook — fetch + ff-pull before `worktree add` |
| `setup/git-freshness/session-fetch.sh` | SessionStart hook — throttled safe pull of all registry repos |
| `setup/git-freshness/git-freshness.config.example.json` | committed template for the local config |
| `setup/local/git-freshness.config.json` | **gitignored** per-machine on/off + throttle |
| `setup/repo-sync/repo-sync.sh` | reused by the SessionStart hook (does the `git pull`) |
| `~/.claude/settings.json` | where each machine wires the two hooks (the merge target) |

## Install
1. Create your local config from the template (edit to taste):
   ```bash
   cp setup/git-freshness/git-freshness.config.example.json setup/local/git-freshness.config.json
   chmod +x setup/git-freshness/*.sh
   ```
2. Merge the hook block into `~/.claude/settings.json` (requires `jq`). `__ORCH__` = absolute path to
   this orchestrator checkout:
   ```bash
   ORCH="$(pwd)"                                   # run from the orchestrator root
   HOOKS="$(cat <<JSON
   {
     "hooks": {
       "PreToolUse": [
         { "matcher": "Bash", "hooks": [
           { "type": "command", "command": "bash \"$ORCH/setup/git-freshness/worktree-fetch.sh\"" } ] }
       ],
       "SessionStart": [
         { "hooks": [
           { "type": "command", "command": "bash \"$ORCH/setup/git-freshness/session-fetch.sh\"" } ] }
       ]
     }
   }
   JSON
   )"
   cp ~/.claude/settings.json ~/.claude/settings.json.bak
   jq -s '.[0] * .[1]' ~/.claude/settings.json <(printf '%s' "$HOOKS") > ~/.claude/settings.json.new
   mv ~/.claude/settings.json.new ~/.claude/settings.json
   ```
   > Note: `*` merge REPLACES an existing `hooks.PreToolUse` / `hooks.SessionStart` array. If you
   > already run other hooks on those events, hand-merge the arrays instead of the `jq` overwrite.
3. Restart Claude Code so it reloads `settings.json`.

## Verify
```bash
jq '.hooks | {PreToolUse, SessionStart}' ~/.claude/settings.json   # both hooks present, paths absolute
echo '{"tool_input":{"command":"git -C '"$PWD"' worktree add /tmp/x -b feat/probe"},"cwd":"'"$PWD"'"}' \
  | bash setup/git-freshness/worktree-fetch.sh; echo "exit=$?"
```
Expect the `git-freshness: fetched + fast-forwarded …` line on stderr and `exit=0`. For the session
hook, start a fresh Claude Code session and confirm registry repos are at their remote tip
(`git -C <repo> status` → "up to date"); it self-throttles for `throttle_minutes` afterward.

## Fix / troubleshoot
| Symptom | Remedy |
|---|---|
| Hook seems to do nothing | Check it's enabled in `setup/local/git-freshness.config.json`; confirm the paths in `~/.claude/settings.json` are absolute and the `.sh` files are `chmod +x`. |
| Session start feels slow | Raise `throttle_minutes`, or set `session_fetch.enabled=false` (worktree hook still guarantees fresh branches). |
| A repo wasn't pulled at session start | It was dirty (safe mode skips it) or throttled. Commit/stash, then `bash setup/repo-sync/repo-sync.sh`. |
| Worktree branch still stale | Ensure the `worktree add` command forks off `origin/<base>` (that's the real guarantee); the hook only refreshes refs. |
| `python3: command not found` | Install Python 3 (macOS ships it via Xcode CLT: `xcode-select --install`). |
| Other hooks got clobbered | Restore `~/.claude/settings.json.bak` and hand-merge the arrays (see Install note). |

## Uninstall
Remove the `PreToolUse` (matcher `Bash`) and `SessionStart` entries pointing at
`setup/git-freshness/` from `~/.claude/settings.json` (or restore `~/.claude/settings.json.bak`), then
restart Claude Code. Delete `setup/local/git-freshness.config.json` if you no longer want the config.
