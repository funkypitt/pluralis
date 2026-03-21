import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/bookmark_provider.dart';
import '../models/bookmark.dart';

class BookmarksTab extends StatelessWidget {
  const BookmarksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookmarkProvider>();
    final bookmarks = provider.bookmarks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: bookmarks.isEmpty
          ? Center(
              child: Text(
                'No bookmarks yet',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return _BookmarkCard(
                  bookmark: bookmark,
                  onDelete: () => provider.removeById(bookmark.articleId),
                );
              },
            ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onDelete;

  const _BookmarkCard({required this.bookmark, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final daysLeft =
        bookmark.autoDeleteAt.difference(DateTime.now()).inDays;

    return Dismissible(
      key: Key(bookmark.articleId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          title: Text(
            bookmark.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${bookmark.sourceName} · Auto-delete in $daysLeft days',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => launchUrl(
              Uri.parse(bookmark.link),
              mode: LaunchMode.externalApplication,
            ),
          ),
          onTap: () => launchUrl(
            Uri.parse(bookmark.link),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    );
  }
}
