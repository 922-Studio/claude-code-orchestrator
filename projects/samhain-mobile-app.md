# Project: Samhain Mobile App

## Overview
- **Type**: app (mobile, Android primary)
- **Path**: /Users/gregor/dev/samhain/mobile_app
- **Status**: active (pilot phase — Haunted Hotel)
- **Description**: Flutter app that acts as the digital host guide for Samhain Krimidinner customers. All content is free, no login. Primary user is the host running the dinner. v1.0 pilots **Haunted Hotel**; other 9 Krimis appear as placeholders. Reference: Lastenheft v0.6 (provided 2026-05-14 by Gregor).

## Tech Stack
- **Language(s)**: Dart (SDK ^3.11.0)
- **Framework(s)**: Flutter (Material 3, dark theme)
- **Audio**: `just_audio ^0.9.42` (bundled mp3 assets)
- **PDF**: `pdfrx ^2.2.24`
- **URL launching**: `url_launcher ^6.3.1`
- **Testing**: `flutter_test` (unit + widget + integration), `integration_test`
- **Lints**: `flutter_lints ^6.0.0`
- **CI/CD**: none yet (local git only — no remote per Gregor 2026-05-14)

## Key Files to Read

| File | Purpose | When to read |
|------|---------|--------------|
| `pubspec.yaml` | Deps + asset declarations | Always |
| `lib/main.dart` | App entry + theme | Always |
| `lib/models/krimi.dart` | `Krimi` + `Character` models | When touching data |
| `lib/data/krimis.dart` | Hardcoded Krimi list (currently Haunted Hotel only) | When adding/changing content |
| `lib/screens/home_screen.dart` | Overview list of Krimis | When changing list/banner UI |
| `lib/screens/krimi_detail_screen.dart` | Detail view + actions + character grid | When changing detail layout |
| `lib/screens/character_screen.dart` | Single character + audio player | When touching audio UX |
| `lib/screens/pdf_viewer_screen.dart` | PDF viewer (menu + invitations) | When touching PDF flow |
| `assets/krimis/haunted_hotel/` | All Haunted Hotel media | When adding new content |
| `docs/FLUTTER_INTRO.md` (TBD) | Onboarding doc for Gregor | First-time Flutter contributors |

## Best Practices
- Material 3 dark theme; primary palette black/red — keep visual identity consistent across screens.
- No state-management framework yet (only `StatefulWidget` + setState). Keep it that way until complexity demands otherwise. Do **not** introduce Provider/Riverpod/Bloc without a dedicated plan.
- All Krimi content is declarative `const` data in `lib/data/`. Adding a Krimi = add an entry + assets + declare assets in `pubspec.yaml`. No code paths should special-case a Krimi by id.
- Asset paths must be declared in `pubspec.yaml` (either as a folder ending with `/` or as a file). Missing declarations fail silently at runtime — always check.
- All user-facing copy is **German** (Lastenheft is German, host audience is German). Code identifiers stay English.
- Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`). No Co-Authored-By trailers.
- Before reporting a UI step done: run the app in Chrome (`flutter run -d chrome`) and verify visually — type-check alone is not enough.

## Testing Strategy
- **Unit tests**: `test/**/*_test.dart` — pure-Dart model + data tests. Run: `flutter test`.
- **Widget tests**: `test/widgets/` — render screens with mock data, verify key UI elements + interactions. Run: `flutter test`.
- **Integration tests**: `integration_test/` — full app flow on a real device/emulator. Run: `flutter test integration_test/` or `flutter drive`.
- **Manual E2E**: Gregor + Claude walk through user journeys in Chrome (or Android device once available). Checklist lives in plan documents.

## Documentation
- **Where**: `docs/` inside the repo (Flutter intro, content authoring guide).
- **Update rule**: Update when a new Krimi is added, when a new feature is exposed in UI, or when audio/PDF/asset conventions change.

## Pipeline & Deployment
- **CI trigger**: none currently.
- **Deploy**: manual `flutter build apk --release` for Android; APK distributed via krimispiele.com later. (Out of scope for pilot.)
- **Monitor after push**: n/a (no remote).

## Dependencies on Other Projects
- **krimispiele.com** (Samhain Verlag homepage) — content source (PDFs, audio, character art).

## Notes
- iOS deliberately out of scope (Apple Dev Account too expensive per Lastenheft).
- Audio strategy: bundled mp3 assets (decision 2026-05-14). Can migrate to streaming in v1.1 if APK size becomes a problem.
- Content delivery for the other 9 Krimis depends on Roger / Samhain Verlag — track in plan as a blocker, not a coding task.
- "Lastenheft v0.6" lives in chat / Gregor's notes; not yet in repo. Consider committing it as `docs/lastenheft.md` for traceability.
