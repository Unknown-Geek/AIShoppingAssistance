import os
from typing import Dict, Any
from groq import Groq
from app.models.recipe import RecipeStructure

class RecipeAgent:
    def __init__(self):
        # Grabs your live environment variable key
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY environment variable is missing!")
        self.client = Groq(api_key=api_key)

    def generate(self, dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Queries the live Groq LLM and forces a structured JSON dictionary output
        matching the RecipeStructure schema. No more hardcoded data!
        """
        prompt = f"Generate a detailed recipe for {dish_query} tailored for {servings} servings."

        # Calling the live Groq API with structured output tool routing
# Calling the live Groq API with an active model string
        completion = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",  # Updated to active Groq supported model
            messages=[
                {
                    "role": "system",
                    "content": "You are an expert chef assistant. You must provide your output matching the structural schema requested."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            response_format={"type": "json_object", "schema": RecipeStructure.model_json_schema()}
        )

        # Parse the live response string directly into a dictionary context
        response_content = completion.choices[0].message.content
        import json
        return json.loads(response_content)