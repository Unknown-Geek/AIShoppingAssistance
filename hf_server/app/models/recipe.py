from pydantic import BaseModel
from typing import List, Optional

class RecipeStructure(BaseModel):
    dish: str
    servings: int
    ingredients: List[str]
    instructions: List[str]

class ChatMessagePayload(BaseModel):
    is_user: bool
    text: str

class RecipeRequest(BaseModel):
    user_id: str
    current_cart_slugs: List[str]
    dish_query: str
    servings: int
    chat_history: Optional[List[ChatMessagePayload]] = None