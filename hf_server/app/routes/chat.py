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

        # ── Source-of-truth sync ────────────────────────────────────────────────
        # Flutter's CartService is the authoritative cart state. Any external
        # modifications (dashboard scanner, checkout, manual cart clear) are
        # reflected here by resetting the server-side memory to match before
        # running any tool calls.
        live_cart_memory.sync_from_client(user, current_cart)

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


@router.post("/test-notification")
async def trigger_test_notification():
    """
    Simulates a payment notification generation from the backend.
    """
    import random
    success = random.choice([True, False])
    txn_id = f"pay_{''.join(random.choices('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', k=12))}" if success else ""
    amount = random.choice([250.00, 499.00, 999.00, 1499.00, 2999.00])
    
    if success:
        message = f"Payment of INR {amount:,.2f} to Qless Merchant was successful."
    else:
        reason = random.choice([
            "declined by the issuing bank",
            "insufficient funds in the account",
            "incorrect OTP entered",
            "network timeout during processing"
        ])
        message = f"Payment of INR {amount:,.2f} failed: {reason}."
        
    return {
        "success": success,
        "message": message,
        "transactionId": txn_id
    }
