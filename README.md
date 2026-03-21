# Pluralis

**Alternative news aggregator for Android** — aggregates RSS feeds from 33 independent and alternative media sources in English and French.

## Features

- 📰 **Home feed** — latest headlines with lead image and excerpt, sorted by date, auto-refreshed on open
- ⭐ **Bookmarks** — save articles, open in browser, auto-deleted after 90 days
- ⚙️ **Sources** — toggle sources on/off, add custom RSS feeds

## Default sources (33)

26 English + 7 French sources across categories: investigative, geopolitical, post-liberal, health, anti-imperialist, Chinese perspective, French-language.

## Tech stack

- Flutter (Android target, min SDK 21)
- `webfeed` — RSS/Atom parsing
- `http` — network requests
- `sqflite` — local bookmarks database
- `cached_network_image` — image caching
- `url_launcher` — open articles in browser
- `shared_preferences` — active sources persistence
- `provider` — state management

## GitHub

https://github.com/YOUR_USERNAME/pluralis

## Getting started

```bash
git clone https://github.com/YOUR_USERNAME/pluralis.git
cd pluralis
flutter pub get
flutter run
```

## Project structure

```
lib/
  main.dart               # App entry point, MaterialApp, BottomNavigationBar
  models/
    article.dart          # Article data model
    source.dart           # Source data model
    bookmark.dart         # Bookmark data model
  services/
    rss_service.dart      # Fetch + parse RSS feeds
    bookmark_service.dart # sqflite CRUD
    source_service.dart   # Load/save sources state
  providers/
    feed_provider.dart    # Feed state (articles, loading, error)
    bookmark_provider.dart
    source_provider.dart
  screens/
    home_screen.dart      # BottomNavigationBar container
    feed_tab.dart         # Article list
    bookmarks_tab.dart    # Saved articles
    sources_tab.dart      # Manage sources
  widgets/
    article_card.dart     # Headline + image + excerpt + star button
    source_tile.dart      # Source row with toggle
assets/
  sources.json            # Default sources with RSS URLs
```
