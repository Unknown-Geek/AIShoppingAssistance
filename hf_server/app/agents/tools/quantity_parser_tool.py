import re
from typing import Dict, Any

class QuantityParserTool:
    """Tool to parse ingredients and extract quantity information"""

    @staticmethod
    def get_tool_definition() -> Dict[str, Any]:
        """Returns the tool definition for Groq function calling"""
        return {
            "type": "function",
            "function": {
                "name": "parse_ingredient_quantity",
                "description": "Parse an ingredient string to extract quantity, unit, and ingredient name. Handles various formats like '1 cup flour', '2 tbsp butter', '3 eggs', etc.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "ingredient_string": {
                            "type": "string",
                            "description": "The ingredient string to parse (e.g., '2 cups flour', '1 tablespoon olive oil')"
                        }
                    },
                    "required": ["ingredient_string"]
                }
            }
        }

    @staticmethod
    def execute(ingredient_string: str) -> Dict[str, Any]:
        """Parse an ingredient string and extract components"""
        ingredient = ingredient_string.strip()
        
        # Remove leading symbols (▢, •, -, +)
        ingredient = re.sub(r"^[\s▢•\-+]*", "", ingredient).strip()
        
        # Remove numbered list markers (e.g., "3. ")
        ingredient = re.sub(r"^\d+\.\s*", "", ingredient).strip()
        
        # Match ANY numeric quantity, unicode fraction, or fraction expression at the start
        num_match = re.match(r"^([\d½¼¾⅓⅔⅛\/\.\-\s]+)", ingredient)
        
        if num_match and num_match.group(1).strip():
            quantity_num = num_match.group(1).strip()
            remainder = ingredient[num_match.end():].strip()
            
            # Check if the remainder starts with a recognized unit
            unit_pattern = r"^(cups?|tablespoons?|tbsp|teaspoons?|tsp|grams?|g|kg|ml|liters?|l)\b"
            unit_match = re.match(unit_pattern, remainder, re.IGNORECASE)
            
            if unit_match:
                unit = unit_match.group(1)
                name = remainder[unit_match.end():].strip()
                quantity = f"{quantity_num} {unit}"
            else:
                # No standard unit matched
                quantity = quantity_num
                name = remainder
                
            # Clean up content in parentheses from the name
            name = re.sub(r"\([^)]*\)", "", name).strip()
            
            return {
                "quantity": quantity,
                "unit": unit_match.group(1) if unit_match else "",
                "name": name,
                "raw_input": ingredient_string
            }
        
        # Fallback: Check if it starts with a single digit or fraction symbol
        fallback_match = re.match(r"^([0-9½¼¾⅓⅔⅛])\s*(.*)$", ingredient)
        if fallback_match:
            return {
                "quantity": fallback_match.group(1),
                "unit": "",
                "name": fallback_match.group(2).strip(),
                "raw_input": ingredient_string
            }
        
        # No quantity found, assume ingredient name only
        return {
            "quantity": "",
            "unit": "",
            "name": ingredient,
            "raw_input": ingredient_string
        }
