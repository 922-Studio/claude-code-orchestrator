# Plan: Bingo Lesson Modes (BGWP / English)

- **Date**: 2026-05-12
- **Status**: Done 2026-05-12 — PR https://github.com/922-Studio/sweatvalley_bingo/pull/4 (branch `feat/bingo-lesson-modes`)
- **Project(s)**: sweatvalley_bingo
- **Goal**: Add selectable lesson mode (`bgwp` / `english`) so the host picks which word pool the game uses, backed by two separate CSV files, with tests covering loader + game wiring + UI.

## Context

Read these files before proceeding:
- `projects/sweatvalley-bingo.md` — project mapping, tech stack, test strategy
- `/Users/gregor/dev/922/sweatvalley_bingo/CLAUDE.md` — architecture, conventions
- `/Users/gregor/dev/922/sweatvalley_bingo/server/server.js` — `loadWords()` (lines 10–33), `create-game` handler (lines 100–124), `start-game` (lines 215–280)
- `/Users/gregor/dev/922/sweatvalley_bingo/server/gameLogic.js` — pure logic (no change expected)
- `/Users/gregor/dev/922/sweatvalley_bingo/client/src/App.js` — host create-game form, settings UI
- `/Users/gregor/dev/922/sweatvalley_bingo/data/words.csv` — current German word list (becomes BGWP)

## Design Decisions

- **Mode values**: `bgwp` (default, backwards-compatible) and `english`.
- **CSV layout**:
  - `data/words.bgwp.csv` ← renamed from `data/words.csv` (1:1 content move).
  - `data/words.english.csv` ← new file, seeded with English-language equivalents using the same `word,difficulty` schema and the existing difficulty tokens (`leicht` / `mittel` / `schwer`) so `gameLogic.js` stays untouched.
- **Loader**: `loadWords()` becomes `loadWords(mode)` returning the per-mode array; server boots a map `{ bgwp: [...], english: [...] }` once at startup. No filesystem reads at game time.
- **Game state**: `game.mode` stored on the game object alongside `gridSize`/`sameWords`. `start-game` resolves the word pool via `wordsByMode[game.mode]`.
- **Selection point**: Host chooses mode in the create-game form (radio / select), sent in the `create-game` socket payload. Joining players inherit it (read-only).
- **Backwards compat**: Missing `mode` on payload → defaults to `bgwp`. No breaking change for existing clients.

## Steps

### Step 1: Split word CSVs
- **Project**: sweatvalley_bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo/data`
- **Parallel with**: Step 2
- **Description**:
  - `git mv data/words.csv data/words.bgwp.csv`.
  - Create `data/words.english.csv` with header `word,difficulty` and an English seed list (~30–40 items, mix of `leicht`/`mittel`/`schwer` — same difficulty distribution as BGWP so existing layout heuristics work).
- **Context files to read**:
  - `data/words.csv` — current content (becomes the BGWP seed); use it to gauge tone/length for the English equivalents.
- **Acceptance criteria**:
  - [ ] `data/words.bgwp.csv` exists with identical content to old `words.csv`.
  - [ ] `data/words.english.csv` exists with ≥30 entries, all three difficulties represented.
  - [ ] Old `data/words.csv` no longer exists.

### Step 2: Server — mode-aware loader & game wiring
- **Project**: sweatvalley_bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo/server`
- **Parallel with**: Step 1
- **Description**:
  - In `server.js`:
    - Replace `loadWords()` with `loadWords(mode)` that takes `'bgwp' | 'english'` and reads the matching CSV. Path resolution lives inside the function (mode → filename map).
    - At boot, build `const wordsByMode = { bgwp: loadWords('bgwp'), english: loadWords('english') };` and pass it into `createServer(wordsByMode)`.
    - `createGame` signature gains `mode` param (default `'bgwp'`), stored on the game object.
    - `create-game` handler reads `data.mode`, validates against allowed set, falls back to `'bgwp'`.
    - `start-game` resolves `const wordsList = wordsByMode[game.mode]` before calling `generateDifficultyLayout`/`generateGridFromLayout`.
    - Include `mode` in any `game-state` / `game-created` payloads so the client can display it.
  - No changes needed in `gameLogic.js` (pure functions take any word array).
- **Context files to read**:
  - `server/server.js` lines 1–35 (loader), 75–135 (create), 215–280 (start)
- **Acceptance criteria**:
  - [ ] Boot loads both CSVs and logs counts per mode.
  - [ ] Invalid `mode` from client falls back to `bgwp` (defensive default).
  - [ ] `game-created` / `game-state` payloads include `mode`.
  - [ ] No filesystem I/O after boot.

### Step 3: Server tests
- **Project**: sweatvalley_bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo/server`
- **Parallel with**: —
- **Depends on**: Step 2
- **Description**:
  - Extend `gameLogic.test.js` only if logic is touched (it shouldn't be) — skip if unchanged.
  - In `integration.test.js` / `socket.test.js`:
    - Add a test that creates a game with `mode: 'english'` and asserts the grid words all come from the English CSV (assert by membership of `word` strings in the English pool).
    - Add a test for default mode (no `mode` field) → BGWP words used.
    - Add a test that an invalid mode (`mode: 'klingon'`) is coerced to BGWP, not rejected (or: explicitly rejected — decide in Step 2 and mirror here).
  - Add a small unit test for `loadWords('english')` returning a non-empty array with valid difficulties.
- **Context files to read**:
  - `server/integration.test.js`, `server/socket.test.js` — existing patterns (set up listeners before emit)
- **Acceptance criteria**:
  - [ ] `cd server && npm test` passes locally.
  - [ ] Coverage ≥70% maintained (current pipeline gate).
  - [ ] New tests fail if mode is ignored (regression guard).

### Step 4: Client — mode picker in host form
- **Project**: sweatvalley_bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo/client/src`
- **Parallel with**: Step 2 (can be developed in parallel; final wiring after Step 2 lands)
- **Description**:
  - In `App.js`, extend the host create-game form with a mode selector (two radio buttons or a `<select>`): `BGWP` (default) and `English`.
  - Include `mode` in the `create-game` emit payload.
  - In the lobby / game header, surface the chosen mode as a small badge so joiners see context.
  - Style in `index.css` consistent with existing settings (gridSize / sameWords styling).
- **Context files to read**:
  - `client/src/App.js` — locate the host setup form and `socket.emit('create-game', ...)`
  - `client/src/index.css` — settings group styles
- **Acceptance criteria**:
  - [ ] Host can pick BGWP or English before creating a game.
  - [ ] Selected mode is visible in lobby for all players.
  - [ ] Default selection is BGWP.

### Step 5: Client tests
- **Project**: sweatvalley_bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo/client/src`
- **Parallel with**: —
- **Depends on**: Step 4
- **Description**:
  - In `App.test.js`:
    - Render the host form, change mode to English, click create, assert the emitted socket payload includes `mode: 'english'`.
    - Default render → submitted payload has `mode: 'bgwp'` (or omitted, depending on chosen wire format — keep it consistent with Step 4).
    - Snapshot/DOM assertion that the mode badge renders the selected mode in the lobby.
- **Context files to read**:
  - `client/src/App.test.js` — existing socket mocking pattern
- **Acceptance criteria**:
  - [ ] `cd client && CI=true npm test -- --watchAll=false` passes.
  - [ ] Coverage ≥30% maintained.

### Step 6: Docs + version + push
- **Project**: sweatvalley_bingo
- **Directory**: `/Users/gregor/dev/922/sweatvalley_bingo`
- **Parallel with**: —
- **Depends on**: Steps 1–5
- **Description**:
  - Update `README.md`: document the two modes, the two CSV files, and how to add words.
  - Update `CLAUDE.md` if architecture notes mention `words.csv` directly.
  - Conventional commit message (`feat:` triggers minor bump in semver workflow).
  - Push to `main`, monitor pipeline, confirm Discord notification + live URL.
- **Acceptance criteria**:
  - [ ] README explains mode selection + CSV layout.
  - [ ] CI pipeline green end-to-end (cancel → version → tests → smoke → deploy → notify).
  - [ ] https://sweatvalley-bingo.922-studio.com serves a build that exposes the mode selector.

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel):
  Step 1: Split word CSVs                          → sweatvalley_bingo @ data/
  Step 2: Server mode-aware loader + game wiring   → sweatvalley_bingo @ server/
  Step 4: Client mode picker in host form          → sweatvalley_bingo @ client/src/
          (Step 4 can start in parallel; final emit wiring synced after Step 2)

Wave 2 (after wave 1):
  Step 3: Server tests (integration + socket)      → sweatvalley_bingo @ server/
  Step 5: Client tests                             → sweatvalley_bingo @ client/src/

Wave 3 (after wave 2):
  Step 6: README/CLAUDE.md update, commit, push, monitor pipeline
```

## Post-Execution Checklist
- [ ] All tests pass (server Vitest + client Jest)
- [ ] README and CLAUDE.md reflect mode selection
- [ ] Pipeline green; live URL serves new build
- [ ] Default mode = BGWP verified (no UX regression for current users)
- [ ] Discord success notification received
