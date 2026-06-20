import traceback
import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from app.models.chat import ChatRequest
from app.agents.shopping_assistant_agent import ShoppingAssistantAgent
from app.utils.cart_state import live_cart_memory

router = APIRouter(prefix="/chat", tags=["Chat Management"])
agent = ShoppingAssistantAgent()

@router.post("/message")
async def send_chat_message(payload: ChatRequest):
    """
    Non-streaming endpoint for backward compatibility (e.g. cart sync, tests).
    Accumulates the generator chunks and returns a flat JSON dictionary.
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

        result = await agent.process_recipe_workflow(
            user_id=user,
            current_cart_slugs=slugs,
            dish_query=query,
            servings=srv,
            chat_history=history,
            current_cart=current_cart,
            image_base64=payload.image_base64
        )
        
        return result
    except Exception as e:
        print("\n=== CRITICAL API ROUTE ERROR TRACEBACK ===")
        traceback.print_exc()
        print("==========================================\n")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/message-stream")
async def send_chat_message_stream(payload: ChatRequest):
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
                current_cart=current_cart,
                image_base64=payload.image_base64
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
    raw_cart_data = live_cart_memory.get_cart(user_id.lower().strip())
    
    formatted_items = [
        {"sku": sku, "quantity": qty}
        for sku, qty in raw_cart_data.items()
    ]
    
    return {
        "user_id": user_id,
        "items": formatted_items
    }
