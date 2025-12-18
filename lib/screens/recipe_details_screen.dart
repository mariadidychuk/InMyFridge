import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';

/// Recipe Details screen:
/// - Ingredient/Amount columns aligned like in Figma
/// - Missing X icon only for missing ingredients
/// - salt/pepper/water are displayed if present, but are NEVER marked have/missing
/// - Steps are rendered as "Step 1/2/3"
class RecipeDetailsScreen extends StatefulWidget {
  final Recipe recipe;

  /// Lowercased ingredient names that user has (matching-only set)
  final List<String> haveIngredientsLower;

  /// Lowercased ingredient names that are missing (matching-only set)
  final List<String> missingIngredientsLower;

  const RecipeDetailsScreen({
    super.key,
    required this.recipe,
    required this.haveIngredientsLower,
    required this.missingIngredientsLower,
  });

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  late final Box<String> _favoritesBox;

  /// Ingredients we always ignore for matching (never have/missing).
  static const Set<String> _ignored = {'salt', 'pepper', 'water'};

  @override
  void initState() {
    super.initState();
    // Get an already opened Hive box (opened in main.dart)
    _favoritesBox = Hive.box<String>('favoritesBox');
  }

  // True if this recipe ID is stored in favorites
  bool get _isBookmarked => _favoritesBox.containsKey(widget.recipe.id);

  // Toggle bookmark state (add/remove by recipe.id)
  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await _favoritesBox.delete(widget.recipe.id);
    } else {
      // Store recipe id as both key and value (simple "set" behavior)
      await _favoritesBox.put(widget.recipe.id, widget.recipe.id);
    }
    setState(() {}); // Refresh AppBar icon immediately
  }

  String _normalize(String s) => s.trim().toLowerCase();

  bool _isIgnored(String name) => _ignored.contains(_normalize(name));

  bool _isMissing(String ingredientName) {
    final nameLower = _normalize(ingredientName);
    if (_ignored.contains(nameLower)) return false; // never missing
    return widget.missingIngredientsLower.contains(nameLower);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF6F2);
    const cardRadius = 20.0;

    final recipe = widget.recipe;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? const Color(0xFFD87C5A) : null,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderImage(
              imageAsset: recipe.imageAsset,
              imageUrl: recipe.imageUrl,
              radius: cardRadius,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(cardRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text(
                        '${recipe.timeMinutes} min',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description (dynamic per recipe)
                  Text(
                    recipe.description,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Ingredients:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  _IngredientsMidAligned(
                    ingredients: recipe.ingredients,
                    isMissing: _isMissing,
                    isIgnored: _isIgnored,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Instructions:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  _StepsNumbered(steps: recipe.steps),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header image supports asset or url; fallback placeholder.
class _HeaderImage extends StatelessWidget {
  final String? imageAsset;
  final String? imageUrl;
  final double radius;

  const _HeaderImage({
    required this.imageAsset,
    required this.imageUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final hasAsset = imageAsset != null && imageAsset!.isNotEmpty;
    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: hasAsset
            ? Image.asset(imageAsset!, fit: BoxFit.cover)
            : hasUrl
                ? Image.network(imageUrl!, fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFFEFE7E3),
                    child: const Center(
                      child: Icon(Icons.image_outlined, size: 42, color: Colors.black38),
                    ),
                  ),
      ),
    );
  }
}

/// Ingredients table:
/// - Ingredient column on the left
/// - Amount column starts closer to center (not pinned to the right)
/// - Missing X icon only for missing items
/// - Ignored items (salt/pepper/water): shown normally, no status icon
class _IngredientsMidAligned extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final bool Function(String ingredientName) isMissing;
  final bool Function(String ingredientName) isIgnored;

  const _IngredientsMidAligned({
    required this.ingredients,
    required this.isMissing,
    required this.isIgnored,
  });

  @override
  Widget build(BuildContext context) {
    const missingColor = Color(0xFFC62828);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Column proportions like in Figma:
        // Ingredient is wider, Amount starts closer to center
        final ingredientWidth = constraints.maxWidth * 0.65;
        final amountWidth = constraints.maxWidth * 0.35;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                SizedBox(
                  width: ingredientWidth,
                  child: const Text(
                    'Ingredient',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: amountWidth,
                  child: const Text(
                    'Amount',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            for (int i = 0; i < ingredients.length; i++) ...[
              Builder(
                builder: (context) {
                  final ing = ingredients[i];
                  final missing = isMissing(ing.name);
                  final ignored = isIgnored(ing.name);

                  // Show X icon only for missing (not for salt/pepper/water)
                  final showMissingIcon = missing && !ignored;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Fixed icon slot to keep alignment
                        SizedBox(
                          width: 22,
                          child: showMissingIcon
                              ? const Icon(Icons.close, size: 16, color: missingColor)
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),

                        // Ingredient column (left)
                        SizedBox(
                          width: ingredientWidth - 30, // icon + spacing
                          child: Text(
                            ing.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Amount column (NOT right-aligned)
                        SizedBox(
                          width: amountWidth,
                          child: Text(
                            ing.amount,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (i != ingredients.length - 1) const Divider(height: 14),
            ],
          ],
        );
      },
    );
  }
}

/// Steps list as "Step 1/2/3".
class _StepsNumbered extends StatelessWidget {
  final List<String> steps;

  const _StepsNumbered({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text(
        'No instructions yet.',
        style: TextStyle(fontSize: 13, height: 1.35),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Text(
            'Step ${i + 1}:',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            steps[i],
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
