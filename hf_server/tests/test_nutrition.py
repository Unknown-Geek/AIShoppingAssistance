import asyncio
from app.services.nutrition_service import NutritionService


async def main():
    service = NutritionService()

    foods = [
        "rice",
        "milk",
        "onion",
        "carrot",
        "potato",
    ]

    for food in foods:
        result = await service.get_nutrition(food)

        print()
        print("=" * 40)
        print(food.upper())
        print(result)


asyncio.run(main())