# 06 — Memory

**Prev**: [05 — Settings and Permissions](05-settings-and-permissions.md) | **Next**: [07 — Skills and Commands](07-skills-and-commands.md)

## Where It Lives

```
~/.claude/projects/-Users-gregor-dev-922/memory/
├── MEMORY.md           ← index (always loaded into context)
└── <slug>.md           ← one file per memory entry
```

The directory name is derived from the workspace path (`/Users/gregor/dev/922` → `-Users-gregor-dev-922`). Each workspace has its own memory store.

## What Gets Loaded

`MEMORY.md` is always injected into context at session start. Individual memory files are read on demand — Claude reads them when a task seems relevant to a stored memory, or when explicitly asked to recall something.

## When Claude Writes Memory

Claude writes memory automatically when it learns something worth persisting:
- User role, background, or preferences (type: `user`)
- Corrections or validated approaches from prior conversations (type: `feedback`)
- Project-level facts: decisions, deadlines, motivations (type: `project`)
- Pointers to external systems: Linear projects, Grafana boards, Slack channels (type: `reference`)

To force a write: "Remember that…" or "Save this for future sessions."
To force a delete: "Forget that…" — Claude will find and remove the relevant file.

## The Four Memory Types

| Type | What it stores | Example |
|------|---------------|---------|
| `user` | Role, skills, preferences | "Senior full-stack dev, owns the prod cluster" |
| `feedback` | Guidance on how to work together | "Don't mock the DB in tests — rule + why" |
| `project` | Ongoing work, decisions, deadlines | "Merge freeze begins 2026-03-05" |
| `reference` | Pointers to external systems | "Pipeline bugs tracked in Linear INGEST" |

## Memory File Format

```markdown
---
name: short-kebab-case-slug
description: one-line summary (used to decide relevance in future sessions)
metadata:
  type: user | feedback | project | reference
---

Content here. For feedback/project types:
**Why:** the reason or motivation
**How to apply:** when this kicks in
```

## What NOT to Store in Memory

- Code patterns, file paths, architecture — read the code instead.
- Git history — `git log` is authoritative.
- In-progress task state — use task tracking for that.
- Anything already in `CLAUDE.md` files.

## Pruning

Memory can go stale. If Claude recommends something based on a memory and it conflicts with what you see in the code, the code wins — and the memory should be updated or removed.

To prune: ask Claude to "remove the memory about X" or edit/delete the file directly in `~/.claude/projects/-Users-gregor-dev-922/memory/`.
