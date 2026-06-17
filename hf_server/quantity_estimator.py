import re


class QuantityEstimator:

    def parse_ingredient(self, ingredient: str):
        ingredient = ingredient.strip()
        
        # Remove leading symbols (▢, •, -, +)
        ingredient = re.sub(r"^[\s▢•\-+]*", "", ingredient).strip()
        
        # Remove numbered list markers (e.g., "3. ")
        ingredient = re.sub(r"^\d+\.\s*", "", ingredient).strip()
        
        # Regex to match quantity with unit at the START only
        match = re.match(
            r"^([\d½¼¾⅓⅔⅛\/\.\-\s]+(?:cups?|tablespoons?|tbsp|teaspoons?|tsp|grams?|g|kg|ml|liters?|l))\s+(.*)$",
            ingredient,
            re.IGNORECASE
        )
        
        if match:
            quantity = match.group(1).strip()
            name = match.group(2).strip()
            # Remove content in parentheses (e.g., "(400 grams)")
            name = re.sub(r"\([^)]*\)", "", name).strip()
            
            return {
                "quantity": quantity,
                "name": name
            }
        
        return {
            "quantity": "",
            "name": ingredient
        }

    def scale_quantity(self, quantity_string: str, factor: float):
        """
        Scale a quantity by a given factor.
        
        Handles integers, decimals, fractions (1/2), and unicode fractions (½).
        
        Examples:
            "2 cups" + factor 2 = "4 cups"
            "400 grams" + factor 1.5 = "600 grams"
            "1 teaspoon" + factor 3 = "3 teaspoons"
            "½ teaspoon" + factor 2 = "1 teaspoon"
        
        Args:
            quantity_string (str): Quantity with optional unit (e.g., "2 cups", "½ teaspoon")
            factor (float): Scaling factor (e.g., 1.5 for 1.5x, 2 for 2x)
        
        Returns:
            str: Scaled quantity, or original if parsing fails
        """
        try:
            quantity_string = quantity_string.strip()
            
            # Extract numeric part and unit
            match = re.match(
                r"^([\d½¼¾⅓⅔⅛\/\.\-\s]+)\s*(.*?)$",
                quantity_string,
                re.IGNORECASE
            )
            
            if not match:
                return quantity_string
            
            numeric_str = match.group(1).strip()
            unit = match.group(2).strip()
            
            # Parse numeric value
            numeric_value = self._parse_numeric(numeric_str)
            if numeric_value is None:
                return quantity_string
            
            # Scale
            scaled_value = numeric_value * factor
            
            # Format result
            if scaled_value == int(scaled_value):
                result = str(int(scaled_value))
            else:
                # Round to 2 decimal places and remove trailing zeros
                result = f"{scaled_value:.2f}".rstrip('0').rstrip('.')
            
            # Pluralize unit if needed
            if unit:
                if scaled_value != 1:
                    # Simple pluralization: add 's' if doesn't already end with 's'
                    if not unit.endswith('s'):
                        unit = unit + 's'
                # If value is 1, keep unit singular
            
            return f"{result} {unit}".strip() if unit else result
        except Exception:
            return quantity_string

    def _parse_numeric(self, numeric_str: str):
        """
        Parse various numeric formats including fractions and unicode fractions.
        
        Handles:
        - Integers: "2"
        - Decimals: "1.5"
        - Unicode fractions: "½", "¼", "¾", "⅓", "⅔", "⅛"
        - Regular fractions: "1/2"
        - Mixed: "1 1/2"
        
        Args:
            numeric_str (str): String representation of a number
        
        Returns:
            float: Parsed numeric value, or None if parsing fails
        """
        try:
            numeric_str = numeric_str.strip()
            
            # Unicode fractions mapping
            unicode_fractions = {
                '½': 0.5,
                '¼': 0.25,
                '¾': 0.75,
                '⅓': 1/3,
                '⅔': 2/3,
                '⅛': 1/8,
            }
            
            # Replace unicode fractions with their decimal equivalents
            for char, value in unicode_fractions.items():
                numeric_str = numeric_str.replace(char, str(value))
            
            # Handle regular fractions (e.g., "1/2" or "1 1/2")
            if '/' in numeric_str:
                parts = numeric_str.split()
                total = 0.0
                for part in parts:
                    if '/' in part:
                        numerator, denominator = part.split('/')
                        total += float(numerator) / float(denominator)
                    else:
                        total += float(part)
                return total
            
            # Simple float conversion
            return float(numeric_str)
        except Exception:
            return None