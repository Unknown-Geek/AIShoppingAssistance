import httpx

class FirecrawlRecipeTool:
    SEARCH_URL = "https://n8n.shravanpandala.me/firecrawl/v1/search"
    SCRAPE_URL = "https://n8n.shravanpandala.me/firecrawl/v1/scrape"

    async def search_recipe(self, dish_name: str):
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                # 1. Execute Search Request
                try:
                    search_response = await client.post(
                        self.SEARCH_URL,
                        json={"query": f"{dish_name} recipe"}
                    )
                except httpx.ReadTimeout:
                    print("Firecrawl search timeout")
                    return None
                except Exception as e:
                    print(f"Firecrawl search error: {e}")
                    return None

                if search_response.status_code != 200:
                    print(f"Firecrawl search failed with status: {search_response.status_code}")
                    return None

                search_data = search_response.json()
                results = search_data.get("data", [])

                if not results:
                    print(f"No search results returned for dish: {dish_name}")
                    return None

                first_url = results[0].get("url")
                if not first_url:
                    return None
                    
                print(f"Firecrawl URL: {first_url}")

                # 2. Execute Scrape Request for target URL
                try:
                    scrape_response = await client.post(
                        self.SCRAPE_URL,
                        json={"url": first_url}
                    )
                except httpx.ReadTimeout:
                    print("Firecrawl scrape timeout")
                    return None
                except Exception as e:
                    print(f"Firecrawl scrape error: {e}")
                    return None

                if scrape_response.status_code != 200:
                    print(f"Firecrawl scrape failed with status: {scrape_response.status_code}")
                    return None

                scrape_data = scrape_response.json()
                markdown = scrape_data.get("data", {}).get("markdown", "")

                if not markdown:
                    print("No markdown content returned from scrape target.")
                    return None

                # Visual log outputs for status visibility
                print("Ingredients found:", "Ingredients" in markdown)
                print("Instructions found:", "Instructions" in markdown)
                print("Method found:", "Method" in markdown)

                print("\n\n===== FIRECRAWL MARKDOWN =====\n")
                print(markdown[:15000])
                print("\n===== END =====\n")

                return {
                    "dish": dish_name,
                    "url": first_url,
                    "markdown": markdown
                }
                
        except Exception as e:
            print(f"Firecrawl error for '{dish_name}': {type(e).__name__}: {e}")
            return None