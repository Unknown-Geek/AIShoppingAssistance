import os
import json
import re
from groq import Groq


class GroqClient:
    api_key = os.getenv("GROQ_API_KEY")

    

    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY environment variable not set")
        self.client = Groq(api_key=api_key)

    def extract_recipe_request(self, prompt: str):
        """
        Extract dish name and servings from user input.
        
        Args:
            prompt (str): User input, e.g., "I want Veg Biryani for 5 people"
        
        Returns:
            dict: {"dish": "Veg Biryani", "servings": 5}
        """
        extraction_prompt = f"""Extract the COMPLETE dish name and number of servings from the user request.
 
CRITICAL RULES:
1. Extract the FULL dish name (e.g., "Chicken Curry", not just "Chicken")
2. Do NOT return partial or incomplete dish names
3. Extract servings from phrases like: "for X people", "serves X", "for X persons", "make enough for X"
4. Default servings to 1 if not mentioned
5. Return ONLY valid JSON - no extra text
 
User request: "{prompt}"
 
Examples:
Input: "Make Chicken Curry for 4 people"
Output: {{"dish": "Chicken Curry", "servings": 4}}
 
Input: "I want Arrabiata for 2 people"
Output: {{"dish": "Arrabiata", "servings": 2}}
 
Input: "Prepare Veg Biryani for 5 persons"
Output: {{"dish": "Veg Biryani", "servings": 5}}
 
Input: "I need Spicy Arrabiata Penne"
Output: {{"dish": "Spicy Arrabiata Penne", "servings": 1}}
 
Input: "Make enough Butter Chicken for 3"
Output: {{"dish": "Butter Chicken", "servings": 3}}
 
Return JSON with fields:
- "dish": the complete, exact name of the dish (string)
- "servings": number of servings (integer)
 
JSON response:"""

        response = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "user", "content": extraction_prompt}
            ]
        )

        response_text = response.choices[0].message.content.strip()


        
        # Extract JSON from potential code fences or surrounding text
        json_text = self._extract_json_from_response(response_text)
        
        try:
            result = json.loads(json_text)
            
            # Validate dish name exists and is not empty
            if "dish" not in result or not result["dish"] or result["dish"] == "Unknown Dish":
                # Fallback: extract food name from prompt using simple heuristics
                result["dish"] = self._extract_dish_from_prompt(prompt)
            
            if "servings" not in result:
                result["servings"] = 1
            else:
                try:
                    result["servings"] = int(result["servings"])
                except (ValueError, TypeError):
                    result["servings"] = 1
            
            return result
        except json.JSONDecodeError:
            # Fallback to extracting from prompt
            return {
                "dish": self._extract_dish_from_prompt(prompt),
                "servings": 1
            }

    def _extract_dish_from_prompt(self, prompt: str):
        """
        Fallback method to extract dish name from prompt using simple heuristics.
        """
        # Common food-related keywords to skip
        skip_words = {"want", "need", "i", "for", "people", "person", "servings", "portions",
                     "get", "make", "cook", "prepare", "have", "recipe", "the", "a", "an",
                     "and", "or", "to", "at", "in", "on", "from"}
        
        # Split prompt and filter out skip words
        words = prompt.split()
        potential_dishes = [w.strip(".,!?") for w in words 
                           if w.lower() not in skip_words and len(w) > 2]
        
        # Return first substantive word as dish name (usually the food name)
        if potential_dishes:
            return potential_dishes[0]
        
        return "Unknown Dish"

    def _extract_json_from_response(self, response_text: str) -> str:
        """
        Robustly extract JSON from Groq response that may contain code fences or surrounding text.
        
        Handles:
        - ```json ... ``` code fences
        - ```javascript ... ``` code fences
        - JSON object surrounded by explanatory text
        
        Args:
            response_text (str): Raw response from Groq
            
        Returns:
            str: Extracted JSON string, or original text if no extraction needed
        """
        # Try to extract from ```json ``` or ```javascript ``` code fences
        json_fence_match = re.search(r'```(?:json|javascript)?\s*(.*?)\s*```', response_text, re.DOTALL)
        if json_fence_match:
            extracted = json_fence_match.group(1).strip()
            if extracted:
                return extracted
        
        # Try to find JSON object by locating first { and last }
        first_brace = response_text.find('{')
        last_brace = response_text.rfind('}')
        
        if first_brace != -1 and last_brace != -1 and first_brace < last_brace:
            return response_text[first_brace:last_brace + 1]
        
        # Return original if no extraction possible
        return response_text
