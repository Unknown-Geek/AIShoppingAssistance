from pydantic import BaseModel

class RecipeRequest(BaseModel):

    dish: str
    servings: int

    prompt: str

