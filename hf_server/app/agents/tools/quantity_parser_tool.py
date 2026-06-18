import re
from typing import Dict, Any, Optional

# Words that describe preparation, not the ingredient itself — stripped from name
_PREP_WORDS = re.compile(
    r"^(chopped|minced|diced|grated|sliced|crushed|ground|peeled|toasted|roasted|"
    r"fresh|freshly|frozen|canned|organic|whole|small|large|medium|"
    r"optional|divided|cloves?|"
    r"cups?|tablespoons?|tbsp|teaspoons?|tsp|grams?|g|kg|ml|liters?|l|"
    r"pinch|sprinkle|dash|drop|inches?|pieces?|sticks?|slices?)\s+",
    re.IGNORECASE
)

# Unit words that can follow conversational quantities ("to taste", "for garnish")
_CONVERSATIONAL_UNITS = {"pinch", "dash", "drop", "sprinkle"}

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
    def _strip_prep_words(name: str) -> str:
        """Remove leading preparation descriptors (chopped, fresh, etc.) from name"""
        while True:
            cleaned = _PREP_WORDS.sub("", name).strip()
            if cleaned == name:
                break
            name = cleaned
        return name.strip("-, ")

    @staticmethod
    def _handle_conversational_phrases(ingredient: str, raw_input: str) -> Optional[Dict[str, Any]]:
        """Handle non-numeric conversational phrases like 'to taste', 'for garnish', 'pinch of'"""
        ingredient_lower = ingredient.lower()

        # "to taste" — can appear at start or end ("to taste Pepper" / "Salt to taste")
        if "to taste" in ingredient_lower:
            name = re.sub(r"\bto taste\b", "", ingredient, flags=re.IGNORECASE).strip("-, ")
            unit, name = QuantityParserTool._extract_conversational_unit(name)
            return {
                "quantity": "to taste",
                "unit": unit,
                "name": QuantityParserTool._strip_prep_words(name),
                "raw_input": raw_input
            }

        # "for garnish" → "Fresh Cilantro for garnish"
        if "for garnish" in ingredient_lower:
            name = re.sub(r"\bfor garnish\b", "", ingredient, flags=re.IGNORECASE).strip("-, ")
            unit, name = QuantityParserTool._extract_conversational_unit(name)
            return {
                "quantity": "for garnish",
                "unit": unit,
                "name": QuantityParserTool._strip_prep_words(name),
                "raw_input": raw_input
            }

        # "a pinch of ..." / "pinch of ..." / "1 pinch of ..." / "2 pinches of ..."
        pinch_match = re.match(r"^(\d+\.?\d*)?\s*(a\s+)?pinch(?:es)?\s+of\s+(.+)", ingredient, re.IGNORECASE)
        if pinch_match:
            quantity = pinch_match.group(1) or "1"
            name = pinch_match.group(3).strip()
            return {
                "quantity": quantity.strip(),
                "unit": "pinch",
                "name": QuantityParserTool._strip_prep_words(name),
                "raw_input": raw_input
            }

        return None

    @staticmethod
    def _extract_conversational_unit(text: str) -> tuple:
        """After stripping a conversational phrase, check if the remainder starts
        with a known unit word (e.g. 'pinch', 'dash') and extract it."""
        text = text.strip()
        for word in sorted(_CONVERSATIONAL_UNITS, key=len, reverse=True):
            if text.lower().startswith(word) and (len(text) == len(word) or not text[len(word)].isalpha()):
                return word, text[len(word):].strip("-, ")
        return "", text

    @staticmethod
    def execute(ingredient_string: str) -> Dict[str, Any]:
        """Parse an ingredient string and extract components"""
        ingredient = ingredient_string.strip()
        
        # Remove leading symbols (▢, •, -, +)
        ingredient = re.sub(r"^[\s▢•\-+]*", "", ingredient).strip()
        
        # Remove numbered list markers (e.g., "3. ")
        ingredient = re.sub(r"^\d+\.\s*", "", ingredient).strip()
        
        # Handle conversational phrases before regex parsing
        conv_result = QuantityParserTool._handle_conversational_phrases(ingredient, ingredient_string)
        if conv_result:
            return conv_result
        
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
                "name": QuantityParserTool._strip_prep_words(name),
                "raw_input": ingredient_string
            }
        
        # Fallback: Check if it starts with a single digit or fraction symbol
        fallback_match = re.match(r"^([0-9½¼¾⅓⅔⅛])\s*(.*)$", ingredient)
        if fallback_match:
            return {
                "quantity": fallback_match.group(1),
                "unit": "",
                "name": QuantityParserTool._strip_prep_words(fallback_match.group(2).strip()),
                "raw_input": ingredient_string
            }
        
        # No quantity found, assume ingredient name only
        return {
            "quantity": "",
            "unit": "",
            "name": QuantityParserTool._strip_prep_words(ingredient),
            "raw_input": ingredient_string
        }
