import traceback
from fastapi import APIRouter, HTTPException
from typing import List
from app.models.recipe import RecipeRequest
from app.agents.shopping_assistant_agent import ShoppingAssistantAgent

router = APIRouter(prefix="/recipe", tags=["Recipe Management"])
agent = ShoppingAssistantAgent()

@router.post("/analyze-ingredients")
async def analyze_recipe_ingredients(payload: RecipeRequest):
    try:
        slugs = [str(s) for s in payload.current_cart_slugs]
        query = str(payload.dish_query)
        srv = int(payload.servings)
        
        result = await agent.process_recipe_workflow(
            current_cart_slugs=slugs,
            dish_query=query,
            servings=srv
        )
        return result
    except Exception as e:
        # This forces the terminal to print out the EXACT line causing the issue!
        print("\n=== CRITICAL API ROUTE ERROR TRACEBACK ===")
        traceback.print_exc()
        print("==========================================\n")
        raise HTTPException(status_code=500, detail=str(e))