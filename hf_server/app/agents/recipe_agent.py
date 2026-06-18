import asyncio
import os
import json
from typing import Dict, Any, Optional
import groq as groq_lib
from groq import Groq
from app.models.recipe import RecipeStructure
from app.agents.tools.recipe_search_tool import RecipeSearchTool
from app.agents.tools.quantity_parser_tool import QuantityParserTool
from app.agents.tools.inventory_match_tool import InventoryMatchTool
from app.agents.tools.web_search_recipe_tool import WebSearchRecipeTool
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
        self.recipe_search_tool = RecipeSearchTool()
        self.quantity_parser_tool = QuantityParserTool()
        self.inventory_match_tool = InventoryMatchTool()
        self.web_search_tool = WebSearchRecipeTool()
        
        # Define available tools for the agent
        self.tools = [
            self.recipe_search_tool.get_tool_definition(),
            self.web_search_tool.get_tool_definition(),
            self.quantity_parser_tool.get_tool_definition(),
            self.inventory_match_tool.get_tool_definition()
        ]

    async def _process_tool_call(self, tool_name: str, tool_input: Dict[str, Any]) -> str:
        """Process a tool call and return the result"""
        if tool_name == "search_recipe":
            result = await self.recipe_search_tool.execute(tool_input["dish_name"])
        elif tool_name == "web_search_recipe":
            result = await self.web_search_tool.execute(tool_input["dish_name"])
        elif tool_name == "parse_ingredient_quantity":
            result = self.quantity_parser_tool.execute(tool_input["ingredient_string"])
        elif tool_name == "match_ingredient_to_inventory":
            result = self.inventory_match_tool.execute(tool_input["ingredient_name"])
        else:
            result = {"error": f"Unknown tool: {tool_name}"}
        
        return json.dumps(result)

    async def generate(self, dish_query: str, servings: int) -> Dict[str, Any]:
        """
        Queries the Groq LLM with tool-calling capabilities to generate recipes
        and process ingredients intelligently.
        """
        messages = [
            {
                "role": "system",
                "content": """You are an expert chef assistant with access to recipe databases and inventory systems.

WORKFLOW:
1. First try: search_recipe tool to get recipe from MealDB
2. If MealDB returns "no recipe found": use web_search_recipe tool as fallback
3. For each ingredient: use parse_ingredient_quantity tool
4. For each ingredient: use match_ingredient_to_inventory tool
5. Return final recipe in JSON format

DO NOT call search_recipe multiple times. If it fails, move to web_search_recipe once.
Keep responses concise - limit to 3 iterations maximum.

FINAL RESPONSE FORMAT (REQUIRED - return this as valid JSON):
{
  "dish": "dish name",
  "servings": number,
  "instructions": ["step 1", "step 2", ...],
  "ingredients": [
    {"name": "ingredient", "quantity": "amount", "unit": "unit"}
  ]
}"""
            },
            {
                "role": "user",
                "content": f"Generate a detailed recipe for {dish_query} for {servings} servings. First search MealDB, then use web search if needed. Parse ingredients and match to available products."
            }
        ]

        # Agentic loop - limited iterations to avoid token waste
        max_iterations = 3
        iteration = 0
        
        while iteration < max_iterations:
            iteration += 1
            print(f"\n[RecipeAgent] Iteration {iteration}")
            print(f"[RecipeAgent] Message stack size: {len(messages)}")
            
            retry_attempt = 0
            while True:
                try:
                    # Call Groq with tool definitions
                    response = self.client.chat.completions.create(
                        model="gemma2-9b-it",
                        messages=messages,
                        tools=self.tools,
                        tool_choice="auto",
                        max_tokens=1024,
                        temperature=0.2
                    )
                    break
                except groq_lib.RateLimitError as rate_error:
                    retry_attempt += 1
                    wait_seconds = min(10, 2 ** retry_attempt)
                    print(f"[RecipeAgent] ⚠️ Rate limit hit on attempt {retry_attempt}: {rate_error}")
                    if retry_attempt >= 3:
                        print("[RecipeAgent] ❌ Rate limit retry limit reached")
                        raise
                    print(f"[RecipeAgent] Waiting {wait_seconds}s before retrying")
                    await asyncio.sleep(wait_seconds)
                except Exception as e:
                    print(f"[RecipeAgent] ❌ API Error on iteration {iteration}: {str(e)[:200]}")
                    raise

            assistant_message = {"role": "assistant", "content": response.choices[0].message.content or ""}
            
            # Add assistant message to conversation
            if response.choices[0].message.tool_calls:
                assistant_message["tool_calls"] = [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments
                        }
                    }
                    for tc in response.choices[0].message.tool_calls
                ]
            
            messages.append(assistant_message)

            # Check if we're done (no tool calls)
            if not response.choices[0].message.tool_calls:
                print("[RecipeAgent] ✓ Agent completed - no more tool calls")
                break

            # Process tool calls
            tool_results_message = []
            for tool_call in response.choices[0].message.tool_calls:
                tool_name = tool_call.function.name
                tool_input = json.loads(tool_call.function.arguments)
                
                print(f"[RecipeAgent] 🔧 Calling tool: {tool_name}")
                
                result = await self._process_tool_call(tool_name, tool_input)
                
                tool_results_message.append({
                    "type": "tool_result",
                    "tool_use_id": tool_call.id,
                    "content": result
                })
            
            # Add tool results to messages as a text string
            # This is the correct format for Groq - content must be a string
            results_text = f"Tool execution results:\n{json.dumps(tool_results_message, indent=2)}"
            
            messages.append({
                "role": "user",
                "content": results_text
            })

        # Extract the final response
        final_response = messages[-1]["content"]
        if isinstance(final_response, str):
            try:
                # Try to parse as JSON if it's a JSON string
                return json.loads(final_response)
            except json.JSONDecodeError:
                # Return as structured dict if not valid JSON
                return {
                    "raw_response": final_response,
                    "dish": dish_query,
                    "servings": servings
                }
        
        return final_response