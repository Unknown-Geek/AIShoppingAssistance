import httpx
import json
from typing import Dict, Any

class WebSearchRecipeTool:
    """Tool to search for recipes using web search via DuckDuckGo API"""
    
    SEARCH_URL = "https://api.duckduckgo.com/"

    @staticmethod
    def get_tool_definition() -> Dict[str, Any]:
        """Returns the tool definition for Groq function calling"""
        return {
            "type": "function",
            "function": {
                "name": "web_search_recipe",
                "description": "Search the web for a recipe when MealDB doesn't have it. Returns recipe ingredients and instructions from web results.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "dish_name": {
                            "type": "string",
                            "description": "The name of the dish to search for (e.g., 'Pasta', 'Biryani', 'Tacos')"
                        }
                    },
                    "required": ["dish_name"]
                }
            }
        }

    @staticmethod
    async def execute(dish_name: str) -> Dict[str, Any]:
        """Execute the web search for a recipe"""
        if not isinstance(dish_name, str):
            return {"error": "Invalid dish name type provided to web_search_recipe tool."}

        query = dish_name.strip()
        if not query:
            return {"error": "Dish name cannot be empty."}

        try:
            async with httpx.AsyncClient() as client:
                # Using DuckDuckGo for recipe search
                response = await client.get(
                    WebSearchRecipeTool.SEARCH_URL,
                    params={
                        "q": f"{query} recipe ingredients instructions",
                        "format": "json"
                    },
                    timeout=10.0
                )

            if response.status_code != 200:
                return {"error": f"Failed to search. Status code: {response.status_code}"}

            data = response.json()
            abstract = data.get("AbstractText", "")
            
            if not abstract:
                # Try related topics
                related = data.get("RelatedTopics", [])
                if related and isinstance(related, list) and len(related) > 0:
                    abstract = related[0].get("Text", "")

            if abstract:
                return {
                    "dish": query,
                    "source": "web_search",
                    "summary": abstract,
                    "search_url": f"https://duckduckgo.com/?q={query.replace(' ', '+')}"
                }
            else:
                return {"error": f"No recipe information found for '{query}' in web search"}

        except httpx.TimeoutException:
            return {"error": "Web search request timed out"}
        except Exception as e:
            return {"error": f"Web search failed: {str(e)}"}
