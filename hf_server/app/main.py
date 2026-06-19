import os
from dotenv import load_dotenv

# Explicitly load .env file from the hf_server directory
base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dotenv_path = os.path.join(base_dir, ".env")
load_dotenv(dotenv_path=dotenv_path, override=True)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routes import health, detection, recipe
from .services.http_client import init_http_client, close_http_client

app = FastAPI()

# Enable CORS so Flutter Web or local clients can call it directly
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:50220",
        "http://127.0.0.1:50220",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router)
app.include_router(detection.router)
app.include_router(recipe.router)

@app.on_event("startup")
async def startup_event():
    await init_http_client()

@app.on_event("shutdown")
async def shutdown_event():
    await close_http_client()
