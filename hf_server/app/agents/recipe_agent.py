import os
import json
import re
from typing import Dict, Any, List
from groq import Groq
from dotenv import load_dotenv

# Explicitly load .env file from the hf_server directory
base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dotenv_path = os.path.join(base_dir, ".env")
load_dotenv(dotenv_path=dotenv_path, override=True)

# Hard Category Guardrail: substrings that identify non-cooking items
# (household cleaners, air fresheners, baby formulas, health drinks, etc.)
# Items matching any of these in their name or slug are excluded from the
# inventory before the LLM ever sees them.
_NON_FOOD_SUBSTRINGS = [
    "air freshener", "air-freshener", "car air freshener",
    "room spray", "room-spray",
    "cleaner", "disinfectant", "flushmatic",
    "shampoo", "hair colour", "water bottle", "water-bottle",
    "cerelac", "ceregrow", "lactogen", "similac",
    "health drink", "health-drink", "horlicks", "bournvita",
    "power pocket", "power-pocket",
]

class RecipeAgent:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            print("[WARNING] GROQ_API_KEY not detected, using mock key")
            api_key = "gsk_mock_key_placeholder_for_verification_only"
        self.client = Groq(api_key=api_key)

    async def generate(self, dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Generates a detailed recipe using Groq forced output structures.
        """
        prompt = f"""Generate a detailed recipe for {dish_query} for {servings} servings.

Return ONLY valid JSON in this exact format (no markdown strings, no code fences):
{{
  "dish": "{dish_query}",
  "servings": {servings},
  "instructions": ["step 1", "step 2"],
  "ingredients": [
    {{"name": "Ingredient Name", "quantity": "amount", "unit": "unit"}}
  ]
}}

CRITICAL RULE — Ingredient Isolation: Every single ingredient must be its own independent dictionary entry in the "ingredients" list. NEVER group multiple items together in a single line like "Spices (Turmeric, Salt, Chili Powder)". Break them down into separate entries: {{"name": "Turmeric Powder", "quantity": "1/2", "unit": "teaspoon"}}, {{"name": "Red Chili Powder", ...}}, and {{"name": "Salt", ...}}."""

        messages = [
            {
                "role": "system", 
                "content": "You are an expert chef assistant. You must provide your output strictly formatted as a json object matching the structural schema requested."
            },
            {"role": "user", "content": prompt}
        ]

        response = self.client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=messages,
            max_tokens=1024,
            temperature=0.2,
            response_format={"type": "json_object"}
        )

        content = response.choices[0].message.content or ""
        content = content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()

        try:
            return json.loads(content)
        except json.JSONDecodeError:
            return {
                "raw_response": content,
                "dish": dish_query,
                "servings": servings,
                "instructions": [],
                "ingredients": []
            }

    def _is_non_food(self, item: Dict[str, Any]) -> bool:
        """Category guardrail: check if an inventory item is a non-cooking item
        (household cleaner, air freshener, baby food, health drink, etc.)"""
        text = (item.get("name", "") + " " + item.get("slug", "")).lower()
        return any(sub in text for sub in _NON_FOOD_SUBSTRINGS)

    def _filter_relevant_inventory(self, parsed_ingredients: List[Dict[str, Any]], inventory_catalog: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Pre-filter inventory to only items whose name/slug shares tokens with ingredient names.
        Then apply Category Guardrail to drop non-cooking items entirely.
        This prevents the LLM from seeing completely unrelated items (e.g. toilet cleaner
        alongside spices) and hallucinating matches."""
        candidates = []
        seen = set()

        # Sauce/condiment guardrail: prevent condiment products (sauce, ketchup, jam, spread)
        # from matching raw ingredients that don't mention the condiment category.
        # e.g. "Sweet Onion Sauce" must NOT match "Onion" — sauce != raw vegetable.
        # "paste" is intentionally excluded since pastes (Ginger Garlic Paste) are valid ingredient matches.
        sauce_keywords = {"sauce", "ketchup", "jam", "spread"}

        for ing in parsed_ingredients:
            ing_name = ing.get("name", "").lower().strip()
            # Clean out common leakage remnants that survived parsing
            ing_name = re.sub(r"\bas needed\b|\binch piece\b", "", ing_name).strip()

            # Split into tokens: keep 3+ char words, plus short staples like "ghee"
            ing_tokens = [t for t in ing_name.split() if len(t) >= 3 or t == "ghee"]

            if not ing_tokens and not ing_name:
                continue

            for item in inventory_catalog:
                # Category Guardrail: skip non-food items entirely
                if self._is_non_food(item):
                    continue

                item_name = item.get("name", "").lower()
                item_slug = item.get("slug", "").lower()

                # Sauce Guardrail: if the item is a condiment and the ingredient is not, skip
                if any(sk in item_name for sk in sauce_keywords) and not any(sk in ing_name for sk in sauce_keywords):
                    continue

                # Broad containment matching: token in name/slug, or full name in item name
                if any(token in item_name or token in item_slug for token in ing_tokens) or ing_name in item_name:
                    key = item.get("sku") or item.get("slug", "")
                    if key not in seen:
                        seen.add(key)
                        candidates.append(item)

        # If filtering removed everything, return a small reasonable subset
        if len(candidates) < 3:
            fallback = [item for item in inventory_catalog if not self._is_non_food(item)]
            return fallback[:25]

        return candidates

    def match_inventory_with_ai(self, parsed_ingredients: List[Dict[str, Any]], inventory_catalog: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Uses Groq to intelligently map parsed ingredients to real store catalog items.
        """
        filtered_catalog = self._filter_relevant_inventory(parsed_ingredients, inventory_catalog)

        prompt = f"""
        You are a strict retail inventory matching system. Your job is to look at each requested recipe ingredient's "name" field and find a semantically equivalent product from our store inventory.

        Requested Recipe Ingredients (only the "name" field matters for matching):
        {json.dumps(parsed_ingredients, indent=2)}

        Our Store Inventory Catalog (only relevant products shown):
        {json.dumps(filtered_catalog, indent=2)}

        ### CRITICAL MATCHING RULES:
        1. The product MUST BE the actual ingredient, not just share a word. Examples of BAD matches you must NEVER do:
           - Ingredient "Onions" → "Cream and Onion Chips" (chips are NOT onions)
           - Ingredient "Rice" → "Cerelac Rice" (baby cereal is NOT cooking rice)
           - Ingredient "Ginger" → "Chocolate Bar" (chocolate is NOT ginger)
           - Ingredient "Garlic" → "Wheat Apple Baby Food" (baby food is NOT garlic)
           - Ingredient "Oil" → "Tomato Ketchup" (ketchup is NOT oil)
           - Ingredient "Spices" → "Air Freshener" (air freshener is NOT a spice)

        2. Only match when the product IS the ingredient (e.g., "Oil" → "Groundnut Oil", "Milk" → "Standardised Milk", "Ginger" or "Garlic" → "Ginger Garlic Paste").

        3. If no truly matching product exists in inventory, you MUST return "sku": "UNKNOWN", "price_rupees": 0, "slug": the ingredient name as a lowercase-slug, "name": the ingredient name. In this case, you should also look at the inventory catalog and provide up to 3 possible close substitutes that are available in the inventory under the "substitutes" key. For example, if "Heavy Cream" is requested and not found, you can suggest "Standardised Milk" or "Butter" as substitutes. If no substitutes are reasonable, return an empty list.

        4. The "required_quantity" field should use the ingredient's "quantity" value from the requested ingredient (or "raw_input").

        ### Expected Output Format:
        Return a strict JSON object with a single key "results" containing an array of matched items:
        {{
          "results": [
            {{
              "sku": "string",
              "slug": "string",
              "name": "string",
              "price_rupees": number,
              "required_quantity": "string",
              "substitutes": [
                {{
                  "sku": "string",
                  "name": "string",
                  "price_rupees": number,
                  "thumbnail_url": "string"
                }}
              ]
            }}
          ]
        }}
        """

        completion = self.client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {
                    "role": "system",
                    "content": "You are a strict inventory matching assistant. Never match an ingredient to a product that is not the actual ingredient. Only match when the product IS the ingredient (e.g. oil to oil, milk to milk). If no match exists, return UNKNOWN. If an ingredient is UNKNOWN, identify up to 3 suitable substitute items from the inventory catalog and place them in the \"substitutes\" list. Return only a valid JSON object with a \"results\" key."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            response_format={"type": "json_object"}
        )

        try:
            result = json.loads(completion.choices[0].message.content)
            # Handle if AI nests it inside a root dictionary key wrapper
            if isinstance(result, dict):
                for key in ["matches", "items", "data", "ingredients", "results"]:
                    if key in result:
                        return result[key]
                return list(result.values())[0] if result else []
            return result
        except Exception:
            return []