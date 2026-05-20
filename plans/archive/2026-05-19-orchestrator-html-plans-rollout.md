# Plan: Orchestrator HTML Plans Rollout

- **Date**: 2026-05-19
- **Project(s)**: orchestrator
- **Goal**: Switch all future orchestrator planning output from Markdown to HTML, rendered with the existing `pages-design-system.{css,html}` (light mode, Studio variant), so plans are visual, browser-viewable, and token-efficient.

## Background / Why

Inspired by Thariq Shihipar's Claude Code interview (https://www.chatprd.ai/how-i-ai/claude-code-anthropic-thariq-shihipar-on-replacing-markdown-with-html): long Markdown plans glaze human eyes; HTML plans turn the reviewer into an active collaborator. Token efficiency is engineered by **never re-generating CSS inline** — every plan links the shared design system as a sibling stylesheet, and uses only documented class names.

A POC plan already exists at `plans/claude-channels-poc.html` (~700 lines, inline CSS — what we are NOT going to do anymore). The target is plans of ~150-300 lines of HTML, content-only, no `<style>` block, linking `../pages-design-system.css`.

This plan is itself authored in Markdown because the HTML template doesn't exist yet — it is the bootstrap. The first real HTML plan is the one that comes after this PR merges.

## Locked Defaults (executor: ask Gregor only if you disagree)

| Decision | Choice | Rationale |
|---|---|---|
| Component location | **Extend** `pages-design-system.css` in-place with a new `/* Plans */` section | Keeps the visual system unified; components are generic enough to also help marketing pages |
| Theme | **Light mode** (`<html class="light">`), no theme toggle, no `<script>` | Per Gregor's instruction |
| Variant | **`variant-studio`** (emerald) | Plans are operational/build-oriented; aligns with the "build" half of 922-Studio |
| Brand chrome | **Cover-only**: blobs + dot grid render on the plan cover (hero) section, switched off in the body | Brand consistency without distracting from dense step lists |
| Interactivity | **None for v1** | Static HTML, file:// double-click, no JS |
| Existing `.md` plans | **Leave as-is** | No batch conversion. Authors of any new plan author it in HTML; old plans keep working |
| File naming | `plans/YYYY-MM-DD-<slug>.html` | One-letter swap from current convention |

## Context — read these files before starting

- `CLAUDE.md` — orchestrator workflow rules (this file gets edited in Step 6)
- `/Users/gregor/dev/922/CLAUDE.md` — universal worktree + branch rules
- `pages-design-system.css` — the existing DS that gets extended in Step 2
- `pages-design-system.html` — the showcase that gets extended in Step 3
- `prompts/planner.md` — the planner contract that gets rewritten in Step 5
- `plans/_template.md` — the current MD template; reference for sections to preserve, then deprecated in Step 8
- `plans/claude-channels-poc.html` — the existing HTML POC; mine it for code-block styling, scope-bar, badges, numbered-phase patterns
- `plans/2026-05-19-homeapi-openclaw-router-registration.md` — a small, recent MD plan; used as the smoke-test conversion in Step 7

## Worktree / Branch / PR

- Repo: `/Users/gregor/dev/922/orchestrator` (this is its own git repo)
- Branch: `feat/orchestrator-html-plans-rollout`
- Worktree path: `/Users/gregor/dev/922/orchestrator/.worktrees/feat-orchestrator-html-plans-rollout`
- Setup: `git -C /Users/gregor/dev/922/orchestrator worktree add /Users/gregor/dev/922/orchestrator/.worktrees/feat-orchestrator-html-plans-rollout -b feat/orchestrator-html-plans-rollout`
- PR target: `main`
- One PR for the whole feature. Steps below are sequential commits inside the same branch.

## Steps

### Step 1: Create worktree and verify baseline

- **Description**: Create the feature branch + worktree off `main`. Confirm `pages-design-system.{css,html}` open cleanly in a browser via `file://` before any edits.
- **Acceptance criteria**:
  - [ ] Worktree exists at the path above and `git status` is clean inside it
  - [ ] `open pages-design-system.html` renders without console errors
  - [ ] All further edits happen inside the worktree, never in the main checkout

---

### Step 2: Extend `pages-design-system.css` with plan components

- **Description**: Append a single, clearly-delimited `/* ================ Plans ================ */` section to the end of `pages-design-system.css`. All new classes use existing tokens (`--color-*`, `--radius-*`, `--font-*`) — no new color hex codes inline.
- **Components to add** (class names below are the contract — keep them stable, they appear in the planner prompt):

| Class | Purpose |
|---|---|
| `.pill` (base) + `.pill--success .pill--error .pill--warning .pill--info .pill--muted .pill--accent` | Status chips: done / blocked / parallel / pending / wave-N |
| `.pill__dot` | 6px leading dot inside a pill |
| `.scope-bar` + `.scope-item` (with `<strong>` label / value layout) | Horizontal quick-facts strip below the hero |
| `.plan-step` (the numbered card) | One container per step. Children: `.plan-step__num` (big mono 01/02/…), `.plan-step__head` (title + meta), `.plan-step__body`, `.plan-step__foot` |
| `.meta-grid` + `.meta-row` (label / value) | Project / Directory / Branch / Worktree / PR target meta |
| `.acceptance` + `.acceptance__item` (with `data-state="todo|done|blocked"`) | Checklist with ✓ / ☐ / ✗ markers — pure CSS via `::before` |
| `.dataframe` (table reset, mono numerals, tabular-nums) | File lists, scope tables, criteria tables |
| `pre.code` + `code.inline` + `.tok-comment .tok-string .tok-keyword .tok-fn` | Code blocks with simple syntax tints. Steal the palette from `plans/claude-channels-poc.html` but re-key to the light-mode tokens |
| `.wave` (group container) + `.wave__label` (eyebrow-style) | "Wave 1 (parallel)" grouping in the execution overview |
| `.plan-cover` (hero variant) — body element gets `data-plan-cover="off"` after the cover to hide blobs/dot grid in the rest of the page | Cover-only background chrome |

- **Constraints**:
  - Light-mode first; provide `html.dark` overrides only where the colour-mix on accent isn't enough
  - No `@keyframes` beyond what already exists
  - Reuse `--radius-md` for cards, `--radius-full` for pills
  - Keep additions under ~250 lines
- **Acceptance criteria**:
  - [ ] CSS file grows by less than 250 lines
  - [ ] Existing `pages-design-system.html` showcase still renders identically (no regression on Studio/Portfolio surfaces)
  - [ ] All new classes are namespaced (`.plan-*`, `.scope-*`, `.meta-*`, `.acceptance*`, `.dataframe`, `.wave*`, `.pill*`, `.tok-*`) — no clashes with existing `.card`, `.btn`, `.eyebrow`
  - [ ] No hard-coded colors; everything goes through existing tokens

---

### Step 3: Extend `pages-design-system.html` showcase with a "Plans" block

- **Description**: Append a new top-level `<section>` (`id="plans"`) to the showcase that demos every new component from Step 2, exactly the way the existing Studio/Portfolio sections demo their own. This becomes the visual contract Claude reads when planning.
- **Sub-sections to include**:
  1. Status pills row (success / error / warning / info / muted / accent + dot variants)
  2. Scope bar (4-5 items example)
  3. Plan-step card (full example: num, title, meta-grid, body prose, code block, acceptance list, foot)
  4. Wave group (two waves with two steps each as compact cards)
  5. Code block + inline code + syntax-tinted example
  6. Dataframe table (file list with mono path column + size column)
  7. Acceptance list with all three states (todo / done / blocked)
- **Acceptance criteria**:
  - [ ] New section appears in the showcase TOC (`.ds-toc` nav strip at top of `pages-design-system.html`)
  - [ ] Every class added in Step 2 is demonstrated at least once
  - [ ] Each demo block shows both the rendered example **and** the raw HTML snippet (use the existing `ds-block` pattern with a `<pre><code>` snippet below the live demo)
  - [ ] Showcase still passes a manual visual check against the Studio variant (open in browser, toggle variant, light/dark — only the cover section should show blobs/dot grid for plans)

---

### Step 4: Create `plans/_template.html`

- **Description**: Author the canonical empty plan as `plans/_template.html`. Target ≤ 80 lines. Content-only HTML; one `<link rel="stylesheet" href="../pages-design-system.css">`; `<html class="light">`; `<body class="variant-studio">`.
- **Required sections** (mirror the current `_template.md` contract, expressed in DS classes):
  1. `<header class="plan-cover">` — eyebrow (date), `<h1>` (plan title), lede (1-sentence goal), scope-bar (Project / Branch / Worktree / PR target)
  2. `<section id="context">` — list of files to read with `<code class="inline">` paths
  3. `<section id="steps">` — one `<article class="plan-step">` per step with placeholder content showing meta-grid + acceptance + code-block + parallel-pill
  4. `<section id="execution-overview">` — wave groups with compact step pills
  5. `<section id="post-execution">` — acceptance list with the quality gates from root CLAUDE.md
- **Acceptance criteria**:
  - [ ] Total file ≤ 80 lines, no `<style>` block, no `<script>`
  - [ ] Opens via `file://` in a browser and renders correctly
  - [ ] Every section in the current `plans/_template.md` has a 1:1 counterpart
  - [ ] Placeholder text makes the structure obvious for the planning agent (e.g. `<!-- one .plan-step per step -->`)

---

### Step 5: Rewrite `prompts/planner.md`

- **Description**: Replace the Markdown-output contract with an HTML-output contract. Keep all the *content* rules (pointers not paste, numbered steps, dependencies, worktree/branch/PR mandate) — only the *output format* section changes.
- **Required additions to the prompt**:
  - "Before drafting, read `../pages-design-system.html` and confirm the class names you intend to use exist there. If you need a class that doesn't exist, stop and propose a DS change instead of inventing one."
  - "Output a single `.html` file under `plans/YYYY-MM-DD-<slug>.html`. Start from `plans/_template.html`. Never emit a `<style>` block, never emit `<script>`. Always link the stylesheet as `<link rel='stylesheet' href='../pages-design-system.css'>`."
  - "Use only documented classes from the design system. Stay content-only. Target ≤ 300 lines of HTML for the whole plan."
  - "Locked: `<html class='light'>` and `<body class='variant-studio'>` for all orchestrator plans."
- **Acceptance criteria**:
  - [ ] All existing planner rules preserved (pointers, numbered steps, parallel marks, worktree/branch/PR per step, quality gates)
  - [ ] Output format section now references the HTML template + DS, not `_template.md`
  - [ ] Token-efficiency rules are explicit (no inline CSS, no JS, ≤ 300 lines)
  - [ ] Path to the broken-class escalation is explicit ("propose a DS change, do not invent")

---

### Step 6: Update orchestrator `CLAUDE.md`

- **Description**: Update the "File Reference" table and the "Creating a plan" section in `orchestrator/CLAUDE.md` to reflect the new flow.
- **Specific edits**:
  - File Reference table: add rows for `pages-design-system.css`, `pages-design-system.html`, `plans/_template.html`. Mark `plans/_template.md` as `deprecated — reference only`.
  - "Creating a plan" section: rewrite steps to "(1) read project mapping, (2) read `pages-design-system.html` for available components, (3) use `plans/_template.html` as the base, (4) save as `plans/YYYY-MM-DD-<slug>.html`, (5) present the execution overview dialog."
  - File-naming: `YYYY-MM-DD-<slug>.html` is the new convention; `.md` plans are legacy.
  - Do NOT duplicate universal rules already in `/Users/gregor/dev/922/CLAUDE.md`.
- **Acceptance criteria**:
  - [ ] File Reference table updated, no broken links
  - [ ] "Creating a plan" section reflects HTML flow end-to-end
  - [ ] Plan-naming convention switched from `.md` to `.html`

---

### Step 7: Smoke-test by converting a small existing plan

- **Description**: Pick the smallest recent MD plan — `plans/2026-05-19-homeapi-openclaw-router-registration.md` (143 lines) — and produce its HTML twin at `plans/2026-05-19-homeapi-openclaw-router-registration.html` following the new template and the new planner prompt. This validates the end-to-end flow as a real reviewer would experience it.
- **Constraints**:
  - Do **not** delete the `.md` version (keep as before/after evidence in the PR)
  - HTML output should be content-only, ≤ 250 lines, no `<style>`, no `<script>`
  - Every status (done/parallel/blocked) and component (meta-grid, code block, acceptance, dataframe) should appear at least once if the source plan naturally has it; do not invent content
- **Acceptance criteria**:
  - [ ] HTML file renders correctly via `file://`
  - [ ] All steps + their meta + their acceptance criteria from the MD source are present in the HTML
  - [ ] Side-by-side: HTML version is more scannable than the MD original (the human-engagement test from the article)
  - [ ] Line count ≤ 250

---

### Step 8: Retire `plans/_template.md`

- **Description**: Rename `plans/_template.md` → `plans/_template.md.deprecated` (or move to `plans/archive/_template.md`) and add a one-line note at the top explaining it is superseded by `_template.html`.
- **Why not delete**: Historical plans link to it conceptually; a tombstone is cheaper than chasing every back-reference.
- **Acceptance criteria**:
  - [ ] Old MD template is no longer the canonical reference
  - [ ] Any reference to `_template.md` in `CLAUDE.md` or `prompts/planner.md` has been updated
  - [ ] `grep -rn '_template.md' .` returns only the tombstone itself (and possibly historical plan headers — those stay)

---

### Step 9: Push branch, open PR, capture URL

- **Description**: Push the branch, open a PR against `main` with `gh pr create`. Title: `feat: switch orchestrator plans from Markdown to HTML`. Body should reference this plan file and include a screenshot or `open` instruction so the reviewer can see the smoke-test plan in a browser.
- **Acceptance criteria**:
  - [ ] PR opened against `main`
  - [ ] PR body references `plans/2026-05-19-orchestrator-html-plans-rollout.md`
  - [ ] PR body includes the path to the smoke-test HTML plan and an "open in browser" hint
  - [ ] PR URL captured and reported back to Gregor as a clickable link

---

### Step 10: Cleanup

- **Description**: After the PR URL is reported back, remove the worktree but keep the remote branch.
- **Command**: `git -C /Users/gregor/dev/922/orchestrator worktree remove /Users/gregor/dev/922/orchestrator/.worktrees/feat-orchestrator-html-plans-rollout`
- **Acceptance criteria**:
  - [ ] Worktree directory no longer exists
  - [ ] Remote branch `origin/feat/orchestrator-html-plans-rollout` still exists (the PR owns it)

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Single wave, sequential (one branch, one PR):

  Step 1: worktree + baseline           → orchestrator @ .worktrees/feat-orchestrator-html-plans-rollout
  Step 2: extend pages-design-system.css with plan components
  Step 3: extend pages-design-system.html showcase with Plans section
  Step 4: create plans/_template.html
  Step 5: rewrite prompts/planner.md
  Step 6: update orchestrator/CLAUDE.md
  Step 7: smoke-test convert plans/2026-05-19-homeapi-openclaw-router-registration.md → .html
  Step 8: retire plans/_template.md
  Step 9: push, open PR, report URL
  Step 10: remove worktree

Branch: feat/orchestrator-html-plans-rollout
PR target: main
Agent prompt: prompts/executor.md
```

## Post-Execution Checklist

- [ ] `pages-design-system.html` showcases all plan components correctly (light mode, variant-studio)
- [ ] `plans/_template.html` exists, ≤ 80 lines, opens in a browser
- [ ] `prompts/planner.md` mandates HTML output, links to DS + template
- [ ] `orchestrator/CLAUDE.md` describes the HTML flow
- [ ] Smoke-test plan `2026-05-19-homeapi-openclaw-router-registration.html` exists and renders
- [ ] No new `<style>` blocks in any plan file
- [ ] All edits done inside the worktree, not the main checkout
- [ ] PR URL reported as a clickable link
- [ ] Worktree removed; remote branch preserved

## Token-Efficiency Contract (for the future, post-merge)

For every plan authored after this PR merges:

- **Hard rule**: zero inline CSS in plan files. CSS lives once in `pages-design-system.css`.
- **Hard rule**: zero `<script>` in plan files.
- **Soft target**: ≤ 300 lines of HTML per plan. Density beats prose.
- **Soft target**: every class used must already exist in `pages-design-system.html`. If a new component is genuinely needed, raise a DS change PR instead of inlining styles.
- **Comparison metric**: a converted plan's HTML line count should be within 1.5-2× of its Markdown equivalent (the POC was ~5× — that was the anti-pattern).

## Notes for the Executing Agent

- This is the **bootstrap** plan. It is itself authored in Markdown because the HTML template doesn't exist yet. The first real HTML plan will be the next one Gregor asks for.
- The relative stylesheet link is `../pages-design-system.css` because plans live in `orchestrator/plans/` while the DS lives at `orchestrator/pages-design-system.css`. Keep that path; do not absolute-link to `file:///`.
- If a class name in this plan looks generic (e.g. `.pill`), check `pages-design-system.css` for prior art — there is currently `.btn-pill` but no `.pill`. Adding `.pill` is fine; do not overload `.btn-pill`.
- All commits should reference this plan file in their message (e.g. `feat(plans): extend DS with plan components (plans/2026-05-19-orchestrator-html-plans-rollout)`).
- No `Co-Authored-By` trailers (universal rule).
