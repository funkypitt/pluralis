import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import 'category_badge.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onTap;

  const ArticleCard({
    super.key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or initial
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 80,
                  child: article.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[200],
                          ),
                          errorWidget: (_, __, ___) =>
                              _InitialBox(article.sourceName),
                        )
                      : _InitialBox(article.sourceName),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            article.sourceName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: kCategoryColors[article.category] ??
                                  const Color(0xFF1A3A5C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (article.publishedAt != null) ...[
                          Text(
                            ' · ${DateFormat.MMMd().format(article.publishedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (article.description != null &&
                        article.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: onBookmarkToggle,
                        child: Icon(
                          isBookmarked ? Icons.star : Icons.star_border,
                          color: isBookmarked
                              ? const Color(0xFFE8A020)
                              : Colors.grey,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialBox extends StatelessWidget {
  final String name;
  const _InitialBox(this.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A3A5C),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
