import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/recipe.dart';
import 'recipe_details_screen.dart';

/// RecipesScreen
/// - filterByFridge == false: show all recipes (A–Z)
/// - filterByFridge == true : show recipes sorted by match quality:
///     1) fewer missing first (missingCount ASC)
///     2) more have first     (haveCount DESC)
///     3) name A–Z
///
/// Matching rules:
/// - We IGNORE salt/pepper/water for matching:
///     * they do not contribute to have/missing
///     * they do not affect sorting
/// - But they can still exist in the recipe ingredient list and should be shown in details.
class RecipesScreen extends StatefulWidget {
  final bool filterByFridge;

  const RecipesScreen({super.key, this.filterByFridge = false});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late final Box<String> _ingredientsBox;
  late final Box<String> _recipesBox;

  /// Ingredients ignored in matching/filtering logic.
  static const Set<String> _ignored = {'salt', 'pepper', 'water'};

  @override
  void initState() {
    super.initState();
    _ingredientsBox = Hive.box<String>('ingredientsBox');
    _recipesBox = Hive.box<String>('recipesBox');

    // ✅ IMPORTANT:
    // No demo seeding here anymore.
    // Seeding is done once in main.dart via seedRecipesIfEmpty(recipesBox).
  }

  String _normalize(String s) => s.trim().toLowerCase();

  /// User ingredients from fridge, lowercased.
  Set<String> _userIngredientsLower() {
    final result = <String>{};
    for (var i = 0; i < _ingredientsBox.length; i++) {
      final v = _normalize(_ingredientsBox.getAt(i) ?? '');
      if (v.isEmpty) continue;
      result.add(v);
    }
    return result;
  }

  /// Parse recipe JSON string (stored in Hive) into Recipe model.
  /// Uses the existing factory Recipe.fromMap(Map) as required.
  Recipe _parseRecipe(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return Recipe.fromMap(map);
  }

  /// Load all recipes from Hive.
  ///
  /// ✅ Your seed stores recipes as:
  ///    key = recipe.id, value = JSON string
  /// So we must iterate over box.values (NOT add/getAt index list).
  List<Recipe> _loadAllRecipes() {
    return _recipesBox.values
        .where((raw) => raw.trim().isNotEmpty)
        .map(_parseRecipe)
        .toList();
  }

  /// Compute match (have/missing) for a recipe based on current fridge ingredients.
  /// - ignores salt/pepper/water completely
  _RecipeMatch _matchRecipe(Recipe recipe, Set<String> userIngredientsLower) {
    final have = <String>[];
    final missing = <String>[];

    for (final ing in recipe.ingredients) {
      final nameLower = _normalize(ing.name);

      // Ignore salt/pepper/water in matching logic
      if (_ignored.contains(nameLower)) continue;

      if (userIngredientsLower.contains(nameLower)) {
        have.add(nameLower);
      } else {
        missing.add(nameLower);
      }
    }

    have.sort();
    missing.sort();

    return _RecipeMatch(recipe: recipe, have: have, missing: missing);
  }

  /// Build display list depending on screen mode.
  List<_RecipeMatch> _buildDisplayList() {
    final user = _userIngredientsLower();
    final all = _loadAllRecipes();

    final matches = all.map((r) => _matchRecipe(r, user)).toList();

    if (!widget.filterByFridge) {
      // Bottom tab "Recipes": show all A–Z by recipe name.
      matches.sort(
        (a, b) => a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase()),
      );
      return matches;
    }

    // From Fridge "See Recipes": sort by match quality.
    matches.sort((a, b) {
      final missingDiff = a.missing.length.compareTo(b.missing.length);
      if (missingDiff != 0) return missingDiff;

      final haveDiff = b.have.length.compareTo(a.have.length);
      if (haveDiff != 0) return haveDiff;

      return a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase());
    });

    return matches;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF6F2);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(widget.filterByFridge ? 'Recipes for you' : 'All Recipes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),

        // ✅ Listen to BOTH:
        // - recipesBox: when seed writes recipes to Hive
        // - ingredientsBox: when user changes fridge ingredients
        child: ValueListenableBuilder(
          valueListenable: _recipesBox.listenable(),
          builder: (context, Box<String> __, ___) {
            return ValueListenableBuilder(
              valueListenable: _ingredientsBox.listenable(),
              builder: (context, Box<String> _, ____) {
                final matches = _buildDisplayList();

                if (matches.isEmpty) {
                  return Center(
                    child: Text(
                      widget.filterByFridge
                          ? 'No recipes match your current ingredients yet.\nTry adding more items in your Fridge.'
                          : 'No recipes available yet.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final m = matches[index];
                    return _RecipeCard(
                      match: m,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailsScreen(
                              recipe: m.recipe,
                              haveIngredientsLower: m.have,
                              missingIngredientsLower: m.missing,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Recipe match info used for UI.
class _RecipeMatch {
  final Recipe recipe;
  final List<String> have; // lowercased
  final List<String> missing; // lowercased

  _RecipeMatch({
    required this.recipe,
    required this.have,
    required this.missing,
  });
}

/// Card UI:
/// - Title + time
/// - "You have X of Y ingredients"
/// - Chips "You have" (green) and "Missing" (red)
class _RecipeCard extends StatelessWidget {
  final _RecipeMatch match;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFD87C5A);
    const haveColor = Color(0xFF2E7D32);
    const missingColor = Color(0xFFC62828);

    final total = match.have.length + match.missing.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restaurant_menu, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${match.recipe.timeMinutes} min',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if (total > 0)
                    Text(
                      'You have ${match.have.length} of $total ingredients',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  const SizedBox(height: 6),
                  if (match.have.isNotEmpty) ...[
                    const Text(
                      'You have:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: match.have
                          .map((h) => _Chip(label: h, color: haveColor))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (match.missing.isNotEmpty) ...[
                    const Text(
                      'Missing:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: match.missing
                          .map((m) => _Chip(label: m, color: missingColor))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}