import httpx
import json
from typing import Dict, Any

class RecipeSearchTool:
    """Tool to search for recipes using TheMealDB API"""
    
    BASE_URL = "https://www.themealdb.com/api/json/v1/1/search.php?s="

    @staticmethod
    def get_tool_definition() -> Dict[str, Any]:
        """Returns the tool definition for Groq function calling"""
        return {
            "type": "function",
            "function": {
                "name": "search_recipe",
                "description": "Search for a recipe by dish name using TheMealDB API. Returns recipe details including ingredients and instructions.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "dish_name": {
                            "type": "string",
                            "description": "The name of the dish to search for (e.g., 'Pasta', 'Biryani', 'Tacos')"
                        }
                    },
                    "required": ["dish_name"]
                }
            }
        }

    @staticmethod
    async def execute(dish_name: str) -> Dict[str, Any]:
        """Execute the recipe search"""
        url = f"{RecipeSearchTool.BASE_URL}{dish_name}"

        async with httpx.AsyncClient() as client:
            response = await client.get(url)

        print(f"[RecipeSearchTool] MealDB URL: {url}")
        print(f"[RecipeSearchTool] Status: {response.status_code}")

        if response.status_code != 200:
            return {"error": f"Failed to fetch recipe. Status code: {response.status_code}"}

        try:
            data = response.json()
        except json.JSONDecodeError:
            return {"error": "Invalid JSON response from MealDB"}

        meals = data.get("meals")
        if not meals:
            return {"error": f"No recipe found for '{dish_name}'"}

        meal = meals[0]

        ingredients = []
        for i in range(1, 21):
            ingredient = meal.get(f"strIngredient{i}")
            measure = meal.get(f"strMeasure{i}")

            if ingredient and ingredient.strip():
                ingredients.append({
                    "name": ingredient.strip(),
                    "quantity": measure.strip() if measure else ""
                })

        return {
            "dish": meal.get("strMeal"),
            "category": meal.get("strCategory"),
            "area": meal.get("strArea"),
            "instructions": meal.get("strInstructions", ""),
            "ingredients": ingredients,
            "image": meal.get("strMealThumb", "")
        }
