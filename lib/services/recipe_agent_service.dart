import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/recipe_response.dart';
import '../models/ingredient_model.dart';

class RecipeAgentService {
  final String _baseUrl = dotenv.env['HF_SPACE_URL'] ?? '';

  Future<RecipeResponse> processPrompt(String userPrompt) async {
    final dish = _extractDishName(userPrompt);
    final servings = _estimateServings(userPrompt);

    final response = await http.post(
      Uri.parse('$_baseUrl/recipe-agent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dish': dish, 'servings': servings}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch recipe');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Recipe not found');
    }

    final ingredients = (data['ingredients'] as List).map((i) {
      return IngredientModel(
        name: i['name'] as String,
        quantity: 1,
        unit: i['quantity'] as String? ?? '',
      );
    }).toList();

    return RecipeResponse(
      dishName: data['dish'] as String,
      servings: data['servings'] as int,
      ingredients: ingredients,
      recommendations: [],
    );
  }

  String _extractDishName(String prompt) {
    return prompt.toLowerCase()
        .replaceAll(RegExp(r'how (do i |to |can i )?make\s*'), '')
        .replaceAll(RegExp(r'recipe for\s*'), '')
        .replaceAll(RegExp(r'i want to cook\s*'), '')
        .replaceAll(RegExp(r'\bfor\s+\d+\s*(people|persons|servings)?\b'), '')
        .replaceAll(RegExp(r'[?.!]'), '')
        .trim();
  }

  int _estimateServings(String prompt) {
    final match = RegExp(r'\b(\d+)\s*(people|persons|servings)?\b')
        .firstMatch(prompt);
    if (match != null) {
      final n = int.tryParse(match.group(1) ?? '');
      if (n != null && n > 0 && n <= 100) return n;
    }
    return 2;
  }
}