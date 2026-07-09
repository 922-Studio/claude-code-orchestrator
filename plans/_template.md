---
title: [Plan title]
status: not started        # not started | in progress | done
created: YYYY-MM-DD
updated: YYYY-MM-DD
goal: [One sentence — what this plan achieves.]
---

# Plan: [Title]

## Human Summary — read this, skip the rest

[2–3 sentences, plain language: the situation and what you'll have when this is done.]

- **Outcome:** [the end state]
- **Status:** not started · **Effort:** [N waves · rough size]

**Decisions & watch-outs**
- **Decision —** [the choice + the trade-off behind it, one line]
- **Decision —** [another key call Gregor might veto]
- **Watch —** [open risk / point that wants a human decision]

---

<!-- ↓ Everything below is for the executor agent ↓ -->

## Context — read before starting

- `projects/<name>.md` — project mapping & best practices
- `[additional file]` — [why]

## Steps

### 1. [Step title]
- **Project / dir:** [name] · `[path]`
- **Branch / worktree:** `feat/<slug>` · `<repo>/.worktrees/feat-<slug>`
- **Parallel with:** —  ·  **Depends on:** —
- What to do: [terse]
- Acceptance: [criterion 1]; [criterion 2]

## Execution Overview

- **Wave 1 (parallel):** 01, 02
- **Wave 2 (sequential):** 03

## Post-execution checklist

- [ ] Tests pass (new tests added if behavior changed)
- [ ] Docs updated (if user- or contract-visible change)
- [ ] CI green
- [ ] PR URL reported back as a clickable link
- [ ] Worktree removed; remote branch preserved
