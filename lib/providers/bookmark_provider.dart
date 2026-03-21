import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

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

  Future<void> removeById(String articleId) async {
    await _service.removeBookmark(articleId);
    await _load();
  }
}
