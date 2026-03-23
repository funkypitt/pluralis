import 'dart:io';
import 'package:xml/xml.dart';
import '../models/source.dart';

class ImportExportService {
  /// Generate OPML XML string from sources
  String exportOpml(List<Source> sources) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', nest: () {
      builder.attribute('version', '2.0');
      builder.element('head', nest: () {
        builder.element('title', nest: 'Pluralis Sources');
      });
      builder.element('body', nest: () {
        for (final source in sources) {
          builder.element('outline', nest: () {
            builder.attribute('text', source.name);
            builder.attribute('title', source.name);
            builder.attribute('type', 'rss');
            builder.attribute('xmlUrl', source.rss);
            builder.attribute('htmlUrl', source.url);
            builder.attribute('category', source.category);
          });
        }
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Parse OPML file and return sources
  List<Source> importOpml(String opmlContent) {
    final doc = XmlDocument.parse(opmlContent);
    final outlines = doc.findAllElements('outline');
    final sources = <Source>[];

    for (final outline in outlines) {
      final xmlUrl = outline.getAttribute('xmlUrl');
      if (xmlUrl == null || xmlUrl.isEmpty) continue;

      final name = outline.getAttribute('text') ??
          outline.getAttribute('title') ??
          xmlUrl;
      final htmlUrl = outline.getAttribute('htmlUrl') ?? xmlUrl;
      final category = outline.getAttribute('category') ?? 'custom';

      final id = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');

      sources.add(Source(
        id: id,
        name: name,
        url: htmlUrl,
        rss: xmlUrl,
        category: category,
        lang: 'EN',
        isDefault: false,
      ));
    }

    return sources;
  }

  /// Export paid Substack sources as CSV (name, url, rss, cookie)
  String exportSubstackCsv(List<Source> sources) {
    final buffer = StringBuffer();
    buffer.writeln('name,url,rss,cookie');
    final substacks = sources
        .where((s) => s.cookie != null && s.cookie!.isNotEmpty);
    for (final s in substacks) {
      buffer.writeln(
          '${_csvEscape(s.name)},${_csvEscape(s.url)},${_csvEscape(s.rss)},${_csvEscape(s.cookie!)}');
    }
    return buffer.toString();
  }

  /// Import Substack sources from CSV
  List<Source> importSubstackCsv(String csvContent) {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    // Skip header if present
    int start = 0;
    if (lines.first.toLowerCase().contains('name') &&
        lines.first.toLowerCase().contains('cookie')) {
      start = 1;
    }

    final sources = <Source>[];
    for (int i = start; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length < 4) continue;

      final name = fields[0];
      final url = fields[1];
      final rss = fields[2];
      final cookie = fields[3];

      if (name.isEmpty || rss.isEmpty) continue;

      final id =
          'substack_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

      sources.add(Source(
        id: id,
        name: name,
        url: url,
        rss: rss,
        category: 'substack',
        lang: 'EN',
        tag: 'paid',
        isDefault: false,
        cookie: cookie,
      ));
    }

    return sources;
  }

  /// Write content to a temporary file and return its path
  Future<File> writeToTempFile(String content, String filename,
      String tempDir) async {
    final file = File('$tempDir/$filename');
    await file.writeAsString(content);
    return file;
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          fields.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(ch);
        }
      }
    }
    fields.add(buffer.toString().trim());
    return fields;
  }
}
