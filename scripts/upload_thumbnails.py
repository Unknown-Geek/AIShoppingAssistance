"""
upload_thumbnails.py
--------------------
Uploads all .webp images from the 'Images (2)' folder to Supabase Storage
(bucket: product-images) and updates the `thumbnail_url` column in the
`products` table for each matching product.

Requirements:
    pip install supabase python-dotenv

Usage:
    python scripts/upload_thumbnails.py
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client, Client

# ── Config ──────────────────────────────────────────────────────────────────
load_dotenv()

SUPABASE_URL  = os.getenv("SUPABASE_URL")
# Use the service role key — it bypasses RLS, safe for server-side scripts only
SUPABASE_KEY  = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
BUCKET_NAME   = "product-images"
IMAGES_DIR    = Path(__file__).parent.parent / "Images (2)"
TABLE_NAME    = "inventory"
NAME_COLUMN   = "name"       # The column in `products` that holds product names
URL_COLUMN    = "thumbnail_url"

if not SUPABASE_URL or not SUPABASE_KEY or SUPABASE_KEY == "PASTE_YOUR_SERVICE_ROLE_KEY_HERE":
    sys.exit("❌  SUPABASE_SERVICE_ROLE_KEY not set in .env — get it from Supabase Dashboard → Settings → API")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ── Helpers ──────────────────────────────────────────────────────────────────

def get_public_url(path_in_bucket: str) -> str:
    """Return the public URL for a file already in the bucket."""
    result = supabase.storage.from_(BUCKET_NAME).get_public_url(path_in_bucket)
    return result

def upload_image(local_path: Path) -> str | None:
    """Upload a single image; return its public URL or None on failure."""
    dest = local_path.name          # e.g. "Maggi Rich Tomato Ketchup.webp"
    with open(local_path, "rb") as f:
        data = f.read()
    try:
        supabase.storage.from_(BUCKET_NAME).upload(
            path=dest,
            file=data,
            file_options={"content-type": "image/webp", "upsert": "true"},
        )
        print(f"  ✅ Uploaded: {dest}")
        return get_public_url(dest)
    except Exception as e:
        print(f"  ⚠️  Upload failed for {dest}: {e}")
        return None

def update_product(product_name: str, url: str) -> bool:
    """Set thumbnail_url for the product whose name matches (case-insensitive)."""
    # Try exact match first
    resp = (
        supabase.table(TABLE_NAME)
        .update({URL_COLUMN: url})
        .ilike(NAME_COLUMN, product_name)
        .execute()
    )
    updated = len(resp.data) if resp.data else 0
    if updated == 0:
        print(f"  ⚠️  No DB row matched for: '{product_name}'")
        return False
    print(f"  🔗 DB updated ({updated} row): '{product_name}'")
    return True

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    images = sorted(IMAGES_DIR.glob("*.webp"))
    if not images:
        sys.exit(f"❌  No .webp images found in: {IMAGES_DIR}")

    print(f"\n📦 Found {len(images)} images to process.\n")

    success_count = 0
    for img_path in images:
        product_name = img_path.stem   # filename without extension
        print(f"→ {product_name}")

        public_url = upload_image(img_path)
        if public_url:
            update_product(product_name, public_url)
            success_count += 1
        print()

    print(f"✅  Done! {success_count}/{len(images)} images uploaded and linked.")


if __name__ == "__main__":
    main()
