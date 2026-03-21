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
