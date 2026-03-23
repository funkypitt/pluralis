import 'package:flutter/painting.dart';

class TextPaginator {
  /// Splits [text] into pages that fit within the given width and heights.
  /// [firstPageHeight] is the available height for the first page (may be
  /// reduced to make room for the article title).
  /// [pageHeight] is the available height for all subsequent pages.
  List<String> paginate({
    required String text,
    required double width,
    required double firstPageHeight,
    required double pageHeight,
    required TextStyle style,
  }) {
    if (text.trim().isEmpty) return [''];

    final pages = <String>[];
    var remaining = text;
    var isFirstPage = true;

    while (remaining.isNotEmpty) {
      final height = isFirstPage ? firstPageHeight : pageHeight;
      isFirstPage = false;

      final tp = TextPainter(
        text: TextSpan(text: remaining, style: style),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: width);

      if (tp.height <= height) {
        // Everything remaining fits on this page
        pages.add(remaining);
        tp.dispose();
        break;
      }

      // Count exactly which lines fit using real line metrics
      final metrics = tp.computeLineMetrics();
      double usedHeight = 0;
      int fittingLines = 0;
      for (final m in metrics) {
        if (usedHeight + m.height > height) break;
        usedHeight += m.height;
        fittingLines++;
      }

      if (fittingLines == 0) {
        // Can't fit even one line — force it to avoid infinite loop
        pages.add(remaining);
        tp.dispose();
        break;
      }

      // Find the character offset at the start of the first non-fitting line.
      // Position (x=0, y=usedHeight) is exactly at the top of that line.
      final breakPos = tp.getPositionForOffset(Offset(0, usedHeight));
      var breakOffset = breakPos.offset;

      // Safety: ensure we actually advance
      if (breakOffset <= 0) {
        pages.add(remaining);
        tp.dispose();
        break;
      }

      pages.add(remaining.substring(0, breakOffset).trimRight());
      remaining = remaining.substring(breakOffset).trimLeft();
      tp.dispose();
    }

    return pages.isEmpty ? [''] : pages;
  }
}
