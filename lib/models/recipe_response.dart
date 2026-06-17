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
}
