# Instructions for Claude Code

## Project: Pluralis — Flutter RSS News Reader

Follow **PLAN.md** step by step. This file has additional context.

## Working style

- Build the complete app in one session following PLAN.md sections 0→8
- Run `flutter pub get` after any pubspec.yaml change
- Run `flutter analyze` after each step and fix all warnings before continuing
- Test with `flutter run` on Android emulator after Step 4

## Key decisions already made

- **State management:** Provider (not Riverpod, not Bloc — keep it simple)
- **Database:** sqflite (not Hive, not Drift)
- **No authentication, no backend** — fully local + RSS fetching only
- **Android only** — do not add iOS/web configurations
- **Target API:** 34, min API: 21

## Sources JSON

`assets/sources.json` contains 33 sources (26 EN + 7 FR) with verified RSS URLs.
Load this file as the default sources on first launch via `rootBundle.loadString`.

## Naming conventions

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/methods: `camelCase`
- Constants: `kCamelCase`

## Color scheme

Primary: `Color(0xFF1A3A5C)` (dark blue)  
Accent: `Color(0xFFE8A020)` (amber)  
Background: `Colors.grey[50]`

Category badge colors (use `.withOpacity(0.15)` for background, full color for text):
```dart
const Map<String, Color> kCategoryColors = {
  'investigatif': Color(0xFF185FA5),
  'geopolitique': Color(0xFF534AB7),
  'sante': Color(0xFF0F6E56),
  'post-liberal': Color(0xFFBA7517),
  'anti-imperialiste': Color(0xFF993556),
  'chinois': Color(0xFFA32D2D),
  'conservateur': Color(0xFF885A30),
  'gauche-socialiste': Color(0xFF185FA5),
  'francophone': Color(0xFF993C1D),
};
```

## RSS edge cases

If a feed returns HTTP 403, add this header to the request:
```dart
'User-Agent': 'Mozilla/5.0 (compatible; Pluralis/1.0; RSS Reader)'
```

Some feeds are Atom not RSS — `webfeed` handles both, but wrap parse attempts in try/catch and try both `RssFeed.parse` then `AtomFeed.parse`.

## Do NOT

- Do not add Substack sources (already filtered out)
- Do not add a dark mode toggle (system theme is fine)
- Do not add pagination — just take the latest 20 items per source
- Do not add notifications
- Do not add user accounts or sync
