import traceback
from fastapi import APIRouter, HTTPException
from typing import List
from app.models.recipe import RecipeRequest
from app.agents.shopping_assistant_agent import ShoppingAssistantAgent
from app.utils.cart_state import live_cart_memory

router = APIRouter(prefix="/recipe", tags=["Recipe Management"])
agent = ShoppingAssistantAgent()

import json
from fastapi.responses import StreamingResponse

@router.post("/analyze-ingredients")
async def analyze_recipe_ingredients(payload: RecipeRequest):
    """
    Non-streaming endpoint for backward compatibility (e.g. cart sync, tests).
    Accumulates the generator chunks and returns a flat JSON dictionary.
    """
    try:
        user = str(payload.user_id).lower().strip() # ◄─ EXTRACT THE USER ID
        slugs = [str(s) for s in payload.current_cart_slugs]
        query = str(payload.dish_query)
        srv = int(payload.servings)
        
        history = []
        if payload.chat_history:
            history = [{"is_user": h.is_user, "text": h.text} for h in payload.chat_history]

        current_cart = []
        if payload.current_cart:
            current_cart = [{"sku": c.sku, "name": c.name, "quantity": c.quantity} for c in payload.current_cart]

        generator = agent.process_recipe_workflow(
            user_id=user,
            current_cart_slugs=slugs,
            dish_query=query,
            servings=srv,
            chat_history=history,
            current_cart=current_cart
        )
        
        full_text = ""
        recipe_data = None
        mutations = None
        
        async for chunk_str in generator:
            if not chunk_str.strip():
                continue
            try:
                chunk = json.loads(chunk_str.strip())
                if "text_chunk" in chunk:
                    full_text += chunk["text_chunk"]
                else:
                    if "recipe" in chunk:
                        recipe_data = chunk["recipe"]
                    if "cart_mutations" in chunk:
                        mutations = chunk["cart_mutations"]
            except Exception as parse_err:
                print(f"Error parsing generator chunk: {parse_err}")
        
        return {
            "response_text": full_text,
            "recipe": recipe_data,
            "cart_mutations": mutations
        }
    except Exception as e:
        print("\n=== CRITICAL API ROUTE ERROR TRACEBACK ===")
        traceback.print_exc()
        print("==========================================\n")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/analyze-ingredients-stream")
async def analyze_recipe_ingredients_stream(payload: RecipeRequest):
    """
    Streaming endpoint returning SSE/chunked response for real-time UI.
    """
    try:
        user = str(payload.user_id).lower().strip()
        slugs = [str(s) for s in payload.current_cart_slugs]
        query = str(payload.dish_query)
        srv = int(payload.servings)
        
        history = []
        if payload.chat_history:
            history = [{"is_user": h.is_user, "text": h.text} for h in payload.chat_history]

        current_cart = []
        if payload.current_cart:
            current_cart = [{"sku": c.sku, "name": c.name, "quantity": c.quantity} for c in payload.current_cart]

        async def event_generator():
            generator = agent.process_recipe_workflow_stream(
                user_id=user,
                current_cart_slugs=slugs,
                dish_query=query,
                servings=srv,
                chat_history=history,
                current_cart=current_cart
            )
            async for chunk in generator:
                yield chunk

        return StreamingResponse(event_generator(), media_type="text/plain")
    except Exception as e:
        print("\n=== CRITICAL STREAM API ROUTE ERROR ===")
        traceback.print_exc()
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