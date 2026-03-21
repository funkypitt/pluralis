import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/source_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/bookmark_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SourceProvider()..load()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()..init()),
      ],
      child: const PluralisApp(),
    ),
  );
}

class PluralisApp extends StatelessWidget {
  const PluralisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pluralis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3A5C),
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
