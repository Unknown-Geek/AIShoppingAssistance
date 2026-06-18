import json
import os
import asyncio
from typing import List, Dict, Any
from groq import Groq
from dotenv import load_dotenv
from app.agents.recipe_agent import RecipeAgent
from app.agents.tools.quantity_parser_tool import QuantityParserTool

load_dotenv()

ADD_TO_CART_TOOL = {
    "type": "function",
    "function": {
        "name": "add_to_cart",
        "description": "Automatically adds missing or required recipe ingredients to the user's retail shopping cart using their unique product SKUs.",
        "parameters": {
            "type": "object",
            "properties": {
                "items": {
                    "type": "array",
                    "description": "A list of product objects to add to the cart.",
                    "items": {
                        "type": "object",
                        "properties": {
                            "sku": {"type": "string", "description": "The matching product SKU code from the inventory list (e.g., 'QLS-0025')."},
                            "quantity": {"type": "integer", "description": "The quantity/number of packets or units to add to the cart. Default is 1."}
                        },
                        "required": ["sku"]
                    }
                }
            },
            "required": ["items"]
        }
    }
}

class ShoppingAssistantAgent:
    def __init__(self):
        self.recipe_agent = RecipeAgent()
        self.quantity_parser = QuantityParserTool()
        self.inventory = self._load_inventory()
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            print("[WARNING] GROQ_API_KEY not detected, using mock key")
            api_key = "gsk_mock_key_placeholder_for_verification_only"
        self.client = Groq(api_key=api_key)

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

    def _process_cart_tool_calls(self, missing_ingredients: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Uses Groq tool-calling to let the LLM decide which ingredients to add to cart.
        The LLM receives the matched items and can invoke add_to_cart for each one."""
        items_with_sku = [item for item in missing_ingredients if item["sku"] != "UNKNOWN"]
        if not items_with_sku:
            return []

        prompt = f"""You are a shopping assistant. The following ingredients (product objects) are available and have been matched to products in the store:
{json.dumps(items_with_sku, indent=2)}

For each item with a valid SKU, use the `add_to_cart` function individually to add it to the user's cart. Ensure the quantity for each item is a small, reasonable integer (e.g., between 1 and 10) suitable for a typical home recipe. When calling `add_to_cart`, provide the `items` parameter as a list containing a single product object, with 'sku' (string) and 'quantity' (integer) fields."""

        messages = [
            {"role": "system", "content": "You are a helpful shopping assistant that adds recipe ingredients to the user's cart."},
            {"role": "user", "content": prompt}
        ]

        response = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=messages,
            tools=[ADD_TO_CART_TOOL],
            tool_choice="auto"
        )

        added_items = []
        if response.choices[0].message.tool_calls:
            for tool_call in response.choices[0].message.tool_calls:
                if tool_call.function.name == "add_to_cart":
                    arguments = json.loads(tool_call.function.arguments)
                    items = arguments.get("items", [])
                    for item in items:
                        sku = item.get("sku")
                        qty = int(round(item.get("quantity", 1)))
                        print(f"🛒 [CART ADDED] -> SKU: {sku} | Quantity: {qty}")
                        added_items.append({"sku": sku, "quantity": qty})
        else:
            print("[ShoppingAssistantAgent] LLM chose not to call add_to_cart tool.")

        return added_items

    async def process_recipe_workflow(self, current_cart_slugs: List[str], dish_query: str, servings: int) -> Dict[str, Any]:
        TOXIC_KEYWORDS = ["harpic", "cleaner", "lizol", "cerelac", "toilet"]
        sanitized_dish_query = dish_query
        for keyword in TOXIC_KEYWORDS:
            sanitized_dish_query = sanitized_dish_query.replace(keyword, "")


        """
        Executes the full pipeline using AI-driven orchestration matching:
        1. Recipe Search (via RecipeAgent)
        2. Quantity structural normalization parsing
        3. Intelligent LLM Semantic Inventory Mapping
        4. Lowercase Cart Item Exclusion filtering
        """
        try:
            # 1. Generate clean recipe structures via Groq
            raw_recipe = await self.recipe_agent.generate(sanitized_dish_query, servings)
            
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

            # 3. Build an AI result lookup keyed by ingredient name (deterministic source-of-truth).
            # The AI may silently drop unmatched ingredients instead of returning sku: UNKNOWN,
            # so we must iterate parsed_ingredients (the source of truth) and inject UNKNOWN
            # for anything the AI skipped.
            ai_lookup: Dict[str, Dict[str, Any]] = {}
            for item in ai_matched_items:
                req_name = item.get("name", "").lower().strip()
                ai_lookup[req_name] = item

            # 4. Clean up casing variables and filter out what is in their active cart
            missing_ingredients = []
            cart_slugs_set = set(str(slug).lower().strip() for slug in current_cart_slugs)
            seen_skus: set = set()

            for ing in parsed_ingredients:
                ing_name = ing.get("name", "").strip()
                ing_name_lower = ing_name.lower().strip()
                ing_slug = ing_name_lower.replace(" ", "-")

                # If they already bought it, skip it entirely!
                if ing_slug in cart_slugs_set:
                    continue

                # Smart deduplication for unit strings: avoid "2 cups cups"
                qty_str = ing.get("quantity", "").strip()
                unit_str = ing.get("unit", "").strip()
                if unit_str and unit_str.lower() not in qty_str.lower():
                    final_qty = f"{qty_str} {unit_str}".strip()
                else:
                    final_qty = qty_str

                # Find the AI match for this specific ingredient
                ai_match = ai_lookup.get(ing_name_lower)
                if not ai_match:
                    # Fuzzy fallback: ingredient name is contained in or contains the AI result name
                    ai_match = next(
                        (v for k, v in ai_lookup.items() if k in ing_name_lower or ing_name_lower in k),
                        None
                    )

                if ai_match and ai_match.get("sku") != "UNKNOWN":
                    item_sku = str(ai_match.get("sku", ""))
                    item_slug = ai_match.get("slug", ing_slug).lower().strip()

                    if item_slug in cart_slugs_set or item_sku in seen_skus:
                        continue

                    seen_skus.add(item_sku)
                    missing_ingredients.append({
                        "sku": item_sku,
                        "slug": ai_match.get("slug", ing_slug),
                        "name": ai_match.get("name", ing_name),
                        "price_rupees": float(ai_match.get("price_rupees", 0.0)),
                        "thumbnail_url": ai_match.get("thumbnail_url", ""),
                        "required_quantity": final_qty
                    })
                else:
                    # AI didn't match or returned UNKNOWN — inject UNKNOWN entry so the ingredient
                    # doesn't silently disappear from the shopping list.
                    missing_ingredients.append({
                        "sku": "UNKNOWN",
                        "slug": ing_slug,
                        "name": ing_name,
                        "price_rupees": 0.0,
                        "thumbnail_url": "",
                        "required_quantity": final_qty
                    })

            # 5. Use Groq tool-calling to let the LLM decide which items to add to cart
            cart_additions = self._process_cart_tool_calls(missing_ingredients)

            return {
                "dish": str(sanitized_dish_query),
                "servings": int(servings),
                "recipe_instructions": list(instructions_list),
                "parsed_ingredients": list(parsed_ingredients),
                "missing_ingredients": missing_ingredients,
                "cart_additions": cart_additions
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