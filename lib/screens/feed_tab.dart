import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../providers/feed_provider.dart';
import '../providers/source_provider.dart';
import '../providers/bookmark_provider.dart';
import '../widgets/article_card.dart';

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final bookmarks = context.watch<BookmarkProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pluralis'),
            if (feed.articles.isNotEmpty)
              Text(
                '${feed.articles.length} articles from ${feed.sourceCount} sources',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (feed.lastRefresh != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  timeago.format(feed.lastRefresh!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final sources = context.read<SourceProvider>().activeSources;
              feed.refresh(sources);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'Pluralis',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text(
                      'Alternative news aggregator\nEN & FR RSS feeds',
                    ),
                  ],
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'about',
                child: Text('About'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context, feed, bookmarks),
    );
  }

  Widget _buildBody(
      BuildContext context, FeedProvider feed, BookmarkProvider bookmarks) {
    if (feed.isLoading && feed.articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feed.error != null && feed.articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Failed to load feeds',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final sources = context.read<SourceProvider>().activeSources;
                feed.refresh(sources);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (feed.articles.isEmpty) {
      return Center(
        child: Text(
          'Enable sources in the Sources tab',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final sources = context.read<SourceProvider>().activeSources;
        await feed.refresh(sources);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: feed.articles.length,
        itemBuilder: (context, index) {
          final article = feed.articles[index];
          return ArticleCard(
            article: article,
            isBookmarked: bookmarks.isBookmarked(article.id),
            onBookmarkToggle: () => bookmarks.toggle(article),
            onTap: () => launchUrl(
              Uri.parse(article.link),
              mode: LaunchMode.externalApplication,
            ),
          );
        },
      ),
    );
  }
}
