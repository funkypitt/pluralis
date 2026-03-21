# PLAN — Build Pluralis (Flutter Android RSS Reader)

## Context

Build a Flutter Android app called **Pluralis** that aggregates RSS feeds from 33 alternative/independent news sources in English and French.

**GitHub repo:** `https://github.com/YOUR_USERNAME/pluralis`  
**Flutter min SDK:** Android 21 (Lollipop)  
**State management:** Provider  
**Local DB:** sqflite  

---

## Step 0 — Project bootstrap

```bash
flutter create pluralis --org com.yourname --platforms android
cd pluralis
```

Then replace `pubspec.yaml` with the provided one and run:

```bash
flutter pub get
```

Create the directory structure:
```
lib/models/
lib/services/
lib/providers/
lib/screens/
lib/widgets/
assets/
```

Copy `assets/sources.json` into the project root `assets/` folder.

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## Step 1 — Data models (`lib/models/`)

### `source.dart`

```dart
class Source {
  final String id;
  final String name;
  final String url;       // website homepage
  final String rss;       // RSS feed URL
  final String category;
  final String lang;      // "EN" | "FR"
  final String tag;       // "" | "media-etat" | "independant"
  bool active;

  Source({...});

  factory Source.fromJson(Map<String, dynamic> json) => Source(
    id: json['id'],
    name: json['name'],
    url: json['url'],
    rss: json['rss'],
    category: json['category'],
    lang: json['lang'],
    tag: json['tag'] ?? '',
    active: json['active'] ?? true,
  );

  Map<String, dynamic> toJson() => {...};
}
```

### `article.dart`

```dart
class Article {
  final String id;          // sha256 of link URL — unique identifier
  final String title;
  final String? description; // plain text, HTML stripped, max 300 chars
  final String? imageUrl;
  final String link;
  final DateTime? publishedAt;
  final String sourceName;
  final String sourceId;
  final String lang;

  Article({...});
}
```

### `bookmark.dart`

```dart
class Bookmark {
  final String articleId;
  final String title;
  final String link;
  final String? imageUrl;
  final String sourceName;
  final DateTime bookmarkedAt;
  final DateTime autoDeleteAt;  // bookmarkedAt + 90 days

  Bookmark({...});

  // sqflite serialization
  Map<String, dynamic> toMap();
  factory Bookmark.fromMap(Map<String, dynamic> map);
}
```

---

## Step 2 — Services (`lib/services/`)

### `source_service.dart`

Responsibilities:
- Load default sources from `assets/sources.json` on first launch
- Persist active/inactive state in `shared_preferences` as JSON string
- Allow adding custom sources (id = slugified name, active = true)
- Allow deleting custom sources (default sources can only be toggled)

Key methods:
```dart
Future<List<Source>> loadSources()          // merge defaults + custom + prefs
Future<void> saveSources(List<Source> s)    // persist to shared_preferences
Future<void> addCustomSource(Source s)
Future<void> removeSource(String id)        // only custom sources
```

Implementation notes:
- SharedPreferences key: `'sources_state'` → JSON string of List<Source>
- On first launch (key absent): load from assets/sources.json, save to prefs
- Use `rootBundle.loadString('assets/sources.json')` for asset loading

### `rss_service.dart`

Responsibilities:
- Fetch RSS/Atom feed for a given Source
- Parse using `webfeed` package
- Return List<Article>
- Handle errors gracefully (timeout, malformed XML, network error) — return empty list, do not throw

Key methods:
```dart
Future<List<Article>> fetchFeed(Source source)
Future<List<Article>> fetchAllFeeds(List<Source> sources)  // parallel with Future.wait
```

Implementation notes:

```dart
import 'package:webfeed/webfeed.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlparser;
import 'dart:convert';
import 'dart:crypto';  // for sha256 — use crypto package or implement simple hash

// Add 'crypto: ^3.0.3' to pubspec.yaml

Future<List<Article>> fetchFeed(Source source) async {
  try {
    final response = await http.get(
      Uri.parse(source.rss),
      headers: {'User-Agent': 'Pluralis/1.0 RSS Reader'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);

    List<dynamic> items = [];
    String? feedTitle;

    try {
      final rssFeed = RssFeed.parse(body);
      items = rssFeed.items ?? [];
    } catch (_) {
      try {
        final atomFeed = AtomFeed.parse(body);
        items = atomFeed.items ?? [];
      } catch (_) {
        return [];
      }
    }

    return items.map((item) => _parseItem(item, source)).whereType<Article>().take(20).toList();
  } catch (_) {
    return [];
  }
}

Article? _parseItem(dynamic item, Source source) {
  // Extract fields whether RSS or Atom
  final String? link = item is RssItem ? item.link : (item as AtomItem).links?.firstOrNull?.href;
  if (link == null || link.isEmpty) return null;

  final String title = _cleanText(item is RssItem ? (item.title ?? '') : (item as AtomItem).title ?? '');
  if (title.isEmpty) return null;

  final String? rawDesc = item is RssItem ? item.description : (item as AtomItem).content?.value ?? (item as AtomItem).summary?.value;
  final String? description = rawDesc != null ? _stripHtml(rawDesc, maxChars: 280) : null;

  final String? imageUrl = _extractImage(item);
  final DateTime? published = item is RssItem ? item.pubDate : (item as AtomItem).updated;

  return Article(
    id: _hashUrl(link),
    title: title,
    description: description,
    imageUrl: imageUrl,
    link: link,
    publishedAt: published,
    sourceName: source.name,
    sourceId: source.id,
    lang: source.lang,
  );
}

String _stripHtml(String html, {int maxChars = 280}) {
  final doc = htmlparser.parse(html);
  final text = doc.body?.text ?? '';
  final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return trimmed.length > maxChars ? '${trimmed.substring(0, maxChars)}…' : trimmed;
}

String _cleanText(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _hashUrl(String url) {
  // simple: use url itself as id (truncated) or use crypto sha256
  final bytes = utf8.encode(url);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}

String? _extractImage(dynamic item) {
  // Try media:content, enclosure, og:image patterns
  if (item is RssItem) {
    if (item.media?.contents?.isNotEmpty == true) {
      return item.media!.contents!.first.url;
    }
    if (item.enclosure?.url != null) {
      final url = item.enclosure!.url!;
      if (url.contains('.jpg') || url.contains('.png') || url.contains('.webp')) {
        return url;
      }
    }
  }
  // Fallback: parse img src from description HTML
  if (item is RssItem && item.description != null) {
    final match = RegExp(r'<img[^>]+src=["\']([^"\']+)["\']').firstMatch(item.description!);
    if (match != null) return match.group(1);
  }
  return null;
}
```

Add `crypto: ^3.0.3` to pubspec.yaml.

### `bookmark_service.dart`

Responsibilities:
- Initialize sqflite database (`pluralis.db`)
- CRUD operations on `bookmarks` table
- Auto-delete articles older than 90 days on init

Database schema:
```sql
CREATE TABLE bookmarks (
  article_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  link TEXT NOT NULL,
  image_url TEXT,
  source_name TEXT NOT NULL,
  bookmarked_at INTEGER NOT NULL,  -- Unix timestamp ms
  auto_delete_at INTEGER NOT NULL  -- bookmarked_at + 90 days in ms
)
```

Key methods:
```dart
Future<void> init()
Future<void> addBookmark(Article article)
Future<void> removeBookmark(String articleId)
Future<List<Bookmark>> getBookmarks()           // sorted by bookmarked_at DESC
Future<bool> isBookmarked(String articleId)
Future<void> purgeExpired()                     // delete where auto_delete_at < now
```

Call `purgeExpired()` inside `init()`.

---

## Step 3 — Providers (`lib/providers/`)

### `source_provider.dart`

```dart
class SourceProvider extends ChangeNotifier {
  List<Source> _sources = [];
  List<Source> get sources => _sources;
  List<Source> get activeSources => _sources.where((s) => s.active).toList();

  final SourceService _service = SourceService();

  Future<void> load() async {
    _sources = await _service.loadSources();
    notifyListeners();
  }

  Future<void> toggleSource(String id) async {
    final i = _sources.indexWhere((s) => s.id == id);
    if (i >= 0) {
      _sources[i].active = !_sources[i].active;
      await _service.saveSources(_sources);
      notifyListeners();
    }
  }

  Future<void> addSource(Source source) async {
    await _service.addCustomSource(source);
    await load();
  }

  Future<void> removeSource(String id) async {
    await _service.removeSource(id);
    await load();
  }
}
```

### `feed_provider.dart`

```dart
class FeedProvider extends ChangeNotifier {
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefresh;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final RssService _rssService = RssService();

  Future<void> refresh(List<Source> activeSources) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _rssService.fetchAllFeeds(activeSources);
      // Sort by publishedAt DESC, nulls last
      results.sort((a, b) {
        if (a.publishedAt == null) return 1;
        if (b.publishedAt == null) return -1;
        return b.publishedAt!.compareTo(a.publishedAt!);
      });
      _articles = results;
      _lastRefresh = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### `bookmark_provider.dart`

```dart
class BookmarkProvider extends ChangeNotifier {
  List<Bookmark> _bookmarks = [];
  Set<String> _bookmarkedIds = {};

  List<Bookmark> get bookmarks => _bookmarks;

  final BookmarkService _service = BookmarkService();

  Future<void> init() async {
    await _service.init();
    await _load();
  }

  Future<void> _load() async {
    _bookmarks = await _service.getBookmarks();
    _bookmarkedIds = _bookmarks.map((b) => b.articleId).toSet();
    notifyListeners();
  }

  bool isBookmarked(String articleId) => _bookmarkedIds.contains(articleId);

  Future<void> toggle(Article article) async {
    if (isBookmarked(article.id)) {
      await _service.removeBookmark(article.id);
    } else {
      await _service.addBookmark(article);
    }
    await _load();
  }
}
```

---

## Step 4 — Screens and widgets

### `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SourceProvider()..load()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()..init()),
      ],
      child: const PluralisApp(),
    ),
  );
}

class PluralisApp extends StatelessWidget {
  const PluralisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pluralis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A5C)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

### `lib/screens/home_screen.dart`

BottomNavigationBar with 3 tabs:
- Tab 0: FeedTab (icon: `newspaper_outlined`, label: 'Feed')
- Tab 1: BookmarksTab (icon: `bookmark_border`, label: 'Bookmarks')
- Tab 2: SourcesTab (icon: `tune`, label: 'Sources')

On app start (initState), trigger `FeedProvider.refresh()` using active sources from `SourceProvider`.

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final sources = context.read<SourceProvider>().activeSources;
    context.read<FeedProvider>().refresh(sources);
  });
}
```

### `lib/screens/feed_tab.dart`

- `RefreshIndicator` wrapping a `ListView.builder` of `ArticleCard` widgets
- AppBar with title "Pluralis" and a refresh `IconButton`
- Show `CircularProgressIndicator` centered when `isLoading == true` and articles empty
- Show error message if `error != null` and articles empty
- On pull-to-refresh or button: call `feedProvider.refresh(activeSources)`
- On article tap: `launchUrl(Uri.parse(article.link), mode: LaunchMode.externalApplication)`

### `lib/screens/bookmarks_tab.dart`

- `ListView.builder` of bookmark cards
- Each card: image (if any) + title + source name + bookmarked date + "open" icon + delete icon
- Empty state: centered text "No bookmarks yet"
- Swipe to delete: `Dismissible` widget wrapping each card
- Tap: open in browser

### `lib/screens/sources_tab.dart`

Two sections:
1. **Active sources** — list of all sources with `SwitchListTile` (toggle active/inactive)
2. **Add source** button at bottom → opens `AlertDialog` with two text fields: Name + RSS URL

Each source tile shows: name + category badge + lang chip + tag chip if applicable.

Custom sources show a delete icon (trailing). Default sources show only the toggle.

### `lib/widgets/article_card.dart`

Layout:
```
┌─────────────────────────────────┐
│ [Image 120×80 left]  Title      │
│                      Source · date│
│                      Description  │
│                      [★ bookmark]│
└─────────────────────────────────┘
```

- Use `CachedNetworkImage` for the image with a grey placeholder
- If no image: show source initial letter in a colored box
- Star icon: filled yellow if bookmarked, outlined if not
- Entire card tappable → open URL in browser
- Star button tappable independently → toggle bookmark

```dart
class ArticleCard extends StatelessWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onTap;
  ...
}
```

Color the source name by category:
- investigatif → blue
- geopolitique → purple  
- sante → green
- post-liberal → orange
- anti-imperialiste → pink
- chinois → red
- conservateur → amber
- gauche-socialiste → teal
- francophone → deepOrange

---

## Step 5 — Error handling and edge cases

1. **RSS fetch errors** — silently skip failed sources, show partial results
2. **No active sources** — show empty state with message "Enable sources in the Sources tab"
3. **No internet** — show snackbar "No connection — showing cached feed" (keep last articles in memory)
4. **Malformed RSS** — catch all parse exceptions, return empty list
5. **Image load failure** — `CachedNetworkImage` errorWidget: grey container with source initial
6. **Duplicate articles** — deduplicate by `article.id` (hash of URL) after merging all feeds
7. **Auto-delete bookmarks** — run `purgeExpired()` on `BookmarkService.init()` only

---

## Step 6 — Polish

1. Show article count in Feed tab AppBar subtitle: "42 articles from 26 sources"
2. Show last refresh time below AppBar: "Updated 3 minutes ago" using `timeago` package (add `timeago: ^3.6.1`)
3. In Bookmarks tab, show "Auto-deleted in N days" subtitle under each bookmark
4. In Sources tab, show article count per source (stored in FeedProvider)
5. Add `about` action in AppBar overflow menu: app version + GitHub link

---

## Step 7 — Android configuration

### `android/app/src/main/AndroidManifest.xml`

Add inside `<application>`:
```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    ...>
    ...
</activity>
```

Add for url_launcher (Android 11+ package visibility):
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

### `android/app/build.gradle`

Set:
```gradle
defaultConfig {
    minSdkVersion 21
    targetSdkVersion 34
}
```

---

## Step 8 — Git setup

```bash
git init
git remote add origin https://github.com/YOUR_USERNAME/pluralis.git
echo "# Pluralis" > .gitignore  # Flutter default .gitignore already handles build/
git add .
git commit -m "feat: initial Pluralis app — 33 RSS sources, 3-tab reader"
git push -u origin main
```

---

## Packages summary (add all to pubspec.yaml)

```yaml
dependencies:
  webfeed: ^0.7.0
  http: ^1.2.0
  sqflite: ^2.3.0
  path: ^1.9.0
  cached_network_image: ^3.3.1
  url_launcher: ^6.2.5
  shared_preferences: ^2.2.2
  provider: ^6.1.2
  html: ^0.15.4
  intl: ^0.19.0
  crypto: ^3.0.3
  timeago: ^3.6.1
```

---

## RSS notes (⚠️ to verify on first run)

Sources marked medium confidence — may need URL adjustment:
- **Antithèse** (bonpourlatete.com) — try `/rss.xml` if `/feed` fails
- **Epoch Times** — try `/rss` if `/feed` fails; may have anti-bot headers
- **Tablet Magazine** — try `/rss` if `/feed` fails
- **The Lamp** — try `/rss` if `/feed` fails  
- **France-Soir** — try `/feed` if `/rss.xml` fails
- **Élucid** — confirm `/feed` works
- **Racket News** — Ghost CMS, try `/rss` if `/feed` fails
- **The Lever** — try `/rss` if `/feed` fails

For sources behind Cloudflare (403 errors), add custom User-Agent header in RssService:
```dart
headers: {
  'User-Agent': 'Mozilla/5.0 (compatible; Pluralis/1.0; RSS Reader)',
  'Accept': 'application/rss+xml, application/xml, text/xml',
}
```

---

## Acceptance criteria

- [ ] App launches and shows feed within 10 seconds on first open
- [ ] Articles sorted newest-first across all active sources
- [ ] Tap article → opens in external browser
- [ ] Star article → appears in Bookmarks tab
- [ ] Unstar / swipe-delete → removed from bookmarks
- [ ] Bookmarks older than 90 days auto-purged on launch
- [ ] Toggle source off → articles from that source disappear after next refresh
- [ ] Add custom source → appears in sources list, included in next fetch
- [ ] Pull-to-refresh works
- [ ] App works offline (shows last fetched articles, no crash)
