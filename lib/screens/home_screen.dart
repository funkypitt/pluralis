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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _initialRefreshDone = false;

  final _tabs = const [
    FeedTab(),
    BookmarksTab(),
    SourcesTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().initFontSize(context);
      _tryInitialRefresh();
      // Listen for sources to finish loading
      context.read<SourceProvider>().addListener(_tryInitialRefresh);
    });
  }

  void _tryInitialRefresh() {
    if (_initialRefreshDone) return;
    final sources = context.read<SourceProvider>().activeSources;
    if (sources.isNotEmpty) {
      _initialRefreshDone = true;
      context.read<FeedProvider>().refresh(sources);
    }
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
