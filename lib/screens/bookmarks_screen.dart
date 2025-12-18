import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'recipe_details_screen.dart';
import '../models/recipe.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late final Box<String> _favoritesBox;
  late final Box<String> _recipesBox;

  // These are ignored for matching (never have/missing)
  static const Set<String> _ignored = {'salt', 'pepper', 'water'};

  @override
  void initState() {
    super.initState();
    _favoritesBox = Hive.box<String>('favoritesBox');
    _recipesBox = Hive.box<String>('recipesBox');
  }

  Recipe? _findRecipeById(String id) {
    // recipesBox stores JSON strings -> decode and match by "id"
    for (int i = 0; i < _recipesBox.length; i++) {
      final raw = _recipesBox.getAt(i);
      if (raw == null) continue;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if ((map['id'] ?? '').toString() == id) {
        return Recipe.fromMap(map);
      }
    }
    return null;
  }

  Set<String> _userIngredientsLower(Box<String> ingredientsBox) {
    final result = <String>{};
    for (int i = 0; i < ingredientsBox.length; i++) {
      final v = (ingredientsBox.getAt(i) ?? '').trim().toLowerCase();
      if (v.isEmpty) continue;
      if (_ignored.contains(v)) continue;
      result.add(v);
    }
    return result;
  }

  List<String> _missingForRecipe(Recipe recipe, Set<String> have) {
    final missing = <String>[];
    for (final ing in recipe.ingredients) {
      final n = ing.name.trim().toLowerCase();
      if (n.isEmpty) continue;
      if (_ignored.contains(n)) continue;
      if (!have.contains(n)) missing.add(n);
    }
    return missing;
  }

  List<String> _haveForRecipe(Recipe recipe, Set<String> have) {
    final haveList = <String>[];
    for (final ing in recipe.ingredients) {
      final n = ing.name.trim().toLowerCase();
      if (n.isEmpty) continue;
      if (_ignored.contains(n)) continue;
      if (have.contains(n)) haveList.add(n);
    }
    return haveList;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF6F2);

    final ingredientsBox = Hive.box<String>('ingredientsBox');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Bookmarks'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          // Rebuild when bookmarks change
          valueListenable: _favoritesBox.listenable(),
          builder: (context, Box<String> favBox, _) {
            final ids = favBox.keys.map((e) => e.toString()).toList();

            if (ids.isEmpty) {
              return const Center(
                child: Text('No bookmarks yet.'),
              );
            }

            final recipes = <Recipe>[];
            for (final id in ids) {
              final r = _findRecipeById(id);
              if (r != null) recipes.add(r);
            }

            if (recipes.isEmpty) {
              return const Center(
                child: Text('Bookmarks exist, but recipes data not found.'),
              );
            }

            return ListView.separated(
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final recipe = recipes[index];

                // Build have/missing for details screen
                final haveSet = _userIngredientsLower(ingredientsBox);
                final missing = _missingForRecipe(recipe, haveSet);
                final haveList = _haveForRecipe(recipe, haveSet);

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailsScreen(
                          recipe: recipe,
                          haveIngredientsLower: haveList,
                          missingIngredientsLower: missing,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark, color: Color(0xFFD87C5A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${recipe.timeMinutes} min',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
