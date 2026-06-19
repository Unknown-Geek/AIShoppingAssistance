import traceback
from fastapi import APIRouter, HTTPException
from typing import List
from app.models.recipe import RecipeRequest
from app.agents.shopping_assistant_agent import ShoppingAssistantAgent
from app.utils.cart_state import live_cart_memory

router = APIRouter(prefix="/recipe", tags=["Recipe Management"])
agent = ShoppingAssistantAgent()

@router.post("/analyze-ingredients")
async def analyze_recipe_ingredients(payload: RecipeRequest):
    try:
        user = str(payload.user_id).lower().strip() # ◄─ EXTRACT THE USER ID
        slugs = [str(s) for s in payload.current_cart_slugs]
        query = str(payload.dish_query)
        srv = int(payload.servings)
        
        history = []
        if payload.chat_history:
            history = [{"is_user": h.is_user, "text": h.text} for h in payload.chat_history]

        result = await agent.process_recipe_workflow(
            user_id=user,
            current_cart_slugs=slugs,
            dish_query=query,
            servings=srv,
            chat_history=history
        )
        return result
    except Exception as e:
        print("\n=== CRITICAL API ROUTE ERROR TRACEBACK ===")
        traceback.print_exc()
        print("==========================================\n")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/cart/{user_id}")
async def get_user_live_cart(user_id: str):
    """
    Endpoint for Flutter client to fetch the active item quantities 
    that the AI agent added via tool calls.
    """
    # Force alignment to lower case to eliminate typographical sorting mismatches
    raw_cart_data = live_cart_memory.get_cart(user_id.lower().strip())
    
    formatted_items = [
        {"sku": sku, "quantity": qty}
        for sku, qty in raw_cart_data.items()
    ]
    
    return {
        "user_id": user_id,
        "items": formatted_items
    }