import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';
import '../models/source.dart';

class RssService {
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (compatible; Pluralis/1.0; RSS Reader)',
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
    'Cache-Control': 'no-cache, no-store',
    'Pragma': 'no-cache',
  };

  Future<List<Article>> fetchFeed(Source source) async {
    try {
      final headers = Map<String, String>.from(_headers);
      if (source.cookie != null && source.cookie!.isNotEmpty) {
        headers['Cookie'] = 'substack.sid=${source.cookie}';
      }
      final response = await http
          .get(Uri.parse(source.rss), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final doc = XmlDocument.parse(body);
      final root = doc.rootElement;

      // Detect RSS vs Atom
      if (root.name.local == 'feed') {
        return _parseAtom(root, source);
      } else {
        return _parseRss(root, source);
      }
    } catch (e) {
      debugPrint('RSS fetch error for ${source.name}: $e');
      return [];
    }
  }

  Future<List<Article>> fetchAllFeeds(List<Source> sources) async {
    final results = await Future.wait(
      sources.map((s) => fetchFeed(s)),
    );
    final all = results.expand((list) => list).toList();

    // Deduplicate by article id
    final seen = <String>{};
    all.retainWhere((a) => seen.add(a.id));

    return all;
  }

  List<Article> _parseRss(XmlElement root, Source source) {
    final channel = root.findAllElements('channel').firstOrNull;
    if (channel == null) return [];

    final items = channel.findAllElements('item');
    return items
        .map((item) => _rssItemToArticle(item, source))
        .whereType<Article>()
        .take(20)
        .toList();
  }

  Article? _rssItemToArticle(XmlElement item, Source source) {
    final link = _text(item, 'link');
    if (link == null || link.isEmpty) return null;

    final title = _cleanText(_text(item, 'title') ?? '');
    if (title.isEmpty) return null;

    final rawDesc = _text(item, 'description');
    final description =
        rawDesc != null ? _stripHtml(rawDesc, maxChars: 500) : null;

    // Capture content:encoded for in-app reader
    final contentEncoded = _text(item, 'content:encoded');
    final fullContent = contentEncoded != null
        ? _stripHtml(contentEncoded, maxChars: 50000)
        : null;

    final imageUrl = _extractImageRss(item) ?? _extractImageFromHtml(rawDesc);

    final pubDateStr = _text(item, 'pubDate');
    final published = pubDateStr != null ? _parseDate(pubDateStr) : null;

    return Article(
      id: _hashUrl(link),
      title: title,
      description: description,
      imageUrl: imageUrl,
      link: link,
      publishedAt: published,
      sourceName: source.name,
      sourceId: source.id,
      category: source.category,
      lang: source.lang,
      fullContent: fullContent,
    );
  }

  List<Article> _parseAtom(XmlElement root, Source source) {
    final entries = root.findAllElements('entry');
    return entries
        .map((entry) => _atomEntryToArticle(entry, source))
        .whereType<Article>()
        .take(20)
        .toList();
  }

  Article? _atomEntryToArticle(XmlElement entry, Source source) {
    // Atom link is an attribute
    final linkEl = entry.findAllElements('link').firstOrNull;
    final link = linkEl?.getAttribute('href');
    if (link == null || link.isEmpty) return null;

    final title = _cleanText(_text(entry, 'title') ?? '');
    if (title.isEmpty) return null;

    final rawDesc =
        _text(entry, 'summary') ?? _text(entry, 'content');
    final description =
        rawDesc != null ? _stripHtml(rawDesc, maxChars: 500) : null;

    final imageUrl = _extractImageFromHtml(rawDesc);

    final updatedStr = _text(entry, 'updated') ?? _text(entry, 'published');
    final published = updatedStr != null ? _parseDate(updatedStr) : null;

    return Article(
      id: _hashUrl(link),
      title: title,
      description: description,
      imageUrl: imageUrl,
      link: link,
      publishedAt: published,
      sourceName: source.name,
      sourceId: source.id,
      category: source.category,
      lang: source.lang,
    );
  }

  String? _text(XmlElement parent, String tag) {
    final el = parent.findAllElements(tag).firstOrNull;
    return el?.innerText.trim();
  }

  String? _extractImageRss(XmlElement item) {
    // media:content
    for (final el in item.findAllElements('media:content')) {
      final url = el.getAttribute('url');
      if (url != null && url.isNotEmpty) return url;
    }
    // media:thumbnail
    for (final el in item.findAllElements('media:thumbnail')) {
      final url = el.getAttribute('url');
      if (url != null && url.isNotEmpty) return url;
    }
    // enclosure
    for (final el in item.findAllElements('enclosure')) {
      final type = el.getAttribute('type') ?? '';
      if (type.startsWith('image/')) {
        final url = el.getAttribute('url');
        if (url != null) return url;
      }
    }
    return null;
  }

  String? _extractImageFromHtml(String? html) {
    if (html == null) return null;
    final match =
        RegExp(r'''<img[^>]+src=["']([^"']+)["']''').firstMatch(html);
    return match?.group(1);
  }

  String _stripHtml(String html, {int maxChars = 280}) {
    final doc = htmlparser.parse(html);
    final text = doc.body?.text ?? '';
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed.length > maxChars
        ? '${trimmed.substring(0, maxChars)}…'
        : trimmed;
  }

  String _cleanText(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        return _parseRfc822(dateStr);
      } catch (_) {
        return null;
      }
    }
  }

  static final _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  DateTime? _parseRfc822(String s) {
    // RFC 822: "Mon, 21 Mar 2026 14:30:00 +0000"
    final parts = s.replaceAll(',', '').trim().split(RegExp(r'\s+'));
    if (parts.length < 5) return null;

    int offset = 0;
    // Skip day name if present
    if (_months.containsKey(parts[1].substring(0, 3).toLowerCase())) {
      offset = 0;
    } else {
      offset = 1;
    }

    final day = int.tryParse(parts[offset]);
    final month = _months[parts[offset + 1].substring(0, 3).toLowerCase()];
    final year = int.tryParse(parts[offset + 2]);
    final timeParts = parts[offset + 3].split(':');

    if (day == null || month == null || year == null || timeParts.length < 3) {
      return null;
    }

    return DateTime.utc(
      year,
      month,
      day,
      int.tryParse(timeParts[0]) ?? 0,
      int.tryParse(timeParts[1]) ?? 0,
      int.tryParse(timeParts[2]) ?? 0,
    );
  }
}
