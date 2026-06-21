import os
import json
import re
from typing import Dict, Any, List
from groq import Groq
from dotenv import load_dotenv
from app.services.nutrition_service import NutritionService
from app.services.quantity_normalizer_service import QuantityNormalizerService

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
        self.model = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
        self.nutrition_service = NutritionService()
        self.quantity_normalizer = QuantityNormalizerService(
            os.getenv("USDA_API_KEY")
        )
    
        


    async def generate(self, dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Generates a detailed recipe using Groq forced output structures.
        """
        prompt = f"""Generate a detailed recipe for {dish_query} for {servings} servings.
        IMPORTANT:
- quantity must be a NUMBER only.
- Never include units inside quantity.
- Correct:
  quantity: 1, unit: "cups"
  quantity: 2, unit: "tablespoons"
  quantity: 3, unit: "cloves"
- Incorrect:
  quantity: "1 cup"
  quantity: "2 tablespoons"
  quantity: "3 cloves"


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
            model=self.model,
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

        # If filtering removed everything, return what we have rather than
        # randomly padding with unrelated food items (which causes hallucinated
        # matches like "Quaker Oats" appearing in a pizza ingredient list).
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
            model=self.model,
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

    async def generate_and_match_recipe(self, dish_query: str, servings: int, inventory_catalog: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Generates a detailed recipe and matches its ingredients to the store catalog in a single LLM call.
        """
        food_catalog = [item for item in inventory_catalog if not self._is_non_food(item)]

        prompt = f"""Generate a detailed recipe for {dish_query} for {servings} servings, and match the required ingredients to our store's inventory catalog.

Available Store Inventory Catalog (SKUs and Names):
{json.dumps(food_catalog, indent=2)}

### CRITICAL MATCHING RULES:
1. Every single recipe ingredient must be matched to a product in the catalog.
2. The product MUST BE the actual ingredient, not just share a word. Examples of BAD matches:
   - "Onions" -> "Cream and Onion Chips" (chips are NOT onions)
   - "Rice" -> "Cerelac Rice" (baby cereal is NOT cooking rice)
   - "Garlic" -> "Wheat Apple Baby Food"
   - "Oil" -> "Tomato Ketchup"
   - "Flour" or any pizza ingredient -> "Quaker Oats" (oats are NOT a pizza ingredient)
   - "Cheese" or "Dough" -> "Oats" or "Cereal" (breakfast items are NOT pizza/bread ingredients)
3. Only match when the product IS the ingredient (e.g. "Oil" -> "Gold Winner Refined Sunflower Oil" or "Idhayam Mantra Groundnut Oil", "Milk" -> "Amul Gold Standardised Milk", "Ginger" or "Garlic" -> "Aachi Ginger Garlic Paste").
4. If no truly matching product exists in the catalog, you MUST return "sku": "UNKNOWN", "price_rupees": 0, "name": the ingredient name, and "slug": the ingredient name as a lowercase-slug. For UNKNOWN items, look at the catalog and provide up to 3 possible close substitutes that are available in our catalog under the "substitutes" key. If no substitutes are reasonable, return an empty list.

Return ONLY valid JSON in this exact format (no markdown strings, no code fences):
{{
  "dish": "{dish_query}",
  "servings": {servings},
  "instructions": ["step 1", "step 2"],
  "ingredients": [
    {{
      "name": "Ingredient Name",
      "quantity": "amount",
      "unit": "unit",
      "sku": "SKU_CODE_IF_MATCHED_OR_UNKNOWN",
      "slug": "product-slug",
      "price_rupees": 0.0,
      "substitutes": [
        {{
          "sku": "string",
          "name": "string",
          "price_rupees": 0.0
        }}
      ]
    }}
  ]
}}
"""

        messages = [
            {
                "role": "system",
                "content": "You are an expert chef and a strict retail inventory matching system. You must generate recipes and match the ingredients strictly to the available catalog products, returning only a valid JSON object matching the requested schema."
            },
            {"role": "user", "content": prompt}
        ]

        response = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            max_tokens=1536,
            temperature=0.2,
            response_format={"type": "json_object"}
        )

        content = response.choices[0].message.content or ""
        content = content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()

        try:
            result = json.loads(content)
            print("\n===== RAW RECIPE INGREDIENTS =====")
            for x in result.get("ingredients", []):
                print(x)
            print("=================================\n")
            async with self.quantity_normalizer as normalizer:
                normalized_ingredients, skipped = (
                    await normalizer.normalize_ingredients(
                        result.get("ingredients", [])
                    )
                )

            print("NORMALIZED:", normalized_ingredients)
            print("SKIPPED:", skipped)

            nutrition = await self.nutrition_service.calculate_recipe_nutrition(
                normalized_ingredients,
                result.get("servings", servings),
            )
            print("NUTRITION RESULT:", nutrition)

            result["nutrition"] = nutrition

            return result
        except json.JSONDecodeError:
            return {
                "dish": dish_query,
                "servings": servings,
                "instructions": [],
                "ingredients": []
            }