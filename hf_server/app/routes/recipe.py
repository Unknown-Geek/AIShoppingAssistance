from fastapi import APIRouter
from ..models.recipe import RecipeRequest
from ..agents.recipe_agent import RecipeAgent

router = APIRouter()
recipe_agent = RecipeAgent()

@router.post("/recipe-agent")
async def recipe_agent_endpoint(request: RecipeRequest):
    return await recipe_agent.generate_recipe(
        request.dish,
        request.servings
    )
