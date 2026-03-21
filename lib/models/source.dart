class Source {
  final String id;
  final String name;
  final String url;
  final String rss;
  final String category;
  final String lang;
  final String tag;
  final bool isDefault;
  bool active;

  Source({
    required this.id,
    required this.name,
    required this.url,
    required this.rss,
    required this.category,
    required this.lang,
    this.tag = '',
    this.isDefault = true,
    this.active = true,
  });

  factory Source.fromJson(Map<String, dynamic> json, {bool isDefault = true}) {
    return Source(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      rss: json['rss'] as String,
      category: json['category'] as String,
      lang: json['lang'] as String,
      tag: (json['tag'] as String?) ?? '',
      isDefault: isDefault,
      active: (json['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'rss': rss,
        'category': category,
        'lang': lang,
        'tag': tag,
        'active': active,
      };
}
