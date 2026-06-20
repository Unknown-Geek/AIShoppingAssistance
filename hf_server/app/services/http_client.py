import httpx

http_client: httpx.AsyncClient | None = None

async def init_http_client():
    global http_client
    http_client = httpx.AsyncClient()

async def close_http_client():
    global http_client
    if http_client:
        await http_client.aclose()
        http_client = None
