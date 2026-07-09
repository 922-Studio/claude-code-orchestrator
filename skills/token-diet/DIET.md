# Token Diet — per-session overhead cleanup (interactive)

**Goal:** shrink the tokens that load into **every** session before you type a word. At 100
sessions/day even 1k tokens of standing overhead is 100k tokens/day of pure tax — paid on every
turn, forever, whether or not the session ever touches that context.

This is an **interactive runbook**. You (the orchestrator) measure, then walk the overhead sources
**biggest-lever-first**, and for each one **present the cost + a concrete proposal and let Gregor
decide** keep / trim / move-to-load-on-demand / remove. Never delete or disable anything without an
explicit yes. Apply, then re-measure so the win is visible.

> Scope note: this trims *standing* overhead (what loads unconditionally at session start). It does
> **not** touch conversation history or per-task context — that's what `/create-handover` is for.

---

## The two rules

1. **Nothing loads unconditionally that isn't needed unconditionally.** Rarely-needed detail becomes
   a *pointer* to a file loaded on demand, not inline prose. This is already the orchestrator's
   planning principle (`feedback_planning_style`) — apply it to config/instructions too.
2. **Decide together, apply immediately, re-measure.** Every section ends with a yes/no from Gregor
   and a visible before/after.

---

## Step 0 — Measure (establish the baseline)

Two measurement sources, used together:

- **`/context`** — run it in Claude Code. It prints the real token breakdown of the current
  session by category (system prompt, tools/MCP, memory files, etc.). This is ground truth for
  *this* session. Ask Gregor to paste the output if you can't see it.
- **`scripts/token-audit.sh`** — run it for a fast, offline estimate of the **file-based** sources
  (CLAUDE.md chain, MEMORY.md, installed commands, settings). Uses a chars/4 heuristic — good enough
  to rank and to show before/after deltas.

```bash
bash skills/token-diet/scripts/token-audit.sh
```

Record the baseline total. Present the ranked sources. Then walk them top-down — **stop at each,
propose, get a decision, apply.**

---

## The overhead sources, biggest lever first

### 1. MCP servers (usually the single biggest lever)

Every connected MCP server injects its tool schemas into context. Servers you don't use in a given
workspace are pure tax. In this workspace that can mean Gmail, Google Calendar, Atlassian, Drive,
Microsoft 365, Betterstack — each one's tool definitions cost hundreds to thousands of tokens.

**Measure:** in `/context`, the tools/MCP line is the total. `claude mcp list` shows what's wired.
The live config is `~/.claude.json` (per-project `mcpServers` + the global set).

**Decide, per workspace:**
- Which servers does work *in this directory* actually use? (Orchestrator work rarely needs Gmail.)
- Two ways to cut cost:
  - **Deferred tools** — servers whose schemas load on-demand via ToolSearch cost only their *name*
    up front, not full schemas. Prefer this for occasionally-useful servers.
  - **Disable per-project** — remove from this project's `mcpServers`, or use
    `enabledMcpjsonServers` / `disabledMcpjsonServers` in settings to scope a server to only the
    workspaces that need it. Fully removes the cost where it's not wanted.

**Propose** a keep/defer/disable list per workspace. Apply only the ones Gregor approves (editing
`~/.claude.json` or settings — see the `update-config` skill for settings edits).

### 2. The CLAUDE.md chain

Every file in the hierarchy loads on every session in scope:
`/Users/gregor/dev/922/CLAUDE.md` (workspace) → `orchestrator/CLAUDE.md` → `orchestrator/CLAUDE.local.md`,
plus `~/.claude/CLAUDE.md` if present. Measure each with the audit script.

**Trim targets — propose, don't auto-apply:**
- Prose that repeats itself across the chain (workspace + orchestrator both state the worktree/PR
  rule — collapse to one authoritative statement + a pointer).
- Long rules that are needed *only when a specific task type comes up* → move the detail to a
  `guides/*.md` and leave a one-line **pointer** (the env-handling rule already does this — copy the
  pattern).
- Examples/rationale that can live in the guide, not the always-loaded instruction.

The bar: **would a session that never does X still need to read the X rule?** If no, it's a pointer.

### 3. Auto-memory `MEMORY.md`

The memory **index** loads every session (the individual memory files do not — they're recalled on
relevance). A long index is standing cost. Path:
`~/.claude/projects/-Users-gregor-dev-922-orchestrator/memory/MEMORY.md`.

**Propose:**
- **Resolved incidents** → archive. An `incident_*` that's fixed and won't recur doesn't need to be
  in the always-loaded index. Move its line to an `ARCHIVE.md` (or delete the memory if truly dead).
- **Consolidate** near-duplicate entries into one.
- **Tighten hooks** — the one-line description is what loads; make each ruthlessly short.

Never silently drop a memory that encodes a still-live constraint — surface it and ask.

### 4. Skills & installed commands

Every installed slash-command's name + description loads into the skills catalog. Check
`~/.claude/commands/` and the built-in skills. Remove commands Gregor no longer uses
(`rm ~/.claude/commands/<name>.md`; re-installable from `setup/orchestrator-commands/`).

### 5. Settings, permissions, statusline

Minor but free wins: an overgrown `permissions.allow` list, dead env vars, or a verbose statusline
all add up. Skim `~/.claude/settings.json` + project settings; propose removals. Use the
`update-config` skill to edit settings safely.

---

## Step N — Re-measure & report

Re-run `token-audit.sh` and (if available) `/context`. Show the before/after total and per-source
deltas. State the estimated **per-session** saving and the **per-day** saving at Gregor's session
volume (× ~100). That number is the whole point — make it visible.

If anything was *moved* (rule → guide, memory → archive), confirm the pointer works and the detail
is still reachable on demand.

---

## After the diet

- If the CLAUDE.md chain, config, or setup registry changed structurally, update `overview.md` +
  `CAPABILITIES.md` the same session (`hub/how-to/HOW-TO-change-the-orchestrator.md`).
- This runbook is meant to be **periodic** — the `setup/reminders/` system nudges it weekly. Nothing
  to schedule from here; just run `/token-diet` when the Monday reminder fires.
