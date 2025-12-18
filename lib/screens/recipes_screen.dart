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

    _seedDemoRecipesIfEmpty(); // temporary demo data until DB/API is connected
  }

  /// Add a few demo recipes to recipesBox so the UI works immediately.
  /// Each value is JSON.
  void _seedDemoRecipesIfEmpty() {
    if (_recipesBox.isNotEmpty) return;

    final demo = <Map<String, dynamic>>[
      {
        "id": "r_choco_peanut",
        "name": "Chocolate Peanut",
        "timeMinutes": 30,
        "description":
            "A quick and easy dessert with a soft crumb and a rich chocolate-peanut taste.",
        "ingredients": [
          {"name": "Flour", "amount": "250 g"},
          {"name": "Sugar", "amount": "100 g"},
          {"name": "Butter", "amount": "100 g"},
          {"name": "Eggs", "amount": "2"},
          {"name": "Milk", "amount": "100 ml"},
          {"name": "Baking powder", "amount": "5 g"},
          {"name": "Salt", "amount": "a pinch"},
          {"name": "Water", "amount": "as needed"},
        ],
        "steps": [
          "Preheat the oven to 180°C (356°F) and grease a baking pan.",
          "Mix flour and baking powder in a bowl.",
          "Beat butter and sugar until creamy, then add eggs one by one.",
          "Add milk and dry ingredients; mix until smooth.",
          "Pour into the pan and bake for 25–30 minutes.",
        ],
        "imageAsset": "", // optional: e.g. "assets/images/chocolate_peanut.jpg"
        "imageUrl": "",
      },
      {
        "id": "r_pancakes",
        "name": "Pancakes",
        "timeMinutes": 20,
        "description":
            "Classic fluffy pancakes — perfect for breakfast with butter or fruit.",
        "ingredients": [
          {"name": "Milk", "amount": "200 ml"},
          {"name": "Eggs", "amount": "2"},
          {"name": "Flour", "amount": "180 g"},
          {"name": "Butter", "amount": "30 g"},
          {"name": "Salt", "amount": "a pinch"},
        ],
        "steps": [
          "Whisk eggs and milk in a bowl.",
          "Add flour and whisk until smooth.",
          "Heat a pan, add a little butter.",
          "Cook pancakes on both sides until golden.",
        ],
        "imageAsset": "",
        "imageUrl": "",
      },
      {
        "id": "r_tomato_pasta",
        "name": "Tomato Basil Pasta",
        "timeMinutes": 25,
        "description":
            "Simple pasta with tomatoes and basil — quick, fresh, and comforting.",
        "ingredients": [
          {"name": "Pasta", "amount": "200 g"},
          {"name": "Tomato", "amount": "2"},
          {"name": "Basil", "amount": "a handful"},
          {"name": "Butter", "amount": "20 g"},
          {"name": "Salt", "amount": "to taste"},
          {"name": "Water", "amount": "for boiling"},
        ],
        "steps": [
          "Boil pasta in salted water.",
          "Prepare tomatoes and basil.",
          "Mix pasta with butter, tomatoes, and basil.",
        ],
        "imageAsset": "",
        "imageUrl": "",
      },
    ];

    for (final r in demo) {
      _recipesBox.add(jsonEncode(r));
    }
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

  /// Parse recipe JSON string from Hive into Recipe model.
  Recipe _parseRecipe(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;

    final ingredientsJson = (map['ingredients'] as List? ?? const []);
    final ingredients = ingredientsJson.map((e) {
      final m = e as Map<String, dynamic>;
      return RecipeIngredient(
        name: (m['name'] ?? '').toString(),
        amount: (m['amount'] ?? '').toString(),
      );
    }).toList();

    final stepsRaw = map['steps'];
    final steps = (stepsRaw is List)
        ? stepsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Recipe(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      timeMinutes: int.tryParse((map['timeMinutes'] ?? 0).toString()) ?? 0,
      description: (map['description'] ?? '').toString(),
      ingredients: ingredients,
      steps: steps,
      imageAsset: (map['imageAsset'] ?? '').toString().isEmpty
          ? null
          : (map['imageAsset'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString().isEmpty
          ? null
          : (map['imageUrl'] ?? '').toString(),
    );
  }

  /// Load all recipes from Hive.
  List<Recipe> _loadAllRecipes() {
    final list = <Recipe>[];
    for (var i = 0; i < _recipesBox.length; i++) {
      final raw = _recipesBox.getAt(i);
      if (raw == null) continue;
      list.add(_parseRecipe(raw));
    }
    return list;
  }

  /// Compute match (have/missing) for a recipe based on current fridge ingredients.
  /// - ignores salt/pepper/water completely
  _RecipeMatch _matchRecipe(Recipe recipe, Set<String> userIngredientsLower) {
    final have = <String>[];
    final missing = <String>[];

    // Use ingredient names for matching (case-insensitive).
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
        child: ValueListenableBuilder(
          valueListenable: _ingredientsBox.listenable(),
          builder: (context, Box<String> _, __) {
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
        ),
      ),
    );
  }
}

/// Recipe match info used for UI.
class _RecipeMatch {
  final Recipe recipe;
  final List<String> have;    // lowercased
  final List<String> missing; // lowercased

  _RecipeMatch({
    required this.recipe,
    required this.have,
    required this.missing,
  });
}

/// Card UI (similar to your earlier version):
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
