import 'ingredient_model.dart';

class RecipeResponse {
  final String dishName;
  final int servings;
  final List<IngredientModel> ingredients;
  final List<dynamic> recommendations;

  RecipeResponse({
    required this.dishName,
    required this.servings,
    required this.ingredients,
    required this.recommendations,
  });

  factory RecipeResponse.fromJson(Map<String, dynamic> json) {
    return RecipeResponse(
      dishName: json['dishName'] as String? ?? '',
      servings: json['servings'] as int? ?? 1,
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((e) => IngredientModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: json['recommendations'] as List<dynamic>? ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dishName': dishName,
      'servings': servings,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'recommendations': recommendations,
    };
  }
}
