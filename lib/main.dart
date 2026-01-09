import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_scaffold.dart';
import 'data/seed/seed_recipes.dart';

/// Hive box name for storing fridge ingredients
const String kBoxName = 'ingredientsBox';

Future<void> main() async {
  // Ensures Flutter engine is initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with Flutter support
  await Hive.initFlutter();

  // Open required Hive boxes (local persistent storage)
  await Hive.openBox<String>('ingredientsBox');
  final recipesBox = await Hive.openBox<String>('recipesBox');
  await Hive.openBox<String>('favoritesBox');
  await Hive.openBox<String>('calendarBox');

  // Seed initial recipe data only once (if box is empty)
  await seedRecipesIfEmpty(recipesBox);

  // Launch application
  runApp(const MyApp());
}

/// Root application widget.
/// Configures global theme and entry screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In My Fridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF6F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD87C5A),
        ),
      ),
      home: const AppScaffold(),
    );
  }
}
