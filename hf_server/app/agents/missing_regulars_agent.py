import os
import json
import statistics
from datetime import datetime
from typing import List, Dict, Any
from groq import Groq
from dotenv import load_dotenv

from app.services.supabase import SupabaseQuerier

base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dotenv_path = os.path.join(base_dir, ".env")
load_dotenv(dotenv_path=dotenv_path, override=True)

class MissingRegularsAgent:
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if api_key:
            api_key = api_key.replace("your_groq_api_key_here", "").strip()
        print(f"[MissingRegularsAgent] GROQ API Key: {api_key}")
        if not api_key:
            print("[WARNING] GROQ_API_KEY not detected, using mock key")
            api_key = "gsk_mock_key_placeholder"
        self.client = Groq(api_key=api_key)
        self.model = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
        self.supabase = SupabaseQuerier()

    def _analyze_regularity(self, orders: List[Dict[str, Any]], current_cart_skus: List[str]) -> List[Dict[str, Any]]:
        """
        Analyzes order history to find regular items missing from the current cart.
        Applies a 3-layer filter: Frequency, Consistency (CV), and Timing (Due Date).
        """
        if not orders:
            return []

        # 1. Extract dates and group by SKU
        sku_history = {}
        sku_metadata = {}

        for order in orders:
            try:
                # The items column might be a JSON string or already parsed list
                items_raw = order.get("items", [])
                items = json.loads(items_raw) if isinstance(items_raw, str) else items_raw
                
                # Parse created_at
                created_at_str = order.get("created_at")
                if not created_at_str:
                    continue
                # Simple parsing assuming ISO format
                created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00")).date()

                for item in items:
                    # Extract SKU from details if id is not the SKU
                    details = item.get("details", "")
                    sku = item.get("id")
                    if "SKU: " in details:
                        sku = details.split("SKU: ")[1].split(" ")[0]

                    if not sku:
                        continue

                    if sku not in sku_history:
                        sku_history[sku] = set()
                        sku_metadata[sku] = {
                            "sku": sku,
                            "name": item.get("name", "Unknown Item"),
                            "price": item.get("price", 0),
                            "imageUrl": item.get("imageUrl", "")
                        }
                    
                    sku_history[sku].add(created_at)

            except Exception as e:
                print(f"[MissingRegularsAgent] Error parsing order: {e}")
                continue

        today = datetime.utcnow().date()
        missing_regulars = []

        # 2. Apply regularity logic
        for sku, dates_set in sku_history.items():
            dates = sorted(list(dates_set))
            
            # Layer 1: Frequency Check (Must be bought on at least 3 distinct days)
            if len(dates) < 3:
                continue

            # Calculate gaps between purchases
            gaps = [(dates[i] - dates[i-1]).days for i in range(1, len(dates))]
            if not gaps:
                continue

            avg_gap = statistics.mean(gaps)
            
            # Layer 2: Consistency Check (CV <= 0.6)
            if len(gaps) > 1:
                std_dev = statistics.stdev(gaps)
                cv = std_dev / avg_gap if avg_gap > 0 else 0
                if cv > 0.6:
                    continue # Too erratic, not a consistent regular item

            # Layer 3: Timing / Due Date Check
            days_since_last = (today - dates[-1]).days
            
            # If they bought it very recently, they don't need it yet.
            # If days_since_last is close to or greater than avg_gap, they are due.
            # We add a small buffer (e.g., -2 days) so we remind them slightly before they completely run out.
            if days_since_last < (avg_gap - 2):
                continue

            # Final Filter: Is it already in the cart?
            if sku in current_cart_skus:
                continue

            # Passed all layers! It's a missing regular.
            item_data = sku_metadata[sku]
            item_data["frequency"] = len(dates)
            item_data["avg_gap_days"] = round(avg_gap, 1)
            item_data["last_bought_days_ago"] = days_since_last
            
            missing_regulars.append(item_data)

        # Sort by most frequently bought
        missing_regulars.sort(key=lambda x: x["frequency"], reverse=True)
        return missing_regulars

    async def analyze_cart(self, user_id: str, current_cart: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Main entry point for the route.
        Fetches history, finds missing regulars, and gets the LLM to write a friendly reminder.
        """
        # Fetch history (last 90 days)
        orders = await self.supabase.get_order_history(user_id=user_id, days=90)
        
        # Extract current SKUs
        current_skus = [item.get("sku") or item.get("id") for item in current_cart]
        
        # Find missing regulars via Python logic
        missing_items = self._analyze_regularity(orders, current_skus)
        
        if not missing_items:
            return {
                "response_text": "",
                "missing_regulars": []
            }

        # Format items for the LLM prompt
        cart_str = ", ".join([item.get("name", "") for item in current_cart]) if current_cart else "Empty cart"
        missing_str = ", ".join([item["name"] for item in missing_items])

        # LLM writes the phrasing
        prompt = f"""You are a helpful, friendly AI shopping assistant.
The user is currently reviewing their shopping cart.
Current cart contains: {cart_str}

Based on our deterministic analysis of their past 90 days of orders, they regularly buy these items every few weeks, but forgot to add them today:
Missing Regulars: {missing_str}

Write a very brief, friendly 1-2 sentence reminder suggesting they might want to add these to their cart before checking out. 
Do not mention the "90 days" or the algorithm. Just be natural and helpful, like "I noticed you usually grab..." or "Don't forget your usual...".
Respond ONLY with the message text. No JSON, no extra formatting."""

        try:
            completion = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=150,
                temperature=0.4
            )
            response_text = completion.choices[0].message.content.strip()
        except Exception as e:
            print(f"[MissingRegularsAgent] LLM Generation failed: {e}")
            response_text = "It looks like you might have forgotten a few of your regular items. Would you like to add them?"

        return {
            "response_text": response_text,
            "missing_regulars": missing_items
        }
