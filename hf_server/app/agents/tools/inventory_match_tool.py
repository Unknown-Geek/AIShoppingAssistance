import json
import os
from typing import Dict, Any, Optional, List

class InventoryMatchTool:
    """Tool to match ingredients against the inventory catalog"""

    def __init__(self):
        self.inventory = self._load_inventory()

    def _load_inventory(self) -> List[Dict[str, Any]]:
        """Load the master retail catalog"""
        inventory_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../../inventory.json"))
        try:
            with open(inventory_path, "r") as f:
                return json.load(f)
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

    def execute(self, ingredient_name: str) -> Dict[str, Any]:
        """Match ingredient against inventory"""
        name_lower = ingredient_name.lower()
        
        # Try exact or partial match
        for item in self.inventory:
            product_name = item.get("name", "").lower()
            if product_name in name_lower or name_lower in product_name:
                return {
                    "matched": True,
                    "sku": item.get("sku"),
                    "slug": item.get("slug"),
                    "name": item.get("name"),
                    "price_rupees": item.get("price_rupees"),
                    "thumbnail_url": item.get("thumbnail_url"),
                    "original_ingredient": ingredient_name
                }
        
        # No match found
        return {
            "matched": False,
            "sku": "UNKNOWN",
            "slug": name_lower.replace(" ", "-"),
            "name": ingredient_name,
            "price_rupees": 0.0,
            "thumbnail_url": "",
            "original_ingredient": ingredient_name
        }
