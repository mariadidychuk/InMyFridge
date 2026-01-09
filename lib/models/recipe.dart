/// Single ingredient of a recipe with display name and amount.
/// Used inside [Recipe] for UI rendering and persistence.
class RecipeIngredient {
  final String name;
  final String amount;

  const RecipeIngredient({
    required this.name,
    required this.amount,
  });

  /// Creates an ingredient from a JSON-compatible map.
  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: (map['name'] ?? '').toString(),
      amount: (map['amount'] ?? '').toString(),
    );
  }

  /// Converts ingredient into a map for storage (Hive / JSON).
  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
      };
}

/// Core domain model representing a cooking recipe.
/// Central data structure used across the entire application.
class Recipe {
  final String id;
  final String name;

  /// Preparation time in minutes (used directly by UI).
  final int timeMinutes;

  /// Short description shown in recipe details.
  final String description;

  /// List of ingredients including amounts.
  final List<RecipeIngredient> ingredients;

  /// Ordered cooking steps displayed sequentially.
  final List<String> steps;

  /// Optional local image asset path.
  final String? imageAsset;

  /// Optional network image URL.
  final String? imageUrl;

  const Recipe({
    required this.id,
    required this.name,
    required this.timeMinutes,
    required this.description,
    required this.ingredients,
    required this.steps,
    this.imageAsset,
    this.imageUrl,
  });

  /// Creates a Recipe instance from persisted JSON data.
  /// Supports multiple legacy formats for backward compatibility.
  factory Recipe.fromMap(Map<String, dynamic> map) {
    final rawIngredients = (map['ingredients'] as List?) ?? const [];
    final rawSteps = (map['steps'] as List?) ?? const [];

    // Ingredients can be stored either as objects or plain strings.
    final ingredients = rawIngredients.map((e) {
      if (e is Map<String, dynamic>) {
        return RecipeIngredient.fromMap(e);
      }
      return RecipeIngredient(name: e.toString(), amount: '');
    }).toList();

    // Time can be stored as int or formatted string (e.g. "30 min").
    int parseMinutes(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      final s = v.toString().toLowerCase().replaceAll('min', '').trim();
      return int.tryParse(s) ?? 0;
    }

    return Recipe(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      timeMinutes: parseMinutes(map['timeMinutes'] ?? map['time']),
      description: (map['description'] ?? '').toString(),
      ingredients: ingredients,
      steps: rawSteps.map((e) => e.toString()).toList(),
      imageAsset: (map['imageAsset'] ?? '').toString().isEmpty
          ? null
          : map['imageAsset'].toString(),
      imageUrl: (map['imageUrl'] ?? '').toString().isEmpty
          ? null
          : map['imageUrl'].toString(),
    );
  }

  /// Converts recipe into a JSON-compatible map for local persistence.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'timeMinutes': timeMinutes,
        'description': description,
        'ingredients': ingredients.map((e) => e.toMap()).toList(),
        'steps': steps,
        'imageAsset': imageAsset ?? '',
        'imageUrl': imageUrl ?? '',
      };
}
