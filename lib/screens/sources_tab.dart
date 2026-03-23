import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/source.dart';
import '../providers/source_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/settings_provider.dart';
import '../services/import_export_service.dart';
import '../widgets/font_size_controls.dart';
import 'source_feed_screen.dart';
import 'substack_login_screen.dart';

class SourcesTab extends StatelessWidget {
  const SourcesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SourceProvider>();
    final sources = provider.sources;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sources (${sources.length})'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import / Export',
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export_opml',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Export OPML'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'import_opml',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Import OPML'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.vpn_key),
                  title: Text('Export Substacks (CSV)'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'import_csv',
                child: ListTile(
                  leading: Icon(Icons.vpn_key_outlined),
                  title: Text('Import Substacks (CSV)'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _FontSizeSection(),
          const Divider(),
          ...sources.map((source) => _SourceTile(source: source)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add source'),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'export_opml':
        _exportOpml(context);
        break;
      case 'import_opml':
        _importOpml(context);
        break;
      case 'export_csv':
        _exportCsv(context);
        break;
      case 'import_csv':
        _importCsv(context);
        break;
    }
  }

  Future<void> _exportOpml(BuildContext context) async {
    final sources = context.read<SourceProvider>().sources;
    final service = ImportExportService();
    final opml = service.exportOpml(sources);

    final tempDir = await getTemporaryDirectory();
    final file = await service.writeToTempFile(
        opml, 'pluralis_sources.opml', tempDir.path);

    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _importOpml(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final service = ImportExportService();
      final sources = service.importOpml(content);

      if (!context.mounted) return;

      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sources found in OPML file')),
        );
        return;
      }

      await context.read<SourceProvider>().addSources(sources);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${sources.length} sources')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final sources = context.read<SourceProvider>().sources;
    final service = ImportExportService();
    final csv = service.exportSubstackCsv(sources);

    final hasSubstacks =
        sources.any((s) => s.cookie != null && s.cookie!.isNotEmpty);
    if (!hasSubstacks) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No paid Substack sources with cookies to export')),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = await service.writeToTempFile(
        csv, 'pluralis_substacks.csv', tempDir.path);

    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final service = ImportExportService();
      final sources = service.importSubstackCsv(content);

      if (!context.mounted) return;

      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Substack sources found in CSV')),
        );
        return;
      }

      await context.read<SourceProvider>().addSources(sources);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Imported ${sources.length} Substack sources with cookies')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('Add RSS source'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddRssDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_open, color: Color(0xFFFF6719)),
              title: const Text('Add Substack (paid)'),
              subtitle: const Text('Requires sign-in for full articles'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSubstackDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRssDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final rssCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add custom source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'My News Source',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rssCtrl,
              decoration: const InputDecoration(
                labelText: 'RSS URL',
                hintText: 'https://example.com/feed',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              var rss = rssCtrl.text.trim();
              if (name.isEmpty || rss.isEmpty) return;

              // Auto-append /feed for Substack URLs
              if (rss.contains('substack.com') && !rss.endsWith('/feed')) {
                rss = rss.endsWith('/') ? '${rss}feed' : '$rss/feed';
              }

              final id = name
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
              final source = Source(
                id: id,
                name: name,
                url: rss,
                rss: rss,
                category: 'custom',
                lang: 'EN',
                isDefault: false,
              );
              context.read<SourceProvider>().addSource(source);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddSubstackDialog(BuildContext context) {
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Substack publication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Publication URL',
                hintText: 'https://example.substack.com',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be asked to sign in to access paid content.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);

              final cookie = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubstackLoginScreen(),
                ),
              );

              if (cookie == null || !context.mounted) return;

              // Derive name from URL
              final uri = Uri.tryParse(url);
              final name = uri?.host
                      .replaceAll('.substack.com', '')
                      .replaceAll('www.', '') ??
                  url;
              final id =
                  'substack_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
              final rss = url.endsWith('/feed') ? url : '$url/feed';

              final source = Source(
                id: id,
                name: name,
                url: url,
                rss: rss,
                category: 'substack',
                lang: 'EN',
                tag: 'paid',
                isDefault: false,
                cookie: cookie,
              );

              if (context.mounted) {
                context.read<SourceProvider>().addSource(source);
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final Source source;
  const _SourceTile({required this.source});

  void _showSourceOptions(BuildContext context) {
    final provider = context.read<SourceProvider>();
    final hasCookie = source.cookie != null && source.cookie!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCookie) ...[
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh cookie'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final cookie = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubstackLoginScreen(),
                    ),
                  );
                  if (cookie != null && context.mounted) {
                    provider.updateSourceCookie(source.id, cookie);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_off),
                title: const Text('Clear cookie'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.updateSourceCookie(source.id, null);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete source'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SourceProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete source?'),
        content: Text('Remove "${source.name}" from your sources?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              provider.removeSource(source.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SourceProvider>();
    final feedActiveIds = context.watch<FeedProvider>().activeSourceIds;
    final isFeedActive = feedActiveIds.contains(source.id);
    final showInactive =
        source.active && feedActiveIds.isNotEmpty && !isFeedActive;
    final hasCookie = source.cookie != null && source.cookie!.isNotEmpty;

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SourceFeedScreen(source: source),
        ),
      ),
      onLongPress: () => _showSourceOptions(context),
      title: Row(
        children: [
          Expanded(
            child: Text(
              source.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasCookie) ...[
            const SizedBox(width: 4),
            const Icon(Icons.vpn_key, size: 14, color: Color(0xFFFF6719)),
          ],
          const SizedBox(width: 4),
          if (showInactive)
            const _StatusChip(label: 'inactive', color: Colors.red)
          else if (source.active && feedActiveIds.isNotEmpty)
            const _StatusChip(label: 'active', color: Colors.green),
          const SizedBox(width: 4),
          _LangChip(lang: source.lang),
        ],
      ),
      trailing: Switch(
        value: source.active,
        onChanged: (_) => provider.toggleSource(source.id),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FontSizeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return ListTile(
      title: const Text('Font size'),
      subtitle: Text(
        settings.fontSizeIsAuto
            ? 'Auto-calculated for this screen'
            : 'Set manually — long-press size to reset',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: const FontSizeControls(),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String lang;
  const _LangChip({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lang,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
