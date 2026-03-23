# Pluralis

**E-ink friendly RSS/Atom reader for Android** — a lightweight, local-first feed reader with a paginated reading mode designed for e-ink displays.

## Features

- **E-ink reading mode** — paginated article reader with adaptive font sizing, serif typography, tap zones for page turns, and high-contrast layout optimized for e-paper displays
- **RSS/Atom aggregator** — subscribe to any RSS or Atom feed, sorted chronologically with source spreading
- **Bookmarks** — save articles for later, auto-cleaned after 90 days
- **OPML import/export** — import your existing feed subscriptions, export to share
- **Substack support** — paid Substack content via cookie authentication, CSV import/export
- **Fully local** — no accounts, no tracking, no server; all data stays on your device

## Getting started

The app ships with a single demo feed (Wikipedia Featured Articles). Add your own sources:

- **Add RSS** — tap "Add source" and enter any RSS/Atom URL
- **Import OPML** — tap the import/export icon in the Sources tab to import an OPML file from another reader
- **Import Substacks** — import paid Substack subscriptions with cookies via CSV

## Tech stack

- Flutter (Android, min SDK 21)
- Provider — state management
- sqflite — local bookmarks database
- xml — RSS/Atom parsing
- shared_preferences — source state persistence
- google_fonts — Merriweather for the e-ink reader

## Build

```bash
git clone https://github.com/funkypitt/pluralis.git
cd pluralis
flutter pub get
flutter build apk --release
```

## License

[GPL-3.0](LICENSE)
