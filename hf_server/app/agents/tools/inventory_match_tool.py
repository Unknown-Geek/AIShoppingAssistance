import json
import os
from typing import Dict, Any, List

class InventoryMatchTool:
    """Tool to match ingredients against the inventory catalog"""

    def __init__(self):
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Load the master retail catalog from candidates list"""
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
            inventory_path = os.path.abspath(os.path.join(base_dir, "..", "..", "..", "..", "inventory.json"))

        try:
            with open(inventory_path, "r") as f:
                data = json.load(f)
                if isinstance(data, dict) and "items" in data:
                    return data["items"]
                if isinstance(data, list):
                    return data
                return []
        except Exception as e:
            print(f"[InventoryMatchTool] Inventory load failed: {e}")
            return []

    def get_tool_definition(self) -> Dict[str, Any]:
        """Returns the tool definition for Groq function calling"""
        return {
            "type": "function",
            "function": {
                "name": "match_ingredient_to_inventory",
                "description": "Match an ingredient name against the retail inventory catalog to find matching products. Returns product details like SKU, slug, price, and thumbnail.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "ingredient_name": {
                            "type": "string",
                            "description": "The ingredient name to match (e.g., 'flour', 'butter', 'eggs')"
                        }
                    },
                    "required": ["ingredient_name"]
                }
            }
        }

    def _tokenize(self, text: str) -> set:
        """Split text into significant word tokens (min 3 chars)"""
        return set(w for w in text.lower().split() if len(w) >= 3)

    def execute(self, ingredient_name: str) -> Dict[str, Any]:
        """Match ingredient against inventory using token overlap scoring"""
        name_lower = ingredient_name.lower().strip()
        ing_tokens = self._tokenize(name_lower)

        if not ing_tokens:
            return {
                "matched": False,
                "sku": "UNKNOWN",
                "slug": name_lower.replace(" ", "-"),
                "name": ingredient_name,
                "price_rupees": 0.0,
                "thumbnail_url": "",
                "original_ingredient": ingredient_name
            }

        best_match = None
        best_score = 0.0
        best_prod_len = 0

        for item in self.inventory:
            product_name = item.get("name", "").lower()
            prod_tokens = self._tokenize(product_name)

            if not prod_tokens:
                continue

            common = ing_tokens & prod_tokens
            if not common:
                continue

            score = len(common) / len(ing_tokens)

            # Tiebreaker: prefer shorter product name (more specific/direct match)
            if score > best_score or (score == best_score and len(product_name) < best_prod_len):
                best_score = score
                best_match = item
                best_prod_len = len(product_name)

        if best_match and best_score > 0.5:
            return {
                "matched": True,
                "sku": best_match.get("sku"),
                "slug": best_match.get("slug"),
                "name": best_match.get("name"),
                "price_rupees": best_match.get("price_rupees"),
                "thumbnail_url": best_match.get("thumbnail_url"),
                "original_ingredient": ingredient_name
            }

        # No good match found
        return {
            "matched": False,
            "sku": "UNKNOWN",
            "slug": name_lower.replace(" ", "-"),
            "name": ingredient_name,
            "price_rupees": 0.0,
            "thumbnail_url": "",
            "original_ingredient": ingredient_name
        }
