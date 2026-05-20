# 02 — Launching a Session

**Prev**: [01 — Overview](01-overview.md) | **Next**: [03 — Orchestrator Workflow](03-orchestrator-workflow.md)

## Preferred: Zed

Open Zed with the workspace root as the project root:

```
File → Open… → /Users/gregor/dev/922
```

Then open the Claude Code panel inside Zed. The session starts in `/Users/gregor/dev/922`.

## CLI Fallback

```bash
cd /Users/gregor/dev/922
claude
```

Using `~/dev/922/SomeProject` as the working directory instead will skip the root `CLAUDE.md` and workspace settings — always launch from the root.

## What Loads Automatically at Startup

| Item | Path | Loaded by |
|------|------|-----------|
| Universal rules | `/Users/gregor/dev/922/CLAUDE.md` | Claude Code (project root) |
| Workspace permissions | `/Users/gregor/dev/922/.claude/settings.local.json` | Claude Code (workspace settings) |
| Global settings | `~/.claude/settings.json` | Claude Code (user settings) |
| Memory index | `~/.claude/projects/-Users-gregor-dev-922/memory/MEMORY.md` | Auto-memory system |
| Orchestrator rules | `orchestrator/CLAUDE.md` | Injected when session is inside `orchestrator/` |

## What Does NOT Load Until You Navigate

Per-project `CLAUDE.md` files (e.g. `HomeAPI/CLAUDE.md`) are **not** loaded at startup. They are injected only when Claude is working inside that project's directory — either because you navigated there or because a tool call targets that path.

This means: if you ask Claude to edit `HomeAPI/src/foo.py` without first loading that project's context, it will work but without the per-project conventions. To ensure per-project `CLAUDE.md` applies, tell Claude to read `HomeAPI/CLAUDE.md` explicitly, or start the session from inside `HomeAPI/`.

## Settings Layering

Settings are merged in this order (later entries win):

```
~/.claude/settings.json          (global — model, theme, plugins, statusline)
    ↓
/Users/gregor/dev/922/.claude/settings.local.json   (workspace — permissions)
    ↓
Per-session overrides (e.g. /model command)
```

See [05 — Settings and Permissions](05-settings-and-permissions.md) for what's in each file.
