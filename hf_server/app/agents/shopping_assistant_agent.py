import json
import os
import asyncio
from typing import List, Dict, Any
from app.agents.recipe_agent import RecipeAgent
from app.agents.tools.quantity_parser_tool import QuantityParserTool
from app.agents.tools.inventory_match_tool import InventoryMatchTool

class ShoppingAssistantAgent:
    def __init__(self):
        self.recipe_agent = RecipeAgent()
        self.quantity_parser = QuantityParserTool()
        self.inventory_matcher = InventoryMatchTool()
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Loads the master retail catalog to match ingredients against real products."""
        inventory_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../inventory.json"))
        try:
            with open(inventory_path, "r") as f:
                return json.load(f)
        except Exception as e:
            print(f"[ShoppingAssistantAgent] Inventory load fallback triggered: {e}")
            return []

    async def process_recipe_workflow(self, current_cart_slugs: List[str], dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Executes the full pipeline using the agentic RecipeAgent with tools:
        1. Recipe Search (agent searches via RecipeSearchTool)
        2. Ingredient Parsing (agent parses quantities via QuantityParserTool)
        3. Inventory Matching (agent matches to products via InventoryMatchTool)
        4. Missing Detection & Response Formulation
        """
        try:
            # 1. Generate recipe using the agentic approach with tools
            raw_recipe = await self.recipe_agent.generate(dish_query, servings)
            
            print("\n===== DEBUG: RECIPE AGENT RESPONSE =====")
            print(f"Type: {type(raw_recipe)}")
            print(f"Content: {json.dumps(raw_recipe, indent=2)[:500]}")
            print("========================================\n")
            
            raw_ingredients = []
            instructions_list = []

            # Parse recipe response - handle various formats
            if isinstance(raw_recipe, dict):
                raw_ingredients = raw_recipe.get("ingredients", [])
                instructions_list = raw_recipe.get("instructions", [])
            elif isinstance(raw_recipe, str):
                try:
                    data = json.loads(raw_recipe)
                    if isinstance(data, dict):
                        raw_ingredients = data.get("ingredients", [])
                        instructions_list = data.get("instructions", [])
                    else:
                        raw_ingredients = [str(data)]
                except Exception:
                    instructions_list = [raw_recipe]
            else:
                try:
                    raw_ingredients = getattr(raw_recipe, "ingredients", [])
                    instructions_list = getattr(raw_recipe, "instructions", [])
                except Exception:
                    pass

            # Ensure lists
            if not isinstance(raw_ingredients, list):
                raw_ingredients = [str(raw_ingredients)] if raw_ingredients else []
            if not isinstance(instructions_list, list):
                instructions_list = [str(instructions_list)] if instructions_list else []

            parsed_ingredients = []
            missing_ingredients = []
            cart_slugs_set = set(slug.lower() for slug in current_cart_slugs)

            # 2. Parse and match each ingredient
            for ing_str in raw_ingredients:
                if not isinstance(ing_str, str) or not ing_str.strip():
                    continue
                
                # Parse quantity
                parsed = self.quantity_parser.execute(ing_str)
                parsed_ingredients.append(parsed)
                
                # 3. Match to inventory
                matched_product = self.inventory_matcher.execute(parsed["name"])
                
                if matched_product["matched"]:
                    slug = matched_product.get("slug")
                    if slug and slug not in cart_slugs_set:
                        missing_ingredients.append({
                            "sku": matched_product.get("sku"),
                            "slug": slug,
                            "name": matched_product.get("name"),
                            "price_rupees": matched_product.get("price_rupees"),
                            "thumbnail_url": matched_product.get("thumbnail_url"),
                            "required_quantity": parsed.get("quantity", "")
                        })
                else:
                    # Product not found in inventory
                    missing_ingredients.append({
                        "sku": "UNKNOWN",
                        "slug": parsed["name"].lower().replace(" ", "-"),
                        "name": parsed["name"],
                        "price_rupees": 0.0,
                        "thumbnail_url": "",
                        "required_quantity": parsed.get("quantity", "")
                    })

            # Format final response
            response_payload = {
                "dish": str(dish_query),
                "servings": int(servings),
                "recipe_instructions": list(instructions_list) if isinstance(instructions_list, list) else [str(instructions_list)],
                "parsed_ingredients": list(parsed_ingredients),
                "missing_ingredients": list(missing_ingredients)
            }
            
            return response_payload
            
        except Exception as e:
            import traceback
            print(f"\n[ShoppingAssistantAgent] Error in workflow: {e}")
            traceback.print_exc()
            return {
                "dish": dish_query,
                "servings": servings,
                "recipe_instructions": [],
                "parsed_ingredients": [],
                "missing_ingredients": [],
                "error": str(e)
            }