import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

/// Seeds initial recipe data into Hive storage.
/// Runs only once when the recipesBox is empty.
Future<void> seedRecipesIfEmpty(Box<String> recipesBox) async {
  // Prevents re-seeding if data already exists
  if (recipesBox.isNotEmpty) return;

  // Load bundled JSON file with predefined recipes
  final jsonStr =
      await rootBundle.loadString('assets/data/recipes_seed_50.json');

  // Decode JSON array into Dart objects
  final List<dynamic> list = jsonDecode(jsonStr);

  // Prepare key-value map for efficient bulk insert into Hive
  final Map<String, String> toPut = {};
  for (final item in list) {
    final map = item as Map<String, dynamic>;
    final id = map['id'].toString();
    toPut[id] = jsonEncode(map);
  }

  // Persist all recipes in a single Hive operation
  await recipesBox.putAll(toPut);
}
