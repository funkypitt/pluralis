import 'package:flutter/painting.dart';

class TextPaginator {
  /// Splits [text] into pages that fit within [pageSize] using [style].
  /// Returns a list of strings, one per page.
  List<String> paginate({
    required String text,
    required Size pageSize,
    required TextStyle style,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    if (text.trim().isEmpty) return [''];

    final availableWidth = pageSize.width - padding.left - padding.right;
    final availableHeight = pageSize.height - padding.top - padding.bottom;

    final pages = <String>[];
    final paragraphs = text.split('\n');
    var currentPageLines = <String>[];
    var currentHeight = 0.0;

    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        // Empty line = paragraph break
        final lineHeight = _measureHeight('', style, availableWidth);
        if (currentHeight + lineHeight > availableHeight) {
          // Start new page
          pages.add(currentPageLines.join('\n'));
          currentPageLines = [];
          currentHeight = 0;
        }
        currentPageLines.add('');
        currentHeight += lineHeight;
        continue;
      }

      // Measure the paragraph as a whole block
      final paraHeight = _measureHeight(paragraph, style, availableWidth);

      if (currentHeight + paraHeight <= availableHeight) {
        // Fits on current page
        currentPageLines.add(paragraph);
        currentHeight += paraHeight;
      } else if (paraHeight > availableHeight) {
        // Paragraph too long for a single page — split by words
        final words = paragraph.split(RegExp(r'\s+'));
        var chunk = StringBuffer();

        for (final word in words) {
          final test =
              chunk.isEmpty ? word : '${chunk.toString()} $word';
          final testHeight = _measureHeight(test, style, availableWidth);
          final totalHeight = currentHeight + testHeight;

          if (totalHeight > availableHeight) {
            if (chunk.isNotEmpty) {
              currentPageLines.add(chunk.toString());
            }
            if (currentPageLines.isNotEmpty) {
              pages.add(currentPageLines.join('\n'));
            }
            currentPageLines = [];
            currentHeight = 0;
            chunk = StringBuffer(word);
          } else {
            chunk = StringBuffer(test);
          }
        }
        if (chunk.isNotEmpty) {
          final remaining = chunk.toString();
          currentPageLines.add(remaining);
          currentHeight += _measureHeight(remaining, style, availableWidth);
        }
      } else {
        // Doesn't fit — start new page
        if (currentPageLines.isNotEmpty) {
          pages.add(currentPageLines.join('\n'));
        }
        currentPageLines = [paragraph];
        currentHeight = paraHeight;
      }
    }

    // Last page
    if (currentPageLines.isNotEmpty) {
      pages.add(currentPageLines.join('\n'));
    }

    return pages.isEmpty ? [''] : pages;
  }

  double _measureHeight(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    tp.layout(maxWidth: maxWidth);
    final height = tp.height;
    tp.dispose();
    return height;
  }
}
