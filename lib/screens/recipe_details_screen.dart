import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';

/// Recipe details screen.
/// Shows one recipe with image, ingredients, steps and actions (bookmark + planning).
class RecipeDetailsScreen extends StatefulWidget {
  final Recipe recipe;

  /// These lists are passed from other screens (e.g. matching logic).
  /// They are kept here to keep the navigation/API stable across the app.
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

  // Main accent color used across the UI
  static const Color _accent = Color(0xFFD87C5A);

  @override
  void initState() {
    super.initState();
    // favoritesBox stores recipe IDs (bookmark feature)
    _favoritesBox = Hive.box<String>('favoritesBox');
  }

  // True if this recipe is currently bookmarked
  bool get _isSaved => _favoritesBox.containsKey(widget.recipe.id);

  // Adds/removes the recipe ID in favoritesBox and refreshes the AppBar icon
  Future<void> _toggleSave() async {
    if (_isSaved) {
      await _favoritesBox.delete(widget.recipe.id);
    } else {
      await _favoritesBox.put(widget.recipe.id, widget.recipe.id);
    }
    if (mounted) setState(() {});
  }

  /// Adds this recipe to the selected day in calendarBox.
  /// Storage format:
  /// key   = "YYYY-MM-DD"
  /// value = JSON encoded List<String> (recipeIds)
  Future<void> _planRecipeForDay(DateTime day) async {
    final calendarBox = Hive.box<String>('calendarBox');

    final dateKey =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    final raw = calendarBox.get(dateKey);
    final List<dynamic> list =
        raw == null ? <dynamic>[] : (jsonDecode(raw) as List<dynamic>);

    final ids = list.map((e) => e.toString()).toList();

    // Avoid duplicates (one recipe should appear only once per day)
    if (!ids.contains(widget.recipe.id)) {
      ids.add(widget.recipe.id);
      await calendarBox.put(dateKey, jsonEncode(ids));
    }

    if (!mounted) return;

    // Simple confirmation feedback for MVP
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Planned for $dateKey'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Opens a date picker and schedules the recipe for the selected date.
  /// The dialog is themed to match the app colors.
  Future<void> _openPlanPicker() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent, // selected day highlight
              onPrimary: Colors.white,
              surface: Color(0xFFFFF6F2), // dialog background
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: const Color(0xFFFFF6F2),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _accent,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _planRecipeForDay(picked);
    }
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
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Action: plan this recipe for a specific day
          IconButton(
            tooltip: 'Plan recipe',
            onPressed: _openPlanPicker,
            icon: const Icon(
              Icons.calendar_month,
              color: _accent,
            ),
          ),

          // Action: toggle bookmark state
          IconButton(
            tooltip: _isSaved ? 'Remove bookmark' : 'Save',
            onPressed: _toggleSave,
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _accent,
            ),
          ),
          const SizedBox(width: 6),
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
                  // Recipe title (single line for stable layout)
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

                  // Cooking time row
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 18, color: Color(0xFFD8CFC7)),
                      const SizedBox(width: 6),
                      Text(
                        '${recipe.timeMinutes} min',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description text
                  Text(
                    recipe.description,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 18),

                  // Ingredients section (card layout with icons)
                  _IngredientsCardExactLikeReference(
                    ingredients: recipe.ingredients,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Instructions:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  // Step list: "Step 1 / Step 2 / ..."
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

/// Header image widget.
/// Supports either a local asset image or a network image.
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
                      child: Icon(Icons.image_outlined,
                          size: 42, color: Colors.black38),
                    ),
                  ),
      ),
    );
  }
}

/// Ingredients card.
/// Uses a local mapping from ingredient name -> icon asset.
/// If there is no matching icon, a fallback icon is shown.
class _IngredientsCardExactLikeReference extends StatelessWidget {
  final List<RecipeIngredient> ingredients;

  const _IngredientsCardExactLikeReference({required this.ingredients});

  // Normalize ingredient names to make mapping more stable
  String _normalize(String s) => s.trim().toLowerCase();

  // Returns icon asset path for an ingredient name (or null if unknown)
  String? _iconFor(String name) {
    final key = _normalize(name);

    const map = <String, String>{
      // A
      'apple': 'assets/icons/ingredients/apple.png',
      'avocado': 'assets/icons/ingredients/avocado.png',

      // B
      'bacon': 'assets/icons/ingredients/bacon.png',
      'baking powder': 'assets/icons/ingredients/baking powder.png',
      'banana': 'assets/icons/ingredients/banana.png',
      'basil': 'assets/icons/ingredients/basil.png',
      'beetroot (cooked)': 'assets/icons/ingredients/beetroot (cooked).png',
      'berries': 'assets/icons/ingredients/berries.png',
      'bread': 'assets/icons/ingredients/bread.png',
      'broccoli': 'assets/icons/ingredients/broccoli.png',
      'butter': 'assets/icons/ingredients/butter.png',

      // C
      'caesar dressing': 'assets/icons/ingredients/caesar dressing.png',
      'carrot': 'assets/icons/ingredients/carrot.png',
      'celery': 'assets/icons/ingredients/celery.png',
      'cheddar': 'assets/icons/ingredients/cheddar.png',
      'cheese': 'assets/icons/ingredients/cheese.png',
      'cherry tomatoes': 'assets/icons/ingredients/cherry tomatoes.png',
      'chicken': 'assets/icons/ingredients/chicken.png',
      'chicken breast': 'assets/icons/ingredients/chicken breast.png',
      'chicken thighs': 'assets/icons/ingredients/chicken thighs.png',
      'chickpeas': 'assets/icons/ingredients/chickpeas.png',
      'chili powder': 'assets/icons/ingredients/chili powder.png',
      'cinnamon': 'assets/icons/ingredients/cinnamon.png',
      'coconut milk': 'assets/icons/ingredients/coconut milk.png',
      'couscous': 'assets/icons/ingredients/couscous.png',
      'cream': 'assets/icons/ingredients/cream.png',
      'croutons': 'assets/icons/ingredients/croutons.png',
      'cucumber': 'assets/icons/ingredients/cucumber.png',
      'curry powder': 'assets/icons/ingredients/curry powder.png',

      // E
      'egg': 'assets/icons/ingredients/egg.png',
      'eggs': 'assets/icons/ingredients/egg.png',

      // F
      'falafel': 'assets/icons/ingredients/falafel.png',
      'feta': 'assets/icons/ingredients/feta.png',
      'flour': 'assets/icons/ingredients/flour.png',

      // G
      'garlic': 'assets/icons/ingredients/garlic.png',
      'granola': 'assets/icons/ingredients/granola.png',
      'green beans': 'assets/icons/ingredients/green beans.png',
      'ground beef': 'assets/icons/ingredients/ground beef.png',

      // H
      'honey': 'assets/icons/ingredients/honey.png',
      'hummus': 'assets/icons/ingredients/hummus.png',

      // K
      'kidney beans': 'assets/icons/ingredients/kidney beans.png',

      // L
      'lemon': 'assets/icons/ingredients/lemon.png',
      'lemon juice': 'assets/icons/ingredients/lemon juice.png',
      'lentils': 'assets/icons/ingredients/lentils.png',
      'lentils (cooked)': 'assets/icons/ingredients/lentils (cooked).png',
      'lettuce': 'assets/icons/ingredients/lettuce.png',

      // M
      'macaroni': 'assets/icons/ingredients/macaroni.png',
      'mayonnaise': 'assets/icons/ingredients/mayonnaise.png',
      'milk': 'assets/icons/ingredients/milk.png',
      'mozzarella': 'assets/icons/ingredients/mozzarella.png',
      'mushrooms': 'assets/icons/ingredients/mushrooms.png',

      // N
      'noodles': 'assets/icons/ingredients/noodles.png',

      // O
      'oats': 'assets/icons/ingredients/oats.png',
      'oil': 'assets/icons/ingredients/oil.png',
      'olive oil': 'assets/icons/ingredients/olive oil.png',
      'olives': 'assets/icons/ingredients/olives.png',
      'onion': 'assets/icons/ingredients/onion.png',
      'oregano': 'assets/icons/ingredients/oregano.png',

      // P
      'paprika': 'assets/icons/ingredients/paprika.png',
      'parmesan': 'assets/icons/ingredients/parmesan.png',
      'pasta': 'assets/icons/ingredients/pasta.png',
      'peanut butter': 'assets/icons/ingredients/peanut butter.png',
      'peas': 'assets/icons/ingredients/peas.png',
      'pepper': 'assets/icons/ingredients/pepper.png',
      'pesto': 'assets/icons/ingredients/pesto.png',
      'potatoes': 'assets/icons/ingredients/potatoes.png',
      'pumpkin': 'assets/icons/ingredients/pumpkin.png',

      // Q
      'quinoa': 'assets/icons/ingredients/quinoa.png',

      // R
      'red onion': 'assets/icons/ingredients/red onion.png',
      'rice (cooked)': 'assets/icons/ingredients/rice (cooked).png',
      'rice (risotto)': 'assets/icons/ingredients/rice (risotto).png',
      'romaine': 'assets/icons/ingredients/romaine.png',

      // S
      'salmon': 'assets/icons/ingredients/salmon.png',
      'salt': 'assets/icons/ingredients/salt.png',
      'sausages': 'assets/icons/ingredients/sausages.png',
      'shrimp': 'assets/icons/ingredients/shrimp.png',
      'soy sauce': 'assets/icons/ingredients/soy sauce.png',
      'spaghetti': 'assets/icons/ingredients/spaghetti.png',

      // T
      'taco shells': 'assets/icons/ingredients/taco shells.png',
      'tomato': 'assets/icons/ingredients/tomato.png',
      'tomatoes': 'assets/icons/ingredients/tomatoes.png',
      'tomato sauce': 'assets/icons/ingredients/tomato sauce.png',
      'tortilla': 'assets/icons/ingredients/tortilla.png',
      'tuna': 'assets/icons/ingredients/tuna.png',

      // V
      'vegetable broth': 'assets/icons/ingredients/vegetable broth.png',

      // W
      'walnuts': 'assets/icons/ingredients/walnuts.png',
      'water': 'assets/icons/ingredients/water.png',

      // Y
      'yogurt': 'assets/icons/ingredients/yogurt.png',
      'yogurt sauce': 'assets/icons/ingredients/yogurt sauce.png',

      // Z
      'zucchini': 'assets/icons/ingredients/zucchini.png',
    };

    return map[key];
  }

  @override
  Widget build(BuildContext context) {
    const border = Color(0x22000000);
    const headerBg = Color(0xFFFBF6F2);
    const rowBg = Colors.white;
    const divider = Color(0x14000000);
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
            // Header row (column labels)
            Container(
              color: headerBg,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: LayoutBuilder(
                builder: (context, c) {
                  final amountW = c.maxWidth * 0.36;
                  final leftW = c.maxWidth - amountW;

                  return Row(
                    children: [
                      SizedBox(
                        width: leftW,
                        child: const Text(
                          'Ingredients',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: amountW,
                        child: const Text(
                          'Amount',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Ingredient rows
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
                              // Small tile with ingredient icon (or fallback)
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: iconTileBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0x11000000)),
                                ),
                                child: Center(
                                  child: Builder(
                                    builder: (_) {
                                      final iconPath =
                                          _iconFor(ingredients[i].name);
                                      return iconPath != null
                                          ? Image.asset(iconPath,
                                              width: 18, height: 18)
                                          : const Icon(Icons.restaurant,
                                              size: 18,
                                              color: Colors.black45);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name column
                              SizedBox(
                                width: leftW - 48,
                                child: Text(
                                  ingredients[i].name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Amount column
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

/// Renders a list of instructions as numbered steps: "Step 1:", "Step 2:", ...
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
