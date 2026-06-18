import json
import os
from typing import List, Dict, Any
from quantity_estimator import QuantityEstimator
from app.agents.recipe_agent import RecipeAgent

class ShoppingAssistantAgent:
    def __init__(self):
        self.estimator = QuantityEstimator()
        self.recipe_agent = RecipeAgent()
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Loads the master retail catalog to match ingredients against real products."""
        inventory_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../inventory.json"))
        try:
            with open(inventory_path, "r") as f:
                return json.load(f)
        except Exception as e:
            print(f"[ShoppingAssistantAgent] Inventory load fallback triggered: {e}")
            return []

    def _match_inventory(self, ingredient_name: str) -> Dict[str, Any] or None:
        """Finds a matching product item in the retail catalog using simple keyword containment."""
        name_lower = ingredient_name.lower()
        for item in self.inventory:
            product_name = item.get("name", "").lower()
            if product_name in name_lower or name_lower in product_name:
                return item
        return None

    def process_recipe_workflow(self, current_cart_slugs: List[str], dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Executes the full pipeline:
        Inventory/Cart -> Recipe Generation -> Parsing -> Missing Detection -> Payload Formulation
        """
        # 1. Generate the recipe structure via your existing Groq client setup
# 1. Generate the recipe structure via your existing Groq client setup
        raw_recipe = self.recipe_agent.generate(dish_query, servings)
        
        print("\n===== DEBUG: LIVE GROQ OBJECT RECEIVED =====")
        print(type(raw_recipe), raw_recipe)
        print("============================================\n")
        
        raw_ingredients = []
        instructions_list = []

        # Completely robust type parsing check
        if isinstance(raw_recipe, dict):
            raw_ingredients = raw_recipe.get("ingredients", [])
            instructions_list = raw_recipe.get("instructions", [])
        elif isinstance(raw_recipe, str):
            try:
                # In case it's a JSON string wrapped as a string text block
                data = json.loads(raw_recipe)
                if isinstance(data, dict):
                    raw_ingredients = data.get("ingredients", [])
                    instructions_list = data.get("instructions", [])
                else:
                    raw_ingredients = [str(data)]
            except Exception:
                # Raw unstructured markdown string fallback execution
                instructions_list = [raw_recipe]
                raw_ingredients = [
                    line.strip("- *▢ ") for line in raw_recipe.split("\n") 
                    if any(x in line.lower() for x in ["cup", "gram", "tbsp", "tsp", "oz", "leaf", "chili", "rice", "materials"])
                ]
        else:
            # Fallback if it's an object instance or alternative data type layout
            try:
                raw_ingredients = getattr(raw_recipe, "ingredients", [])
                instructions_list = getattr(raw_recipe, "instructions", [])
            except Exception:
                pass

        # Ensure we always deal with iterable lists safely
        if not isinstance(raw_ingredients, list):
            raw_ingredients = [str(raw_ingredients)] if raw_ingredients else []
        if not isinstance(instructions_list, list):
            instructions_list = [str(instructions_list)] if instructions_list else []

        parsed_ingredients = []
        missing_ingredients = []

        # Map current cart slugs to lowercase for fast lookups
        cart_slugs_set = set(slug.lower() for slug in current_cart_slugs)

        # 2. Loop through generated ingredients & parse using your fixed estimator
        for ing_str in raw_ingredients:
            if not isinstance(ing_str, str) or not ing_str.strip():
                continue
            parsed = self.estimator.parse_ingredient(ing_str)
            parsed_ingredients.append(parsed)
            
            # 3. Missing Ingredient Detection
            matched_product = self._match_inventory(parsed["name"])
            
            if matched_product:
                slug = matched_product.get("slug")
                if slug not in cart_slugs_set:
                    missing_ingredients.append({
                        "sku": matched_product.get("sku"),
                        "slug": slug,
                        "name": matched_product.get("name"),
                        "price_rupees": matched_product.get("price_rupees"),
                        "thumbnail_url": matched_product.get("thumbnail_url"),
                        "required_quantity": parsed["quantity"]
                    })
            else:
                missing_ingredients.append({
                    "sku": "UNKNOWN",
                    "slug": parsed["name"].lower().replace(" ", "-"),
                    "name": parsed["name"],
                    "price_rupees": 0.0,
                    "thumbnail_url": "",
                    "required_quantity": parsed["quantity"]
                })

# Force convert everything to explicit, safe native data models
        try:
            response_payload = {
                "dish": str(dish_query),
                "servings": int(servings),
                "recipe_instructions": list(instructions_list) if isinstance(instructions_list, list) else [str(instructions_list)],
                "parsed_ingredients": list(parsed_ingredients),
                "missing_ingredients": list(missing_ingredients)
            }
            return response_payload
        except Exception as e:
            return {
                "dish": dish_query,
                "servings": servings,
                "recipe_instructions": ["Failed to build structured response context safely."],
                "parsed_ingredients": [],
                "missing_ingredients": [],
                "error_debug": str(e)
            }