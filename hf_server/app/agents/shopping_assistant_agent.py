import json
import os
import asyncio
from typing import List, Dict, Any
from app.agents.recipe_agent import RecipeAgent
from app.agents.tools.quantity_parser_tool import QuantityParserTool

class ShoppingAssistantAgent:
    def __init__(self):
        self.recipe_agent = RecipeAgent()
        self.quantity_parser = QuantityParserTool()
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Loads the master retail catalog to match ingredients against real products."""
        inventory_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../data/inventory.json"))
        # Fallback check if it sits outside the app module boundaries
        if not os.path.exists(inventory_path):
            inventory_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../inventory.json"))
            
        try:
            with open(inventory_path, "r") as f:
                data = json.load(f)
                if isinstance(data, dict) and "items" in data:
                    return data["items"]
                if isinstance(data, list):
                    return data
                return []
        except Exception as e:
            print(f"[ShoppingAssistantAgent] Inventory load fallback triggered: {e}")
            return []

    async def process_recipe_workflow(self, current_cart_slugs: List[str], dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Executes the full pipeline using AI-driven orchestration matching:
        1. Recipe Search (via RecipeAgent)
        2. Quantity structural normalization parsing
        3. Intelligent LLM Semantic Inventory Mapping
        4. Lowercase Cart Item Exclusion filtering
        """
        try:
            # 1. Generate clean recipe structures via Groq
            raw_recipe = await self.recipe_agent.generate(dish_query, servings)
            
            print("\n===== DEBUG: RECIPE AGENT RESPONSE =====")
            print(f"Type: {type(raw_recipe)}")
            print(f"Content: {json.dumps(raw_recipe, indent=2)[:500]}")
            print("========================================\n")
            
            raw_ingredients = []
            instructions_list = []

            # Normalize structure layers
            if isinstance(raw_recipe, dict):
                raw_ingredients = raw_recipe.get("ingredients", [])
                instructions_list = raw_recipe.get("instructions", [])
            elif isinstance(raw_recipe, str):
                try:
                    data = json.loads(raw_recipe)
                    if isinstance(data, dict):
                        raw_ingredients = data.get("ingredients", [])
                        instructions_list = data.get("instructions", [])
                except Exception:
                    instructions_list = [raw_recipe]

            # Parse string tokens into predictable structural objects for the inventory matcher
            parsed_ingredients = []
            for ing in raw_ingredients:
                if isinstance(ing, dict):
                    name = ing.get("name", "").strip()
                    qty = ing.get("quantity", "").strip()
                    unit = ing.get("unit", "").strip()

                    # Skip non-food items like water
                    if name.lower() in ("water",):
                        continue

                    # Avoid duplicating the unit when quantity already contains it
                    # Handle singular/plural: "1 cup" should detect "cups" is already present
                    # e.g. quantity="2 cups" + unit="cups" should not produce "2 cups cups X"
                    if unit:
                        unit_norm = unit.lower().rstrip("s")
                        qty_norm = qty.lower().rstrip("s")
                        if unit_norm not in qty_norm:
                            ing_str = f"{qty} {unit} {name}".strip()
                        elif qty_norm:
                            ing_str = f"{qty} {name}".strip()
                        else:
                            ing_str = name
                    elif qty:
                        ing_str = f"{qty} {name}".strip()
                    else:
                        ing_str = name
                else:
                    ing_str = str(ing).strip()

                if ing_str:
                    parsed = self.quantity_parser.execute(ing_str)
                    parsed_ingredients.append(parsed)

            # 2. Fire the whole batch into our new AI Semantic Engine!
            ai_matched_items = self.recipe_agent.match_inventory_with_ai(parsed_ingredients, self.inventory)

            # 3. Clean up casing variables and filter out what is in their active cart
            missing_ingredients = []
            cart_slugs_set = set(str(slug).lower().strip() for slug in current_cart_slugs)

            for item in ai_matched_items:
                item_slug = item.get("slug", "").lower().strip()
                
                # If they already bought it, skip it entirely!
                if item_slug in cart_slugs_set:
                    continue
                    
                missing_ingredients.append({
                    "sku": item.get("sku", "UNKNOWN"),
                    "slug": item.get("slug", item_slug),
                    "name": item.get("name"),
                    "price_rupees": float(item.get("price_rupees", 0.0)),
                    "thumbnail_url": item.get("thumbnail_url", ""),
                    "required_quantity": item.get("required_quantity", "")
                })

            return {
                "dish": str(dish_query),
                "servings": int(servings),
                "recipe_instructions": list(instructions_list),
                "parsed_ingredients": list(parsed_ingredients),
                "missing_ingredients": missing_ingredients
            }
            
        except Exception as e:
            import traceback
            print(f"\n[ShoppingAssistantAgent] Error in workflow execution: {e}")
            traceback.print_exc()
            return {
                "dish": dish_query,
                "servings": servings,
                "recipe_instructions": [],
                "parsed_ingredients": [],
                "missing_ingredients": [],
                "error": str(e)
            }