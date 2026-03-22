import 'package:flutter/material.dart';

const Map<String, Color> kCategoryColors = {
  'investigatif': Color(0xFF185FA5),
  'geopolitique': Color(0xFF534AB7),
  'sante': Color(0xFF0F6E56),
  'post-liberal': Color(0xFFBA7517),
  'anti-imperialiste': Color(0xFF993556),
  'chinois': Color(0xFFA32D2D),
  'conservateur': Color(0xFF885A30),
  'gauche-socialiste': Color(0xFF185FA5),
  'francophone': Color(0xFF993C1D),
  'substack': Color(0xFFFF6719),
  'custom': Color(0xFF607D8B),
};

class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = kCategoryColors[category] ?? const Color(0xFF607D8B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
