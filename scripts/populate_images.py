import json
import urllib.request
import urllib.parse
import re
import time
import os

def get_product_image_url(product_name):
    # We query Bing Image Search with the product name and "product package" or "thumbnail"
    query = f"{product_name} packaging"
    encoded_query = urllib.parse.quote_plus(query)
    url = f"https://www.bing.com/images/search?q={encoded_query}"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8', errors='ignore')
            
        # Find OIP links
        matches = re.findall(r'(https?://[^\s\"\'<>\\#]+?/th/id/OIP\.[^\s\"\'<>\\#]+)', html)
        if matches:
            # Clean OIP URL
            base_url = matches[0].split('?')[0]
            # Clean up any HTML entities (like &amp; if they leaked, though split by ? usually handles query params)
            base_url = base_url.replace('&amp;', '&')
            # Append size constraints to make it a perfect fast-loading 200x200 square thumbnail
            return f"{base_url}?w=200&h=200&c=7"
    except Exception as e:
        print(f"Error fetching image for '{product_name}': {e}")
    
    # Return a fallback or placeholder
    return None

def main():
    json_path = 'inventory.json'
    if not os.path.exists(json_path):
        print(f"Error: {json_path} not found.")
        return
        
    print("Loading inventory.json...")
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    items = data.get('items', [])
    total_items = len(items)
    print(f"Loaded {total_items} items. Starting image scraping...")
    
    for idx, item in enumerate(items):
        name = item.get('name')
        sku = item.get('sku')
        print(f"[{idx+1}/{total_items}] Scraping image for '{name}' ({sku})...")
        
        # Check if it already has a non-placeholder image
        # (if we want to allow rerunning the script safely)
        if 'image_url' in item and item['image_url'] and 'unsplash' not in item['image_url']:
            print("  Already has custom image, skipping.")
            continue
            
        img_url = get_product_image_url(name)
        if img_url:
            item['image_url'] = img_url
            print(f"  Found URL: {img_url}")
        else:
            # Fallback if scraping failed
            item['image_url'] = "https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=200&auto=format&fit=crop"
            print("  Scraping failed, using fallback Unsplash placeholder.")
            
        # Delay to avoid rate limiting
        time.sleep(0.5)
        
    print("Writing updated data back to inventory.json...")
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)
        
    print("Successfully populated inventory.json with image URLs!")

if __name__ == '__main__':
    main()
