import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
from app.services.nutrition_service import NutritionService

async def main():
    service = NutritionService()
    await service.get_nutrition("Amul Gold Standardised Milk")

asyncio.run(main())