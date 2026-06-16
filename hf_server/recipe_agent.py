from recipe_tool import RecipeTool
from firecrawl_recipe_tool import FirecrawlRecipeTool


class RecipeAgent:

    def __init__(self):
        self.tool = RecipeTool()
        self.firecrawl_tool = FirecrawlRecipeTool()

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
            return recipe

        return {
            "status": "error",
            "message": "Recipe not found"
        }