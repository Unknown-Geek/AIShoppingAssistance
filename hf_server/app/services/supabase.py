import os
import httpx
from .http_client import http_client

class SupabaseQuerier:
    def __init__(self, url: str = None, key: str = None):
        self.url = url or os.environ.get("SUPABASE_URL", "")
        self.key = key or os.environ.get("SUPABASE_ANON_KEY", "")

    async def get_product_by_slug(self, slug: str) -> dict | None:
        if not self.url or not self.key:
            print("[SupabaseQuerier] Warning: Supabase credentials missing.")
            return None

        base_url = self.url.rstrip("/")
        query_url = f"{base_url}/rest/v1/inventory?slug=eq.{slug}&select=sku,slug,name,price_rupees,staging_dirs"
        
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}"
        }

        client = http_client if http_client is not None else httpx.AsyncClient()
        close_client = http_client is None
        try:
            response = await client.get(query_url, headers=headers, timeout=5.0)
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list) and len(data) > 0:
                    return data[0]
            else:
                print(f"[SupabaseQuerier] Query failed: {response.status_code} - {response.text}")
        except Exception as e:
            print(f"[SupabaseQuerier] Error querying Supabase: {e}")
        finally:
            if close_client:
                await client.aclose()
        return None

    async def get_order_history(self, user_id: str, days: int = 90) -> list:
        if not self.url or not self.key:
            print("[SupabaseQuerier] Warning: Supabase credentials missing.")
            return []

        from datetime import datetime, timedelta
        cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()

        base_url = self.url.rstrip("/")
        query_url = f"{base_url}/rest/v1/user_carts?user_id=eq.{user_id}&status=eq.processed&created_at=gte.{cutoff_date}&select=items,created_at"
        
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}"
        }

        client = http_client if http_client is not None else httpx.AsyncClient()
        close_client = http_client is None
        try:
            print(f"DEBUG: Query URL: {query_url}")
            response = await client.get(query_url, headers=headers, timeout=5.0)
            print(f"DEBUG: Status Code: {response.status_code}")
            if response.status_code == 200:
                print(f"DEBUG: Response length: {len(response.json())}")
                return response.json()
            else:
                print(f"[SupabaseQuerier] Order history query failed: {response.status_code} - {response.text}")
        except Exception as e:
            print(f"[SupabaseQuerier] Error querying Supabase order history: {e}")
        finally:
            if close_client:
                await client.aclose()
        return []
