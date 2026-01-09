import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/recipe.dart';
import 'recipe_details_screen.dart';

/// Screen with two list modes:
/// - All Recipes (A–Z, search only)
/// - Recipes for you (filtered/sorted by fridge ingredients + matching UI)
///
/// Matching notes:
/// - salt/pepper/water are ignored in matching and sorting
/// - they can still appear in recipe data and are shown in details
class RecipesScreen extends StatefulWidget {
  final bool filterByFridge;

  const RecipesScreen({super.key, this.filterByFridge = false});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late final Box<String> _ingredientsBox;
  late final Box<String> _recipesBox;

  /// Ingredients that are not counted for "have/missing".
  static const Set<String> _ignored = {'salt', 'pepper', 'water'};

  /// Used for filtering the list by recipe name.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ingredientsBox = Hive.box<String>('ingredientsBox');
    _recipesBox = Hive.box<String>('recipesBox');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalize(String s) => s.trim().toLowerCase();

  /// Reads all ingredients from the fridge box and normalizes them.
  Set<String> _userIngredientsLower() {
    final result = <String>{};
    for (var i = 0; i < _ingredientsBox.length; i++) {
      final v = _normalize(_ingredientsBox.getAt(i) ?? '');
      if (v.isEmpty) continue;
      result.add(v);
    }
    return result;
  }

  /// Parses a JSON string (Hive storage) into the Recipe model.
  Recipe _parseRecipe(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return Recipe.fromMap(map);
  }

  /// Loads all recipes from Hive.
  /// Recipes are stored as JSON strings in recipesBox.
  List<Recipe> _loadAllRecipes() {
    return _recipesBox.values
        .where((raw) => raw.trim().isNotEmpty)
        .map(_parseRecipe)
        .toList();
  }

  /// Creates a match object (have/missing) for one recipe based on fridge contents.
  /// Ignored ingredients are skipped completely.
  _RecipeMatch _matchRecipe(Recipe recipe, Set<String> userIngredientsLower) {
    final have = <String>[];
    final missing = <String>[];

    for (final ing in recipe.ingredients) {
      final nameLower = _normalize(ing.name);
      if (nameLower.isEmpty) continue;

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

  /// Builds the list that is shown on the screen, depending on the mode.
  /// - All Recipes: alphabetical
  /// - Recipes for you: only recipes with at least one match, sorted by match quality
  List<_RecipeMatch> _buildDisplayList() {
    final user = _userIngredientsLower();
    final all = _loadAllRecipes();

    var matches = all.map((r) => _matchRecipe(r, user)).toList();

    if (!widget.filterByFridge) {
      // All Recipes: simple A–Z sorting.
      matches.sort(
        (a, b) => a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase()),
      );
      return matches;
    }

    // Recipes for you: show only recipes that match at least one fridge ingredient.
    matches = matches.where((m) => m.have.isNotEmpty).toList();

    // Sort by: fewer missing -> more have -> name A–Z.
    matches.sort((a, b) {
      final missingDiff = a.missing.length.compareTo(b.missing.length);
      if (missingDiff != 0) return missingDiff;

      final haveDiff = b.have.length.compareTo(a.have.length);
      if (haveDiff != 0) return haveDiff;

      return a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase());
    });

    return matches;
  }

  /// Filters a prepared list by the search query (recipe name).
  List<_RecipeMatch> _applySearch(List<_RecipeMatch> input) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return input;

    return input.where((m) {
      final name = m.recipe.name.toLowerCase();
      return name.contains(q);
    }).toList();
  }

  /// Reusable search bar widget (used in both modes).
  Widget _searchBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.black54),
              onPressed: () {
                _searchCtrl.clear();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF6F2);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.filterByFridge ? 'Recipes for you' : 'All Recipes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: _recipesBox.listenable(),
          builder: (context, Box<String> __, ___) {
            return ValueListenableBuilder(
              valueListenable: _ingredientsBox.listenable(),
              builder: (context, Box<String> _, ____) {
                final matches = _buildDisplayList();
                final shown = _applySearch(matches);

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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _searchBar(),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      const Text('No matches.', style: TextStyle(color: Colors.black54))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final m = shown[index];

                            return _RecipeRowTile(
                              match: m,
                              showMatchingUI: widget.filterByFridge,
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
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RecipeMatch {
  final Recipe recipe;
  final List<String> have;
  final List<String> missing;

  _RecipeMatch({
    required this.recipe,
    required this.have,
    required this.missing,
  });
}

class _RecipeRowTile extends StatelessWidget {
  final _RecipeMatch match;
  final VoidCallback onTap;
  final bool showMatchingUI;

  const _RecipeRowTile({
    required this.match,
    required this.onTap,
    required this.showMatchingUI,
  });

  @override
  Widget build(BuildContext context) {
    const cardRadius = 18.0;
    const haveColor = Color(0xFF2E7D32);
    const missingColor = Color(0xFFC62828);

    final total = match.have.length + match.missing.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(cardRadius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RecipeThumb(
              imageAsset: match.recipe.imageAsset,
              imageUrl: match.recipe.imageUrl,
              width: 68,
              height: 48,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe title (single line to keep row height stable)
                  Text(
                    match.recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                  if (showMatchingUI) ...[
                    const SizedBox(height: 10),
                    if (total > 0)
                      Text(
                        'You have ${match.have.length} of $total ingredients',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    const SizedBox(height: 6),

                    // Missing list (shown only if there are missing ingredients)
                    if (match.missing.isNotEmpty) ...[
                      const Text(
                        'Missing:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: match.missing
                            .map((m) => _Chip(label: m, color: missingColor))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Have list (shown only if there are matched ingredients)
                    if (match.have.isNotEmpty) ...[
                      const Text(
                        'You have:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: match.have
                            .map((h) => _Chip(label: h, color: haveColor))
                            .toList(),
                      ),
                    ],
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

class _RecipeThumb extends StatelessWidget {
  final String? imageAsset;
  final String? imageUrl;
  final double width;
  final double height;
  final double radius;

  const _RecipeThumb({
    required this.imageAsset,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final hasAsset = imageAsset != null && imageAsset!.trim().isNotEmpty;
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    // Try asset first, then URL, otherwise fallback placeholder.
    Widget image;
    if (hasAsset) {
      image = Image.asset(
        imageAsset!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (hasUrl) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFF4ECE8),
        alignment: Alignment.center,
        child: image,
      ),
    );
  }

  Widget _placeholder() {
    return const Icon(Icons.image_outlined, size: 20, color: Colors.black38);
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
