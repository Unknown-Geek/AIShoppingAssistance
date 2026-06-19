import json
import os
import asyncio
from typing import List, Dict, Any
from groq import Groq
from dotenv import load_dotenv
from app.agents.recipe_agent import RecipeAgent
from app.agents.tools.quantity_parser_tool import QuantityParserTool

# ─── NEW IMPORT ADDED HERE ───
from app.utils.cart_state import live_cart_memory

load_dotenv()

# ─── UPDATED REAL TOOL FUNCTION ───
def execute_database_cart_addition(user_id: str, sku: str, quantity: int) -> bool:
    """
    Directly writes a persistent modification entry to your application's 
    active shopping cart storage cache layer.
    """
    success = live_cart_memory.add_item(user_id=user_id, sku=sku, quantity=quantity)
    if success:
        print(f"💾 [STATE COMMIT] User: '{user_id}' | SKU: '{sku}' successfully written to memory.")
    return success

# ─── ACTIVE REGISTRY MANDATORY HOOK ───
ACTIVE_CART_TOOLS_REGISTRY = {
    "add_to_cart": execute_database_cart_addition
}

class ShoppingAssistantAgent:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            print("[WARNING] GROQ_API_KEY not detected in environment, using mock key to prevent startup crash")
            api_key = "gsk_mock_key_placeholder_for_verification_only"
        self.client = Groq(api_key=api_key)
        self.recipe_agent = RecipeAgent()
        self.quantity_parser = QuantityParserTool()
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Loads the store inventory catalog from the verified absolute container workspace root path."""
        inventory_path = "/workspaces/AIShoppingAssistance/inventory.json"
        
        if not os.path.exists(inventory_path):
            inventory_path = "../inventory.json"

        try:
            with open(inventory_path, "r") as f:
                data = json.load(f)
                return data.get("items", data) if isinstance(data, dict) else data
        except Exception as e:
            print(f"⚠️ [WARNING] Failed to load inventory database catalog from {inventory_path}: {e}")
            return []

    async def process_recipe_workflow(self, user_id: str, current_cart_slugs: List[str], dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Executes the full recipe pipeline, screens out payload injections, 
        consolidates recurring missing items/cart additions cleanly, and formats for Flutter.
        """
        try:
            # ─────────────────────────────────────────────────────────────────
            # GATE 1: IMMEDIATE FRONT-DOOR INPUT SANITIZATION
            # ─────────────────────────────────────────────────────────────────
            toxic_keywords = {"cleaner", "harpic", "lizol", "toilet", "disinfectant", "floor", "soap"}
            processed_keywords = {"cerelac", "boost", "horlicks", "bournvita", "baby", "cereal", "chocos"}
            sauce_keywords = {"sauce", "ketchup", "paste", "jam", "spread"}
            snack_keywords = {"chips", "lays", "kurkure", "namkeen", "biscuit", "cookie", "bingo"}
            utility_keywords = {"bottle", "flask", "container", "jar", "box", "spoon", "knife", "pan"}
            
            query_lower = dish_query.lower()
            if any(tk in query_lower for tk in toxic_keywords):
                print(f"🛑 [SECURITY BLOCK] Malicious payload injection caught in query: '{dish_query}'")
                return {
                    "dish": str(dish_query),
                    "servings": int(servings),
                    "recipe_instructions": ["Recipe blocked due to safety violations."],
                    "parsed_ingredients": [],
                    "missing_ingredients": [],
                    "cart_additions": []
                }

            # 1. Generate clean recipe structures via Groq
            raw_recipe = await self.recipe_agent.generate(dish_query, servings)
            
            raw_ingredients = []
            instructions_list = []

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

            # Parse measurements cleanly via QuantityParserTool
            parsed_ingredients = []
            for ing in raw_ingredients:
                if isinstance(ing, dict):
                    name = ing.get("name", "").strip()
                    qty = ing.get("quantity", "").strip()
                    unit = ing.get("unit", "").strip()
                    
                    # Deduplicate stutters: If unit string context is already sitting inside the quantity token, remove duplication
                    if unit and unit.lower() in qty.lower():
                        ing_str = f"{qty} {name}".strip()
                    else:
                        ing_str = f"{qty} {unit} {name}".strip()
                else:
                    ing_str = str(ing).strip()

                if ing_str:
                    parsed = self.quantity_parser.execute(ing_str)
                    
                    # Deep-clean inner tool output stutter mappings (e.g. "1 tablespoon tablespoons")
                    raw_in = parsed.get("raw_input", "")
                    for u_word in ["tablespoons", "tablespoon", "teaspoons", "teaspoon", "cups", "cup", "pieces", "piece"]:
                        if raw_in.lower().count(u_word) > 1:
                            # Reconstruct clean text dynamically
                            raw_in = f"{parsed.get('quantity', '')} {parsed.get('unit', '')} {parsed.get('name', '')}".replace("  ", " ").strip()
                            parsed["raw_input"] = raw_in
                            break
                            
                    parsed_ingredients.append(parsed)

            # ─────────────────────────────────────────────────────────────────
            # GATE 2: BACKEND CATALOG FILTER MATRIX
            # ─────────────────────────────────────────────────────────────────
            targeted_catalog = []

            for ing in parsed_ingredients:
                ing_name = ing.get("name", "").lower().strip()
                if not ing_name:
                    continue
                
                if any(tk in ing_name for tk in toxic_keywords):
                    continue
                    
                ing_tokens = set(t for t in ing_name.split() if len(t) >= 3 or t == "ghee" or t == "oil")
                
                for item in self.inventory:
                    item_name = item.get("name", "").lower()
                    item_slug = item.get("slug", "").lower()

                    if any(tk in item_name for tk in toxic_keywords):
                        continue
                    if any(pk in item_name for pk in processed_keywords) and not any(pk in ing_name for pk in processed_keywords):
                        continue
                    if any(sk in item_name for sk in sauce_keywords) and not any(sk in ing_name for sk in sauce_keywords):
                        continue

                    item_tokens = set(item_name.split() + item_slug.split("-"))
                    if ing_name in item_name or item_name in ing_name or ing_tokens.intersection(item_tokens):
                        if item not in targeted_catalog:
                            targeted_catalog.append(item)

            if not targeted_catalog and self.inventory:
                targeted_catalog = [item for item in self.inventory if not any(tk in item.get("name", "").lower() for tk in toxic_keywords)]

            # Run AI matching context sequence
            ai_matched_items = []
            try:
                ai_matched_items = self.recipe_agent.match_inventory_with_ai(parsed_ingredients, targeted_catalog)
            except Exception as ai_err:
                print(f"⚠️ [AI MATCHING ERROR] Falling back entirely to deterministic matrix matcher: {ai_err}")

            ai_lookup = {}
            if isinstance(ai_matched_items, list):
                for item in ai_matched_items:
                    if isinstance(item, dict):
                        req_name = str(item.get("requested_name", item.get("name", ""))).lower().strip()
                        ai_lookup[req_name] = item

            missing_ingredients_map = {} # ◄─── Map to deduplicate repetitive warehouse matching objects
            cart_additions_map = {}
            normalized_cart_slugs = [str(slug).lower().strip() for slug in current_cart_slugs]

            # ─────────────────────────────────────────────────────────────────
            # STRUCTURAL COMPOSITION GENERATION
            # ─────────────────────────────────────────────────────────────────
            for ing in parsed_ingredients:
                ing_name = ing.get("name", "").strip()
                ing_name_lower = ing_name.lower().strip()
                ing_slug_fallback = ing_name_lower.replace(" ", "-")
                
                if ing_slug_fallback in normalized_cart_slugs:
                    continue

                qty_str = ing.get('quantity', '').strip()
                unit_str = ing.get('unit', '').strip()
                final_qty = f"{qty_str} {unit_str}".strip() if unit_str and unit_str.lower() not in qty_str.lower() else qty_str

                # Try Layer 1: AI lookup matching
                ai_match = ai_lookup.get(ing_name_lower) or next((v for k, v in ai_lookup.items() if k in ing_name_lower or ing_name_lower in k), None)
                
                final_match = None
                if ai_match and ai_match.get("sku") != "UNKNOWN":
                    final_match = ai_match
                else:
                    # Try Layer 2: Deterministic substring containment & token scoring matrix fallback
                    best_match = None
                    best_score = 0
                    ing_tokens = set(t for t in ing_name_lower.split() if len(t) >= 3 or t in ["ghee", "oil"])
                    
                    for item in targeted_catalog:
                        item_name_lower = item.get("name", "").lower()
                        item_slug_lower = item.get("slug", "").lower()
                        
                        if any(sk in item_name_lower for sk in snack_keywords) and any(spice in ing_name_lower for spice in ["masala", "powder", "salt", "spice"]):
                            continue
                        if any(uk in item_name_lower for uk in utility_keywords) and ing_name_lower in ["water", "milk", "oil", "ghee", "juice"]:
                            continue
                        
                        item_tokens = set(item_name_lower.split() + item_slug_lower.split("-"))
                        score = len(ing_tokens.intersection(item_tokens))
                        
                        if ing_name_lower in item_name_lower or item_name_lower in ing_name_lower:
                            score += 5
                            
                        if score > best_score:
                            best_score = score
                            best_match = item
                            
                    if best_score > 0:
                        final_match = best_match

                # ─────────────────────────────────────────────────────────────
                # PAYLOAD COMPOSITION STEP WITH MAP DEDUPLICATION
                # ─────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────
                # PAYLOAD COMPOSITION & DATABASE WRITE BACK TRANSACTION
                # ─────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────
                # PAYLOAD COMPOSITION & DATABASE WRITE BACK TRANSACTION
                # ─────────────────────────────────────────────────────────────
                if final_match and final_match.get("sku"):
                    item_sku = final_match.get("sku")
                    item_slug = final_match.get("slug", ing_slug_fallback).lower().strip()
                    
                    if item_slug in normalized_cart_slugs:
                        continue

                    # 🚀 FORCE ACTIVE AGENT TOOL CALL INTERACTION
                    is_committed = False  # ◄─ This must stay BEFORE the 'try' block starts
                    try:
                        # Fetch the function directly from the registry
                        tool_action_hook = ACTIVE_CART_TOOLS_REGISTRY["add_to_cart"]
                        
                        # Use the incoming dynamic user_id variable
                        is_committed = tool_action_hook(user_id=user_id, sku=item_sku, quantity=1)
                        print(f"🎯 [AGENT ACTION] Fired tool call for User '{user_id}' | SKU {item_sku}. Result: {is_committed}")
                    except Exception as tool_ex:
                        print(f"⚠️ [TOOL RUNTIME FAULT] Failed to run database tool: {tool_ex}")
                        is_committed = False
                    
                    # Handle Missing Ingredients List Consolidation Matrix
                    if item_sku in missing_ingredients_map:
                        missing_ingredients_map[item_sku]["required_quantity"] += f" + {final_qty}"
                    else:
                        missing_ingredients_map[item_sku] = {
                            "sku": item_sku,
                            "slug": item_slug,
                            "name": final_match.get("name"),
                            "price_rupees": float(final_match.get("price_rupees", 0.0)),
                            "thumbnail_url": final_match.get("thumbnail_url", ""),
                            "required_quantity": final_qty,
                            "agent_tool_status": "Committed to DB" if is_committed else "Tool Error"
                        }
                    
                    # Handle Flutter Cart Service Mapping Matrix
                    if item_sku in cart_additions_map:
                        cart_additions_map[item_sku]["quantity"] += 1
                    else:
                        cart_additions_map[item_sku] = {
                            "sku": item_sku,
                            "name": final_match.get("name"),
                            "price": float(final_match.get("price_rupees", 0.0)),
                            "quantity": 1
                        }
                else:
                    # Keep non-catalog items tracked flatly by fallback slug
                    missing_ingredients_map[ing_slug_fallback] = {
                        "sku": "UNKNOWN",
                        "slug": ing_slug_fallback,
                        "name": ing_name,
                        "price_rupees": 0.0,
                        "thumbnail_url": "",
                        "required_quantity": final_qty
                    }

            return {
                "dish": str(dish_query),
                "servings": int(servings),
                "recipe_instructions": list(instructions_list),
                "parsed_ingredients": list(parsed_ingredients),
                "missing_ingredients": list(missing_ingredients_map.values()), # ◄─── Cleanly cast to flat list layout
                "cart_additions": list(cart_additions_map.values())
            }
            
        except Exception as e:
            import traceback
            print("❌ [CRITICAL PIPELINE EXCEPTION]")
            traceback.print_exc()
            return {"error": str(e), "missing_ingredients": [], "cart_additions": []}