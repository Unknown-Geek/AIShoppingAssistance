from recipe_tool import RecipeTool
from firecrawl_recipe_tool import FirecrawlRecipeTool
from recipe_parser import RecipeParser
from quantity_estimator import QuantityEstimator
from groq_client import GroqClient


class RecipeAgent:

    def __init__(self):
        self.tool = RecipeTool()
        self.firecrawl_tool = FirecrawlRecipeTool()
        self.parser = RecipeParser()
        self.quantity_estimator = QuantityEstimator()
        self.groq_client = GroqClient()

    async def generate_recipe(
        self,
        dish: str,
        servings: int
    ):

        recipe = await self.tool.search_recipe(dish)

        # MealDB found recipe
        if recipe is not None:
            return {
                "status": "success",
                "dish": recipe["dish"],
                "servings": servings,
                "ingredients": recipe["ingredients"]
            }

        # MealDB failed → Firecrawl fallback
        recipe = await self.firecrawl_tool.search_recipe(dish)

        if recipe is not None:
            parsed = self.parser.parse(
                recipe["markdown"]
            )
            original_servings = parsed.get("servings", 1)
            if original_servings <= 0:
                original_servings = 1
            scale_factor = servings / original_servings
            
            structured_ingredients = []
            
            for ingredient in parsed["ingredients"]:
                ingredient_data = (
                    self.quantity_estimator.parse_ingredient(
                        ingredient
                    )
                )

                ingredient_data["quantity"] = (
                    self.quantity_estimator.scale_quantity(
                        ingredient_data["quantity"],
                        scale_factor
                    )
                )

                structured_ingredients.append(
                    ingredient_data
                )
            
            return {
                "status": "success",
                "dish": dish,
                "servings": servings,
                "ingredients": structured_ingredients,
                "instructions": parsed["instructions"],
                "source": recipe["url"]
            }

        return {
            "status": "error",
            "message": "Recipe not found"
        }

    async def generate_recipe_from_prompt(self, prompt: str):
        """
        Extract dish and servings from user prompt, then generate recipe.
        
        Args:
            prompt (str): User input, e.g., "I want Veg Biryani for 5 people"
        
        Returns:
            dict: Recipe response with status, dish, servings, ingredients, etc.
        """
        print("PROMPT:", prompt)

        extracted = self.groq_client.extract_recipe_request(prompt)

        print("EXTRACTED:", extracted)

        dish = extracted["dish"]
        servings = extracted["servings"]
        
        return await self.generate_recipe(dish, servings)
