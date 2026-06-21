"""
USDA foodMeasures Verification Script
Run: python3 verify_usda_measures.py YOUR_API_KEY
"""

import sys
import json
import urllib.request
import urllib.parse

API_KEY  = sys.argv[1] if len(sys.argv) > 1 else "DEMO_KEY"
BASE_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"

INGREDIENTS = [
    ("rice",        "Basmati rice",     ["cup", "tablespoon"]),
    ("onion",       "Onion",            ["medium", "small", "cup", "tablespoon"]),
    ("garlic",      "Garlic",           ["clove", "cup"]),
    ("oil",         "Oil, vegetable",   ["tablespoon", "cup", "teaspoon"]),
    ("tomato",      "Tomatoes, raw",    ["medium", "cup", "slice"]),
    ("potato",      "Potato, raw",      ["medium", "large", "cup"]),
]

DATA_TYPES = "SR Legacy,Foundation"

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

results_summary = []

def fetch(query):
    params = urllib.parse.urlencode({
        "query":    query,
        "api_key":  API_KEY,
        "dataType": DATA_TYPES,
        "pageSize": 1,
    })
    url = f"{BASE_URL}?{params}"
    with urllib.request.urlopen(url, timeout=10) as r:
        return json.loads(r.read())

print(f"\n{BOLD}USDA foodMeasures Verification{RESET}")
print(f"API key: {API_KEY[:8]}{'*' * (len(API_KEY)-8) if len(API_KEY) > 8 else ''}")
print(f"dataType filter: {DATA_TYPES}")
print("=" * 70)

for query, label, wanted_units in INGREDIENTS:
    print(f"\n{BOLD}{label}{RESET}  (query: '{query}')")
    try:
        data  = fetch(query)
        foods = data.get("foods", [])

        if not foods:
            print(f"  {RED}✗ NO RESULTS returned by USDA{RESET}")
            results_summary.append((label, False, "no results"))
            continue

        food     = foods[0]
        desc     = food.get("description", "?")
        dtype    = food.get("dataType", "?")
        measures = food.get("foodMeasures", [])

        print(f"  matched: {desc}  [{dtype}]")

        if not measures:
            print(f"  {RED}✗ foodMeasures MISSING — design assumption FAILS for this ingredient{RESET}")
            results_summary.append((label, False, "foodMeasures absent"))
            continue

        print(f"  {GREEN}✓ foodMeasures present ({len(measures)} entries){RESET}")

        # Show all measures
        found_units = set()
        for m in measures:
            text = m.get("disseminationText", "")
            gw   = m.get("gramWeight")
            unit_word = text.split()[-1].lower().rstrip("s") if text else ""
            found_units.add(unit_word)
            print(f"      {text:25s}  →  {gw} g")

        # Check which wanted units are covered
        print(f"  wanted units: {wanted_units}")
        hits   = []
        misses = []
        for u in wanted_units:
            u_singular = u.rstrip("s")
            if any(u_singular in m.get("disseminationText","").lower() for m in measures):
                hits.append(u)
            else:
                misses.append(u)

        if hits:
            print(f"  {GREEN}covered: {hits}{RESET}")
        if misses:
            print(f"  {YELLOW}not covered: {misses} (SI fallback or skip){RESET}")

        all_ok = len(misses) == 0
        results_summary.append((label, True, hits, misses))

    except Exception as e:
        print(f"  {RED}ERROR: {e}{RESET}")
        results_summary.append((label, False, str(e)))

# ── Summary ──────────────────────────────────────────────────────────────────
print(f"\n{'=' * 70}")
print(f"{BOLD}SUMMARY{RESET}")
print(f"{'=' * 70}")

design_safe = True
for row in results_summary:
    name = row[0]
    ok   = row[1]
    if ok:
        hits, misses = row[2], row[3]
        status = f"{GREEN}✓ foodMeasures present{RESET}"
        if misses:
            status += f"  {YELLOW}(missing: {misses}){RESET}"
            print(f"  {status}   {name}")
        else:
            print(f"  {status}   {name}")
    else:
        design_safe = False
        reason = row[2]
        print(f"  {RED}✗ FAILED ({reason})   {name}{RESET}")

print()
if design_safe:
    print(f"{GREEN}{BOLD}✓ DESIGN ASSUMPTION HOLDS.{RESET}")
    print("  USDA foodMeasures covers your core ingredients.")
    print("  The QuantityNormalizerService approach is safe to build.")
else:
    print(f"{RED}{BOLD}✗ DESIGN ASSUMPTION FAILS for one or more ingredients.{RESET}")
    print("  Check the details above. You may need a fallback strategy.")
print()