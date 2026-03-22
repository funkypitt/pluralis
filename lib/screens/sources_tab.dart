import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/source_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/category_badge.dart';
import '../widgets/font_size_controls.dart';

class SourcesTab extends StatelessWidget {
  const SourcesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SourceProvider>();
    final sources = provider.sources;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sources (${sources.length})'),
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
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add source'),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
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
              final rss = rssCtrl.text.trim();
              if (name.isEmpty || rss.isEmpty) return;

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
}

class _SourceTile extends StatelessWidget {
  final Source source;
  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SourceProvider>();
    final feedActiveIds = context.watch<FeedProvider>().activeSourceIds;
    final isFeedActive = feedActiveIds.contains(source.id);
    // Only show inactive if the source is toggled on but returned no articles
    final showInactive = source.active && feedActiveIds.isNotEmpty && !isFeedActive;

    return SwitchListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              source.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          if (showInactive)
            const _StatusChip(label: 'inactive', color: Colors.red)
          else if (source.active && feedActiveIds.isNotEmpty)
            const _StatusChip(label: 'active', color: Colors.green),
          const SizedBox(width: 4),
          CategoryBadge(category: source.category),
          const SizedBox(width: 4),
          _LangChip(lang: source.lang),
          if (source.tag.isNotEmpty) ...[
            const SizedBox(width: 4),
            _TagChip(tag: source.tag),
          ],
        ],
      ),
      value: source.active,
      onChanged: (_) => provider.toggleSource(source.id),
      secondary: !source.isDefault
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => provider.removeSource(source.id),
            )
          : null,
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
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
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

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: const TextStyle(fontSize: 10, color: Colors.orange),
      ),
    );
  }
}
