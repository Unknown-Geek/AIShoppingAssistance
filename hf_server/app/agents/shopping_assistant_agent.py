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

    async def _classify_query(self, query: str) -> Dict[str, Any]:
        """
        Classifies user query into 'recipe' or 'conversational'.
        If conversational, generates response text.
        """
        prompt = f"""Analyze the following user query:
"{query}"

Classify this query as one of:
- "recipe": the user is explicitly asking for a recipe, cooking steps, or instructions to prepare a specific dish/meal (e.g. "how to cook pasta", "veg biryani recipe", "how do I bake a cake").
- "conversational": the user is greeting, chitchatting, asking generic questions about the store/app, asking for shopping recommendations/suggestions, or asking for general advice (e.g., "hi", "who are you?", "suggest some healthy snacks", "do you sell milk?", "is organic food healthy?").

If classified as "conversational", also generate a helpful, natural, friendly response as the AI retail assistant. Do not try to generate a structured recipe for conversational queries.

Return ONLY a valid JSON object in this format:
{{
  "classification": "recipe" or "conversational",
  "response_text": "your friendly chatbot response goes here if conversational, otherwise null"
}}"""

        messages = [
            {
                "role": "system",
                "content": "You are a helpful retail and cooking assistant for the Qless self-checkout store. You must categorize queries and provide chat responses when appropriate, formatted strictly as a json object matching the requested schema."
            },
            {"role": "user", "content": prompt}
        ]

        try:
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self.client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=messages,
                    max_tokens=256,
                    temperature=0.3,
                    response_format={"type": "json_object"}
                )
            )
            content = response.choices[0].message.content or ""
            content = content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
            return json.loads(content)
        except Exception as e:
            print(f"⚠️ [WARNING] Query classification failed: {e}")
            return {"classification": "recipe", "response_text": None}

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
                    
                    # Deduplicate stutters
                    if unit and unit.lower() in qty.lower():
                        ing_str = f"{qty} {name}".strip()
                    else:
                        ing_str = f"{qty} {unit} {name}".strip()
                else:
                    ing_str = str(ing).strip()

                if ing_str:
                    parsed = self.quantity_parser.execute(ing_str)
                    
                    # Deep-clean inner tool output stutter mappings
                    raw_in = parsed.get("raw_input", "")
                    for u_word in ["tablespoons", "tablespoon", "teaspoons", "teaspoon", "cups", "cup", "pieces", "piece"]:
                        if raw_in.lower().count(u_word) > 1:
                            raw_in = f"{parsed.get('quantity', '')} {parsed.get('unit', '')} {parsed.get('name', '')}".replace("  ", " ").strip()
                            parsed["raw_input"] = raw_in
                            break
                            
                    parsed_ingredients.append(parsed)

            # GATE 2: BACKEND CATALOG FILTER MATRIX
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

            missing_ingredients_map = {}
            cart_additions_map = {}
            normalized_cart_slugs = [str(slug).lower().strip() for slug in current_cart_slugs]

            # STRUCTURAL COMPOSITION GENERATION
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

                # PAYLOAD COMPOSITION & DATABASE WRITE BACK TRANSACTION
                if final_match and final_match.get("sku"):
                    item_sku = final_match.get("sku")
                    item_slug = final_match.get("slug", ing_slug_fallback).lower().strip()
                    
                    if item_slug in normalized_cart_slugs:
                        continue

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
                    subs = []
                    if ai_match and isinstance(ai_match, dict) and "substitutes" in ai_match:
                        subs = ai_match["substitutes"]
                    missing_ingredients_map[ing_slug_fallback] = {
                        "sku": "UNKNOWN",
                        "slug": ing_slug_fallback,
                        "name": ing_name,
                        "price_rupees": 0.0,
                        "thumbnail_url": "",
                        "required_quantity": final_qty,
                        "substitutes": subs
                    }

            return {
                "dish": str(dish_query),
                "servings": int(servings),
                "recipe_instructions": list(instructions_list),
                "parsed_ingredients": list(parsed_ingredients),
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
        current_cart: List[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        mutations = []
        recipe_data = None
        
        # Format the current cart details
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
                    "description": "Generate a cooking recipe for a specific dish and match its ingredients against the store inventory.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "dish_name": {
                                "type": "string",
                                "description": "The name of the dish."
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
                    "description": "Clear all items from the user's shopping cart.",
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


### Guidelines:
1. **Conversational Responses**: Be extremely friendly, natural, and helpful.
2. **Tool Usage**: Use the tool-calling interface to search inventory, add/remove items, or match recipes.
3. **No Raw Tool Tags**: Do NOT write tool calls as raw text, XML, or `<function>` tags in your response content. Only use the official API tool-calling mechanism.
4. **No Hallucinations**: Only use the exact SKUs found in the inventory search.
5. **Displaying Cart and Cart Quantities**:
   - When asked to show, display, or list the cart, list each item on a new line in a clear, user-friendly bulleted list showing its name and quantity (e.g., "- Product Name: 2"). Do not list the SKU to keep the response clean. Do not call any tools to list the cart; rely strictly on the "Current Cart Items" list provided above.
   - **CRITICAL**: The "Current Cart Items" block represents the absolute, exact, and up-to-date state of the user's cart. Past chat history requests (e.g., "add 4 items") are already fully processed and reflected in "Current Cart Items". Do NOT sum, add, or accumulate quantities from the chat history with the "Current Cart Items". Do NOT assume the user has items that are not explicitly present in the "Current Cart Items" list.
6. **Displaying Search Results / Products**: When listing products from inventory searches or queries:
   - Always display them as a clean bulleted list on new lines (rather than inline or in paragraphs) for better readability.
   - Show only the human-friendly product names.
   - Do NOT display product SKUs (e.g., "QLS-XXXX") in your final response text unless the user specifically asks for the SKU.
7. **Semantic Relevance Filtering**: The `search_inventory` tool performs a keyword-based search and may return items that merely contain the search term in their name (e.g., searching for "milk" returns "Cadbury Dairy Milk Chocolate" and "Nestle Milkybar White Chocolate", and searching for "onion" returns "Cream and Onion Chips"). When responding to the user, you must intelligently filter these results to only include products that are semantically relevant to the user's actual request. For example, if the user asks for "milk" or raw cooking ingredients, do not list chocolates, chips, or baby foods even if they appeared in the search results.
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

        # Add the latest user message
        messages.append({
            "role": "user",
            "content": dish_query
        })

        executed_tool_calls = set()
        for loop_iter in range(3):
            try:
                loop = asyncio.get_event_loop()
                completion = await loop.run_in_executor(
                    None,
                    lambda: self.client.chat.completions.create(
                        model=self.model,
                        messages=messages,
                        tools=tools_definitions,
                        tool_choice="auto",
                        max_tokens=1024,
                        temperature=0.3
                    )
                )
            except Exception as e:
                print(f"⚠️ [AGENT LLM FAULT] {e}")
                break

            msg = completion.choices[0].message
            messages.append(msg)

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
            messages.extend(responses)

            if should_break:
                break

        messages.append({
            "role": "user",
            "content": """Provide your final response as a JSON object containing only a single key "response_text" with your friendly chatbot response to the user.
Example:
{
  "response_text": "I have added 2 Snickers to your cart."
}

Return ONLY this JSON object. No markdown formatting, no code fences, no extra text."""
        })

        try:
            loop = asyncio.get_event_loop()
            final_completion = await loop.run_in_executor(
                None,
                lambda: self.client.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    max_tokens=1024,
                    temperature=0.2,
                    response_format={"type": "json_object"}
                )
            )
            final_content = final_completion.choices[0].message.content or ""
            final_content = final_content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
            final_json = json.loads(final_content)
            
            # Safeguard "response_text" key
            if not isinstance(final_json, dict) or "response_text" not in final_json:
                final_json = {"response_text": str(final_json)}
                
            final_json["cart_mutations"] = mutations if mutations else None
            final_json["recipe"] = recipe_data if recipe_data else None
                
            return final_json
        except Exception as e:
            print(f"⚠️ [FINAL FORMAT FAULT] {e}")
            return {
                "response_text": "I processed your request, but had trouble formatting the response.",
                "recipe": recipe_data,
                "cart_mutations": mutations
            }