# Plan: Samhain Mobile App — Detail-Screen Polish & Shop Deep-Linking

- **Date**: 2026-05-19
- **Project(s)**: samhain-mobile-app
- **Goal**: Three targeted fixes on top of the v1.0 pilot — (a) eliminate the slow first-paint + janky scrolling of the menu PDF by pre-warming the document before the user opens it, (b) replace the fixed, non-scrolling cover header in the detail screen with a header that scrolls away while the bottom nav stays put, and (c) make the shop link deep-link to the specific Krimi product instead of the storefront root.

## Context

Read these files before proceeding:
- `projects/samhain-mobile-app.md` — project mapping (tech stack, conventions, German-UI hard rule)
- `/Users/gregor/.claude/projects/-Users-gregor-dev-samhain-mobile-app/memory/feedback_german_ui.md` — 100% German UI rule (still applies to every new label introduced here)
- `/Users/gregor/dev/samhain/mobile_app/lib/models/krimi.dart` — current model; will gain `shopUrl`
- `/Users/gregor/dev/samhain/mobile_app/lib/data/krimis.dart` — both Krimi entries; will get product URLs
- `/Users/gregor/dev/samhain/mobile_app/lib/data/krimi_validator.dart` — extend for the new field if it becomes required
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/krimi_detail_screen.dart` — current fixed `_Header` inside a `Column` (line 39-64); the cause of the "stale header" complaint
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/sections/einfuehrung_section.dart`, `vorbereitung_section.dart`, `spiel_section.dart`, `extras_section.dart` — each uses a top-level `ListView` (must convert to slivers if NestedScrollView is chosen, or keep as ListView if "header inside each section" is chosen — see Step 2 design)
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/pdf_viewer_screen.dart` — current viewer uses `PdfViewer.asset(assetPath)` (synchronous-looking but does on-demand decode at first paint)
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/sections/extras_section.dart` — shop link target (line 20)
- `/Users/gregor/dev/samhain/mobile_app/lib/screens/sections/vorbereitung_section.dart` — Menükarte tile (line 80–97); the entry point that needs to consume the pre-warmed document

Pre-existing constraints to honor (do NOT relax without Gregor confirming):
- All new user-visible text in German.
- No placeholder Krimis; both real Krimis must keep working.
- Local git only (no remote); commit per step; merge to `main` after each step's analyzer + test pass.
- State management stays `StatefulWidget` + `setState`. Do NOT introduce Provider/Riverpod/Bloc.

## Design Decisions

### Fix A — Menu pre-warming
- Use `pdfrx`'s document API directly. Instead of having `PdfViewerScreen` take an `assetPath` and start decoding when it mounts, the screen will take an already-created `PdfDocumentRef` (specifically `PdfDocumentRefAsset` from `pdfrx`). The viewer then renders the in-flight or already-resolved document — no fresh decode work.
- `KrimiDetailScreen` becomes a stateful host that, on `initState`, immediately constructs `PdfDocumentRefAsset(menuPdfPath)` for the Krimi (if `menuPdfPath != null`) and holds onto it for the screen's lifetime. The "Menükarte" tile then navigates with that ref.
- Same treatment for character invitations if there is appetite (they're smaller, but the same lag exists). For this plan: **only the menu** is pre-warmed (clearly Gregor's pain point); invitations stay on the per-tap path to avoid memory pressure.
- Trade-off: PDF stays in memory while the detail screen lives. For a single Krimi at a time on the host's phone, that's fine.
- Fallback: if the user never opens the menu, the work is wasted. Worst case is a few hundred ms of extra background decode on detail-screen entry — acceptable.
- Scrolling jank specifically: `pdfrx` renders pages as PNG textures; the first-page texture upload happens lazily. Pre-warming the document ref does **not** by itself force texture upload, but it removes the parse step from the critical path. If jank remains after this step, follow-up plan: pre-render page 1 with `PdfDocument.pages.first.render(...)` into a cached image before the user taps. Out of scope for now — measure first.

### Fix B — Scrollable detail header
- Replace the `Column [Header, Expanded(IndexedStack(...))]` with **`NestedScrollView`**:
  - `headerSliverBuilder` returns a `SliverAppBar` that holds the cover image and the title + `SpecIndicatorStrip(size: SpecStripSize.full)`.
  - `body` is the same `IndexedStack` of section widgets, but each section is converted to use `CustomScrollView` with sliver-based children (or kept as `ListView` and wrapped via the `NestedScrollViewBuilder` pattern — pdftrx + NestedScrollView requires the inner scrollables to use `SliverFillRemaining` / `CustomScrollView`, so we convert).
- The bottom `NavigationBar` is unchanged and stays pinned at the bottom (it's a `Scaffold.bottomNavigationBar`, never part of any scroll view).
- `SliverAppBar` is configured:
  - `pinned: false`, `floating: false`, `snap: false` → fully scrolls away.
  - `expandedHeight: ~280` (current header is ~310 visually with cover + title + indicators).
  - `flexibleSpace: FlexibleSpaceBar` with the cover image as `background:` and a darkening gradient on top.
  - The title + indicators live inside `bottom:` as a `PreferredSize` of ~120, so they remain visible until the user scrolls past them.
  - Back button: a `leading` `IconButton` on the SliverAppBar with tooltip `'Zurück'`.
- Why `NestedScrollView` and not "embed header into each section's `ListView`":
  - Repeating the header in 4 places couples sections to header layout; bad refactor cost.
  - `NestedScrollView` is the Flutter-canonical answer for "SliverAppBar + tabbed body" — it handles the overscroll, the parallax, the gesture handoff between header and body for free.
- Risk: the section `ListView`s must become `CustomScrollView` (or be wrapped) for the inner-scroll-handoff to work correctly. Plan converts them to `CustomScrollView` with `SliverList` / `SliverPadding`. This is a mechanical change.

### Fix C — Per-Krimi shop deep-link
- Add `final String? shopUrl;` to `Krimi`. Optional; falls back to `https://krimispiele.com` (current behavior) if null.
- Validator: NOT required field — so existing Krimis without a known URL still ship. Do log a debug-only `print` warning in `validateAllKrimis()` if `shopUrl == null` so Gregor sees it in the boot log.
- `ExtrasSection` reads `krimi.shopUrl ?? 'https://krimispiele.com'`. Subtitle text updates to the actual hostname/path so the user sees where the tap will take them.
- Both Krimi entries need their real product URLs. The slug convention on `krimispiele.com` is unknown from the local snapshot. Two options for sub-agent:
  1. Use `WebFetch` to hit `https://krimispiele.com` and find the product URLs for "Haunted Hotel" and "Ruf der Tiefen".
  2. If WebFetch is blocked, fall back to the canonical WooCommerce pattern `https://krimispiele.com/produkt/<slug>/` with slugs `haunted-hotel` and `ruf-der-tiefen`, and surface this assumption in the step report so Gregor can correct it.

## Steps

### Step 1: Add `shopUrl` field + populate per-Krimi product URLs
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib`
- **Branch**: `feat/samhain-detail-fixes-step-1` (off current `main`)
- **Parallel with**: Steps 2 and 3 — different files; no overlap with the detail screen or PDF viewer.
- **Description**:
  - Extend `Krimi` (`lib/models/krimi.dart`): add `final String? shopUrl;` and the matching constructor param (default `null`, NOT required).
  - Update `lib/data/krimis.dart`:
    - Resolve the canonical product URLs. Preferred path: use `WebFetch` against `https://krimispiele.com` and locate the product permalinks for "Haunted Hotel" and "Ruf der Tiefen". If unreachable, fall back to WooCommerce convention (`/produkt/<slug>/`) and surface the assumption in the commit body.
    - Populate `shopUrl` on both Krimi entries.
  - Extend `lib/data/krimi_validator.dart`: do NOT throw on null; instead, when in debug mode, `debugPrint` a warning `'Krimi <id>: shopUrl ist nicht gesetzt – Shop-Link nutzt den Startseiten-Fallback.'` (German because it's visible in dev console while testing the app).
  - Update `lib/screens/sections/extras_section.dart`:
    - Read `krimi.shopUrl ?? 'https://krimispiele.com'`.
    - Subtitle: derive from the URL host+path (e.g. `'krimispiele.com/produkt/haunted-hotel/'`). Helper: small `String _shortUrl(String url)` that strips scheme and trailing slash.
    - Label stays `'Shop besuchen'`.
- **Context files to read**:
  - `lib/models/krimi.dart`, `lib/data/krimis.dart`, `lib/data/krimi_validator.dart`, `lib/screens/sections/extras_section.dart`
- **Acceptance criteria**:
  - [ ] `flutter analyze` clean (zero issues).
  - [ ] `flutter test` green; existing tests still pass without changes.
  - [ ] Tapping Extras → "Shop besuchen" routes to the per-Krimi product URL (verify in Chrome by inspecting the launched URL or by temporarily logging it).
  - [ ] If WebFetch was used, the chosen URLs are documented in the commit body; otherwise the WooCommerce-pattern assumption is documented.
- **Commit message**: `feat: per-Krimi shop deep-link (shopUrl on Krimi)`

### Step 2: Scrollable detail header via `NestedScrollView` + `SliverAppBar`
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib/screens`
- **Branch**: `feat/samhain-detail-fixes-step-2`
- **Parallel with**: Step 1 (different files). Sequential with Step 3 only because Step 3 modifies the same `KrimiDetailScreen` and `VorbereitungSection` files; do Step 3 after this lands to avoid merge conflicts.
- **Description**:
  - Rewrite `KrimiDetailScreen.build`:
    - `Scaffold(body: NestedScrollView(headerSliverBuilder: ..., body: IndexedStack(...)), bottomNavigationBar: NavigationBar(...))`.
    - `headerSliverBuilder` returns one `SliverOverlapAbsorber` wrapping a `SliverAppBar` (pinned=false, floating=false, expandedHeight ~280).
    - `flexibleSpace: FlexibleSpaceBar(background: cover image + gradient)`.
    - Title + `SpecIndicatorStrip(size: SpecStripSize.full)` live in `bottom: PreferredSize(child: ...)` of `SliverAppBar` so they are part of the collapsing region. Author "von …" line stays here.
    - `leading: IconButton(Icons.arrow_back, ...)` with German tooltip.
    - Remove the current `_Header` widget (or keep it as a private helper that builds just the flex-space content).
  - Convert each section to be `NestedScrollView`-compatible:
    - `EinfuehrungSection`, `VorbereitungSection`, `SpielSection`, `ExtrasSection`: switch the top-level `ListView` to `CustomScrollView` whose first sliver is `SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context))`, followed by `SliverPadding(sliver: SliverList(delegate: SliverChildListDelegate([...])))` containing the same children as before.
    - This is mechanical: existing children stay the same widgets.
  - Verify: scrolling any section makes the header slide up; the bottom nav stays pinned; switching tabs preserves the header position OR resets to expanded (pick the behavior that feels least surprising — default Flutter behavior with one shared scroll controller is "resets per body" because each section has its own `PrimaryScrollController` inside `NestedScrollView.body`; that's fine).
- **Context files to read**:
  - All 4 `lib/screens/sections/*_section.dart`, `lib/screens/krimi_detail_screen.dart`, `lib/widgets/spec_indicator_strip.dart` (for the full-size variant)
- **Acceptance criteria**:
  - [ ] Header collapses away while scrolling in any tab.
  - [ ] Bottom `NavigationBar` remains pinned and tappable while header is collapsed.
  - [ ] Back button still works from any scroll position.
  - [ ] Existing widget tests still pass (`Krimi detail renders title + all 4 nav destinations`, `Switching to Extras tab shows shop tile`, `Ruf der Tiefen detail handles empty characters list`).
  - [ ] Add one new widget test: pump the detail screen at small viewport, drag-fling, assert the title rendered in the AppBar position scrolls out of the visible region (or — simpler — assert that the SliverAppBar widget exists in the tree).
  - [ ] `flutter analyze` clean.
- **Commit message**: `refactor: scrollable detail header via NestedScrollView + SliverAppBar`

### Step 3: Pre-warm menu PDF on detail-screen entry
- **Project**: samhain-mobile-app
- **Directory**: `/Users/gregor/dev/samhain/mobile_app/lib/screens`
- **Branch**: `feat/samhain-detail-fixes-step-3`
- **Parallel with**: — (depends on Step 2 because both modify `krimi_detail_screen.dart` and `vorbereitung_section.dart`)
- **Description**:
  - In `lib/screens/krimi_detail_screen.dart` `_KrimiDetailScreenState`:
    - Add `PdfDocumentRef? _menuDocRef;`.
    - In `initState`, if `widget.krimi.menuPdfPath != null`, set `_menuDocRef = PdfDocumentRefAsset(widget.krimi.menuPdfPath!)`. This kicks off the asset load via `pdfrx`'s ref machinery without blocking the build.
    - In `dispose`, dispose the ref if `pdfrx` exposes a disposer for it (verify against current `pdfrx` API — if not, drop the reference; the docs auto-close when there are no listeners).
    - Pass `_menuDocRef` down to `VorbereitungSection` as a new constructor param (nullable).
  - In `lib/screens/sections/vorbereitung_section.dart`:
    - Add `final PdfDocumentRef? menuDocRef;` to `VorbereitungSection`.
    - The Menükarte tile, when tapped, opens `PdfViewerScreen` with the ref instead of the asset path.
  - In `lib/screens/pdf_viewer_screen.dart`:
    - Make it accept **either** a `PdfDocumentRef` (preferred) **or** an `assetPath` (fallback for invitations).
    - Use `PdfViewer.documentRef(ref)` when ref is provided; fall back to `PdfViewer.asset(assetPath)` otherwise.
    - Constructor: `PdfViewerScreen.fromRef(...)` and keep existing `PdfViewerScreen(assetPath: ...)` for invitations. Don't break callers.
  - Validate against the current `pdfrx ^2.2.24` API: confirm the exact class names (`PdfDocumentRefAsset`, `PdfViewer.documentRef`) before editing — if names differ, adapt.
  - **Do not** add explicit prefetching of page-1 image; out of scope.
- **Context files to read**:
  - `lib/screens/krimi_detail_screen.dart` (post-Step-2 shape), `lib/screens/sections/vorbereitung_section.dart`, `lib/screens/pdf_viewer_screen.dart`, `pubspec.yaml` (confirm `pdfrx ^2.2.24`)
  - `pdfrx` package: check API by inspecting `~/.pub-cache/hosted/pub.dev/pdfrx-2.2.24/lib/` for the exposed types if needed.
- **Acceptance criteria**:
  - [ ] Opening a Krimi detail kicks off menu-PDF load in the background (no UI block).
  - [ ] Tapping Menükarte after waiting ~1 s opens the viewer instantly (subjectively faster than baseline; ideal: no spinner at all on re-entry).
  - [ ] Scrolling the PDF is smoother — first-page paint happens before user-visible spinner replacement (measure subjectively).
  - [ ] Invitations still open via the old asset-path code path; no regression.
  - [ ] `flutter analyze` clean; `flutter test` green.
- **Commit message**: `perf: pre-warm menu PDF document ref on detail-screen entry`

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1 (parallel — independent files):
  Step 1: shopUrl + per-Krimi product link              → lib/models, lib/data, sections/extras
  Step 2: NestedScrollView + SliverAppBar refactor      → lib/screens/krimi_detail + all 4 sections

Wave 2 (sequential — touches files Step 2 just changed):
  Step 3: Pre-warm menu PDF                             → lib/screens/krimi_detail, sections/vorbereitung, pdf_viewer
```

## Sub-Agent Execution Prompts

### Prompt — Step 1
```
You are executing Step 1 of /Users/gregor/dev/922/orchestrator/plans/2026-05-19-samhain-detail-polish-fixes.md.

HARD RULES: 100% German UI strings; no remote, commits stay local; `flutter analyze` must be clean.

Read first:
- The plan file (Step 1 section + Design Decisions / Fix C)
- /Users/gregor/dev/922/orchestrator/projects/samhain-mobile-app.md
- /Users/gregor/dev/samhain/mobile_app/lib/models/krimi.dart
- /Users/gregor/dev/samhain/mobile_app/lib/data/krimis.dart
- /Users/gregor/dev/samhain/mobile_app/lib/data/krimi_validator.dart
- /Users/gregor/dev/samhain/mobile_app/lib/screens/sections/extras_section.dart

Work dir: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-detail-fixes-step-1` off `main`.

Do:
1. Try `WebFetch https://krimispiele.com` (and a search-style follow-up if needed) to find the product URLs for "Haunted Hotel" and "Ruf der Tiefen". If unreachable, fall back to https://krimispiele.com/produkt/haunted-hotel/ and https://krimispiele.com/produkt/ruf-der-tiefen/, and note the assumption.
2. Add `final String? shopUrl;` to Krimi (nullable, default null).
3. Populate `shopUrl` on both Krimi entries.
4. Update validator to debugPrint a German warning when shopUrl is null (do not throw).
5. Update ExtrasSection: use krimi.shopUrl ?? 'https://krimispiele.com'; subtitle shows host+path of the chosen URL (German label stays 'Shop besuchen').
6. `flutter analyze` and `flutter test` must be green.
7. Commit with message: feat: per-Krimi shop deep-link (shopUrl on Krimi)

Report: branch + commit SHA + analyzer/test output + which URLs you used and how you sourced them.
```

### Prompt — Step 2
```
You are executing Step 2 of /Users/gregor/dev/922/orchestrator/plans/2026-05-19-samhain-detail-polish-fixes.md.

HARD RULES: 100% German UI; no remote; analyzer + tests clean.

Read first:
- The plan file (Step 2 section + Design Decisions / Fix B)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/krimi_detail_screen.dart
- All four lib/screens/sections/*_section.dart files
- /Users/gregor/dev/samhain/mobile_app/lib/widgets/spec_indicator_strip.dart

Work dir: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-detail-fixes-step-2` off `main` (or off Step 1's branch tip if Step 1 has already merged).

Do:
1. Convert KrimiDetailScreen body to NestedScrollView with a SliverAppBar that contains the cover (background), title + author + SpecIndicatorStrip(full) in `bottom:`, and a back IconButton in `leading:`. pinned=false, floating=false.
2. Convert each of the 4 section widgets from top-level ListView to CustomScrollView + SliverOverlapInjector + SliverPadding(SliverList(...)). Keep the actual content widgets unchanged — only the outer wrapping changes.
3. Add one widget test in test/screens/krimi_detail_screen_test.dart: assert that a SliverAppBar exists in the rendered tree (one-line `expect(find.byType(SliverAppBar), findsOneWidget);`).
4. Keep existing detail-screen tests green.
5. `flutter analyze` clean; `flutter test` green.
6. Commit message: refactor: scrollable detail header via NestedScrollView + SliverAppBar

Report: branch + commit SHA + analyzer/test output + whether tabs share scroll position or reset (state your observation, don't tune unless Gregor asks).
```

### Prompt — Step 3
```
You are executing Step 3 of /Users/gregor/dev/922/orchestrator/plans/2026-05-19-samhain-detail-polish-fixes.md.

HARD RULES: 100% German UI; no remote; analyzer + tests clean.

Read first:
- The plan file (Step 3 section + Design Decisions / Fix A)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/krimi_detail_screen.dart (post-Step-2)
- /Users/gregor/dev/samhain/mobile_app/lib/screens/sections/vorbereitung_section.dart
- /Users/gregor/dev/samhain/mobile_app/lib/screens/pdf_viewer_screen.dart
- /Users/gregor/dev/samhain/mobile_app/pubspec.yaml (confirm pdfrx ^2.2.24)
- pdfrx API surface: list ~/.pub-cache/hosted/pub.dev/pdfrx-2.2.24/lib/src/ (or equivalent) to confirm `PdfDocumentRefAsset` exists; if the class name differs in this version, adapt.

Work dir: /Users/gregor/dev/samhain/mobile_app
Branch: `feat/samhain-detail-fixes-step-3` off Step 2's branch tip (after Step 2 merged to main).

Do:
1. In KrimiDetailScreen state: create the menu PdfDocumentRef once in initState (only when menuPdfPath != null). Hold it in a nullable field.
2. Pass the ref down to VorbereitungSection as a new optional constructor param.
3. Refactor PdfViewerScreen to support both `(ref: PdfDocumentRef)` and `(assetPath: String)` construction without breaking existing call sites (invitations).
4. The Menükarte tile uses the ref when available, falls back to asset path when ref is null.
5. Verify by running the app in Chrome and tapping Menükarte after a ~1s wait — should be subjectively faster than baseline.
6. `flutter analyze` clean; `flutter test` green.
7. Commit message: perf: pre-warm menu PDF document ref on detail-screen entry

Report: branch + commit SHA + analyzer/test output + a one-line subjective note on perceived load improvement.
```

## Open Questions / Risks

1. **Real product URLs** — best effort via WebFetch; if blocked, the WooCommerce-pattern fallback is plausible but not guaranteed correct. Surface the assumption in Step 1's commit body so Gregor can override.
2. **NestedScrollView + IndexedStack interaction** — Flutter's `NestedScrollView` is designed for `TabBarView` bodies, not `IndexedStack`. Each tab needs its own `Scrollable` so the overlap-injector pattern works. If `IndexedStack` causes the inner scroll handles to conflict (only one tab is "active" at a time and the others are off-stage), we may need to switch the body to `PageView` with `physics: NeverScrollableScrollPhysics()` or to per-tab `Builder` returning a fresh `CustomScrollView`. Step 2 sub-agent should report observed behavior.
3. **pdfrx API drift** — `pdfrx 2.2.24` is the pinned version; confirm class names before editing in Step 3. If the API surface differs (e.g. ref class renamed), adapt the prompt's expectations.

## Post-Execution Checklist
- [ ] All three step branches merged into `main`.
- [ ] `flutter analyze` clean on `main`.
- [ ] `flutter test` green on `main`.
- [ ] Chrome dev instance reloaded; menu opens noticeably faster, header scrolls away, shop link routes to product page.
- [ ] If Step 1's WebFetch fallback was used, Gregor confirms the product URLs (or supplies the right ones) before this plan is closed.
