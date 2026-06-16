from recipe_tool import RecipeTool


class RecipeAgent:

    def __init__(self):
        self.tool = RecipeTool()

    async def generate_recipe(
        self,
        dish: str,
        servings: int
    ):
        recipe = await self.tool.search_recipe(dish)

        if recipe is None:
            return {
                "status": "error",
                "message": "Recipe not found"
            }

        return {
            "status": "success",
            "dish": recipe["dish"],
            "servings": servings,
            "ingredients": recipe["ingredients"]
        }