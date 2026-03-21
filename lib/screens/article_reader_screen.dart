import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../providers/settings_provider.dart';
import '../services/article_extractor_service.dart';
import '../services/text_paginator.dart';
import '../widgets/font_size_controls.dart';

class ArticleReaderScreen extends StatefulWidget {
  final Article article;

  const ArticleReaderScreen({super.key, required this.article});

  @override
  State<ArticleReaderScreen> createState() => _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends State<ArticleReaderScreen> {
  final _extractor = ArticleExtractorService();
  final _paginator = TextPaginator();

  ExtractedArticle? _extracted;
  List<String> _pages = [];
  int _currentPage = 0;
  bool _isLoading = true;
  String? _error;
  double _lastFontSize = 0;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Try RSS fullContent first, then fetch from web
    if (widget.article.fullContent != null &&
        widget.article.fullContent!.length > 200) {
      _extracted = ExtractedArticle(
        title: widget.article.title,
        content: widget.article.fullContent!,
        siteName: widget.article.sourceName,
      );
      if (mounted) _repaginate();
      return;
    }

    final extracted = await _extractor.extract(widget.article.link);

    if (!mounted) return;

    if (extracted == null) {
      setState(() {
        _isLoading = false;
        _error = 'Could not extract article content';
      });
      return;
    }

    _extracted = extracted;
    _repaginate();
  }

  void _repaginate() {
    if (_extracted == null || !mounted) return;

    final settings = context.read<SettingsProvider>();
    final screenSize = MediaQuery.of(context).size;

    final style = GoogleFonts.merriweather(
      fontSize: settings.fontSize,
      height: 1.7,
      color: Colors.black87,
    );

    // Reserve space for header on first page
    final headerHeight = settings.fontSize * 3 + 60;
    final firstPageSize = Size(
      screenSize.width,
      screenSize.height - headerHeight - 100, // AppBar + bottom bar
    );
    final normalPageSize = Size(
      screenSize.width,
      screenSize.height - 100,
    );

    // Paginate with first page smaller (for title)
    final allPages = _paginator.paginate(
      text: _extracted!.content,
      pageSize: normalPageSize,
      style: style,
    );

    // Re-paginate first page with reduced height
    if (allPages.isNotEmpty) {
      final firstPages = _paginator.paginate(
        text: allPages.first,
        pageSize: firstPageSize,
        style: style,
      );
      if (firstPages.length > 1) {
        // First page content overflows when title is shown — re-split
        final fullText = _extracted!.content;
        final pages = _paginator.paginate(
          text: fullText,
          pageSize: firstPageSize,
          style: style,
        );
        setState(() {
          _pages = pages;
          _currentPage = 0;
          _lastFontSize = settings.fontSize;
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _pages = allPages;
      _currentPage = 0;
      _lastFontSize = settings.fontSize;
      _isLoading = false;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Re-paginate if font size changed
    if (_extracted != null && settings.fontSize != _lastFontSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _repaginate());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          widget.article.sourceName,
          style: TextStyle(fontSize: settings.fontSize - 2),
        ),
        actions: [
          const FontSizeControls(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: () => launchUrl(
              Uri.parse(widget.article.link),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: _buildBody(settings),
    );
  }

  Widget _buildBody(SettingsProvider settings) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Extracting article...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(widget.article.link),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open in browser'),
              ),
            ],
          ),
        ),
      );
    }

    final style = GoogleFonts.merriweather(
      fontSize: settings.fontSize,
      height: 1.7,
      color: Colors.black87,
    );

    return GestureDetector(
      onTapUp: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 3) {
          _prevPage();
        } else if (details.globalPosition.dx > width * 2 / 3) {
          _nextPage();
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -100) {
          _nextPage();
        } else if (velocity > 100) {
          _prevPage();
        }
      },
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show title only on first page
                      if (_currentPage == 0 && _extracted != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _extracted!.title,
                          style: GoogleFonts.merriweather(
                            fontSize: settings.fontSize + 4,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 12),
                      ],
                      if (_pages.isNotEmpty)
                        Text(
                          _pages[_currentPage],
                          style: style,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Page indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Prev indicator
                  Icon(
                    Icons.chevron_left,
                    color: _currentPage > 0
                        ? Colors.black54
                        : Colors.transparent,
                  ),
                  Text(
                    '${_currentPage + 1} / ${_pages.length}',
                    style: TextStyle(
                      fontSize: settings.fontSize - 4,
                      color: Colors.black54,
                    ),
                  ),
                  // Next indicator
                  Icon(
                    Icons.chevron_right,
                    color: _currentPage < _pages.length - 1
                        ? Colors.black54
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
