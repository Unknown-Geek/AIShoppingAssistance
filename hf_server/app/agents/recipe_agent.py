import json
from typing import Dict, Any
from groq import Groq
from dotenv import load_dotenv
import os

load_dotenv()

class RecipeAgent:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            print("[WARNING] GROQ_API_KEY not detected, using mock key")
            api_key = "gsk_mock_key_placeholder_for_verification_only"
        self.client = Groq(api_key=api_key)

    async def generate(self, dish_query: str, servings: int) -> Dict[str, Any]:
        prompt = f"""Generate a detailed recipe for {dish_query} for {servings} servings.

Return ONLY valid JSON in this exact format (no markdown, no code fences):
{{
  "dish": "{dish_query}",
  "servings": {servings},
  "instructions": ["step 1", "step 2", ...],
  "ingredients": [
    {{"name": "ingredient with quantity", "quantity": "amount", "unit": "unit"}}
  ]
}}"""

        messages = [
            {"role": "system", "content": "You are an expert chef. Return only valid JSON, no markdown."},
            {"role": "user", "content": prompt}
        ]

        response = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=messages,
            max_tokens=1024,
            temperature=0.2
        )

        content = response.choices[0].message.content or ""
        content = content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()

        try:
            return json.loads(content)
        except json.JSONDecodeError:
            return {
                "raw_response": content,
                "dish": dish_query,
                "servings": servings
            }
