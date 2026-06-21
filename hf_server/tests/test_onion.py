import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
import os
from dotenv import load_dotenv

load_dotenv()

from app.services.quantity_normalizer_service import QuantityNormalizerService

async def main():
    async with QuantityNormalizerService(
        api_key=os.getenv("USDA_API_KEY")
    ) as q:

        result = await q.normalize_ingredient({
            "name": "Onion",
            "quantity": "1",
            "unit": "medium"
        })

        print(result)

asyncio.run(main())