import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';

/// Recipe Details screen:
/// - Keep original typography (same font sizes/weights as your code)
/// - Ingredients card EXACT like reference (beige header + white rows + border)
/// - Ingredient icon tiles (from assets/icons/ingredients)
/// - NO missing / NO red / NO X
/// - salt/pepper/water are displayed normally
/// - Steps are rendered as "Step 1/2/3"
class RecipeDetailsScreen extends StatefulWidget {
  final Recipe recipe;

  /// Keep params to avoid breaking other places in your app
  final List<String> haveIngredientsLower;
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

  @override
  void initState() {
    super.initState();
    _favoritesBox = Hive.box<String>('favoritesBox');
  }

  bool get _isBookmarked => _favoritesBox.containsKey(widget.recipe.id);

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await _favoritesBox.delete(widget.recipe.id);
    } else {
      await _favoritesBox.put(widget.recipe.id, widget.recipe.id);
    }
    setState(() {});
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
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   softWrap: false,
                   style: const TextStyle(
                   fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                     ),
                     ),
                  const SizedBox(height: 8),

                  // Time
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: Color (0xFFD8CFC7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${recipe.timeMinutes} min',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    recipe.description,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),

                  const SizedBox(height: 18),

                  
                  _IngredientsCardExactLikeReference(
                    ingredients: recipe.ingredients,
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

/// - Amount column not pinned hard right 
class _IngredientsCardExactLikeReference extends StatelessWidget {
  final List<RecipeIngredient> ingredients;

  const _IngredientsCardExactLikeReference({
    required this.ingredients,
  });

  String _normalize(String s) => s.trim().toLowerCase();

  String? _iconFor(String name) {
    final key = _normalize(name);

    const map = <String, String>{
      'spaghetti': 'assets/icons/ingredients/spaghetti.png',
      'egg': 'assets/icons/ingredients/egg.png',
      'eggs': 'assets/icons/ingredients/egg.png',
      'bacon': 'assets/icons/ingredients/bacon.png',
      'diced bacon': 'assets/icons/ingredients/bacon.png',
      'parmesan': 'assets/icons/ingredients/cheese.png',
      'grated parmesan': 'assets/icons/ingredients/cheese.png',
      'cheese': 'assets/icons/ingredients/cheese.png',
      'salt': 'assets/icons/ingredients/salt.png',
      'pepper': 'assets/icons/ingredients/pepper.png',
    };

    return map[key];
  }

  @override
  Widget build(BuildContext context) {
    // Reference-like palette
    const border = Color(0x22_000000);
    const headerBg = Color(0xFFFBF6F2);
    const rowBg = Colors.white;
    const divider = Color(0x14_000000);
    const iconTileBg = Color(0xFFFDF9F7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            // HEADER (beige)
            Container(
              color: headerBg,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: LayoutBuilder(
                builder: (context, c) {
                  // Amount is slightly towards center
                  final amountW = c.maxWidth * 0.36;
                  final leftW = c.maxWidth - amountW;

                  return Row(
                    children: [
                      SizedBox(
                        width: leftW,
                        child: const Text(
                          'Ingredients',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: amountW,
                        child: const Text(
                          'Amount',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ROWS (white)
            Container(
              color: rowBg,
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: LayoutBuilder(
                builder: (context, c) {
                  final amountW = c.maxWidth * 0.36;
                  final leftW = c.maxWidth - amountW;

                  return Column(
                    children: [
                      for (int i = 0; i < ingredients.length; i++) ...[
                        if (i != 0) const Divider(height: 1, color: divider),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              // Icon tile
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: iconTileBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0x11_000000)),
                                ),
                                child: Center(
                                  child: Builder(
                                    builder: (_) {
                                      final iconPath = _iconFor(ingredients[i].name);
                                      return iconPath != null
                                          ? Image.asset(iconPath, width: 18, height: 18)
                                          : const Icon(Icons.restaurant,
                                              size: 18, color: Colors.black45);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name 
                              SizedBox(
                                width: leftW - 48, // icon + spacing
                                child: Text(
                                  ingredients[i].name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Amount
                              SizedBox(
                                width: amountW,
                                child: Text(
                                  ingredients[i].amount,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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