import os
import json
import re
from typing import Dict, Any, List
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

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
}}"""

        messages = [
            {
                "role": "system", 
                "content": "You are an expert chef assistant. You must provide your output strictly formatted as a json object matching the structural schema requested."
            },
            {"role": "user", "content": prompt}
        ]

        response = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",
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
        ingredient_tokens = set()
        for ing in parsed_ingredients:
            for word in ing.get("name", "").lower().split():
                if len(word) >= 3:
                    ingredient_tokens.add(word)

        if not ingredient_tokens:
            return [item for item in inventory_catalog if not self._is_non_food(item)]

        candidates = []
        seen = set()
        for item in inventory_catalog:
            # Category Guardrail: skip non-food items entirely
            if self._is_non_food(item):
                continue
            text = (item.get("name", "") + " " + item.get("slug", "")).lower()
            if any(token in text for token in ingredient_tokens):
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

        3. If no truly matching product exists in inventory, you MUST return "sku": "UNKNOWN", "price_rupees": 0, "slug": the ingredient name as a lowercase-slug, "name": the ingredient name. It is BETTER to return UNKNOWN than to return a wrong product.

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
              "required_quantity": "string"
            }}
          ]
        }}
        """

        completion = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {
                    "role": "system",
                    "content": "You are a strict inventory matching assistant. Never match an ingredient to a product that is not the actual ingredient. Only match when the product IS the ingredient (e.g. oil to oil, milk to milk). If no match exists, return UNKNOWN. Return only a valid JSON object with a \"results\" key."
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