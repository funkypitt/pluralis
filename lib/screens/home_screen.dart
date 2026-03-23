import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/source_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/settings_provider.dart';
import 'feed_tab.dart';
import 'bookmarks_tab.dart';
import 'sources_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastRefresh;

  final _tabs = const [
    FeedTab(),
    BookmarksTab(),
    SourcesTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().initFontSize(context);
      _doInitialRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfStale();
    }
  }

  /// Refresh feeds if last refresh was more than 5 minutes ago
  void _refreshIfStale() {
    if (!mounted) return;
    if (_lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!).inMinutes < 5) {
      return;
    }
    final sources = context.read<SourceProvider>().activeSources;
    if (sources.isNotEmpty) {
      _lastRefresh = DateTime.now();
      context.read<FeedProvider>().refresh(sources);
    }
  }

  void _doInitialRefresh() {
    final sourceProvider = context.read<SourceProvider>();

    // If sources are already loaded, refresh immediately
    final sources = sourceProvider.activeSources;
    if (sources.isNotEmpty) {
      _lastRefresh = DateTime.now();
      context.read<FeedProvider>().refresh(sources);
      return;
    }

    // Otherwise, wait for sources to finish loading via listener
    late final void Function() listener;
    listener = () {
      if (!mounted) {
        sourceProvider.removeListener(listener);
        return;
      }
      final loaded = sourceProvider.activeSources;
      if (loaded.isNotEmpty) {
        sourceProvider.removeListener(listener);
        _lastRefresh = DateTime.now();
        context.read<FeedProvider>().refresh(loaded);
      }
    };
    sourceProvider.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Sources',
          ),
        ],
      ),
    );
  }
}
