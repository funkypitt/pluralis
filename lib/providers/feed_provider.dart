import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/source.dart';
import '../services/rss_service.dart';

class FeedProvider extends ChangeNotifier {
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefresh;
  int _sourceCount = 0;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;
  int get sourceCount => _sourceCount;

  final RssService _rssService = RssService();

  Future<void> refresh(List<Source> activeSources) async {
    _isLoading = true;
    _error = null;
    _sourceCount = activeSources.length;
    notifyListeners();

    try {
      final results = await _rssService.fetchAllFeeds(activeSources);
      results.sort((a, b) {
        if (a.publishedAt == null) return 1;
        if (b.publishedAt == null) return -1;
        return b.publishedAt!.compareTo(a.publishedAt!);
      });
      _articles = _spreadSources(results);
      _lastRefresh = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Breaks up blocks of 3+ consecutive articles from the same source
  /// by pushing extras further down, interleaving with other sources.
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
        // Before adding, try to insert a deferred article from a different source
        if (deferred.isNotEmpty) {
          final idx = deferred.indexWhere((d) => d.sourceId != article.sourceId);
          if (idx >= 0) {
            result.add(deferred.removeAt(idx));
          }
        }
        result.add(article);
      }
    }

    // Append remaining deferred articles at the end
    result.addAll(deferred);
    return result;
  }
}
