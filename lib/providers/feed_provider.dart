import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/source.dart';
import '../services/rss_service.dart';

enum FeedViewMode { latest, perSource }

class FeedProvider extends ChangeNotifier {
  List<Article> _chronoArticles = [];
  List<Article> _perSourceArticles = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefresh;
  int _sourceCount = 0;
  FeedViewMode _viewMode = FeedViewMode.latest;
  Set<String> _activeSourceIds = {};

  List<Article> get articles =>
      _viewMode == FeedViewMode.latest ? _chronoArticles : _perSourceArticles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;
  int get sourceCount => _sourceCount;
  FeedViewMode get viewMode => _viewMode;

  /// Source IDs that returned at least one article on last fetch.
  Set<String> get activeSourceIds => _activeSourceIds;

  final RssService _rssService = RssService();

  void toggleViewMode() {
    _viewMode = _viewMode == FeedViewMode.latest
        ? FeedViewMode.perSource
        : FeedViewMode.latest;
    notifyListeners();
  }

  Future<void> refresh(List<Source> activeSources) async {
    _isLoading = true;
    _error = null;
    _sourceCount = activeSources.length;
    notifyListeners();

    try {
      final results = await _rssService.fetchAllFeeds(activeSources);

      // Track which sources returned articles
      _activeSourceIds = results.map((a) => a.sourceId).toSet();

      // Chronological view (with spread)
      results.sort((a, b) {
        if (a.publishedAt == null) return 1;
        if (b.publishedAt == null) return -1;
        return b.publishedAt!.compareTo(a.publishedAt!);
      });
      _chronoArticles = _spreadSources(List.of(results));

      // Per-source round-robin view
      _perSourceArticles = _buildPerSourceView(results);

      _lastRefresh = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Round-robin: 1 article per source, cycling through all sources.
  /// Sources ranked by most recent article.
  static List<Article> _buildPerSourceView(List<Article> sorted) {
    // Group by source
    final bySource = <String, List<Article>>{};
    for (final a in sorted) {
      bySource.putIfAbsent(a.sourceId, () => []).add(a);
    }

    // Rank sources by their most recent article
    final sourceOrder = bySource.keys.toList();
    sourceOrder.sort((a, b) {
      final aFirst = bySource[a]!.first.publishedAt;
      final bFirst = bySource[b]!.first.publishedAt;
      if (aFirst == null) return 1;
      if (bFirst == null) return -1;
      return bFirst.compareTo(aFirst);
    });

    // Interleave: round 0 = 1st article per source, round 1 = 2nd, etc.
    final result = <Article>[];
    int round = 0;
    bool added = true;

    while (added) {
      added = false;
      for (final sourceId in sourceOrder) {
        final list = bySource[sourceId]!;
        if (round < list.length) {
          result.add(list[round]);
          added = true;
        }
      }
      round++;
    }

    return result;
  }

  /// Breaks up blocks of 3+ consecutive articles from the same source.
  static List<Article> _spreadSources(List<Article> sorted) {
    const maxConsecutive = 2;
    final result = <Article>[];
    final deferred = <Article>[];

    String? lastSourceId;
    int consecutive = 0;

    for (final article in sorted) {
      if (article.sourceId == lastSourceId) {
        consecutive++;
      } else {
        lastSourceId = article.sourceId;
        consecutive = 1;
      }

      if (consecutive > maxConsecutive) {
        deferred.add(article);
      } else {
        if (deferred.isNotEmpty) {
          final idx =
              deferred.indexWhere((d) => d.sourceId != article.sourceId);
          if (idx >= 0) {
            result.add(deferred.removeAt(idx));
          }
        }
        result.add(article);
      }
    }

    result.addAll(deferred);
    return result;
  }
}
