from typing import List, Optional, Any, Dict
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException
import traceback

from app.agents.missing_regulars_agent import MissingRegularsAgent

router = APIRouter(prefix="/cart-analysis", tags=["Cart Analysis"])
agent = MissingRegularsAgent()

class CartItem(BaseModel):
    id: str = None
    sku: str = None
    name: str = None
    price: float = 0.0
    quantity: int = 1
    
    def dict(self, **kwargs):
        return super().model_dump(**kwargs)

class CartAnalysisRequest(BaseModel):
    user_id: str
    current_cart: List[CartItem] = []

@router.post("/missing-regulars")
async def get_missing_regulars(payload: CartAnalysisRequest):
    """
    Analyzes the user's past 90 days of order history to identify items 
    they buy regularly but haven't added to their current cart.
    Returns a friendly LLM-generated message and a list of structured item suggestions.
    """
    try:
        user = str(payload.user_id).lower().strip()
        # Convert pydantic models to dicts for the agent
        current_cart = [item.dict() for item in payload.current_cart]

        result = await agent.analyze_cart(user_id=user, current_cart=current_cart)
        return result
        
    except Exception as e:
        print("\n=== CRITICAL API ROUTE ERROR TRACEBACK ===")
        traceback.print_exc()
        print("==========================================\n")
        raise HTTPException(status_code=500, detail=str(e))
