import os
from typing import Dict, Any
from groq import Groq
from app.models.recipe import RecipeStructure
from dotenv import load_dotenv
load_dotenv()
class RecipeAgent:
    def __init__(self):
        # Grabs your live environment variable key
        api_key = os.getenv("GROQ_API_KEY")
        
        # Safe fallback check to prevent system boot crashes
        if not api_key:
            print("[WARNING] GROQ_API_KEY environment variable not detected in terminal process instance context.")
            print("[INFO] Attempting dummy mock key allocation for initialization verification purposes...")
            api_key = "gsk_mock_key_placeholder_for_verification_only"
            
        self.client = Groq(api_key=api_key)

    def generate(self, dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Queries the live Groq LLM and forces a structured JSON dictionary output
        """
        prompt = f"Generate a detailed recipe for {dish_query} tailored for {servings} servings."

        completion = self.client.chat.completions.create(
            model="llama-3.1-8b-instant",  
            messages=[
                {
                    "role": "system",
                    "content": "You are an expert chef assistant. You must provide your output strictly formatted as a json object matching the structural schema requested."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            response_format={"type": "json_object", "schema": RecipeStructure.model_json_schema()}
        )

        response_content = completion.choices[0].message.content
        import json
        return json.loads(response_content)