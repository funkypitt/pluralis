import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/article.dart';
import '../models/bookmark.dart';

class BookmarkService {
  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'pluralis.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bookmarks (
            article_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            link TEXT NOT NULL,
            image_url TEXT,
            source_name TEXT NOT NULL,
            bookmarked_at INTEGER NOT NULL,
            auto_delete_at INTEGER NOT NULL
          )
        ''');
      },
    );
    await purgeExpired();
  }

  Future<void> addBookmark(Article article) async {
    final now = DateTime.now();
    final bookmark = Bookmark(
      articleId: article.id,
      title: article.title,
      link: article.link,
      imageUrl: article.imageUrl,
      sourceName: article.sourceName,
      bookmarkedAt: now,
    );
    await _db!.insert(
      'bookmarks',
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeBookmark(String articleId) async {
    await _db!.delete(
      'bookmarks',
      where: 'article_id = ?',
      whereArgs: [articleId],
    );
  }

  Future<List<Bookmark>> getBookmarks() async {
    final maps = await _db!.query(
      'bookmarks',
      orderBy: 'bookmarked_at DESC',
    );
    return maps.map((m) => Bookmark.fromMap(m)).toList();
  }

  Future<bool> isBookmarked(String articleId) async {
    final result = await _db!.query(
      'bookmarks',
      where: 'article_id = ?',
      whereArgs: [articleId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> purgeExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.delete(
      'bookmarks',
      where: 'auto_delete_at < ?',
      whereArgs: [now],
    );
  }
}
