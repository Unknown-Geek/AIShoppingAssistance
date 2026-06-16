import httpx


class RecipeTool:
    BASE_URL = "https://www.themealdb.com/api/json/v1/1/search.php?s="

    async def search_recipe(self, dish_name: str):
        url = f"{self.BASE_URL}{dish_name}"

        async with httpx.AsyncClient() as client:
            response = await client.get(url)

        print("MealDB URL:", url)
        print("MealDB Response:", response.text[:500])

        if response.status_code != 200:
            return None

        data = response.json()

        meals = data.get("meals")
        if not meals:
            return None

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
            "ingredients": ingredients
        }