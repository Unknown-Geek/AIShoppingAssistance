import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import IMAGES_DIR
from .routes import health, detection, recipe
from .services.http_client import init_http_client, close_http_client

# Ensure captured_images directory exists
os.makedirs(IMAGES_DIR, exist_ok=True)

app = FastAPI()

# Enable CORS so Flutter Web or local clients can call it directly
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
