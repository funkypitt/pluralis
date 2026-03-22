import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/source_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/category_badge.dart';
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
              final id = 'substack_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
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

  void _showCookieOptions(BuildContext context) {
    final provider = context.read<SourceProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Clear cookie'),
              onTap: () {
                Navigator.pop(ctx);
                provider.updateSourceCookie(source.id, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SourceProvider>();
    final feedActiveIds = context.watch<FeedProvider>().activeSourceIds;
    final isFeedActive = feedActiveIds.contains(source.id);
    final showInactive = source.active && feedActiveIds.isNotEmpty && !isFeedActive;
    final hasCookie = source.cookie != null && source.cookie!.isNotEmpty;

    return GestureDetector(
      onLongPress: hasCookie ? () => _showCookieOptions(context) : null,
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SourceFeedScreen(source: source),
          ),
        ),
        leading: !source.isDefault
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => provider.removeSource(source.id),
              )
            : null,
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
            CategoryBadge(category: source.category),
            const SizedBox(width: 4),
            _LangChip(lang: source.lang),
            if (source.tag.isNotEmpty) ...[
              const SizedBox(width: 4),
              _TagChip(tag: source.tag),
            ],
          ],
        ),
        trailing: Switch(
          value: source.active,
          onChanged: (_) => provider.toggleSource(source.id),
        ),
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
