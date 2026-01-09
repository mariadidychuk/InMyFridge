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

  static const Color _bg = Color(0xFFFFF6F2);

  // These ingredients are excluded from matching logic (never "have" or "missing")
  static const Set<String> _ignored = {'salt', 'pepper', 'water'};

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _favoritesBox = Hive.box<String>('favoritesBox');
    _recipesBox = Hive.box<String>('recipesBox');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Reads recipesBox and returns the recipe map for a given recipeId (if found)
  Map<String, dynamic>? _findRecipeMapById(String id) {
    for (int i = 0; i < _recipesBox.length; i++) {
      final raw = _recipesBox.getAt(i);
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if ((map['id'] ?? '').toString() == id) return map;
      } catch (_) {}
    }
    return null;
  }

  // Returns a list of saved recipe IDs.
  // Supports both styles:
  // - values-based storage (favBox.values)
  // - keys-based storage (favBox.keys)
  List<String> _favoriteIds(Box<String> favBox) {
    final values =
        favBox.values.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (values.isNotEmpty) return values;
    return favBox.keys.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  // Removes a bookmark.
  // Works for both storage variants (ID as key OR ID as value).
  Future<void> _removeFavorite(String recipeId) async {
    // Keys-based: key == recipeId
    if (_favoritesBox.containsKey(recipeId)) {
      await _favoritesBox.delete(recipeId);
      return;
    }

    // Values-based: find the key that stores this value and delete it
    dynamic keyToDelete;
    for (final entry in _favoritesBox.toMap().entries) {
      if (entry.value.toString() == recipeId) {
        keyToDelete = entry.key;
        break;
      }
    }
    if (keyToDelete != null) {
      await _favoritesBox.delete(keyToDelete);
    }
  }

  // Restores a bookmark after Undo.
  // We try "put" first (key-value), fallback to "add" (list-style).
  Future<void> _addFavoriteBack(String recipeId) async {
    if (_favoritesBox.containsKey(recipeId)) return;

    try {
      await _favoritesBox.put(recipeId, recipeId);
    } catch (_) {
      await _favoritesBox.add(recipeId);
    }
  }

  // Reads user's ingredients from ingredientsBox as lowercase Set for matching
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

  // Computes missing ingredient names for a recipe (ignored items are skipped)
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

  // Computes available ingredient names for a recipe (ignored items are skipped)
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

  // Returns the image reference from JSON map:
  // - prefer local asset path (imageAsset)
  // - otherwise use URL (imageUrl)
  String? _imageFromMap(Map<String, dynamic> map) {
    final asset = (map['imageAsset'] ?? '').toString().trim();
    if (asset.isNotEmpty) return asset;

    final url = (map['imageUrl'] ?? '').toString().trim();
    if (url.isNotEmpty) return url;

    return null;
  }

  // Simple confirmation dialog before removing a bookmark by swipe
  Future<bool> _confirmRemove(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove bookmark?'),
        content: const Text('This recipe will be removed from your bookmarks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // Background shown when the user swipes a card to remove it
  Widget _dismissBg() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete_outline, color: Colors.red),
          SizedBox(width: 8),
          Text(
            'Remove',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // SnackBar with Undo option after removing a bookmark
  void _showUndoSnack({
    required String recipeId,
    required String title,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$title" removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _addFavoriteBack(recipeId),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Card widget used in the bookmarks list (image + title overlay)
  Widget _imageCard({
    required String? img,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main image: asset preferred, otherwise network, otherwise placeholder
              if (img != null && img.trim().isNotEmpty && img.startsWith('assets/'))
                Image.asset(
                  img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEFE7E3)),
                )
              else if (img != null && img.trim().isNotEmpty)
                Image.network(
                  img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEFE7E3)),
                )
              else
                Container(
                  color: const Color(0xFFEFE7E3),
                  child: const Center(
                    child: Icon(Icons.image_outlined, size: 42, color: Colors.black38),
                  ),
                ),

              // Title overlay with gradient for readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 44, 14, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 0.75, 1.0],
                      colors: [
                        Color(0x00000000),
                        Color(0x24000000),
                        Color(0x4D000000),
                        Color(0x80000000),
                      ],
                    ),
                  ),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsBox = Hive.box<String>('ingredientsBox');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Bookmarks', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          // Rebuild when favoritesBox changes (add/remove bookmark)
          valueListenable: _favoritesBox.listenable(),
          builder: (context, Box<String> favBox, _) {
            final ids = _favoriteIds(favBox);

            if (ids.isEmpty) {
              return const Center(child: Text('No bookmarks yet.'));
            }

            // Resolve saved IDs -> full Recipe objects from recipesBox
            final items = <({Recipe recipe, Map<String, dynamic> map})>[];

            for (final id in ids) {
              final map = _findRecipeMapById(id);
              if (map == null) continue;
              try {
                final r = Recipe.fromMap(map);
                items.add((recipe: r, map: map));
              } catch (_) {}
            }

            if (items.isEmpty) {
              return const Center(child: Text('Bookmarks exist, but recipes data not found.'));
            }

            // Simple name search within bookmarks
            final q = _searchCtrl.text.trim().toLowerCase();
            final shown = q.isEmpty
                ? items
                : items.where((x) => x.recipe.name.toLowerCase().contains(q)).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Container(
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
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (shown.isEmpty)
                  const Text('No matches.', style: TextStyle(color: Colors.black54))
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final recipe = shown[index].recipe;
                        final map = shown[index].map;

                        // Compute have/missing for details screen preview logic
                        final haveSet = _userIngredientsLower(ingredientsBox);
                        final missing = _missingForRecipe(recipe, haveSet);
                        final haveList = _haveForRecipe(recipe, haveSet);

                        final img = _imageFromMap(map);

                        return Dismissible(
                          key: ValueKey('bm_${recipe.id}'),
                          direction: DismissDirection.endToStart,
                          background: _dismissBg(),
                          confirmDismiss: (_) => _confirmRemove(context),
                          onDismissed: (_) async {
                            await _removeFavorite(recipe.id);
                            _showUndoSnack(recipeId: recipe.id, title: recipe.name);
                          },
                          child: _imageCard(
                            img: img,
                            title: recipe.name,
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
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
