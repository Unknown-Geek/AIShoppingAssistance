import re


class QuantityEstimator:

    def parse_ingredient(self, ingredient: str):

        ingredient = ingredient.strip()

        match = re.match(
            r"^([\d½¼¾⅓⅔⅛\/\.\-\s]+(?:cups?|cup|tablespoons?|tbsp|teaspoons?|tsp|grams?|g|kg|ml|liters?|l)?)\s+(.*)$",
            ingredient,
            re.IGNORECASE
        )

        if match:
            return {
                "quantity": match.group(1).strip(),
                "name": match.group(2).strip()
            }

        return {
            "quantity": "",
            "name": ingredient
        }