"""
QuantityNormalizerService
=========================
Converts recipe cooking-unit ingredients → grams using USDA FoodData Central.

Flow per ingredient:
    1. Search /v1/foods/search  → fdcId
    2. Fetch /v1/food/{fdcId}   → foodPortions + foodMeasures
    3. Match cooking unit to a USDA portion entry
    4. Return grams

Design constraints honoured:
    ✓ No hardcoded ingredient conversion tables
    ✓ No extra LLM calls
    ✓ USDA is the single source of truth
    ✓ Returns None (never 0) when conversion impossible — caller skips
"""

import re
import logging
from difflib import SequenceMatcher
from typing import Optional

import httpx  # already in your stack; swap for aiohttp if preferred

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# USDA base URL — single constant, easy to mock in tests
# ---------------------------------------------------------------------------
USDA_BASE = "https://api.nal.usda.gov/fdc/v1"

# ---------------------------------------------------------------------------
# Unit alias table
# Purpose: normalise user-facing cooking strings → a canonical key.
# These are UNIT NAME normalisations only — no gram values here.
# ---------------------------------------------------------------------------
UNIT_ALIASES: dict[str, str] = {
    # cups
    "cup": "cup", "cups": "cup", "c": "cup", "c.": "cup",
    # tablespoons
    "tablespoon": "tablespoon", "tablespoons": "tablespoon",
    "tbsp": "tablespoon", "tbsp.": "tablespoon", "tbs": "tablespoon",
    "tb": "tablespoon",
    # teaspoons
    "teaspoon": "teaspoon", "teaspoons": "teaspoon",
    "tsp": "teaspoon", "tsp.": "teaspoon",
    # mass — handled directly, no USDA lookup needed
    "gram": "gram", "grams": "gram", "g": "gram", "g.": "gram",
    "kilogram": "kilogram", "kilograms": "kilogram", "kg": "kilogram",
    # imperial mass
    "ounce": "ounce", "ounces": "ounce", "oz": "ounce", "oz.": "ounce",
    "pound": "pound", "pounds": "pound", "lb": "pound",
    "lbs": "pound", "lb.": "pound",
    # volume (liquid)
    "milliliter": "milliliter", "milliliters": "milliliter",
    "ml": "milliliter", "ml.": "milliliter",
    "liter": "liter", "liters": "liter", "l": "liter",
    "fluid ounce": "fluid_ounce", "fl oz": "fluid_ounce",
    "fl. oz.": "fluid_ounce",
    # cooking pieces — all resolved via USDA foodPortions
    "clove": "clove", "cloves": "clove",
    "piece": "piece", "pieces": "piece",
    "whole": "whole",
    "small": "small",
    "medium": "medium",
    "large": "large",
    "extra large": "extra_large", "xl": "extra_large",
    "slice": "slice", "slices": "slice",
    "sprig": "sprig", "sprigs": "sprig",
    "stalk": "stalk", "stalks": "stalk",
    "bunch": "bunch", "bunches": "bunch",
    "head": "head", "heads": "head",
    "handful": "handful",
    "can": "can", "cans": "can",
    "package": "package", "packages": "package", "pkg": "package",
    "strip": "strip", "strips": "strip",
    "fillet": "fillet", "fillets": "fillet",
    "breast": "breast", "thigh": "thigh", "leg": "leg",
    "pinch": "pinch", "dash": "dash",
}

# ---------------------------------------------------------------------------
# SI fallback — for mass/volume units that need no ingredient-specific data.
# Used ONLY when USDA returns nothing useful.
# ---------------------------------------------------------------------------
SI_GRAMS: dict[str, float] = {
    "gram":        1.0,
    "kilogram":    1000.0,
    "ounce":       28.3495,
    "pound":       453.592,
    "milliliter":  1.0,      # water-density assumption; fine for oils/broths
    "liter":       1000.0,
    "fluid_ounce": 29.5735,
    "tablespoon":  14.7868,  # last-resort SI for liquids only
    "teaspoon":    4.9289,   # last-resort SI for liquids only
}

# ---------------------------------------------------------------------------
# Negligible units — nutritionally irrelevant; skip cleanly without warning
# ---------------------------------------------------------------------------
SKIP_UNITS = {"pinch", "dash", "to taste", "as needed", "a pinch"}


# ===========================================================================
class QuantityNormalizerService:
    """
    Async service.  Instantiate once, reuse across requests (shares httpx client).

    Usage:
        async with QuantityNormalizerService(api_key="...") as normalizer:
            result = await normalizer.normalize_ingredient({
                "name": "Basmati Rice",
                "quantity": "1",
                "unit": "cup"
            })
    """

    def __init__(self, api_key: str):
        self._api_key = api_key
        self._client: Optional[httpx.AsyncClient] = None

    # ------------------------------------------------------------------
    # Context manager — keeps a single httpx session alive
    # ------------------------------------------------------------------
    async def __aenter__(self):
        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(10.0),
            params={"api_key": self._api_key},
        )
        return self

    async def __aexit__(self, *_):
        if self._client:
            await self._client.aclose()

    # ==================================================================
    # Public API
    # ==================================================================

    async def normalize_ingredient(self, ingredient: dict) -> Optional[dict]:
        """
        Convert one ingredient dict to grams.

        Input:
            {"name": "Garlic", "quantity": "2", "unit": "cloves"}

        Output (success):
            {
                "name": "Garlic",
                "original_quantity": "2 cloves",
                "quantity": 6.0,
                "unit": "g"
            }

        Output (failure):
            None   ← caller skips this ingredient, reason already logged
        """
        name         = ingredient.get("name", "").strip()
        raw_quantity = str(ingredient.get("quantity", "0")).strip()
        raw_unit     = str(ingredient.get("unit", "")).strip()

        if not name:
            logger.warning("normalize_ingredient: ingredient has no name — skipping")
            return None

        quantity = self._parse_quantity(raw_quantity)
        if quantity is None or quantity <= 0:
            logger.warning(
                "[%s] quantity '%s' could not be parsed — skipping", name, raw_quantity
            )
            return None

        canonical_unit = self._canonicalize(raw_unit)

        # Negligible units — skip without noise
        if canonical_unit in SKIP_UNITS:
            logger.info("[%s] unit '%s' is negligible — skipping", name, raw_unit)
            return None

        original = f"{raw_quantity} {raw_unit}".strip()
        logger.debug("[%s] normalising: %s", name, original)

        # ── Path 1: already in grams / kg ──────────────────────────────────
        if canonical_unit in ("gram", "kilogram"):
            grams = quantity * SI_GRAMS[canonical_unit]
            return self._result(name, original, grams)

        # ── Path 2: USDA lookup ─────────────────────────────────────────────
        grams = await self._usda_convert(name, quantity, canonical_unit, raw_unit)
        if grams is not None:
            return self._result(name, original, grams)

        # ── Path 3: SI fallback (oz, lb, ml, l, fl oz) ─────────────────────
        if canonical_unit in SI_GRAMS:
            grams = quantity * SI_GRAMS[canonical_unit]
            logger.info(
                "[%s] SI fallback: %s %s → %.2fg", name, quantity, raw_unit, grams
            )
            return self._result(name, original, grams)

        # ── No conversion possible ──────────────────────────────────────────
        logger.warning(
            "[%s] SKIP — cannot convert '%s %s': "
            "no USDA portion match and no SI fallback for this unit.",
            name, quantity, raw_unit,
        )
        return None

    async def normalize_ingredients(
        self, ingredients: list[dict]
    ) -> tuple[list[dict], list[dict]]:
        """
        Normalise a list of ingredients.

        Returns (normalised, skipped) — two separate lists so the caller
        can log or surface skipped items to the user.
        """
        import asyncio
        tasks = [self.normalize_ingredient(i) for i in ingredients]
        results = await asyncio.gather(*tasks, return_exceptions=False)

        normalised, skipped = [], []
        for original, result in zip(ingredients, results):
            if result is None:
                skipped.append(original)
            else:
                normalised.append(result)

        print("\n===== NORMALIZED INGREDIENTS =====")
        for item in normalised:
            print(item)

        print("\n===== SKIPPED INGREDIENTS =====")
        for item in skipped:
            print(item)

        print("=================================\n")

        return normalised, skipped

    # ==================================================================
    # USDA logic
    # ==================================================================

    async def _usda_convert(
        self,
        name: str,
        quantity: float,
        canonical_unit: str,
        raw_unit: str,
    ) -> Optional[float]:
        """
        Full USDA two-step:
            1. Search → fdcId
            2. Food detail → foodPortions + foodMeasures
            3. Match unit → gramWeight
        """
        fdc_id = await self._search_fdc_id(name)
        if fdc_id is None:
            logger.warning("[%s] USDA search returned no results", name)
            return None

        portions, measures = await self._fetch_portions(fdc_id, name)

        # Try foodPortions first (richer, from /food/{fdcId})
        gw = self._match_portions(canonical_unit, portions)
        if gw is not None:
            result = quantity * gw
            logger.debug(
                "[%s] foodPortions match: %s %s → %.2fg (%.4g g/unit)",
                name, quantity, raw_unit, result, gw,
            )
            return result

        # Fall back to foodMeasures (also present on detail endpoint)
        gw = self._match_measures(canonical_unit, measures)
        if gw is not None:
            result = quantity * gw
            logger.debug(
                "[%s] foodMeasures match: %s %s → %.2fg (%.4g g/unit)",
                name, quantity, raw_unit, result, gw,
            )
            return result

        logger.info(
            "[%s] fdcId=%s — no portion/measure match for unit '%s'. "
            "Available: portions=%s  measures=%s",
            name, fdc_id,
            canonical_unit,
            [p.get("modifier","") or p.get("measureUnit",{}).get("name","") for p in portions],
            [m.get("disseminationText","") for m in measures],
        )
        return None

    async def _search_fdc_id(self, query: str) -> Optional[int]:
        """Search USDA, return fdcId of best SR Legacy / Foundation match.

        Uses pageSize=100 and scores results so that SR Legacy/Foundation entries for
        raw/whole foods rank above processed or branded items that happen
        to share a keyword (e.g. "Rice crackers" vs "Rice, white, raw").
        """
        # Generic query sanitization: regex-remove parenthetical text and trim
        query = re.sub(r"\(.*?\)", "", query).strip()
        query = re.sub(r"\s+", " ", query)

        _PROCESSED_KW = {
            "cracker", "snack", "cake", "cookie", "chip", "mix", "beverage",
            "soup", "sauce", "pudding", "babyfood", "ring", "frozen", "fried",
            "powder", "flake", "dehydrated", "pickled", "canned", "bread",
            "breadstick", "sausage",
        }

        def _score(food: dict, q_str: str) -> float:
            desc  = food.get("description", "").lower()
            q_low = q_str.lower()
            sc    = SequenceMatcher(None, q_low, desc).ratio()
            # Bonus: description starts with a query word ("Onions, raw" for "Onion")
            q_stems = {w.rstrip("s") for w in q_low.split()}
            d_first = desc.split(",")[0].strip().rstrip("s") if desc else ""
            if d_first and d_first in q_stems:
                sc += 1.0
                if "," in desc[:15]:   # "Onions, raw" pattern — tightly scoped entry
                    sc += 2.0
            # Bonus: raw / whole food
            if any(w in desc for w in ("raw", "fresh", "uncooked")):
                sc += 0.5
            # SR Legacy has richer foodPortions than Foundation
            if food.get("dataType") == "SR Legacy":
                sc += 2.0
            # Penalty: processed / packaged food
            for kw in _PROCESSED_KW:
                if kw in desc:
                    sc -= 3.0
                    break
            return sc

        # Formulate search queries: try appending "raw" first if not specified
        queries = [query]
        q_low = query.lower()
        if not any(w in q_low for w in ("raw", "fresh", "uncooked", "cooked", "dry", "canned", "powder")):
            queries.insert(0, f"{query} raw")

        for q in queries:
            try:
                resp = await self._client.get(
                    f"{USDA_BASE}/foods/search",
                    params={
                        "query":    q,
                        "dataType": "SR Legacy,Foundation",
                        "pageSize": 100,
                    },
                )
                resp.raise_for_status()
                foods = resp.json().get("foods", [])
                if foods:
                    best = max(foods, key=lambda f: _score(f, q))
                    return best.get("fdcId")
            except httpx.HTTPError as exc:
                logger.error("[%s] USDA search HTTP error for query '%s': %s", query, q, exc)
        return None

    async def _fetch_portions(
        self, fdc_id: int, name: str
    ) -> tuple[list[dict], list[dict]]:
        """
        Fetch /v1/food/{fdcId}.
        Returns (foodPortions, foodMeasures) — both may be empty lists.
        """
        try:
            resp = await self._client.get(f"{USDA_BASE}/food/{fdc_id}")
            resp.raise_for_status()
            data = resp.json()
            portions = data.get("foodPortions", [])
            measures = data.get("foodMeasures", [])
            logger.debug(
                "[%s] fdcId=%s  portions=%d  measures=%d",
                name, fdc_id, len(portions), len(measures),
            )
            return portions, measures
        except httpx.HTTPError as exc:
            logger.error("[%s] USDA detail HTTP error (fdcId=%s): %s", name, fdc_id, exc)
            return [], []

    # ==================================================================
    # Matching logic
    # ==================================================================

    def _match_portions(
        self, canonical_unit: str, portions: list[dict]
    ) -> Optional[float]:
        """
        Match against foodPortions (from /food/{fdcId}).

        foodPortions entry shape:
        {
            "id": 123,
            "amount": 1.0,
            "gramWeight": 186.0,
            "modifier": "1 cup",               ← free-text description
            "measureUnit": {
                "id": 999,
                "name": "cup",                  ← structured unit name
                "abbreviation": "cup"
            },
            "portionDescription": "1 cup"
        }
        """
        best_score = -1.0
        best_gw: Optional[float] = None
        size_units = {'small', 'medium', 'large', 'whole', 'piece'}
        penalized_keywords = ['slice', 'sliced', 'chopped', 'diced', 'rings']

        for portion in portions:
            gw     = portion.get("gramWeight")
            amount = portion.get("amount") or 1.0
            if not gw or gw <= 0 or not amount:
                continue

            # Gather candidate text fields for this portion
            candidates = self._portion_text_candidates(portion)

            for text in candidates:
                if not text:
                    continue
                usda_canonical = self._canonicalize(text)

                # Exact match — done
                if usda_canonical == canonical_unit:
                    score = 1.0
                # Substring match — "medium onion" contains "medium"
                elif canonical_unit in usda_canonical or usda_canonical in canonical_unit:
                    score = 0.9
                else:
                    score = SequenceMatcher(None, canonical_unit, usda_canonical).ratio()

                # Adjust portion ranking: favor whole-item/each portions when input unit is medium/whole
                if canonical_unit in size_units:
                    if any(x in usda_canonical for x in penalized_keywords):
                        score -= 0.4
                    if any(x in usda_canonical for x in (canonical_unit, "whole", "each")):
                        score += 0.05

                if score > best_score and score >= 0.78:
                    best_score = score
                    best_gw = gw / amount

        return best_gw

    def _match_measures(
        self, canonical_unit: str, measures: list[dict]
    ) -> Optional[float]:
        """
        Match against foodMeasures (also present on /food/{fdcId}).

        foodMeasures entry shape:
        {
            "disseminationText": "1 cup",
            "gramWeight": 186.0,
            "id": 456,
            "measureUnitAbbreviation": "cup",
            "measureUnitName": "cup",
            "rank": 1
        }
        """
        best_score = 0.0
        best_gw: Optional[float] = None

        for measure in measures:
            gw    = measure.get("gramWeight")
            dissem = measure.get("disseminationText", "")
            if not gw or gw <= 0 or not dissem:
                continue

            usda_qty, usda_unit_raw = self._parse_usda_dissem(dissem)
            if not usda_qty or usda_qty <= 0:
                continue

            usda_canonical = self._canonicalize(usda_unit_raw)

            if usda_canonical == canonical_unit:
                return gw / usda_qty

            if canonical_unit in usda_canonical or usda_canonical in canonical_unit:
                score = 0.9
            else:
                score = SequenceMatcher(None, canonical_unit, usda_canonical).ratio()

            if score > best_score and score >= 0.78:
                best_score = score
                best_gw = gw / usda_qty

        return best_gw

    # ==================================================================
    # Parsing helpers
    # ==================================================================

    @staticmethod
    def _portion_text_candidates(portion: dict) -> list[str]:
        """
        Extract all text fields from a foodPortions entry that might
        describe the unit — in priority order.
        """
        candidates = []

        # Structured unit name (most reliable)
        mu = portion.get("measureUnit") or {}
        if mu.get("name") and mu["name"].lower() != "undetermined":
            candidates.append(mu["name"])
        if mu.get("abbreviation") and mu["abbreviation"].lower() != "undetermined":
            candidates.append(mu["abbreviation"])

        # Free-text modifier: "1 cup", "medium", "1 NLEA serving"
        modifier = portion.get("modifier", "")
        if modifier:
            # Strip leading quantity if present ("1 cup" → "cup")
            clean = re.sub(r"^\d+[\./]?\d*\s*", "", modifier).strip()
            candidates.append(clean)
            candidates.append(modifier)  # also try full string

        # portionDescription as last resort
        desc = portion.get("portionDescription", "")
        if desc:
            clean = re.sub(r"^\d+[\./]?\d*\s*", "", desc).strip()
            candidates.append(clean)

        return [c.strip().lower() for c in candidates if c.strip()]

    @staticmethod
    def _parse_usda_dissem(text: str) -> tuple[Optional[float], str]:
        """
        Parse USDA disseminationText.

        "1 cup"        → (1.0, "cup")
        "1/2 teaspoon" → (0.5, "teaspoon")
        "3 cloves"     → (3.0, "cloves")
        "medium"       → (1.0, "medium")   ← no leading number
        """
        text = text.strip()
        match = re.match(r"^(\d+(?:\.\d+)?|\d+/\d+)\s+(.*)", text)
        if not match:
            # No leading number — treat whole string as unit name, qty=1
            return 1.0, text

        qty_str, unit_str = match.group(1), match.group(2).strip()
        if "/" in qty_str:
            try:
                num, den = qty_str.split("/", 1)
                qty = float(num) / float(den)
            except (ValueError, ZeroDivisionError):
                return None, unit_str
        else:
            try:
                qty = float(qty_str)
            except ValueError:
                return None, unit_str

        return qty, unit_str

    @staticmethod
    def _parse_quantity(raw: str) -> Optional[float]:
        """
        Parse a quantity string to float.

        "1"     → 1.0
        "1.5"   → 1.5
        "1/2"   → 0.5
        "½"     → 0.5
        "2 cup" → 2.0   (leading number extracted)
        """
        UNICODE_FRACTIONS = {
            "½": "1/2", "⅓": "1/3", "⅔": "2/3",
            "¼": "1/4", "¾": "3/4", "⅛": "1/8",
        }
        for char, repl in UNICODE_FRACTIONS.items():
            raw = raw.replace(char, repl)

        match = re.match(r"^(\d+(?:\.\d+)?|\d+/\d+)", raw.strip())
        if not match:
            return None

        qty_str = match.group(1)
        if "/" in qty_str:
            try:
                num, den = qty_str.split("/", 1)
                return float(num) / float(den)
            except (ValueError, ZeroDivisionError):
                return None
        try:
            return float(qty_str)
        except ValueError:
            return None

    @staticmethod
    def _canonicalize(unit: str) -> str:
        """
        'Tbsp.'   → 'tablespoon'
        'CLOVES'  → 'clove'
        '1 cup'   → 'cup'          (leading quantity stripped before alias lookup)
        '1 tsp'   → 'teaspoon'     (strip number, then alias tsp→teaspoon)
        '3 cloves'→ 'clove'        (strip number, strip trailing s)
        'medium onion' → try alias, fall back to lowercased string
        """
        cleaned = unit.strip().lower()
        # Strip leading integer/fraction quantity ("1 ", "1/2 ", "0.25 ") so
        # USDA modifier strings like "1 cup" or "3 cloves" resolve via the alias table.
        stripped_qty = re.sub(r"^\d+(?:[./]\d+)?\s+", "", cleaned).strip()
        # Try each form: number-stripped first (most specific), then with number
        for candidate in (stripped_qty, cleaned):
            if candidate in UNIT_ALIASES:
                return UNIT_ALIASES[candidate]
            without_suffix = candidate.rstrip(".").rstrip("s")
            if without_suffix in UNIT_ALIASES:
                return UNIT_ALIASES[without_suffix]
        return stripped_qty or cleaned

    @staticmethod
    def _result(name: str, original: str, grams: float) -> dict:
        return {
            "name":              name,
            "original_quantity": original,
            "quantity":          round(grams, 4),
            "unit":              "g",
        }