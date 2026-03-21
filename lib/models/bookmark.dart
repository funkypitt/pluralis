class Bookmark {
  final String articleId;
  final String title;
  final String link;
  final String? imageUrl;
  final String sourceName;
  final DateTime bookmarkedAt;
  final DateTime autoDeleteAt;

  Bookmark({
    required this.articleId,
    required this.title,
    required this.link,
    this.imageUrl,
    required this.sourceName,
    required this.bookmarkedAt,
    DateTime? autoDeleteAt,
  }) : autoDeleteAt =
            autoDeleteAt ?? bookmarkedAt.add(const Duration(days: 90));

  Map<String, dynamic> toMap() => {
        'article_id': articleId,
        'title': title,
        'link': link,
        'image_url': imageUrl,
        'source_name': sourceName,
        'bookmarked_at': bookmarkedAt.millisecondsSinceEpoch,
        'auto_delete_at': autoDeleteAt.millisecondsSinceEpoch,
      };

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      articleId: map['article_id'] as String,
      title: map['title'] as String,
      link: map['link'] as String,
      imageUrl: map['image_url'] as String?,
      sourceName: map['source_name'] as String,
      bookmarkedAt:
          DateTime.fromMillisecondsSinceEpoch(map['bookmarked_at'] as int),
      autoDeleteAt:
          DateTime.fromMillisecondsSinceEpoch(map['auto_delete_at'] as int),
    );
  }
}
