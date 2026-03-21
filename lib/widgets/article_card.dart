import 'package:flutter/material.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CategoryBadge(category: article.category),
                  const SizedBox(width: 6),
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
                      ' · ${DateFormat.MMMd().add_Hm().format(article.publishedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: onBookmarkToggle,
                    child: Icon(
                      isBookmarked ? Icons.star : Icons.star_border,
                      color: isBookmarked
                          ? const Color(0xFFE8A020)
                          : Colors.grey,
                      size: 22,
                    ),
                  ),
                ],
              ),
              if (article.description != null &&
                  article.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  article.description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
