import 'dart:convert';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

class ExtractedArticle {
  final String title;
  final String content;
  final String? siteName;

  const ExtractedArticle({
    required this.title,
    required this.content,
    this.siteName,
  });
}

class ArticleExtractorService {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*',
  };

  /// Fetches the article page and extracts clean readable text.
  Future<ExtractedArticle?> extract(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final doc = htmlparser.parse(body);

      final title = _extractTitle(doc);
      final content = _extractContent(doc);

      if (content.trim().length < 100) return null;

      final siteName = _extractMeta(doc, 'og:site_name');

      return ExtractedArticle(
        title: title,
        content: content,
        siteName: siteName,
      );
    } catch (_) {
      return null;
    }
  }

  String _extractTitle(Document doc) {
    // Try og:title first
    final ogTitle = _extractMeta(doc, 'og:title');
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle;

    // Try <h1>
    final h1 = doc.querySelector('h1');
    if (h1 != null && h1.text.trim().isNotEmpty) return h1.text.trim();

    // Fallback to <title>
    final titleEl = doc.querySelector('title');
    return titleEl?.text.trim() ?? '';
  }

  String? _extractMeta(Document doc, String property) {
    final el = doc.querySelector('meta[property="$property"]') ??
        doc.querySelector('meta[name="$property"]');
    return el?.attributes['content']?.trim();
  }

  String _extractContent(Document doc) {
    // Remove noise elements
    for (final selector in [
      'script', 'style', 'nav', 'header', 'footer',
      'aside', 'iframe', 'form', 'noscript',
      '.sidebar', '.comments', '.comment', '.social-share',
      '.share-buttons', '.related-posts', '.advertisement',
      '.ad', '.ads', '.cookie', '.popup', '.modal',
      '.newsletter', '.subscribe', '.menu', '.navigation',
      '#comments', '#sidebar', '#footer', '#header', '#nav',
    ]) {
      doc.querySelectorAll(selector).forEach((e) => e.remove());
    }

    // Strategy 1: <article> tag
    final article = doc.querySelector('article');
    if (article != null) {
      final text = _nodeToText(article);
      if (text.length > 200) return text;
    }

    // Strategy 2: common content selectors
    for (final selector in [
      '.post-content',
      '.entry-content',
      '.article-content',
      '.article-body',
      '.story-body',
      '.content-body',
      '.post-body',
      '.td-post-content',
      '.single-post-content',
      '[itemprop="articleBody"]',
      '.field-item',
      'main',
      '#content',
      '.content',
    ]) {
      final el = doc.querySelector(selector);
      if (el != null) {
        final text = _nodeToText(el);
        if (text.length > 200) return text;
      }
    }

    // Strategy 3: find the div with most <p> text (readability heuristic)
    final candidates = doc.querySelectorAll('div, section');
    Element? best;
    int bestScore = 0;

    for (final el in candidates) {
      final paragraphs = el.querySelectorAll('p');
      int score = 0;
      for (final p in paragraphs) {
        final len = p.text.trim().length;
        if (len > 30) score += len;
      }
      if (score > bestScore) {
        bestScore = score;
        best = el;
      }
    }

    if (best != null && bestScore > 200) {
      return _nodeToText(best);
    }

    // Fallback: all <p> tags
    final allP = doc.querySelectorAll('p');
    final buf = StringBuffer();
    for (final p in allP) {
      final text = p.text.trim();
      if (text.length > 30) {
        buf.writeln(text);
        buf.writeln();
      }
    }
    return buf.toString().trim();
  }

  /// Converts an element tree to clean readable text with paragraph breaks.
  String _nodeToText(Element root) {
    final buf = StringBuffer();
    _walkNode(root, buf);
    // Clean up excessive whitespace
    return buf
        .toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void _walkNode(Node node, StringBuffer buf) {
    if (node is Text) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.trim().isNotEmpty) buf.write(text);
      return;
    }

    if (node is! Element) return;

    final tag = node.localName?.toLowerCase() ?? '';

    // Skip non-content elements
    if (['script', 'style', 'nav', 'button', 'input', 'select', 'textarea',
         'figure', 'figcaption', 'img', 'video', 'audio', 'svg']
        .contains(tag)) {
      return;
    }

    // Block-level elements get line breaks
    final isBlock = ['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
                     'blockquote', 'li', 'br', 'hr', 'section',
                     'article', 'tr'].contains(tag);

    if (tag == 'br' || tag == 'hr') {
      buf.writeln();
      return;
    }

    // Headings get emphasis
    if (tag.startsWith('h') && tag.length == 2) {
      buf.writeln();
    }

    for (final child in node.nodes) {
      _walkNode(child, buf);
    }

    if (isBlock) {
      buf.writeln();
      if (tag == 'p' || tag.startsWith('h')) buf.writeln();
    }
  }
}
