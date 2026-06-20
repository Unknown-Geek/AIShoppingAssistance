import os
import httpx
from dotenv import load_dotenv

load_dotenv()


class NutritionService:
    def __init__(self):
        self.api_key = os.getenv("USDA_API_KEY")
        self.base_url = "https://api.nal.usda.gov/fdc/v1/foods/search"

    def _score_food(self, food: dict, query: str) -> float:
        from difflib import SequenceMatcher
        desc = food.get("description", "").lower()
        q_low = query.lower()
        
        score = SequenceMatcher(None, q_low, desc).ratio()
        
        q_tokens = [w.strip(",.()\"'").rstrip("s") for w in q_low.split() if w.strip()]
        d_tokens = [w.strip(",.()\"'").rstrip("s") for w in desc.lower().split() if w.strip()]
        
        if not q_tokens or not d_tokens:
            return score
            
        core_noun = q_tokens[-1]
        adjectives = set(q_tokens[:-1])
        
        if core_noun in d_tokens:
            score += 3.0
        else:
            has_adjective_match = False
            for adj in adjectives:
                if adj in d_tokens:
                    has_adjective_match = True
            if has_adjective_match:
                score -= 4.0

        for idx, token in enumerate(q_tokens):
            if token in d_tokens:
                weight = (idx + 1) / len(q_tokens)
                score += weight * 1.5

        d_first = desc.split(",")[0].strip().rstrip("s") if desc else ""
        if d_first and d_first in q_tokens:
            score += 1.0
            
        if "raw" in desc:
            score += 0.5
            
        bad_keywords = ["patty", "chips", "rings", "fried", "powder", "salad", "frozen"]
        if any(w in desc for w in bad_keywords):
            score -= 3.0
            
        return score

    def _select_best_food(self, foods, query: str):
        if not foods:
            return None
        return max(foods, key=lambda f: self._score_food(f, query))

    async def get_nutrition(self, ingredient_name: str):
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    self.base_url,
                    params={
                        "query": ingredient_name,
                        "pageSize": 10,
                        "api_key": self.api_key,
                    },
                )

                response.raise_for_status()

                data = response.json()

                foods = data.get("foods", [])

                if not foods:
                    return None

                food = self._select_best_food(foods, ingredient_name)

                if not food:
                    return None

                print(
                    f"[NutritionService] '{ingredient_name}' matched to '{food.get('description')}'"
                )

                nutrients = {
                    n["nutrientName"]: n["value"]
                    for n in food.get("foodNutrients", [])
                    if "value" in n
                }

                return {
                    "calories": nutrients.get("Energy", 0),
                    "protein": nutrients.get("Protein", 0),
                    "carbs": nutrients.get("Carbohydrate, by difference", 0),
                    "fat": nutrients.get("Total lipid (fat)", 0),
                }

        except Exception as e:
            print(f"[NutritionService] {ingredient_name}: {e}")
            return None
    def _safe_float(self, value):
        try:
            return float(value)
        except Exception:
            return 0.0

    async def calculate_recipe_nutrition(
        self,
        ingredients,
        servings,
    ):
        total_calories = 0.0
        total_protein = 0.0
        total_carbs = 0.0
        total_fat = 0.0

        for ingredient in ingredients:

            name = ingredient.get("name", "")

            quantity = self._safe_float(
                ingredient.get("quantity", 0)
            )

            unit = (
                ingredient.get("unit", "")
                .lower()
                .strip()
            )

            print(f"CHECKING USDA FOR: {name}")

            # TEMP DEBUG
            # if unit not in ["g", "gm", "gram", "grams"]:
            #     continue

            nutrition = await self.get_nutrition(name)

            if not nutrition:
                continue

            multiplier = quantity / 100.0

            total_calories += nutrition["calories"] * multiplier
            total_protein += nutrition["protein"] * multiplier
            total_carbs += nutrition["carbs"] * multiplier
            total_fat += nutrition["fat"] * multiplier

        servings = max(1, servings)

        return {
            "total": {
                "calories": round(total_calories, 1),
                "protein": round(total_protein, 1),
                "carbs": round(total_carbs, 1),
                "fat": round(total_fat, 1),
            },
            "per_serving": {
                "calories": round(total_calories / servings, 1),
                "protein": round(total_protein / servings, 1),
                "carbs": round(total_carbs / servings, 1),
                "fat": round(total_fat / servings, 1),
            },
        }        