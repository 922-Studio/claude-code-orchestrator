# 07 — Skills and Commands

**Prev**: [06 — Memory](06-memory.md) | **Next**: [08 — Handover Checklist](08-handover-checklist.md)

## What Are Skills

Skills are named, reusable instruction sets invoked with a slash command. They are loaded at runtime — Claude doesn't hardcode them. Available skills appear in `<system-reminder>` messages at session start; the list can vary per session.

## How to Invoke

```
/skill-name
/skill-name optional-args
```

Claude executes the skill by fetching its instructions and following them. Skills can call tools, spawn sub-agents, and interact with external systems.

## Core Skills in This Workspace

| Skill | What it does |
|-------|-------------|
| `/review` | Reviews a pull request — reads the diff, checks against project conventions, reports verdict |
| `/security-review` | Security-focused review of pending branch changes |
| `/loop` | Runs a prompt or command on a recurring interval (e.g. `/loop 5m /babysit-prs`) |
| `/schedule` | Creates/manages scheduled remote agents running on a cron schedule |
| `/fewer-permission-prompts` | Scans transcripts for repeated permission prompts, adds allowlist entries to `settings.local.json` |
| `/orchestrator-cleanup` | Orchestrator maintenance — archiving, registry hygiene |
| `/init` | Initializes a `CLAUDE.md` for a project that doesn't have one |
| `/update-config` | Configures harness behaviors (hooks, permissions, env vars) in `settings.json` |

## Built-in Commands (Not Skills)

These are native Claude Code commands, not skill-based:

| Command | Effect |
|---------|--------|
| `/model <name>` | Switch model for the current session |
| `/fast` | Toggle fast mode (Opus with faster output) |
| `/help` | List available commands |
| `/clear` | Clear conversation context |

## Discovering Available Skills

At session start, `<system-reminder>` messages list the skills available for that session. If a skill you expect isn't listed, it may not be installed or the session may not have picked it up. Check `~/.claude/settings.json` for plugin/skill configuration.
