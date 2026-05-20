# Plan: Samhain Krimidinner App — v1.0 (Haunted Hotel + Ruf der Tiefen)

- **Date**: 2026-05-14 (revised after Gregor feedback)
- **Project(s)**: samhain-mobile-app
- **Goal**: Take the current Flutter prototype to a usable v1.0 covering **Haunted Hotel + Ruf der Tiefen**, with an architecture designed so adding more Krimis is a pure-data operation (drop assets in, add a `Krimi(...)` entry — no code changes). Implements Lastenheft v0.6 F1–F7, the 4-section in-app structure (Einführung / Vorbereitung / Spiel / Extras), the refreshed overview/detail design per Gregor's screenshot (2026-05-14), an automated test suite, a Flutter onboarding doc, and a live teaching/E2E session with Gregor.

## Hard Rules
- **UI language**: 100% German. Every `Text` the user sees is German. Code, comments, logs, and `docs/` are English. See memory: `feedback_german_ui.md`.
- **No placeholders**: All Krimis shown in the overview must be fully functional. v1.0 ships with **2 Krimis**: Haunted Hotel + Ruf der Tiefen. Adding the next 8 Krimis later must require **zero code changes** — only assets + a data entry.
- **Teaching mode**: As we build, Claude explains *what each piece does, why it's built this way, and what alternatives exist*, then asks Gregor short comprehension questions. Gregor's answers + corrections feed into `docs/FLUTTER_INTRO.md` so the doc captures what Gregor actually learned, not a generic tutorial.

## Context

Read these files before proceeding:
- `projects/samhain-mobile-app.md` — project mapping, tech stack, conventions
- `/Users/gregor/dev/samhain/mobile_app/pubspec.yaml` — current deps + asset declarations
- `/Users/gregor/dev/samhain/mobile_app/lib/main.dart` — theme + entry
- `/Users/gregor/dev/samhain/mobile_app/lib/models/krimi.dart` — model fields
- `/Users/gregor/dev/samhain/mobile_app/lib/data/krimis.dart` — current Haunted Hotel data
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/home_screen.dart` — overview list
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/krimi_detail_screen.dart` — current detail (will be restructured)
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/character_screen.dart` — audio player
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/pdf_viewer_screen.dart` — PDF viewer

Lastenheft v0.6 (Gregor, 2026-05-14) summary — features:
| # | Function | Notes |
|---|----------|-------|
| F1 | Krimi overview | Cover banner, title, short description, 4 spec icons |
| F2 | Interactive navigation | 4 in-app sections per Krimi |
| F3 | Audio player | Character voices, intro audio, transition audio |
| F4 | Text mode | Role booklets, host moderation hints |
| F5 | PDF docs | Menu + invitation cards, view & share |
| F6 | Send invitations | Email or WhatsApp from the app |
| F7 | Shop link | External link to krimispiele.com |

In-app structure per Krimi (4 tabs):
1. **Einführung** — host hint ("Gastgeber-Heft bereithalten"), intro text describing the Krimi, character grid.
2. **Vorbereitung** — invitations (PDF + send), deco/gift ideas, menu cards (PDF), Spotify playlist link.
3. **Das Spiel** — Ablaufplan, intro audio, transition audios, character intro audios.
4. **Extras** — open slot for additional content.

Design directives from 2026-05-14 (verbatim, to be honored):
- Overview banners per series with the series logo on the **left**, text right of it saying the series name.
- On detail (and on overview cards): title at top, then **4 square indicator icons** in a horizontal strip, each with its own number + label underneath. Per Gregor's reference screenshot (Box-Ruf-der-Tiefen style):
  1. **Spieleranzahl** — "1–7 Verfluchte" (people-at-table icon)
  2. **Dauer** — "ca. 3–4 Stunden" (clock icon)
  3. **Anspruch** — "3 von 5 Anspruch" (signal-bars icon)
  4. **Altersfreigabe** — "ab 18 Jahren" (age icon)
  The `1 ; 5 ; 1 ; 1` notation in Gregor's notes refers to those four indicator cells (one square icon each, side by side).
- Cover banner — remove text overlay, image only; the box artwork already carries its own typography. Scaling will be tuned in the E2E session.
- Character graphics with transparent background (existing PNGs already are).
- v1.0 ships **Haunted Hotel + Ruf der Tiefen**. No placeholder cards. The architecture must make Krimi #3..#10 a pure-content addition.

## Design Decisions

- **Source control**: Local git only. One feature branch per step (`feat/samhain-pilot-step-<N>`). No remote, no PRs. Sub-agents commit; Gregor merges to `main` locally after review.
- **State management**: Stay with `StatefulWidget` + setState. No Provider/Riverpod/Bloc.
- **Audio**: Bundled mp3 assets via `just_audio`. Single shared `AudioPlayerController` per detail screen so a new playback stops the previous one.
- **Navigation per Krimi**: Bottom `NavigationBar` (Material 3) with 4 tabs inside `KrimiDetailScreen`.
- **Data-driven, no placeholders**: `Krimi` model fields are nullable/optional **only** where Lastenheft says the content is optional (e.g., transition audios, deco ideas). Required content (cover, title, characters, intro text, Ablaufplan) is non-null. Adding a new Krimi = (1) drop a folder under `assets/krimis/<id>/` following the canonical layout, (2) declare the folder in `pubspec.yaml`, (3) append one `Krimi(...)` const entry to `lib/data/krimis.dart`. Nothing else.
- **Canonical asset layout per Krimi** (enforced by docs + tests):
  ```
  assets/krimis/<id>/
    cover.png                   # full-bleed box artwork, no overlay text
    series_logo.png             # series badge (used in overview series header)
    characters/<character_id>.png  # transparent background
    invitations/<character_id>.pdf
    audio/<character_id>.mp3
    audio/intro.mp3             # optional
    audio/transitions/<n>.mp3   # optional, any count
    menu/menuekarte.pdf
    role_booklets/<character_id>.pdf  # optional, text mode F4
    krimi.json (optional, future) — metadata if we later want to load from disk instead of Dart const
  ```
- **Spec indicators**: Reusable `SpecIndicator` widget (icon + value + label) and a `SpecIndicatorStrip` that lays out the 4 indicators per the screenshot. Used both on overview cards and detail header — same widget, two sizes.
- **Send invitations**: `share_plus` — single share sheet covers Email / WhatsApp / any installed handler.
- **Testing pyramid**: ~70% widget tests, ~20% unit (model + data integrity validators that prevent broken Krimi entries), ~10% integration (one end-to-end flow).
- **UI language enforcement**: Add a lightweight `tools/check_german_ui.dart` (or a unit test) that grep-asserts no obvious English UI strings sneak into `lib/screens/` and `lib/widgets/`. Best-effort, not a hard gate — easy to evade, but catches accidents.

## Steps

### Step 0: Initialize git + commit baseline + scaffold docs folder
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app`
- **Branch**: `main` (initial commit), no worktree
- **Parallel with**: —
- **Description**:
  - `git init`, add `.flutter-plugins-dependencies`, `build/`, `.dart_tool/`, `*.iml`, `flutter_*.log` to `.gitignore` (current file is sparse — extend it).
  - Commit current state as `chore: initial commit (Haunted Hotel prototype)`.
  - Create `docs/` directory with empty `lastenheft.md` placeholder (Gregor will paste v0.6 content later or Step 7 fills it).
- **Context files to read**:
  - `.gitignore` — verify what already excluded; extend, don't duplicate.
- **Acceptance criteria**:
  - [ ] `git log` shows a single baseline commit on `main`.
  - [ ] `docs/` exists and is tracked.
  - [ ] `git status` clean.

### Step 1: Flutter intro doc — written *live with Gregor* during teaching mode
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app`
- **Branch**: `feat/samhain-pilot-step-1`
- **Parallel with**: Steps 2, 3 (the doc is written incrementally throughout)
- **Description**:
  This step is **not** a sub-agent task — Claude runs it inline. While building Steps 2–6, Claude:
  1. Explains *what each piece of Flutter does and why* before editing it (e.g. before rewriting `home_screen.dart`, explain `Widget`, `build()`, `BuildContext`, `setState`).
  2. Asks Gregor 1–2 short comprehension questions per concept (e.g. "Why does Flutter call `build()` on every state change instead of mutating widgets in place?").
  3. Captures Gregor's answers + corrections + the actual decision into `docs/FLUTTER_INTRO.md`, so the doc reflects **what Gregor learned**, not a generic tutorial.
  4. The doc is structured as a sequence of short concept notes keyed to where they were applied in the code (e.g. "We hit `StatefulWidget` first in `character_screen.dart` — here's why audio needs state.").
  Topics covered organically over the build:
  - Widget tree, `StatelessWidget` vs `StatefulWidget`, `setState`, `BuildContext`
  - `pubspec.yaml`: deps + asset declarations; silent-failure trap
  - Hot reload vs hot restart
  - `const` constructors (and why our data layer is heavily `const`)
  - Asset lifecycle, `rootBundle`
  - `Future`/`async`/`await` (intro audio playback)
  - `dispose` and resource cleanup (audio player)
  - Navigation (`Navigator.push`, named routes — when each)
  - Material 3 theming + how our dark/red identity is applied
  - Testing: unit vs widget vs integration (added after Step 7)
- **Acceptance criteria**:
  - [ ] By end of Step 8, `docs/FLUTTER_INTRO.md` covers all topics above, anchored to real files we touched.
  - [ ] Each concept section ends with a 1-line "Gregor's takeaway" — the answer to a question he got asked.
  - [ ] No marketing fluff; ≤ 400 lines total.

### Step 2: Model + data layer for content-driven Krimis (no placeholders)
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib`
- **Branch**: `feat/samhain-pilot-step-2`
- **Parallel with**: Steps 1, 3
- **Description**:
  - Extend `models/krimi.dart`:
    - `Krimi` gains (required unless marked optional):
      - `String seriesName` (required)
      - `String seriesLogoPath` (required)
      - `String coverPath` (rename from `thumbnailPath` — clearer; keep getter alias for backwards-compat to avoid churn elsewhere)
      - `String introText` (required, German)
      - `String? introAudioPath` (optional)
      - `List<String> transitionAudioPaths` (default `const []`)
      - `String ablaufplanText` (required, German — Markdown-style allowed)
      - `List<String> decoIdeas` (default `const []`, German)
      - `String? invitationsBundlePdfPath`
      - `SpecIndicators specs` — see below (required)
    - New value class `SpecIndicators` carrying the 4 indicator values used both on overview + detail:
      - `String playersLabel` (e.g. `"1–7 Verfluchte"`)
      - `String durationLabel` (e.g. `"ca. 3–4 Stunden"`)
      - `String difficultyLabel` (e.g. `"3 von 5 Anspruch"`)
      - `String ageLabel` (e.g. `"ab 18 Jahren"`)
      - Plus the raw numeric fields (`int minPlayers, maxPlayers, minDuration, maxDuration, difficulty, minAge`) for any future filtering UI.
    - `Character` gains: `String? roleDescription` (German long-form, optional), `String? roleBookletPdfPath` (optional).
  - Add `data/series.dart` with a `Series` const list. Two confirmed series so far:
    - `'horror'` → label `"Horror"` (Haunted Hotel, …)
    - `'mystery'` → label TBD with Gregor (Ruf der Tiefen sits here unless he says otherwise; ask in teaching mode).
  - Update `data/krimis.dart` to contain **exactly two** entries:
    - Haunted Hotel (existing data, mapped to new model + `SpecIndicators`).
    - Ruf der Tiefen (new — cover at `assets/krimis/ruf_der_tiefen/thumbnail/Box-Ruf-der-Tiefen.png`, characters/audio/PDFs TBD by Gregor; for v1.0 launch we need minimum viable content: cover, title, intro text, Ablaufplan, and the spec indicator values — characters/audio can land in a follow-up).
  - Add a small **content validator** `lib/data/krimi_validator.dart` exporting `void validateAllKrimis()` that asserts: unique ids, non-empty required strings, all asset paths declared. Call it once from `main()` in debug mode (`assert(() { validateAllKrimis(); return true; }())`).
- **Context files to read**:
  - `models/krimi.dart`, `data/krimis.dart`, `pubspec.yaml`
- **Acceptance criteria**:
  - [ ] `flutter analyze` clean.
  - [ ] `allKrimis.length == 2`; both fully populated.
  - [ ] No `isPlaceholder` flag anywhere.
  - [ ] `validateAllKrimis()` passes in debug-mode boot.
  - [ ] `docs/ADDING_A_KRIMI.md` written: a 1-page recipe for adding Krimi #3 — copy a folder, declare assets, append a `Krimi(...)` entry. No code changes elsewhere.

### Step 3: Asset reorg + Ruf der Tiefen scaffolding
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/assets`
- **Branch**: `feat/samhain-pilot-step-3`
- **Parallel with**: Steps 1, 2
- **Description**:
  - Standardize `assets/krimis/<id>/` layout for both Krimis. For Haunted Hotel this is mostly cosmetic (already laid out); leave existing files in place to avoid breaking paths.
  - For Ruf der Tiefen: the cover already exists at `assets/krimis/ruf_der_tiefen/thumbnail/Box-Ruf-der-Tiefen.png`. Create empty subfolders for `characters/`, `invitations/`, `audio/`, `menu/`, `role_booklets/` so the canonical layout is discoverable. Add a `assets/krimis/ruf_der_tiefen/README.md` noting which content is still pending from Roger.
  - Create `assets/series/` with two logos: `horror.png` (existing Samhain horror branding if available; else a simple text badge) and one for Ruf der Tiefen's series. **Ask Gregor** in teaching mode whether the homepage already has series-level branding we can reuse from `samhain/homepage/wp-content/uploads/`.
  - Update `pubspec.yaml`:
    - Add `assets/krimis/ruf_der_tiefen/thumbnail/`
    - Add `assets/krimis/ruf_der_tiefen/characters/`, `invitations/`, `audio/`, `menu/`, `role_booklets/`
    - Add `assets/series/`
  - **Do not** delete or rename existing Haunted Hotel assets.
- **Context files to read**:
  - `pubspec.yaml` (assets block), `assets/krimis/ruf_der_tiefen/`
- **Acceptance criteria**:
  - [ ] `flutter pub get` succeeds.
  - [ ] `flutter build web --no-tree-shake-icons` smoke passes.
  - [ ] Ruf der Tiefen cover renders in overview without `Unable to load asset` console errors.

### Step 4: Overview redesign + reusable `SpecIndicatorStrip` widget
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib`
- **Branch**: `feat/samhain-pilot-step-4`
- **Parallel with**: —
- **Depends on**: Steps 2, 3
- **Description**:
  - New widget `lib/widgets/spec_indicator_strip.dart` exporting:
    - `SpecIndicator(icon, value, label)` — single square cell, dark background, icon on top, big number/short value in the middle, small label below (matches screenshot).
    - `SpecIndicatorStrip(specs, size)` — lays out the 4 indicators horizontally; `size` picks between compact (overview card) and full (detail header).
    - Icons (Material): `Icons.groups` for Verfluchte, `Icons.schedule` for Stunden, `Icons.signal_cellular_alt` for Anspruch, `Icons.cake` for Altersfreigabe. Swap to custom SVG/PNG once Gregor delivers the squared icons.
  - Rebuild `lib/screens/home_screen.dart`:
    - Group Krimis by `seriesName`. Each group renders a **series header row** (logo LEFT, series label right) before its cards.
    - Krimi card layout (top → bottom):
      1. Cover image only (no overlay text/badges).
      2. Title (German).
      3. `SpecIndicatorStrip(specs, compact)`.
    - Tap → existing `KrimiDetailScreen` route (Step 5 restructures it).
  - All copy in German: "Krimi-Dinner", "von <author>", etc.
- **Context files to read**:
  - Current `home_screen.dart`, `data/krimis.dart` (post-Step-2)
- **Acceptance criteria**:
  - [ ] Series header renders for both Krimis' series.
  - [ ] Each card shows cover (only), then title, then 4 indicator squares matching the reference screenshot's visual structure.
  - [ ] `flutter analyze` clean.
  - [ ] No English UI strings introduced (run `tools/check_german_ui.dart` if it exists yet, otherwise spot-check).

### Step 5: Detail screen restructure (4-tab navigation + new sections)
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib/screens`
- **Branch**: `feat/samhain-pilot-step-5`
- **Parallel with**: —
- **Depends on**: Steps 2, 3
- **Description**:
  Restructure `krimi_detail_screen.dart` into a `Scaffold` with a `NavigationBar` (Material 3 bottom nav), 4 destinations:
  1. **Einführung** (`lib/screens/sections/einfuehrung_section.dart` — new):
     - Top callout: "Halte das Gastgeber-Heft für die Auflösung bereit." in a styled card.
     - Intro text (from `krimi.introText`).
     - Character grid (re-use existing grid from current detail screen).
  2. **Vorbereitung** (`lib/screens/sections/vorbereitung_section.dart` — new):
     - "Einladungen" — list each character's invitation PDF + a button "Per Email / WhatsApp senden" using `share_plus`.
     - "Deko / Gast-Geschenke" — bullet list from `krimi.decoIdeas` (empty for now → "Inhalte folgen").
     - "Menükarte" — opens existing PDF viewer.
     - "Spotify-Playlist" — existing external link launcher.
  3. **Das Spiel** (`lib/screens/sections/spiel_section.dart` — new):
     - "Ablaufplan" — render `krimi.ablaufplanText` (Markdown-style or simple `Text` with line breaks — pick simplest).
     - "Einleitungs-Audio" — play `krimi.introAudioPath` via the same `AudioPlayer` pattern used in `character_screen.dart`.
     - "Überleitungs-Audios" — list each transition audio with a play button.
     - "Charakter-Audios" — list each character with their audio; tap → existing `CharacterScreen`.
  4. **Extras** (`lib/screens/sections/extras_section.dart` — new):
     - For pilot: just a "Shop besuchen" tile that launches `https://krimispiele.com`.
     - Leave room for more content blocks.
  - The app bar at the top should keep the cover image as a `SliverAppBar` only on the **Einführung** tab, or extract the cover to a small fixed banner above the nav — pick whatever reads cleanest visually and report the choice.
  - Add a single `AudioPlayerController` (a thin wrapper around `just_audio.AudioPlayer`) shared across the Spiel tab to avoid two audios playing simultaneously. Dispose on screen exit.
- **Context files to read**:
  - Current `krimi_detail_screen.dart`, `character_screen.dart` (audio lifecycle pattern).
- **Acceptance criteria**:
  - [ ] All 4 tabs render without errors on Haunted Hotel.
  - [ ] Audio playback in Spiel tab works (intro audio plays, stops correctly).
  - [ ] Starting a second audio stops the first.
  - [ ] Invitations tab: tapping "Senden" opens the system share sheet (verify in Chrome — share sheet falls back to copying URL; on Android device it shows Email/WhatsApp).
  - [ ] Shop link in Extras opens `https://krimispiele.com` in an external browser.
  - [ ] `flutter analyze` clean.

### Step 6: Send-invitations via share_plus + text mode for role booklets
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib`
- **Branch**: `feat/samhain-pilot-step-6`
- **Parallel with**: —
- **Depends on**: Step 5
- **Description**:
  - Add `share_plus: ^10.0.0` to `pubspec.yaml`; run `flutter pub get`.
  - In Vorbereitung section, the "Senden" action loads the invitation PDF as bytes (`rootBundle.load`), writes to a temp file via `path_provider`, and calls `Share.shareXFiles([XFile(path)], text: '...')`.
  - Add `path_provider: ^2.1.0`.
  - Text mode (F4): on `CharacterScreen`, add a "Rolle lesen" button that opens a new screen (`character_text_screen.dart`) showing `character.roleDescription` (long-form text, scrollable). If `roleBookletPdfPath` is set, also show a "PDF öffnen" button.
- **Context files to read**:
  - Current `character_screen.dart`, `pdf_viewer_screen.dart`.
- **Acceptance criteria**:
  - [ ] Share sheet appears in Chrome with a fallback message or on Android with real handlers (depending on platform).
  - [ ] "Rolle lesen" screen renders text and is scrollable for long bodies.
  - [ ] No `unused_import` or other analyzer warnings.

### Step 7: Test suite (unit + widget + integration)
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/test` (+ new `integration_test/`)
- **Branch**: `feat/samhain-pilot-step-7`
- **Parallel with**: —
- **Depends on**: Steps 4–6
- **Description**:
  - **Unit tests** (`test/models/`, `test/data/`):
    - `Krimi`/`Character` defaults (placeholders default to `isPlaceholder: false`, lists default to empty).
    - `allKrimis` has exactly 10 entries; exactly one non-placeholder; all `thumbnailPath` resolve to declared asset directories.
    - All character image paths in Haunted Hotel point to existing asset paths (string check + `File` existence via a `dart:io` test runner — gated `@TestOn('vm')`).
  - **Widget tests** (`test/screens/`):
    - `home_screen_test.dart` — pump `HomeScreen`, assert 1 series header + 10 cards rendered, 9 cards have the "Bald verfügbar" badge.
    - `krimi_detail_screen_test.dart` — pump detail for Haunted Hotel, switch through all 4 tabs, assert each renders its key heading.
    - `character_screen_test.dart` — render with audio path null vs set; assert play button only shown when audio exists.
  - **Integration test** (`integration_test/app_test.dart`):
    - Launch app → tap Haunted Hotel → cycle Einführung → Vorbereitung → Spiel → Extras → tap Shop link (intercept `url_launcher` via platform mock).
  - Add `dev_dependency`: `integration_test` (from Flutter SDK).
  - Wire `flutter test` to run unit + widget; document `flutter test integration_test/` separately in `docs/FLUTTER_INTRO.md`.
- **Context files to read**:
  - Existing `test/` dir (currently has only the default sample test — confirm what's there).
- **Acceptance criteria**:
  - [ ] `flutter test` passes (unit + widget).
  - [ ] `flutter test integration_test/` passes on Chrome (`flutter test integration_test/ -d chrome`).
  - [ ] No analyzer warnings introduced by test code.
  - [ ] Test files follow `_test.dart` suffix convention.

### Step 8: Manual E2E walk-through with Gregor + design polish pass
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app`
- **Branch**: `feat/samhain-pilot-step-8`
- **Parallel with**: —
- **Depends on**: Steps 4–7
- **Description**:
  - Run app in Chrome; Claude drives, Gregor reviews live.
  - Walk through the E2E checklist (see "E2E Checklist" below).
  - For each item flagged by Gregor: either fix on the spot (small CSS-like tweak) or capture as a follow-up in a "Polish backlog" section of this plan.
  - Resolve the open design questions:
    - 4th spec icon (difficulty? other?)
    - "Icons 1 ; 5 ; 1 ; 1" — confirm final overview layout slots.
    - Cover banner scaling values.
  - Final commit: `feat: v1.0 pilot ready for review`.
- **Acceptance criteria**:
  - [ ] E2E checklist all green or moved to polish backlog with justification.
  - [ ] No regressions in `flutter test` or `flutter analyze`.
  - [ ] `docs/FLUTTER_INTRO.md` updated with final test-running instructions from Step 7.

## E2E Checklist (used in Step 8)

Overview:
- [ ] App header renders (German).
- [ ] Series header(s) render with logo left + name right.
- [ ] Both Krimi cards: cover-only image, title below, 4-indicator strip below — matches reference screenshot.
- [ ] Tap either card → detail with 4-tab nav.
- [ ] No English UI strings visible anywhere.

Einführung:
- [ ] "Gastgeber-Heft bereithalten" callout visible.
- [ ] Intro text renders.
- [ ] Character grid renders with transparent-background art (confirm character PNGs render cleanly on the dark theme).

Vorbereitung:
- [ ] Invitations list renders one row per character with both "Ansehen" and "Senden" actions.
- [ ] "Ansehen" opens the PDF.
- [ ] "Senden" triggers share sheet.
- [ ] Menükarte opens.
- [ ] Spotify link opens externally.

Spiel:
- [ ] Ablaufplan readable.
- [ ] Intro audio plays / pauses.
- [ ] Transition audios listed and playable.
- [ ] Character audios listed; tap → CharacterScreen.
- [ ] Starting a second audio stops the first.

Extras:
- [ ] Shop link opens `https://krimispiele.com`.

Cross-cutting:
- [ ] Back navigation never strands the user.
- [ ] No `Unable to load asset` errors in the console for any normal path.
- [ ] No audio bleeds after leaving a screen (verify by `dispose`).

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 0 (sequential, prerequisite):
  Step 0: Init git + baseline commit                          → samhain-mobile-app @ /

Wave 1 (parallel — independent foundations):
  Step 1: Flutter intro doc                                   → docs/
  Step 2: Model + data extensions (+ 9 stubs)                 → lib/models, lib/data
  Step 3: Asset reorg + placeholder asset                     → assets/, pubspec.yaml

Wave 2 (parallel — depend on Wave 1):
  Step 4: Overview redesign (series banners + placeholders)   → lib/screens/home_screen.dart
  Step 5: Detail screen restructure (4-tab nav)               → lib/screens/krimi_detail_screen.dart + sections/
  (Step 4 and Step 5 touch different files — safe to parallelize.)

Wave 3 (sequential, depends on Wave 2):
  Step 6: Send invitations (share_plus) + text mode           → lib/screens/

Wave 4 (sequential, depends on Wave 3):
  Step 7: Test suite (unit + widget + integration)            → test/, integration_test/

Wave 5 (manual, with Gregor):
  Step 8: E2E walk-through + design polish + final commit     → all
```

## Sub-Agent Execution Prompts

Each prompt is copy-paste-ready. Each agent should run via the `Agent` tool with `subagent_type: claude` (default) and read the listed context files first.

### Prompt — Step 0
```
You are executing Step 0 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

Read first:
- /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md (Step 0 section)
- /Users/gregor/dev/samhain/mobile_app/.gitignore

Work directory: /Users/gregor/dev/samhain/mobile_app

Do:
1. Run `git init` if not already a repo.
2. Extend .gitignore to also exclude: build/, .dart_tool/, .flutter-plugins, .flutter-plugins-dependencies, *.iml, flutter_*.log, .idea/ (keep .idea entries already there).
3. Create docs/ with an empty `lastenheft.md` placeholder file (single line "# Lastenheft v0.6 (TBD)").
4. `git add -A && git commit -m "chore: initial commit (Haunted Hotel prototype)"`.

Report: commit SHA + branch (`main`). Do not push.
```

### Prompt — Step 1
```
You are executing Step 1 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

Read first:
- The plan file (Step 1 section)
- /Users/gregor/dev/922/orchestrator/projects/samhain-mobile-app.md
- All files in /Users/gregor/dev/samhain/mobile_app/lib/ (for examples)
- /Users/gregor/dev/samhain/mobile_app/pubspec.yaml

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: create + switch to `feat/samhain-pilot-step-1` off `main`.

Write docs/FLUTTER_INTRO.md per the spec in Step 1. Keep under 300 lines. Reference real file paths in this repo. No code changes outside docs/.

Commit (`docs: add Flutter onboarding intro`). Do not push. Leave the branch checked out; report the branch name.
```

### Prompt — Step 2
```
You are executing Step 2 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

HARD RULES (do not violate):
- 100% German for any user-visible string. Code, comments, logs, docs/ stay English.
- NO placeholder Krimis. v1.0 has exactly two Krimis: Haunted Hotel + Ruf der Tiefen, both fully populated.

Read first:
- The plan file (Hard Rules + Step 2 section + Canonical asset layout)
- /Users/gregor/dev/922/orchestrator/projects/samhain-mobile-app.md
- /Users/gregor/dev/samhain/mobile_app/lib/models/krimi.dart
- /Users/gregor/dev/samhain/mobile_app/lib/data/krimis.dart

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-pilot-step-2` off `main`.

Do:
1. Extend Krimi model with required fields (seriesName, seriesLogoPath, introText, ablaufplanText, specs: SpecIndicators) and optional fields (introAudioPath, transitionAudioPaths, decoIdeas, invitationsBundlePdfPath). Rename thumbnailPath → coverPath with a deprecated getter alias.
2. Add SpecIndicators value class with the 4 indicator label strings (German) + raw numeric fields.
3. Add lib/data/series.dart with at least one Series entry.
4. Update lib/data/krimis.dart to have EXACTLY two entries: Haunted Hotel (mapped to new model) and Ruf der Tiefen (minimum viable content: cover at assets/krimis/ruf_der_tiefen/thumbnail/Box-Ruf-der-Tiefen.png, German title + introText + ablaufplanText + specs). For Ruf der Tiefen, leave characters list empty until Gregor delivers them — the model and detail screen must handle empty character lists gracefully.
5. Add lib/data/krimi_validator.dart with validateAllKrimis(); call it from main() inside an assert in debug mode.
6. Write docs/ADDING_A_KRIMI.md — a one-page German-audience-aware recipe (doc itself in English, examples reference German content) for adding Krimi #3: drop folder, declare assets, append const entry.

Run `flutter analyze` — must be clean.
Commit (`feat: content-driven Krimi model + SpecIndicators + Ruf der Tiefen entry`).
Report branch + analyzer output + the final `allKrimis.length`.
```

### Prompt — Step 3
```
You are executing Step 3 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

HARD RULES: German UI; no placeholder Krimis.

Read first:
- The plan file (Step 3 section + Canonical asset layout)
- /Users/gregor/dev/samhain/mobile_app/pubspec.yaml
- /Users/gregor/dev/samhain/mobile_app/lib/data/series.dart (post-Step-2)
- ls /Users/gregor/dev/samhain/mobile_app/assets/krimis/ruf_der_tiefen/
- Optionally ls /Users/gregor/dev/samhain/homepage/wp-content/uploads/2023/10/ for reusable Ruf der Tiefen branding (menu/playlist/name-tag PDFs are there).

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-pilot-step-3` (off Step 2 tip).

Do:
1. Ensure Ruf der Tiefen canonical asset folders exist: characters/, invitations/, audio/, menu/, role_booklets/. Create assets/krimis/ruf_der_tiefen/README.md listing what content is still needed.
2. Create assets/series/ with at least the Horror series logo (generate a simple dark "HORROR" badge PNG via ImageMagick if you do not have a real logo; flag for Gregor to replace).
3. Update pubspec.yaml assets list to declare every canonical folder for both Krimis + assets/series/.
4. Do NOT delete or rename existing Haunted Hotel assets.
5. Run `flutter pub get` → `flutter build web --no-tree-shake-icons` smoke.

Commit (`chore: standardize asset layout + Ruf der Tiefen scaffolding`).
Report branch + which assets remain TODO per the README you wrote.
```

### Prompt — Step 4
```
You are executing Step 4 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

HARD RULES: German UI; no placeholders; build the reusable SpecIndicatorStrip widget so it can be reused on the detail header in Step 5.

Read first:
- The plan file (Step 4 section + Design directives)
- The reference screenshot description: 4 square indicator cells, each with an icon on top, big short value in the middle, small label below ("1–7 Verfluchte", "ca. 3–4 Stunden", "3 von 5 Anspruch", "ab 18 Jahren").
- /Users/gregor/dev/samhain/mobile_app/lib/screens/home_screen.dart
- /Users/gregor/dev/samhain/mobile_app/lib/data/krimis.dart (post-Step-2)
- /Users/gregor/dev/samhain/mobile_app/lib/data/series.dart

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-pilot-step-4` (off step-3 tip).

Do:
1. Create lib/widgets/spec_indicator_strip.dart with SpecIndicator and SpecIndicatorStrip (compact + full sizes).
2. Rebuild home_screen.dart: group by series; series header (logo LEFT, German label right); per-card layout cover → title → SpecIndicatorStrip(compact).
3. Every string the user sees must be German.
4. Run app in Chrome and verify visually before reporting. Stop Chrome before exit.

`flutter analyze` must be clean.
Commit (`feat: overview redesign with series headers and SpecIndicatorStrip`).
Report a 5-line visual description.
```

### Prompt — Step 5
```
You are executing Step 5 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

Read first:
- The plan file (Step 5 section)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/krimi_detail_screen.dart (current)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/character_screen.dart (audio pattern)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/pdf_viewer_screen.dart

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-pilot-step-5` (off step-3 tip; safe to parallelize with step-4 — different files).

Implement the 4-tab nav (Einführung / Vorbereitung / Spiel / Extras) with the section files listed in the plan. Create a small AudioPlayerController wrapper to prevent overlapping playback.

Run `flutter analyze` — must be clean. Run app in Chrome and click through all 4 tabs.

Commit (`feat: 4-section detail nav with shared audio controller`).
```

### Prompt — Step 6
```
You are executing Step 6 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

Read first:
- The plan file (Step 6 section)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/character_screen.dart
- /Users/gregor/dev/samhain/mobile_app/lib/screens/sections/vorbereitung_section.dart (from Step 5)

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-pilot-step-6` (off step-5 tip).

Add share_plus + path_provider, wire the share flow, and add the text-mode reading screen. Test the share sheet manually in Chrome (will fall back to clipboard / browser share API).

Commit (`feat: invitation share flow + character text-mode screen`).
```

### Prompt — Step 7
```
You are executing Step 7 of /Users/gregor/dev/922/orchestrator/plans/2026-05-14-samhain-app-v1-pilot.md.

Read first:
- The plan file (Step 7 section)
- /Users/gregor/dev/samhain/mobile_app/test/ (existing test, if any)
- All files in /Users/gregor/dev/samhain/mobile_app/lib/

Work directory: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-pilot-step-7` (off step-6 tip).

Add unit + widget + integration tests per the spec. Ensure `flutter test` and `flutter test integration_test/ -d chrome` both pass.

Commit (`test: add unit, widget, and integration test suite`).
Report the test counts and any flakiness observed.
```

### Step 8 — driven live by Claude + Gregor (no sub-agent)

Run interactively in the main session. Claude drives, Gregor watches and calls out tweaks.

## Open Questions (resolve in teaching/E2E session)

1. **Series for Ruf der Tiefen** — is it the same "Horror" series or its own? Affects overview grouping.
2. **Series logos** — does the homepage already have series-level branding we can reuse?
3. **Ruf der Tiefen content** — which characters, audios, PDFs exist today; which are pending from Roger?
4. **Cover banner scaling** — fixed height, aspect ratio, or full-width letterbox? (To be tuned visually with Gregor in the E2E session.)
5. **Ablaufplan format** — free text, structured timeline, or PDF? Default: Markdown-style text rendered as German body copy.
6. **Send invitations message body** — German pre-filled message for the share sheet?
7. **Squared indicator icons** — Gregor will deliver custom icons; until then we use Material icons matching the screenshot's intent.

## Post-Execution Checklist
- [ ] All step branches exist locally and have been reviewed by Gregor.
- [ ] `flutter analyze` clean on the final merged branch.
- [ ] `flutter test` green.
- [ ] `flutter test integration_test/ -d chrome` green.
- [ ] `docs/FLUTTER_INTRO.md` final.
- [ ] E2E checklist all green or items moved to a documented polish backlog.
- [ ] Roger has been pinged for v1.0 content delivery on the 9 placeholder Krimis (separate, non-coding task).
