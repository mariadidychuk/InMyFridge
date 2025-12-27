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

  // Ingredients ignored for matching (never treated as have/missing)
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

  // Finds a recipe JSON map by recipe id inside recipesBox
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

  // Returns favorite recipe IDs (supports both keys-based and values-based storage)
  List<String> _favoriteIds(Box<String> favBox) {
    final values = favBox.values.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (values.isNotEmpty) return values;
    return favBox.keys.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  // Returns user's available ingredients (lowercase)
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

  // Returns ingredients missing for a given recipe
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

  // Returns ingredients already available for a given recipe
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

  // Extracts image path from recipe JSON:
  // - imageAsset for local images
  String? _imageFromMap(Map<String, dynamic> map) {
    final asset = (map['imageAsset'] ?? '').toString().trim();
    if (asset.isNotEmpty) return asset;

    final url = (map['imageUrl'] ?? '').toString().trim();
    if (url.isNotEmpty) return url;

    return null;
  }

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
              // image
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

              // smoother gradient + title
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
                      // More stops = smoother, less “hard line”
                      stops: [0.0, 0.45, 0.75, 1.0],
                      colors: [
                        Color(0x00000000), // transparent
                        Color(0x24000000), // very light
                        Color(0x4D000000), // medium
                        Color(0x80000000), // dark but not too heavy
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
          valueListenable: _favoritesBox.listenable(),
          builder: (context, Box<String> favBox, _) {
            final ids = _favoriteIds(favBox);

            if (ids.isEmpty) {
              return const Center(child: Text('No bookmarks yet.'));
            }

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

            final q = _searchCtrl.text.trim().toLowerCase();
            final shown = q.isEmpty
                ? items
                : items.where((x) => x.recipe.name.toLowerCase().contains(q)).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                        final haveSet = _userIngredientsLower(ingredientsBox);
                        final missing = _missingForRecipe(recipe, haveSet);
                        final haveList = _haveForRecipe(recipe, haveSet);

                        final img = _imageFromMap(map);

                        return _imageCard(
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