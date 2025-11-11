import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_scaffold.dart'; // Root widget with bottom navigation

/// Optional constant from your previous smoke test (kept for clarity).
/// You can still use 'ingredientsBox' directly below.
const String kBoxName = 'ingredientsBox';

Future<void> main() async {
  // Ensure Flutter engine bindings are ready before async work
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize Hive for Flutter (web/mobile/desktop)
  await Hive.initFlutter();

  // 2) Open the three boxes used across the app.
  //    If a box does not exist yet, Hive will create it on first open.
  await Hive.openBox<String>('ingredientsBox'); // user-entered ingredients
  await Hive.openBox<String>('recipesBox');     // normalized recipe maps later
  await Hive.openBox<String>('favoritesBox');   // list/set of recipe IDs

  // 3) Start the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Global MaterialApp wrapper (themes, routing, etc.)
    return MaterialApp(
      title: 'In My Fridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Match your Figma background and accent palette
        scaffoldBackgroundColor: const Color(0xFFFFF6F2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD87C5A)),
      ),

      // Show the main app shell with bottom navigation (Recipes/Calendar/Bookmarks/Fridge)
      home: const AppScaffold(),
    );
  }
}