from pydantic import BaseModel


class RecipeRequest(BaseModel):
    prompt: str