from fastapi import APIRouter
from ..config import MODEL_ID, DEVICE

router = APIRouter(tags=["Health & Status"])

@router.api_route("/health", methods=["GET", "HEAD"])
def health_check():
    """Liveness probe to verify the server is running and accessible."""
    return {"status": "ok"}

@router.get("/")
def read_root():
    """Retrieve basic server status metadata and active model details."""
    return {
        "status": "running", 
        "model": MODEL_ID,
        "device": DEVICE
    }
