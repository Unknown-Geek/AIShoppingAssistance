import httpx

class FirecrawlRecipeTool:
    SEARCH_URL = "https://n8n.shravanpandala.me/firecrawl/v1/search"
    SCRAPE_URL = "https://n8n.shravanpandala.me/firecrawl/v1/scrape"

    async def search_recipe(self, dish_name: str):
        async with httpx.AsyncClient() as client:
            # Search
            search_response = await client.post(
                self.SEARCH_URL,
                json={"query": f"{dish_name} recipe"}
            )

            if search_response.status_code != 200:
                return None

            search_data = search_response.json()
            results = search_data.get("data", [])

            if not results:
                return None

            first_url = results[0]["url"]

            # Scrape
            scrape_response = await client.post(
                self.SCRAPE_URL,
                json={"url": first_url}
            )

            if scrape_response.status_code != 200:
                return None

            scrape_data = scrape_response.json()
            markdown = scrape_data.get("data", {}).get("markdown", "")
            print("Ingredients found:", "Ingredients" in markdown)
            print("Instructions found:", "Instructions" in markdown)
            print("Method found:", "Method" in markdown)

            print("\n\n===== FIRECRAWL MARKDOWN =====\n")
            print(markdown[:15000])
            print("\n===== END =====\n")

            if not markdown:
                return None

            return {
                "dish": dish_name,
                "url": first_url,
                "markdown": markdown
            }
