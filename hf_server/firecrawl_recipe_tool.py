import httpx


class FirecrawlRecipeTool:

    SEARCH_URL = "https://n8n.shravanpandala.me/firecrawl/v1/search"
    SCRAPE_URL = "https://n8n.shravanpandala.me/firecrawl/v1/scrape"

    async def search_recipe(self, dish_name: str):
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:

                # Search
                try:
                    search_response = await client.post(
                        self.SEARCH_URL,
                        json={"query": f"{dish_name} recipe"}
                    )
                except httpx.ReadTimeout:
                    print("Firecrawl timeout")
                    return None
                except Exception as e:
                    print(f"Firecrawl error: {e}")
                    return None

                if search_response.status_code != 200:
                    return None

                search_data = search_response.json()

                results = search_data.get("data", [])

                if not results:
                    return None

                first_url = results[0]["url"]
                print(f"Firecrawl URL: {first_url}")

                # Scrape
                try:
                    scrape_response = await client.post(
                        self.SCRAPE_URL,
                        json={"url": first_url}
                    )
                except httpx.ReadTimeout:
                    print("Firecrawl timeout")
                    return None
                except Exception as e:
                    print(f"Firecrawl error: {e}")
                    return None

                if scrape_response.status_code != 200:
                    return None

                scrape_data = scrape_response.json()

                markdown = scrape_data.get("data", {}).get("markdown", "")
                

                if not markdown:
                    return None

                return {
                    "dish": dish_name,
                    "url": first_url,
                    "markdown": markdown
                }
        except Exception as e:
            print(f"Firecrawl error for '{dish_name}': {type(e).__name__}: {e}")
            return None