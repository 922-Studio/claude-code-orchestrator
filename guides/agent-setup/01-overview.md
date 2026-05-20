# 01 — Overview

**Prev**: [README](README.md) | **Next**: [02 — Launching](02-launching.md)

The workspace is a collection of independent git repos under a single root directory. Claude Code sessions are launched from that root, giving every session access to the global orchestration layer while keeping per-project concerns isolated.

## CLAUDE.md Hierarchy

```
/Users/gregor/dev/922/
├── CLAUDE.md                    ← loaded for every session (universal rules)
│   └── orchestrator/CLAUDE.md  ← loaded when working inside orchestrator/
│   └── HomeAPI/CLAUDE.md       ← loaded when working inside HomeAPI/
│   └── <project>/CLAUDE.md     ← per-project, loads only in that directory
│
├── orchestrator/                ← central planning + execution hub
│   ├── registry.md              ← master project list (also symlinked as registry.md at root)
│   ├── server.md                ← infra reference (also symlinked as server.md at root)
│   ├── plans/                   ← dated plan files
│   ├── projects/                ← per-project mapping files
│   └── prompts/                 ← planner / executor / reviewer system prompts
│
├── HomeAPI/                     ← independent git repo
├── HomeUI/                      ← independent git repo
└── ...                          ← 14 projects total (see registry.md)
```

**Key point**: the root `CLAUDE.md` is always in context. Per-project `CLAUDE.md` files are injected only when the session is inside that project's directory. This means the root file must contain only rules that apply universally.

## Symlinks at Root

Two symlinks at `/Users/gregor/dev/922/` make frequently-referenced orchestrator files available without a path prefix in any session:

- `registry.md` → `orchestrator/registry.md`
- `server.md` → `orchestrator/server.md`

## Orchestrator as Hub

The orchestrator is not a runnable service — it is a directory that holds the planning and execution infrastructure:

| Layer | What lives there |
|-------|-----------------|
| Plans | `plans/YYYY-MM-DD-<slug>.md` — sequenced steps, dependencies, acceptance criteria |
| Project mappings | `projects/<name>.md` — tech stack, key files, best practices per project |
| Agent prompts | `prompts/{planner,executor,reviewer}.md` — system prompts for agent roles |
| Registry | `registry.md` — every project's path, type, status |
| Infra reference | `server.md` — cluster, services, ports, networks |

Claude operates as planner, executor, or reviewer depending on which prompt and context it is given. See [03 — Orchestrator Workflow](03-orchestrator-workflow.md) for the planning loop.

## Memory

A file-based auto-memory store at `~/.claude/projects/-Users-gregor-dev-922/memory/` persists facts across sessions. Claude reads and writes it automatically; the index is `MEMORY.md`. See [06 — Memory](06-memory.md).

## Root Is Not a Git Repo

`/Users/gregor/dev/922` is intentionally **not** a git repository. Each project directory (`HomeAPI/`, `HomeUI/`, etc.) is its own independent repo with its own remote. The root is just a directory that holds them all. Claude Code only needs the root `CLAUDE.md` and `.claude/settings.local.json` to be present there — no git required.

## Zed as Launch Host

Zed opens `/Users/gregor/dev/922` as the workspace root and launches Claude Code from there. This guarantees:
- Root `CLAUDE.md` always loads.
- Workspace settings (`settings.local.json`) always apply.
- Memory index (`MEMORY.md`) is always in context.

See [02 — Launching](02-launching.md) for the exact start-up sequence.
