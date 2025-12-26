import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_scaffold.dart';
import 'data/seed/seed_recipes.dart';

const String kBoxName = 'ingredientsBox';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // 1) Open boxes
  await Hive.openBox<String>('ingredientsBox');
  final recipesBox = await Hive.openBox<String>('recipesBox');
  await Hive.openBox<String>('favoritesBox');

  // 2) Seed recipes (only if recipesBox is empty)
  await seedRecipesIfEmpty(recipesBox);

  // 3) Start app
  runApp(const MyApp());
}

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD87C5A)),
      ),
      home: const AppScaffold(),
    );
  }
}