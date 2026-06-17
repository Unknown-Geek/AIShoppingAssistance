from fastapi import APIRouter
from ..config import MODEL_ID, DEVICE

router = APIRouter()

@router.api_route("/health", methods=["GET", "HEAD"])
def health_check():
    return {"status": "ok"}

@router.get("/")
def read_root():
    return {
        "status": "running", 
        "model": MODEL_ID,
        "device": DEVICE
    }
