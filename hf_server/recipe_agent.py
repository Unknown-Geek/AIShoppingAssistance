from recipe_tool import RecipeTool
from firecrawl_recipe_tool import FirecrawlRecipeTool
from recipe_parser import RecipeParser


class RecipeAgent:

    def __init__(self):
        self.tool = RecipeTool()
        self.firecrawl_tool = FirecrawlRecipeTool()
        self.parser = RecipeParser()

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
            return {
                "status": "success",
                "dish": dish,
                "servings": servings,
                "ingredients": parsed["ingredients"],
                "instructions": parsed["instructions"],
                "source": recipe["url"]
            }

        return {
            "status": "error",
            "message": "Recipe not found"
        }
