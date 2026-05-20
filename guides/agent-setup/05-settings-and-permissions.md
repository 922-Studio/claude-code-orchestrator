# 05 — Settings and Permissions

**Prev**: [04 — Worktree & PR Flow](04-worktree-pr-flow.md) | **Next**: [06 — Memory](06-memory.md)

## Two Settings Files

### Global: `~/.claude/settings.json`

Applies to all Claude Code sessions for this user.

| Key | Current value | Effect |
|-----|--------------|--------|
| `model` | `opus` | Default model (overridable per session with `/model`) |
| `theme` | `dark` | UI theme |
| `statusLine` | custom `ctx_monitor.js` command | Statusline content (see below) |
| `enabledPlugins` | `warp@claude-code-warp: true` | Warp terminal plugin |
| `effortLevel` | `medium` | Default thinking effort |
| `skipDangerousModePermissionPrompt` | `true` | Skips the dangerous-mode confirmation prompt |
| `includeCoAuthoredBy` | `false` | No `Co-Authored-By` trailers in commits |

### Workspace: `/Users/gregor/dev/922/.claude/settings.local.json`

Applies only to sessions launched from this workspace root. Contains the permission allowlist — commands that don't trigger a confirmation prompt.

Current allowed operations (as of initial setup):
- `Read` on most of `~/.config/zed/`, Zed app support, and `~/` broadly
- `Bash(gh issue *)`, `Bash(gh pr *)`, `Bash(gh run *)`
- `Bash(git -C *)`, `Bash(git status*)`, `Bash(git diff*)`, `Bash(git log*)`, `Bash(git branch*)`, `Bash(git worktree *)`
- `Bash(ls *)`

## Extending the Permission Allowlist

Two ways:

**Via skill** (preferred — scans transcripts for what you actually use):
```
/fewer-permission-prompts
```
This reads recent transcripts, finds repetitive permission prompts, and adds them to `settings.local.json`.

**Manually**: edit `settings.local.json` and add entries to `permissions.allow`. Format is `"Tool(pattern)"` where pattern supports `*` wildcards.

## Statusline

The statusline runs `node ~/.claude/statusline/ctx_monitor.js` after each turn and displays the output in the Claude Code UI footer. It monitors context window usage — useful for knowing when the conversation is approaching compression.

To change it: edit `statusLine` in `~/.claude/settings.json`. Set `"type": "off"` to disable.

## Plugins

`warp@claude-code-warp` is enabled globally. It adds Warp-specific terminal integrations. Source: `warpdotdev/claude-code-warp` on GitHub. Disable by setting its value to `false` in `enabledPlugins`.

## Model Selection

Default model is set in `~/.claude/settings.json` (`"model": "opus"`). To override for a session:

```
/model sonnet     ← switch to Sonnet for the current session
/model opus       ← switch back
```

Fast mode (Opus with faster output) can be toggled with `/fast`.
