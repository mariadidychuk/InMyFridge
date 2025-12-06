import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// RecipesScreen
/// - if filterByFridge == false  -> show all recipes
/// - if filterByFridge == true   -> show recipes sorted by how well they match
///                                 current fridge ingredients
///
/// Data assumptions:
///  - 'ingredientsBox'  : Box<String> with user ingredients
///  - 'recipesBox'      : Box<String> where each value is a JSON string:
///        {"id":"r_001","name":"Pancakes","time":"20 min","ingredients":["milk","egg","flour","butter"]}
///
///  - We ignore "salt", "pepper", "water" when calculating missing ingredients
///    (we assume the user always has them).
class RecipesScreen extends StatefulWidget {
  final bool filterByFridge;

  const RecipesScreen({super.key, this.filterByFridge = false});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late final Box<String> _ingredientsBox;
  late final Box<String> _recipesBox;

  /// Ingredients we always assume the user has.
  static const Set<String> _assumed = {'salt', 'pepper', 'water'};

  @override
  void initState() {
    super.initState();
    _ingredientsBox = Hive.box<String>('ingredientsBox');
    _recipesBox = Hive.box<String>('recipesBox');

    _seedDemoRecipesIfEmpty(); // temporary demo data for development
  }

  /// Temporary demo recipes so that the UI works before you connect a real DB.
  void _seedDemoRecipesIfEmpty() {
    if (_recipesBox.isNotEmpty) return;

    final List<Map<String, dynamic>> demo = [
      {
        "id": "r_001",
        "name": "Pancakes",
        "time": "20 min",
        "ingredients": ["milk", "egg", "flour", "butter", "salt"],
      },
      {
        "id": "r_002",
        "name": "Tomato Basil Pasta",
        "time": "25 min",
        "ingredients": ["pasta", "tomato", "basil", "butter", "salt", "water"],
      },
      {
        "id": "r_003",
        "name": "Banana Smoothie",
        "time": "5 min",
        "ingredients": ["banana", "milk", "water"],
      },
      {
        "id": "r_004",
        "name": "Broccoli Soup",
        "time": "30 min",
        "ingredients": ["broccoli", "milk", "water", "salt", "pepper"],
      },
      {
        "id": "r_005",
        "name": "Garlic Bread",
        "time": "15 min",
        "ingredients": ["bread", "butter", "salt"],
      },
    ];

    for (final r in demo) {
      _recipesBox.add(jsonEncode(r));
    }
  }

  /// Convert current user ingredients into a lowercase Set,
  /// ignoring assumed ingredients (salt, pepper, water).
  Set<String> _userIngredientsLower() {
    final result = <String>{};
    for (var i = 0; i < _ingredientsBox.length; i++) {
      final value = (_ingredientsBox.getAt(i) ?? '').trim().toLowerCase();
      if (value.isEmpty) continue;
      if (_assumed.contains(value)) continue; // ignore assumed ones
      result.add(value);
    }
    return result;
  }

  /// Parse one recipe JSON string into a typed model.
  _Recipe _parseRecipe(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return _Recipe(
      id: map['id'] as String,
      name: map['name'] as String,
      time: map['time'] as String? ?? '',
      ingredients: List<String>.from(map['ingredients'] as List),
    );
  }

  /// Load all recipes from recipesBox.
  List<_Recipe> _loadAllRecipes() {
    final list = <_Recipe>[];
    for (var i = 0; i < _recipesBox.length; i++) {
      final raw = _recipesBox.getAt(i);
      if (raw == null) continue;
      list.add(_parseRecipe(raw));
    }
    return list;
  }

  /// Compute match info (have/missing) for each recipe based on current fridge.
  List<_RecipeMatch> _buildMatches() {
    final have = _userIngredientsLower();
    final all = _loadAllRecipes();

    final matches = <_RecipeMatch>[];

    for (final recipe in all) {
      // Normalize recipe ingredients and ignore assumed ones.
      final normalized = recipe.ingredients
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty && !_assumed.contains(e))
          .toList();

      final haveSet = <String>{};
      final missingSet = <String>{};

      for (final ing in normalized) {
        if (have.contains(ing)) {
          haveSet.add(ing);
        } else {
          missingSet.add(ing);
        }
      }

      matches.add(
        _RecipeMatch(
          recipe: recipe,
          have: haveSet.toList()..sort(),
          missing: missingSet.toList()..sort(),
        ),
      );
    }

    return matches;
  }

  /// Build final list to show on screen depending on filterByFridge flag.
  List<_RecipeMatch> _buildDisplayList() {
    final matches = _buildMatches();

    if (!widget.filterByFridge) {
      // Bottom tab "Recipes": show ALL recipes, sorted by name.
      matches.sort(
        (a, b) =>
            a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase()),
      );
      return matches;
    }

    // "See Recipes" from Fridge:
    // sort by:
    //  1) missing count ascending
    //  2) have count descending
    //  3) name
    matches.sort((a, b) {
      final missingDiff =
          a.missing.length.compareTo(b.missing.length); // fewer missing first
      if (missingDiff != 0) return missingDiff;

      final haveDiff =
          b.have.length.compareTo(a.have.length); // more have first
      if (haveDiff != 0) return haveDiff;

      return a.recipe.name
          .toLowerCase()
          .compareTo(b.recipe.name.toLowerCase());
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
          // Rebuild when ingredients change -> matching changes
          valueListenable: _ingredientsBox.listenable(),
          builder: (context, Box<String> _, __) {
            final matches = _buildDisplayList();

            if (matches.isEmpty) {
              return _EmptyState(filterByFridge: widget.filterByFridge);
            }

            return ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final m = matches[index];
                return _RecipeCard(match: m);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Empty state text depending on where user came from.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filterByFridge});

  final bool filterByFridge;

  @override
  Widget build(BuildContext context) {
    final text = filterByFridge
        ? 'No recipes match your current ingredients yet.\nTry adding more items in your Fridge.'
        : 'No recipes available yet.\nPlease add recipes data to the app.';
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// UI card for one recipe with "have" / "missing" ingredients.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.match});

  final _RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFD87C5A);
    const haveColor = Color(0xFF2E7D32); // green-ish
    const missingColor = Color(0xFFC62828); // red-ish

    final recipe = match.recipe;
    final totalCount = match.have.length + match.missing.length;

    return Container(
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
                // Title + time
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (recipe.time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    recipe.time,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],

                const SizedBox(height: 8),

                // Summary line "You have X of Y ingredients"
                if (totalCount > 0)
                  Text(
                    'You have ${match.have.length} of $totalCount ingredients',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),

                const SizedBox(height: 6),

                // Have list (green)
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
                        .map(
                          (h) => _IngredientChip(
                            label: h,
                            color: haveColor,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                ],

                // Missing list (red)
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
                        .map(
                          (m) => _IngredientChip(
                            label: m,
                            color: missingColor,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small colored chip to display one ingredient.
class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label, required this.color});

  final String label;
  final Color color;

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

/// Simple data class for recipe data.
class _Recipe {
  final String id;
  final String name;
  final String time;
  final List<String> ingredients;

  _Recipe({
    required this.id,
    required this.name,
    required this.time,
    required this.ingredients,
  });
}

/// Data class combining a recipe and how it matches current fridge.
class _RecipeMatch {
  final _Recipe recipe;
  final List<String> have;
  final List<String> missing;

  _RecipeMatch({
    required this.recipe,
    required this.have,
    required this.missing,
  });
}
