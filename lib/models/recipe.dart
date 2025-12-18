class RecipeIngredient {
  final String name;
  final String amount;

  const RecipeIngredient({
    required this.name,
    required this.amount,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: (map['name'] ?? '').toString(),
      amount: (map['amount'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
      };
}

class Recipe {
  final String id;
  final String name;

  /// Minutes (integer) used by UI: "${timeMinutes} min"
  final int timeMinutes;

  /// 1–2 sentences description (optional but recommended)
  final String description;

  /// Ingredients with amounts
  final List<RecipeIngredient> ingredients;

  /// Steps displayed as "Step 1/2/3"
  final List<String> steps;

  /// Optional: local asset path (e.g. 'assets/images/pancakes.jpg')
  final String? imageAsset;

  /// Optional: network image URL
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

  factory Recipe.fromMap(Map<String, dynamic> map) {
    final rawIngredients = (map['ingredients'] as List?) ?? const [];
    final rawSteps = (map['steps'] as List?) ?? const [];

    // Support both:
    // 1) ingredients: [{"name":"flour","amount":"250 g"}, ...]
    // 2) ingredients: ["flour","milk"]  -> amount becomes ""
    final ingredients = rawIngredients.map((e) {
      if (e is Map<String, dynamic>) {
        return RecipeIngredient.fromMap(e);
      }
      return RecipeIngredient(name: e.toString(), amount: '');
    }).toList();

    // Support time stored as int minutes or as string like "30 min"
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
