# Projects Module Overhaul — Execution Roadmap

**Plan**: `plans/2026-03-19-projects-module-overhaul.md`
**Project**: HomeUI (`/Users/gregor/dev/922/HomeUI`)
**Prompts**: `prompts/2026-03-19-projects-overhaul/`

---

## Wave 1 — Tests First (all parallel)

Write all tests before touching any production code. Some tests will intentionally fail — that's the point.

| ID | Prompt File | Scope | ~Files | Can Parallel |
|----|-------------|-------|--------|--------------|
| **1A** | `wave-1a-api-tests.md` | `src/api/projects.test.ts` — all 14 API functions + query factories | 1 | Yes |
| **1B** | `wave-1b-hook-tests.md` | Extend `useProjects.test.tsx` + `useProjectNotes.test.tsx` | 2 | Yes |
| **1C** | `wave-1c-section-tests.md` | 8 section component tests (Goals, Tasks, Ideas, Notes, Worklogs, Header, Stats, Description) | 8 | Yes |
| **1D** | `wave-1d-dialog-tests.md` | 5 dialog tests (Edit, Task, Idea, Worklog, Create) | 5 | Yes |
| **1E** | `wave-1e-page-tests.md` | 4 page/layout tests (Detail, List, Tasks, Layout) | 4 | Yes |

**Total Wave 1**: ~20 new test files
**Parallelism**: All 5 prompts can run simultaneously — zero dependencies between them.
**Expected result**: Most tests pass, but tests marked "TEST FOR FUTURE FIX" will fail (scrollability, full width, hover edit, tasks page).

### Recommended Grouping for Execution
If you have 3 agents:
- Agent 1: **1A + 1B** (API + hooks — small, fast)
- Agent 2: **1C** (8 section tests — biggest batch)
- Agent 3: **1D + 1E** (dialogs + pages)

If you have 5 agents: one per prompt.

---

## Wave 2 — Code Fixes (all parallel, after Wave 1)

Fix the production code to make all Wave 1 tests green.

| ID | Prompt File | Scope | Risk |
|----|-------------|-------|------|
| **2A** | `wave-2a-dialog-scroll.md` | Add `max-h-[85vh] overflow-y-auto` to Dialog | Low — 2 CSS classes |
| **2B** | `wave-2b-layout-fix.md` | Remove `maxWidth: 960px` from detail page | Low — delete one property |
| **2C** | `wave-2c-goals-upgrade.md` | Styled add button + hover edit + inline edit | Medium — new interaction logic |
| **2D** | `wave-2d-tasks-page.md` | Rewrite tasks page to show actual tasks | Medium — new data fetching + rendering |
| **2E** | `wave-2e-button-unify.md` | Unify 4 add buttons to zinc-800 style | Low — find & replace in 4 files |
| **2F** | `wave-2f-api-fixes.md` | Fix `status`→`project_status`, verify context payload | Medium — needs backend investigation |

**Parallelism**: 2A-2E can all run in parallel. 2F may need results from 1A tests.
**Dependencies**: Wave 2 → Wave 1 (tests must exist first)

### Recommended Grouping
- Agent 1: **2A + 2B + 2E** (quick fixes, 10 min total)
- Agent 2: **2C** (goals upgrade, standalone)
- Agent 3: **2D** (tasks page rewrite, standalone)
- Agent 4: **2F** (API investigation, may need SSH)

---

## Wave 3 — Green Suite (sequential, after Wave 2)

| ID | Prompt File | Scope |
|----|-------------|-------|
| **3** | `wave-3-green-suite.md` | Run full suite, fix remaining failures, lint, build, optional E2E scaffold |

**Parallelism**: None — this is the integration check.
**One agent**, takes the full context of what Waves 1+2 produced.

---

## Execution Commands

### Start Wave 1 (in HomeUI directory)
```bash
# Each prompt feeds into a separate agent/Claude Code instance
# All 5 run simultaneously

# Agent 1: API + Hook tests
cat prompts/2026-03-19-projects-overhaul/wave-1a-api-tests.md

# Agent 2: Section tests
cat prompts/2026-03-19-projects-overhaul/wave-1c-section-tests.md

# Agent 3: Dialog tests
cat prompts/2026-03-19-projects-overhaul/wave-1d-dialog-tests.md

# Agent 4: Page tests
cat prompts/2026-03-19-projects-overhaul/wave-1e-page-tests.md

# Agent 5: Hook tests
cat prompts/2026-03-19-projects-overhaul/wave-1b-hook-tests.md
```

### After Wave 1 — Commit Tests
```bash
cd /Users/gregor/dev/922/HomeUI
git add src/**/*.test.tsx src/**/*.test.ts
git commit -m "test(projects): add comprehensive unit tests for projects module (test-first)"
```

### Start Wave 2 (after Wave 1 committed)
```bash
# Same pattern — one agent per prompt, all parallel
```

### After Wave 2 — Commit Fixes
```bash
git add -A
git commit -m "fix(projects): full-width layout, scrollable dialogs, goal editing, tasks page, unified buttons, API payload fixes"
```

### Wave 3
```bash
# Single agent
cat prompts/2026-03-19-projects-overhaul/wave-3-green-suite.md
```

---

## Success Criteria

- [ ] ~20 new test files covering the entire projects module
- [ ] All tests green (`npm run test:ci`)
- [ ] Lint clean (`npm run lint`)
- [ ] Build passes (`npm run build`)
- [ ] Dialogs scroll on small screens
- [ ] Project detail fills full width (no 960px cap)
- [ ] Goals have hover-only edit button + inline editing
- [ ] Tasks page shows actual tasks grouped by project
- [ ] All add buttons match "Edit Project" zinc-800 style
- [ ] API payloads match backend expectations
- [ ] 2 clean commits: one for tests, one for fixes
