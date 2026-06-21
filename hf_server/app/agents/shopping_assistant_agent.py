import json
import os
import asyncio
from typing import List, Dict, Any
from groq import Groq
from dotenv import load_dotenv
from app.agents.recipe_agent import RecipeAgent
from app.agents.tools.quantity_parser_tool import QuantityParserTool

# Explicitly load .env file from the hf_server directory
base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dotenv_path = os.path.join(base_dir, ".env")
load_dotenv(dotenv_path=dotenv_path, override=True)

from app.utils.cart_state import live_cart_memory

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

def execute_database_cart_removal(user_id: str, sku: str, quantity: int) -> bool:
    """
    Directly writes a persistent modification entry to remove or decrement a SKU in the cart.
    """
    success = live_cart_memory.remove_item(user_id=user_id, sku=sku, quantity=quantity)
    if success:
        print(f"💾 [STATE REMOVE] User: '{user_id}' | SKU: '{sku}' successfully removed/decremented from memory.")
    return success

# ─── ACTIVE REGISTRY MANDATORY HOOK ───
ACTIVE_CART_TOOLS_REGISTRY = {
    "add_to_cart": execute_database_cart_addition,
    "remove_from_cart": execute_database_cart_removal
}

def format_ingredient_quantity(quantity: Any, unit: Any) -> str:
    """
    Formats the quantity and unit of an ingredient safely, avoiding duplication
    such as "1 cup cup" or "1 cup cup flour".
    """
    qty_str = str(quantity or "").strip()
    unit_str = str(unit or "").strip()
    
    if not unit_str:
        return qty_str
    if not qty_str:
        return unit_str
        
    # Check if the unit string is already present in quantity or vice versa
    if unit_str.lower() in qty_str.lower():
        return qty_str
    if qty_str.lower() in unit_str.lower():
        return unit_str
        
    # Word-level comparison to prevent e.g. "1 cup" and "cups" -> "1 cup cups"
    qty_words = qty_str.split()
    if qty_words:
        last_word = qty_words[-1]
        
        def clean_word(w):
            w = w.lower().strip(".,() ")
            if w.endswith("es"):
                w = w[:-2]
            elif w.endswith("s"):
                w = w[:-1]
            return w
            
        if clean_word(last_word) == clean_word(unit_str):
            return qty_str
            
    return f"{qty_str} {unit_str}"

def clean_ingredient_name(name: Any, unit: Any) -> str:
    """
    Cleans the ingredient name by removing any prepended unit words.
    E.g. name="cups All-purpose flour", unit="cups" -> "All-purpose flour"
    E.g. name="teaspoons Active dry yeast", unit="teaspoons" -> "Active dry yeast"
    """
    name_str = str(name or "").strip()
    unit_str = str(unit or "").strip()
    if not name_str or not unit_str:
        return name_str
        
    name_words = name_str.split()
    if not name_words:
        return name_str
        
    first_word = name_words[0]
    
    # Exact word match (case-insensitive)
    if first_word.lower() == unit_str.lower():
        cleaned = " ".join(name_words[1:]).strip()
        if cleaned.lower().startswith("of "):
            cleaned = cleaned[3:].strip()
        return cleaned
        
    # Singular/plural matched word comparison
    def clean_word(w):
        w = w.lower().strip(".,() ")
        if w.endswith("es"):
            w = w[:-2]
        elif w.endswith("s"):
            w = w[:-1]
        return w
        
    if clean_word(first_word) == clean_word(unit_str):
        cleaned = " ".join(name_words[1:]).strip()
        if cleaned.lower().startswith("of "):
            cleaned = cleaned[3:].strip()
        return cleaned
        
    return name_str

class ShoppingAssistantAgent:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            print("[WARNING] GROQ_API_KEY not detected in environment, using mock key to prevent startup crash")
            api_key = "gsk_mock_key_placeholder_for_verification_only"
        self.client = Groq(api_key=api_key)
        self.model = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
        self.recipe_agent = RecipeAgent()
        self.quantity_parser = QuantityParserTool()
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Loads the store inventory catalog from candidate locations."""
        base_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            "/workspaces/AIShoppingAssistance/inventory.json",
            os.path.abspath(os.path.join(base_dir, "inventory.json")),
            os.path.abspath(os.path.join(base_dir, "..", "inventory.json")),
            os.path.abspath(os.path.join(base_dir, "..", "..", "inventory.json")),
            os.path.abspath(os.path.join(base_dir, "..", "..", "..", "inventory.json")),
            os.path.abspath(os.path.join(base_dir, "..", "..", "..", "..", "inventory.json")),
            os.path.abspath("inventory.json"),
            os.path.abspath("../inventory.json"),
        ]
        
        inventory_path = None
        for path in candidates:
            if os.path.exists(path):
                inventory_path = path
                break
                
        if not inventory_path:
            inventory_path = os.path.abspath(os.path.join(base_dir, "..", "..", "inventory.json"))

        try:
            with open(inventory_path, "r") as f:
                data = json.load(f)
                return data.get("items", data) if isinstance(data, dict) else data
        except Exception as e:
            print(f"⚠️ [WARNING] Failed to load inventory database catalog from {inventory_path}: {e}")
            return []

    # ── Stopwords to strip before keyword matching ──
    _STOP_WORDS = {
        "a", "an", "the", "is", "are", "do", "you", "have", "has", "me", "my",
        "i", "to", "of", "for", "in", "on", "at", "and", "or", "but", "can",
        "it", "this", "that", "what", "how", "where", "which", "with", "your",
        "add", "get", "show", "give", "want", "buy", "some", "any", "please",
        "tell", "like", "make", "under", "over", "than", "more", "less", "much",
        "many", "very", "just", "also", "from", "about", "would", "could", "should",
    }

    def _prefetch_relevant_items(self, query: str) -> List[Dict[str, Any]]:
        """
        Regex-extract meaningful keywords from the user query, run token
        matching against the inventory, and return the top matches with full
        details (name, SKU, price).  Called before the first LLM request so
        the LLM can answer price/detail questions without an extra
        search_inventory round-trip.
        """
        import re

        # ── Category-word → inventory-token expansion ──────────────────────
        _CATEGORY_MAP = {
            "snack":     ["chocolate", "chips", "biscuit", "cookie", "wafer", "bar", "candy", "cracker"],
            "snacks":    ["chocolate", "chips", "biscuit", "cookie", "wafer", "bar", "candy", "cracker"],
            "drink":     ["drink", "juice", "milk", "water", "coffee", "tea", "energy"],
            "drinks":    ["drink", "juice", "milk", "water", "coffee", "tea", "energy"],
            "noodle":    ["noodles", "maggi", "instant", "cuppa"],
            "noodles":   ["noodles", "maggi", "instant", "cuppa"],
            "breakfast": ["cereal", "oats", "milk", "bread", "egg", "muesli"],
            "chocolate": ["chocolate", "cocoa", "dark"],
            "biscuit":   ["biscuit", "cookie", "digestive", "cream"],
            "biscuits":  ["biscuit", "cookie", "digestive", "cream"],
            "chips":     ["chips", "crisps", "namkeen", "rings", "puffs"],
            "sauce":     ["sauce", "ketchup", "chutney", "paste"],
        }

        # ── Extract price ceiling from query (e.g. "under ₹50", "below 100") ──
        price_ceiling = None
        price_match = re.search(r"(?:under|below|less\s+than|within)\s*[₹rs\.]*\s*(\d+)", query.lower())
        if price_match:
            price_ceiling = int(price_match.group(1))

        # Lowercase, strip punctuation, tokenise
        cleaned = re.sub(r"[^\w\s]", " ", query.lower())
        raw_tokens = [t for t in cleaned.split() if len(t) >= 3 and t not in self._STOP_WORDS]

        # Expand category words
        expanded_tokens = list(raw_tokens)
        for t in raw_tokens:
            if t in _CATEGORY_MAP:
                expanded_tokens.extend(_CATEGORY_MAP[t])

        if not expanded_tokens:
            return []

        matches: List[tuple] = []
        for item in self.inventory:
            item_name   = item.get("name", "").lower()
            item_slug   = item.get("slug", "").lower()
            item_tokens = set(item_name.split() + item_slug.split("-"))
            score = sum(1 for t in expanded_tokens if t in item_tokens)
            # Exact substring bonus for original (non-expanded) tokens
            for t in raw_tokens:
                if t in item_name:
                    score += 2
            if score > 0:
                matches.append((item, score))

        matches.sort(key=lambda x: x[1], reverse=True)
        top = [item for item, _ in matches[:20]]

        # Apply price filter if detected
        if price_ceiling is not None:
            top = [it for it in top if it.get("price_rupees", 9999) <= price_ceiling]

        return top[:12]


    # ── Regex-based recipe intent classifier (no LLM needed) ──────────────
    _RECIPE_PATTERNS = [
        r"\b(recipe|recipes)\b",
        r"\bhow\s+(?:do\s+(?:i|we)|to|can\s+(?:i|we))\s+(?:make|cook|prepare|bake|fry|boil|roast|grill)\b",
        r"\b(?:steps?|instructions?|procedure)\s+(?:to|for)\s+(?:make|cook|prepare)\b",
        r"\b(?:make|cook|prepare|bake)\s+(?:me\s+)?(?:a|an|some)?\s*\w+\s+(?:dish|meal|curry|biryani|dosa|roti|bread|cake|soup|salad|pasta|noodle)\b",
        r"\bingredients\s+(?:for|to\s+make)\b",
        r"\bwhat\s+(?:do\s+i\s+need|ingredients)\s+(?:for|to\s+(?:make|cook))\b",
    ]

    def _is_recipe_query(self, query: str) -> bool:
        """Pure-regex recipe intent check — no LLM call needed."""
        import re
        q = query.lower()
        return any(re.search(p, q) for p in self._RECIPE_PATTERNS)


    def tool_search_inventory(self, query: str) -> List[Dict[str, Any]]:
        """Search the store inventory for products matching the query."""
        query_lower = query.lower().strip()
        ing_tokens = set(t for t in query_lower.split() if len(t) >= 3 or t in ["ghee", "oil"])
        
        matches = []
        for item in self.inventory:
            item_name = item.get("name", "").lower()
            item_slug = item.get("slug", "").lower()
            
            # Simple scoring
            item_tokens = set(item_name.split() + item_slug.split("-"))
            score = len(ing_tokens.intersection(item_tokens))
            if query_lower in item_name or item_name in query_lower:
                score += 5
                
            if score > 0:
                matches.append((item, score))
                
        # Sort by score descending
        matches.sort(key=lambda x: x[1], reverse=True)
        return [item for item, score in matches[:10]]

    def tool_add_to_cart(self, user_id: str, sku: str, quantity: int = 1, mutations: List[Dict[str, Any]] = None) -> str:
        # Find item details
        item = next((x for x in self.inventory if x.get("sku") == sku), None)
        if not item:
            return f"Error: SKU '{sku}' not found in inventory."
            
        success = execute_database_cart_addition(user_id, sku, quantity)
        if success and mutations is not None:
            mutations.append({
                "action": "add",
                "sku": sku,
                "name": item.get("name"),
                "price": float(item.get("price_rupees", 0.0)),
                "quantity": quantity,
                "thumbnail_url": item.get("thumbnail_url", "")
            })
        return f"Successfully added {quantity} x '{item.get('name')}' (SKU: {sku}) to the cart."

    def tool_remove_from_cart(self, user_id: str, sku: str, quantity: int = 1, mutations: List[Dict[str, Any]] = None) -> str:
        item = next((x for x in self.inventory if x.get("sku") == sku), None)
        if not item:
            return f"Error: SKU '{sku}' not found in inventory."
            
        success = execute_database_cart_removal(user_id, sku, quantity)
        if success and mutations is not None:
            mutations.append({
                "action": "remove",
                "sku": sku,
                "name": item.get("name"),
                "price": float(item.get("price_rupees", 0.0)),
                "quantity": quantity
            })
        return f"Successfully removed/decremented {quantity} x '{item.get('name')}' (SKU: {sku}) from the cart."

    def tool_clear_cart(self, user_id: str, mutations: List[Dict[str, Any]] = None) -> str:
        live_cart_memory.clear_cart(user_id)
        if mutations is not None:
            mutations.append({
                "action": "clear"
            })
        return "Successfully cleared all items from the cart."

    async def _generate_and_match_recipe_internal(self, user_id: str, current_cart_slugs: List[str], dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Generates the recipe and runs matching against catalog.
        This contains the original process_recipe_workflow implementation.
        """
        try:
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
            
            # 1. Generate and match recipe in a single LLM call
            recipe_result = await self.recipe_agent.generate_and_match_recipe(dish_query, servings, self.inventory)
            
            instructions_list = recipe_result.get("instructions", [])
            ingredients = recipe_result.get("ingredients", [])

            missing_ingredients_map = {}
            cart_additions_map = {}
            normalized_cart_slugs = [str(slug).lower().strip() for slug in current_cart_slugs]

            # Parse and compose the final missing ingredients and cart additions lists
            for ing in ingredients:
                ing_name = clean_ingredient_name(ing.get("name", ""), ing.get("unit", ""))
                ing_name_lower = ing_name.lower().strip()
                ing_sku = ing.get("sku", "UNKNOWN")
                
                # Deduplicate slug format
                ing_slug = ing.get("slug", ing_name_lower.replace(" ", "-")).lower().strip()
                if not ing_slug:
                    ing_slug = ing_name_lower.replace(" ", "-")

                if ing_slug in normalized_cart_slugs:
                    continue

                final_qty = format_ingredient_quantity(ing.get('quantity'), ing.get('unit'))

                if ing_sku != "UNKNOWN":
                    # Look up actual item from catalog to resolve name, slug, price, and thumbnail_url
                    actual_item = next((item for item in self.inventory if item.get("sku") == ing_sku), None)
                    if actual_item:
                        item_sku = actual_item.get("sku")
                        item_slug = actual_item.get("slug", ing_slug).lower().strip()
                        
                        if item_slug in normalized_cart_slugs:
                            continue

                        if item_sku in missing_ingredients_map:
                            missing_ingredients_map[item_sku]["required_quantity"] += f" + {final_qty}"
                        else:
                            missing_ingredients_map[item_sku] = {
                                "sku": item_sku,
                                "slug": item_slug,
                                "name": actual_item.get("name"),
                                "price_rupees": float(actual_item.get("price_rupees", 0.0)),
                                "thumbnail_url": actual_item.get("thumbnail_url", ""),
                                "required_quantity": final_qty,
                                "agent_tool_status": "Committed to DB"
                            }
                        
                        if item_sku in cart_additions_map:
                            cart_additions_map[item_sku]["quantity"] += 1
                        else:
                            cart_additions_map[item_sku] = {
                                "sku": item_sku,
                                "name": actual_item.get("name"),
                                "price": float(actual_item.get("price_rupees", 0.0)),
                                "quantity": 1
                            }
                else:
                    # Clean up substitute list if any (ensure thumbnail URLs from inventory match if applicable)
                    cleaned_subs = []
                    for sub in ing.get("substitutes", []):
                        sub_sku = sub.get("sku")
                        if sub_sku:
                            actual_sub = next((item for item in self.inventory if item.get("sku") == sub_sku), None)
                            if actual_sub:
                                cleaned_subs.append({
                                    "sku": sub_sku,
                                    "name": actual_sub.get("name"),
                                    "price_rupees": float(actual_sub.get("price_rupees", 0.0)),
                                    "thumbnail_url": actual_sub.get("thumbnail_url", "")
                                })
                            else:
                                cleaned_subs.append(sub)
                        else:
                            cleaned_subs.append(sub)

                    missing_ingredients_map[ing_slug] = {
                        "sku": "UNKNOWN",
                        "slug": ing_slug,
                        "name": ing_name,
                        "price_rupees": 0.0,
                        "thumbnail_url": "",
                        "required_quantity": final_qty,
                        "substitutes": cleaned_subs
                    }

            return {
                "dish": str(dish_query),
                "servings": int(servings),
                "instructions": list(instructions_list),
                "recipe_instructions": list(instructions_list),
                "ingredients": [
                    {
                        "name": clean_ingredient_name(ing.get("name", ""), ing.get("unit", "")),
                        "quantity": format_ingredient_quantity(ing.get("quantity"), ing.get("unit"))
                    }
                    for ing in ingredients
                ],
                "parsed_ingredients": [],
                "missing_ingredients": list(missing_ingredients_map.values()),
                "cart_additions": list(cart_additions_map.values())
            }
            
        except Exception as e:
            import traceback
            print("❌ [CRITICAL PIPELINE EXCEPTION]")
            traceback.print_exc()
            return {"error": str(e), "missing_ingredients": [], "cart_additions": []}

    async def process_recipe_workflow(
        self,
        user_id: str = "anonymous_user",
        current_cart_slugs: List[str] = None,
        dish_query: str = "",
        servings: int = 2,
        chat_history: List[Dict[str, Any]] = None,
        current_cart: List[Dict[str, Any]] = None,
        image_base64: str = None
    ) -> Dict[str, Any]:
        generator = self.process_recipe_workflow_stream(
            user_id=user_id,
            current_cart_slugs=current_cart_slugs,
            dish_query=dish_query,
            servings=servings,
            chat_history=chat_history,
            current_cart=current_cart,
            image_base64=image_base64
        )
        full_text = ""
        recipe_data = None
        mutations = None
        async for chunk_str in generator:
            if not chunk_str.strip():
                continue
            try:
                chunk = json.loads(chunk_str.strip())
                if "text_chunk" in chunk:
                    full_text += chunk["text_chunk"]
                else:
                    if "recipe" in chunk:
                        recipe_data = chunk["recipe"]
                    if "cart_mutations" in chunk:
                        mutations = chunk["cart_mutations"]
            except Exception as parse_err:
                print(f"Error parsing generator chunk: {parse_err}")
        # Handle case where the LLM may have output a JSON wrapper (legacy behavior)
        response_text = full_text.strip()
        if response_text.startswith('{'):
            try:
                parsed = json.loads(response_text)
                if isinstance(parsed, dict) and "response_text" in parsed:
                    response_text = parsed["response_text"]
            except Exception:
                pass  # Not JSON, use as-is
        
        return {
            "response_text": response_text,
            "recipe": recipe_data,
            "cart_mutations": mutations
        }

    async def process_recipe_workflow_stream(
        self,
        user_id: str = "anonymous_user",
        current_cart_slugs: List[str] = None,
        dish_query: str = "",
        servings: int = 2,
        chat_history: List[Dict[str, Any]] = None,
        current_cart: List[Dict[str, Any]] = None,
        image_base64: str = None
    ):
        mutations: List[Dict[str, Any]] = []
        recipe_data = None

        # Format current cart details
        cart_details_str = "No items in cart."
        if current_cart:
            cart_details_str = "\n".join([
                f"- {item.get('name', 'Unknown')} (Quantity: {item.get('quantity', 1)}, SKU: {item.get('sku', 'UNKNOWN')})"
                for item in current_cart
            ])
        elif current_cart_slugs:
            cart_details_str = "\n".join([
                f"- {slug} (Quantity: 1)"
                for slug in current_cart_slugs
            ])

        # ── Pre-fetch relevant inventory items for this query ──────────────
        prefetched_items: List[Dict[str, Any]] = []
        if dish_query and not image_base64:
            prefetched_items = self._prefetch_relevant_items(dish_query)

        # ── Fast-path: if clearly a recipe query, skip LLM tool-call round-trip ──
        if dish_query and not image_base64 and self._is_recipe_query(dish_query):
            print(f"🍳 [RECIPE FAST-PATH] Detected recipe intent in: {dish_query!r}")
            recipe_data = await self._generate_and_match_recipe_internal(
                user_id=user_id,
                current_cart_slugs=current_cart_slugs,
                dish_query=dish_query,
                servings=servings
            )
            yield json.dumps({"text_chunk": f"Here's your recipe for {dish_query}! I've matched the ingredients to our store catalog. Check the recipe card below 🍽️"}) + "\n"
            yield json.dumps({"cart_mutations": mutations if mutations else None, "recipe": recipe_data}) + "\n"
            return

        # Format the catalog details for system prompt
        # When prefetch found relevant items, use those (with price) instead of the full catalog
        # to save tokens. Fall back to full catalog for open-ended or greeting queries.
        catalog_str = "No items in catalog."
        if self.inventory:
            if prefetched_items:
                catalog_str = (
                    "(Showing items most relevant to this query — full catalog available via search_inventory tool)\n"
                    + "\n".join(
                        f"- Name: {it.get('name')} | SKU: {it.get('sku')} | Price: ₹{it.get('price_rupees', '?')}"
                        for it in prefetched_items
                    )
                )
            else:
                catalog_str = "\n".join([
                    f"- Name: {item.get('name')} | SKU: {item.get('sku')}"
                    for item in self.inventory
                ])

        
        tools_definitions = [
            {
                "type": "function",
                "function": {
                    "name": "search_inventory",
                    "description": "Search the store inventory for products matching the query term. Returns items with SKU, name, price, and slug.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "The search term to look for in the catalog (e.g. 'snickers', 'milk', 'eggs')."
                            }
                        },
                        "required": ["query"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "add_to_cart",
                    "description": "Add a specific product to the user's cart by its SKU.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "sku": {
                                "type": "string",
                                "description": "The SKU of the product to add."
                            },
                            "quantity": {
                                "type": "integer",
                                "description": "The quantity to add.",
                                "default": 1
                            }
                        },
                        "required": ["sku"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "remove_from_cart",
                    "description": "Remove or decrement a product from the user's cart by its SKU.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "sku": {
                                "type": "string",
                                "description": "The SKU of the product to remove/decrement."
                            },
                            "quantity": {
                                "type": "integer",
                                "description": "The quantity to remove/decrement.",
                                "default": 1
                            }
                        },
                        "required": ["sku"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "generate_and_match_recipe",
                    "description": "Generate a cooking recipe for a SPECIFIC dish name (e.g. 'pasta', 'veg biryani'). DO NOT call this tool for general shopping recommendations, breakfast item suggestions, snacks, greetings, or conversational questions.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "dish_name": {
                                "type": "string",
                                "description": "The name of the specific dish to generate a recipe for (e.g., 'Tomato Soup'). Do NOT pass general queries or lists here."
                            },
                            "servings": {
                                "type": "integer",
                                "description": "The number of servings.",
                                "default": 2
                            }
                        },
                        "required": ["dish_name"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "clear_cart",
                    "description": "ONLY call this tool when the user EXPLICITLY requests to clear, empty, or wipe their entire cart (e.g. 'clear my cart', 'empty my cart', 'remove all items', 'start fresh'). NEVER call this tool when the user wants to ADD items, REMOVE a specific item, or asks about the cart. Calling this tool destroys the entire cart, so it must be used with extreme caution.",
                    "parameters": {
                        "type": "object",
                        "properties": {}
                    }
                }
            }
        ]

        messages = [
            {
                "role": "system",
                "content": f"""You are the Qless Assistant, an intelligent, conversational AI retail and cooking assistant for the Qless self-checkout store.
You help users with shopping suggestions, chitchat, cooking recipe inquiries, and real-time cart modifications.

Active User ID: {user_id}

Current Cart Items:
{cart_details_str}

*IMPORTANT NOTE ON CART STATE*: The "Current Cart Items" list above is the absolute, authoritative truth of what is currently in the user's cart. Any past requests in the chat history (e.g., "add 4 items") have already been fully executed and are already included in the list above. Refer only to the list above to know what is in the cart.
- Even if a product name mentioned in the chat history (e.g., "Cadbury Fuse") is slightly different from the name in the "Current Cart Items" list (e.g., "Cadbury Fuse Chocolate Bar"), they refer to the same item and you must NOT sum their quantities. The quantity in the "Current Cart Items" list is the ONLY quantity in the cart.
- Any item mentioned in the chat history that is NOT in the "Current Cart Items" list above has been removed and is NO LONGER in the cart. Do NOT list it or assume it is still in the cart.
- Do NOT sum, add, or double-count quantities from the chat history with the list above.

⚠️ CRITICAL — STALE CART DATA IN HISTORY: The chat history you receive may contain old assistant responses that listed cart contents (e.g., "Current Cart Items: Lays x5"). These are SNAPSHOTS of a PAST state and are ALWAYS WRONG about the current cart. The cart can be modified at any time from outside this chat (e.g., via the store scanner or manual clearing). You MUST COMPLETELY IGNORE any cart quantities or item lists mentioned in previous assistant messages. The ONLY correct cart state is the "Current Cart Items" block at the top of this system prompt. Treat any cart listing in the chat history as if it were from a different session entirely.


### Guidelines:
1. **Conversational Responses**: Be extremely friendly, natural, and helpful. Always write your final response as plain, readable text — never as JSON or code blocks.
2. **Tool Usage**: Use the tool-calling interface to search inventory, add/remove items, or match recipes.
3. **No Raw Tool Tags**: Do NOT write tool calls as raw text, XML, or `<function>` tags in your response content. Only use the official API tool-calling mechanism.
4. **No Hallucinations**: Only use the exact SKUs found in the inventory catalog.
4b. **CRITICAL — DO NOT CLEAR CART BY MISTAKE**: The `clear_cart` tool PERMANENTLY destroys the entire cart. You MUST NEVER call `clear_cart` when the user says "add", "buy", "get", or anything that sounds like they want to put something in the cart. Only call `clear_cart` if the user uses an explicit phrase like: "clear my cart", "empty cart", "wipe the cart", "remove everything", "start over". If in doubt, do NOT call it.
5. **Displaying Cart and Cart Quantities**:
   - When asked to show, display, or list the cart, list each item on a new line in a clear, user-friendly bulleted list showing its name and quantity (e.g., "- Product Name: 2"). Do not list the SKU to keep the response clean. Do not call any tools to list the cart; rely strictly on the "Current Cart Items" list provided above.
   - **CRITICAL**: The "Current Cart Items" block represents the absolute, exact, and up-to-date state of the user's cart. Past chat history requests (e.g., "add 4 items") are already fully processed and reflected in "Current Cart Items". Do NOT sum, add, or accumulate quantities from the chat history with the "Current Cart Items". Do NOT assume the user has items that are not explicitly present in the "Current Cart Items" list.
5b. **Cart Action Confirmations**: After successfully adding, removing, or clearing items from the cart via a tool call, respond with a short, friendly confirmation message ONLY about what you just did (e.g., "Done! I've added 5 Lays to your cart 🛒", "All clear! Your cart is now empty 🧹"). **NEVER list the full cart state or say 'Current Cart Items:' after an action** — this creates stale data in the chat history that causes confusion on future requests. Only list cart contents if the user explicitly asks "what's in my cart?" or "show my cart".
6. **Displaying Search Results / Products**: When listing products from inventory searches or queries:
   - Always display them as a clean bulleted list on new lines (rather than inline or in paragraphs) for better readability.
   - Show only the human-friendly product names.
   - Do NOT display product SKUs (e.g., "QLS-XXXX") in your final response text unless the user specifically asks for the SKU.
7. **Semantic Relevance Filtering**: The `search_inventory` tool performs a keyword-based search and may return items that merely contain the search term in their name (e.g., searching for "milk" returns "Cadbury Dairy Milk Chocolate" and "Nestle Milkybar White Chocolate", and searching for "onion" returns "Cream and Onion Chips"). When responding to the user, you must intelligently filter these results to only include products that are semantically relevant to the user's actual request. For example, if the user asks for "milk" or raw cooking ingredients, do not list chocolates, chips, or baby foods even if they appeared in the search results.
8. **General Shopping Suggestions and Chitchat**:
   - If the user asks for general shopping recommendations, breakfast item suggestions, snacks, greetings, or conversational questions, do NOT call the `generate_and_match_recipe` tool.
   - Instead, respond conversationally using products that are available in the 'Available Store Catalog' list below (e.g., for breakfast suggest "Nestle Ceregrow Multigrain Cereal", "Standardised Milk", "Organic Eggs", etc.).
   - Only call the `generate_and_match_recipe` tool when the user is explicitly requesting a recipe or cooking instructions for a specific dish.

Available Store Catalog (SKUs and Names):
{catalog_str}

*PRO-TIP FOR CATALOG USAGE*: Since you are provided with the absolute list of all available items in the store in the 'Available Store Catalog' section above, you can and must directly select the matching SKU and call `add_to_cart` or `remove_from_cart` immediately without needing to search the inventory first. Use the `search_inventory` tool ONLY if the item name requested by the user is ambiguous or not clearly matching any of the items in the catalog above.
"""
            }
        ]

        if chat_history:
            for item in chat_history:
                role = "user" if item.get("is_user") else "assistant"
                messages.append({
                    "role": role,
                    "content": item.get("text") or ""
                })

        # Determine model to use (switch to vision-capable model if image is attached)
        model_to_use = self.model
        if image_base64:
            model_to_use = "meta-llama/llama-4-scout-17b-16e-instruct"
            user_content = [
                {
                    "type": "text",
                    "text": dish_query if dish_query else "What is this image? Tell me if I should add it to my cart or how I can cook with it."
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{image_base64}"
                    }
                }
            ]
        else:
            user_content = dish_query
            # ── Pre-fetch relevant inventory items and inject into user message ──
            if dish_query and not image_base64:
                prefetched = self._prefetch_relevant_items(dish_query)
                if prefetched:
                    product_lines = "\n".join(
                        f"- {it['name']} (SKU: {it['sku']}, Price: ₹{it.get('price_rupees', '?')})"
                        for it in prefetched
                    )
                    user_content = (
                        f"{dish_query}\n\n"
                        f"[Context – Matching Store Products]\n"
                        f"{product_lines}\n"
                        f"(Use this list to answer directly; only call search_inventory if the user's request is "
                        f"not covered by these results.)"
                    )

        # Add the latest user message
        messages.append({
            "role": "user",
            "content": user_content
        })

        executed_tool_calls = set()
        for loop_iter in range(3):
            content = ""
            tool_calls_dict = {}
            try:
                loop = asyncio.get_event_loop()
                def get_stream():
                    return self.client.chat.completions.create(
                        model=model_to_use,
                        messages=messages,
                        tools=tools_definitions,
                        tool_choice="auto",
                        max_tokens=1024,
                        temperature=0.3,
                        stream=True
                    )
                
                completion_stream = await loop.run_in_executor(None, get_stream)
                
                role = "assistant"
                for chunk in completion_stream:
                    delta = chunk.choices[0].delta
                    if delta.content:
                        content += delta.content
                        yield json.dumps({"text_chunk": delta.content}) + "\n"
                    
                    if delta.tool_calls:
                        for tc in delta.tool_calls:
                            idx = tc.index
                            if idx not in tool_calls_dict:
                                tool_calls_dict[idx] = {
                                    "id": tc.id or "",
                                    "type": "function",
                                    "function": {
                                        "name": tc.function.name or "",
                                        "arguments": tc.function.arguments or ""
                                    }
                                }
                            else:
                                if tc.id:
                                    tool_calls_dict[idx]["id"] += tc.id
                                if tc.function.name:
                                    tool_calls_dict[idx]["function"]["name"] += tc.function.name
                                if tc.function.arguments:
                                    tool_calls_dict[idx]["function"]["arguments"] += tc.function.arguments
            except Exception as e:
                print(f"⚠️ [AGENT LLM FAULT] {e}")
                if not content:
                    yield json.dumps({"text_chunk": "Sorry, I'm having trouble connecting right now. Please try again in a moment."}) + "\n"
                break

            # Reconstruct SimpleNamespace for internal checks
            tool_calls = []
            if tool_calls_dict:
                from types import SimpleNamespace
                for idx in sorted(tool_calls_dict.keys()):
                    tc_data = tool_calls_dict[idx]
                    tool_calls.append(SimpleNamespace(
                        id=tc_data["id"],
                        type="function",
                        function=SimpleNamespace(
                            name=tc_data["function"]["name"],
                            arguments=tc_data["function"]["arguments"]
                        )
                    ))
            
            from types import SimpleNamespace
            msg = SimpleNamespace(
                role=role,
                content=content if content else None,
                tool_calls=tool_calls if tool_calls else None
            )

            # Append plain dict to message history list for API compatibility
            api_msg = {
                "role": role,
                "content": content if content else None
            }
            if tool_calls_dict:
                api_msg["tool_calls"] = [
                    {
                        "id": tc_data["id"],
                        "type": "function",
                        "function": {
                            "name": tc_data["function"]["name"],
                            "arguments": tc_data["function"]["arguments"]
                        }
                    }
                    for tc_data in tool_calls_dict.values()
                ]
            messages.append(api_msg)

            if not msg.tool_calls:
                break

            # Check loop prevention first
            should_break = False
            for tool_call in msg.tool_calls:
                call_signature = (tool_call.function.name, tool_call.function.arguments)
                if call_signature in executed_tool_calls:
                    print(f"🔁 [LOOP PREVENTED] Agent attempted to call tool '{tool_call.function.name}' with identical arguments {tool_call.function.arguments} again. Breaking loop.")
                    should_break = True
                    break
                executed_tool_calls.add(call_signature)

            if should_break:
                break

            # Execute tool calls in parallel
            async def execute_single_tool(tool_call) -> Dict[str, Any]:
                nonlocal recipe_data
                tool_name = tool_call.function.name
                tool_args_str = tool_call.function.arguments
                arguments = json.loads(tool_args_str)
                print(f"🛠️ [TOOL CALL] {tool_name} with args {arguments}")

                result_str = ""
                if tool_name == "search_inventory":
                    res = await loop.run_in_executor(None, lambda: self.tool_search_inventory(arguments.get("query", "")))
                    result_str = json.dumps(res)
                elif tool_name == "add_to_cart":
                    res = await loop.run_in_executor(None, lambda: self.tool_add_to_cart(user_id, arguments.get("sku"), arguments.get("quantity", 1), mutations))
                    result_str = res
                elif tool_name == "remove_from_cart":
                    res = await loop.run_in_executor(None, lambda: self.tool_remove_from_cart(user_id, arguments.get("sku"), arguments.get("quantity", 1), mutations))
                    result_str = res
                elif tool_name == "clear_cart":
                    res = await loop.run_in_executor(None, lambda: self.tool_clear_cart(user_id, mutations))
                    result_str = res
                    # Signal the outer loop to short-circuit with a canned response
                    return {
                        "role": "tool",
                        "tool_call_id": tool_call.id,
                        "name": tool_name,
                        "content": result_str,
                        "__fast_path_response": "Done! Your cart has been cleared. 🧹 Let me know if you'd like to add anything!"
                    }
                elif tool_name == "generate_and_match_recipe":
                    recipe_data = await self._generate_and_match_recipe_internal(
                        user_id=user_id,
                        current_cart_slugs=current_cart_slugs,
                        dish_query=arguments.get("dish_name"),
                        servings=arguments.get("servings", servings)
                    )
                    result_str = "Successfully generated recipe."
                else:
                    result_str = f"Error: Tool '{tool_name}' not found."

                return {
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "name": tool_name,
                    "content": result_str
                }

            tasks = [execute_single_tool(tc) for tc in msg.tool_calls]
            responses = await asyncio.gather(*tasks)

            # Check if any tool requested a fast-path early exit
            fast_path_msg = None
            for resp in responses:
                if resp and resp.get("__fast_path_response"):
                    fast_path_msg = resp.pop("__fast_path_response")
                    break

            messages.extend(responses)

            if fast_path_msg:
                yield json.dumps({"text_chunk": fast_path_msg}) + "\n"
                break

            if should_break:
                break

        # Yield final metadata chunk
        yield json.dumps({
            "cart_mutations": mutations if mutations else None,
            "recipe": recipe_data if recipe_data else None
        }) + "\n"
