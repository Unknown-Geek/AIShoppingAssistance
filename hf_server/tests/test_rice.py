import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
import os
from dotenv import load_dotenv

load_dotenv()

print("USDA_API_KEY =", os.getenv("USDA_API_KEY"))

from app.services.quantity_normalizer_service import QuantityNormalizerService


async def main():
    async with QuantityNormalizerService(
        api_key=os.getenv("USDA_API_KEY")
    ) as q:

        result = await q.normalize_ingredient({
            "name": "Basmati Rice",
            "quantity": "1",
            "unit": "cup"
        })

        print(result)

asyncio.run(main())