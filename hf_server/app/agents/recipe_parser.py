import re

class RecipeParser:
    BAD_WORDS = [
        "facebook",
        "instagram",
        "youtube",
        "pinterest",
        "twitter",
        "share",
        "recipe",
        "faq",
        "faqs",
        "tips",
        "comments",
        "jump",
        "about"
    ]

    def _clean_text(self, text: str) -> str:
        text = re.sub(r'\[(.*?)\]\([^)]*\)', r'\1', text)
        text = re.sub(r'\*\*|__|~~', '', text)
        text = text.replace('•', '-').strip()
        text = re.sub(r'\s+', ' ', text)
        return text.strip()

    def _is_markdown_link(self, text: str) -> bool:
        return bool(re.match(r'^\[.*\]\(.*\)$', text))

    def _should_skip(self, text: str) -> bool:
        cleaned = self._clean_text(text).lower()
        if not cleaned:
            return True
        if self._is_markdown_link(cleaned):
            return True
        if any(word in cleaned for word in self.BAD_WORDS):
            return True
        return False

    def parse(self, markdown: str):
        ingredients = []
        instructions = []

        for line in markdown.splitlines():
            raw = line.strip()
            if not raw:
                continue

            normalized = self._clean_text(raw)
            if not normalized or self._should_skip(raw):
                continue

            if re.match(r'^(ingredients?|shopping list)\s*:?', normalized, re.IGNORECASE):
                continue

            if re.match(r'^[-*]\s+', raw):
                item = re.sub(r'^[-*]\s+', '', raw)
                item = self._clean_text(item)
                if item and not self._should_skip(item):
                    ingredients.append(item)

            elif re.match(r'^\d+[.)]\s+', raw):
                item = re.sub(r'^\d+[.)]\s+', '', raw)
                item = self._clean_text(item)
                if item and not self._should_skip(item):
                    instructions.append(item)

        return {
            "ingredients": ingredients,
            "instructions": instructions
        }
