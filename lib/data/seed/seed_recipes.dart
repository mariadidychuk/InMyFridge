import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

Future<void> seedRecipesIfEmpty(Box<String> recipesBox) async {
  if (recipesBox.isNotEmpty) return;

  final jsonStr =
      await rootBundle.loadString('assets/data/recipes_seed_50.json');

  final List<dynamic> list = jsonDecode(jsonStr);

  final Map<String, String> toPut = {};
  for (final item in list) {
    final map = item as Map<String, dynamic>;
    final id = map['id'].toString();
    toPut[id] = jsonEncode(map);
  }

  await recipesBox.putAll(toPut);
}