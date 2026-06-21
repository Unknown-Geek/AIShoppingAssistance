import threading
from typing import Dict, Any, List

class InMemoryCartStateManager:
    def __init__(self):
        # Dictionary structure: { user_id: { sku: quantity } }
        self._carts: Dict[str, Dict[str, int]] = {}
        self._lock = threading.Lock()

    def sync_from_client(self, user_id: str, current_cart: List[Dict[str, Any]]) -> None:
        """
        Resets the server-side cart for a user to exactly match the authoritative
        state sent by the Flutter client on every request.

        Flutter's CartService is the single source of truth. This prevents the
        server accumulating stale quantities when the cart is modified externally
        (dashboard scanner, checkout, manual clear from outside the chatbot).
        """
        with self._lock:
            if not current_cart:
                # Cart was cleared externally — wipe server state entirely
                self._carts[user_id] = {}
            else:
                # Rebuild map directly from client payload
                self._carts[user_id] = {
                    item["sku"]: int(item.get("quantity", 1))
                    for item in current_cart
                    if item.get("sku")
                }

    def add_item(self, user_id: str, sku: str, quantity: int = 1) -> bool:
        """Thread-safe write operation to add or increment a SKU in a user's cart."""
        with self._lock:
            if user_id not in self._carts:
                self._carts[user_id] = {}
            
            # Increment the quantity if it already exists, otherwise set it
            current_qty = self._carts[user_id].get(sku, 0)
            self._carts[user_id][sku] = current_qty + quantity
            return True

    def get_cart(self, user_id: str) -> Dict[str, int]:
        """Thread-safe read operation to fetch a user's full cart map."""
        with self._lock:
            # Return a copy to prevent external mutation outside the lock
            return dict(self._carts.get(user_id, {}))

    def clear_cart(self, user_id: str) -> None:
        """Thread-safe operation to wipe out a cart session."""
        with self._lock:
            if user_id in self._carts:
                self._carts[user_id] = {}

    def remove_item(self, user_id: str, sku: str, quantity: int = 1) -> bool:
        """Thread-safe write operation to remove or decrement a SKU in a user's cart."""
        with self._lock:
            if user_id not in self._carts or sku not in self._carts[user_id]:
                return False
            
            current_qty = self._carts[user_id][sku]
            if current_qty > quantity:
                self._carts[user_id][sku] = current_qty - quantity
            else:
                del self._carts[user_id][sku]
            return True

# Instantiate a single global singleton instance to be imported across modules
live_cart_memory = InMemoryCartStateManager()