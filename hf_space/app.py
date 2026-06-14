from __future__ import annotations
import os
import io
import time
import datetime
import httpx
from fastapi import FastAPI, File, UploadFile, BackgroundTasks, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from transformers import CLIPProcessor
from PIL import Image
from huggingface_hub import hf_hub_download
import onnxruntime as ort
import numpy as np

app = FastAPI()

# Enable CORS so Flutter Web or local clients can call it directly
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model and processor on startup using ONNX Runtime
model_id = "Xenova/clip-vit-base-patch32"
device = "cpu"

print("Loading CLIP processor 'openai/clip-vit-base-patch32'...")
processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")

print(f"Downloading ONNX model '{model_id}'...")
model_file = hf_hub_download(repo_id=model_id, filename="onnx/vision_model.onnx")

print("Initializing ONNX Runtime session...")
session = ort.InferenceSession(model_file, providers=["CPUExecutionProvider"])
print("Model loaded successfully!")

# Ensure captured_images directory exists
IMAGES_DIR = "captured_images"
os.makedirs(IMAGES_DIR, exist_ok=True)

def save_image_task(contents: bytes, filepath: str):
    try:
        with open(filepath, "wb") as f:
            f.write(contents)
        print(f"Saved scanned image in background to {filepath}")
    except Exception as save_err:
        print(f"Error saving image in background: {save_err}")

class ChromaSearcher:
    def __init__(self, token: str = None):
        self.api_key = token or os.environ.get("CHROMA_API_KEY", "")
        self.tenant = "99526d4b-48cf-4b20-896b-0947aa36d4ab"
        self.database = "QLESS"
        self.collection_id = "c1102322-920e-4775-96c1-e324bdadaa1d"
        self.url = f"https://api.trychroma.com/api/v2/tenants/{self.tenant}/databases/{self.database}/collections/{self.collection_id}/query"

    async def search(self, embedding: list[float]) -> tuple[str, float] | None:
        if not self.api_key:
            print("[ChromaSearcher] Warning: No Chroma API key found.")
            return None

        headers = {
            "x-chroma-token": self.api_key,
            "Content-Type": "application/json"
        }
        payload = {
            "query_embeddings": [embedding],
            "n_results": 1
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(self.url, headers=headers, json=payload, timeout=5.0)
                if response.status_code == 200:
                    data = response.json()
                    metadatas = data.get("metadatas", [])
                    distances = data.get("distances", [])

                    if metadatas and metadatas[0] and metadatas[0][0]:
                        item_meta = metadatas[0][0]
                        raw_name = item_meta.get("product_name", "Unknown Item")
                        slug = self._normalize_slug(str(raw_name))
                        distance = distances[0][0] if (distances and distances[0]) else 2.0
                        return slug, float(distance)
                else:
                    status = response.status_code
                    print(f"[ChromaSearcher] Query failed: {status} - {response.text}")
            except Exception as e:
                print(f"[ChromaSearcher] Error querying ChromaDB: {e}")
        return None

    def _normalize_slug(self, slug: str) -> str:
        import re
        clean_slug = re.sub(r'-\d+$', '', slug)
        mapping = {
            'roasted-almond-chocolate-bar-cadbury': 'dairy-milk-roast-almond-cadbury',
            'cadbury-dairy-milk-crispello': 'dairy-milk-crispello-cadbury',
            'fruit-and-nut-milk-chocolate-bar-cadbury': 'dairy-milk-chocolate-cadbury',
        }
        return mapping.get(clean_slug, clean_slug)

class SupabaseQuerier:
    def __init__(self, url: str = None, key: str = None):
        self.url = url or os.environ.get("SUPABASE_URL", "")
        self.key = key or os.environ.get("SUPABASE_ANON_KEY", "")

    async def get_product_by_slug(self, slug: str) -> dict | None:
        if not self.url or not self.key:
            print("[SupabaseQuerier] Warning: Supabase credentials missing.")
            return None

        base_url = self.url.rstrip("/")
        query_url = f"{base_url}/rest/v1/inventory?slug=eq.{slug}&select=sku,slug,name,price_rupees,staging_dirs"
        
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}"
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(query_url, headers=headers, timeout=5.0)
                if response.status_code == 200:
                    data = response.json()
                    if isinstance(data, list) and len(data) > 0:
                        return data[0]
                else:
                    print(f"[SupabaseQuerier] Query failed: {response.status_code} - {response.text}")
            except Exception as e:
                print(f"[SupabaseQuerier] Error querying Supabase: {e}")
        return None

@app.post("/embed")
async def get_embedding(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    try:
        contents = await file.read()
        filename = f"capture_{int(time.time() * 1000)}.jpg"
        filepath = os.path.join(IMAGES_DIR, filename)
        background_tasks.add_task(save_image_task, contents, filepath)

        image = Image.open(io.BytesIO(contents)).convert("RGB")
        inputs = processor(images=image, return_tensors="np")
        pixel_values = inputs["pixel_values"]
        
        outputs = session.run(["image_embeds"], {"pixel_values": pixel_values})
        image_embeds = outputs[0]
        
        norm = np.linalg.norm(image_embeds, axis=-1, keepdims=True)
        normalized_image_embeds = image_embeds / (norm + 1e-12)
        
        embedding = normalized_image_embeds[0].tolist()
        return {"status": "success", "embedding": embedding}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/detect")
async def detect_item(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    x_chroma_token: str = Header(default=None),
    x_supabase_url: str = Header(default=None),
    x_supabase_key: str = Header(default=None)
):
    start_total = time.time()
    try:
        t0 = time.time()
        contents = await file.read()
        t_read = time.time() - t0

        filename = f"capture_{int(time.time() * 1000)}.jpg"
        filepath = os.path.join(IMAGES_DIR, filename)
        background_tasks.add_task(save_image_task, contents, filepath)

        t0 = time.time()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        inputs = processor(images=image, return_tensors="np")
        pixel_values = inputs["pixel_values"]
        t_preprocess = time.time() - t0
        
        t0 = time.time()
        outputs = session.run(["image_embeds"], {"pixel_values": pixel_values})
        image_embeds = outputs[0]
        t_onnx = time.time() - t0
        
        norm = np.linalg.norm(image_embeds, axis=-1, keepdims=True)
        normalized_image_embeds = image_embeds / (norm + 1e-12)
        embedding = normalized_image_embeds[0].tolist()

        t0 = time.time()
        searcher = ChromaSearcher(token=x_chroma_token)
        search_result = await searcher.search(embedding)
        t_chroma = time.time() - t0

        if search_result is None:
            print(f"[detect] Finished (No ChromaDB Response) in {time.time() - start_total:.4f}s")
            return {"status": "success", "match_found": False, "reason": "No ChromaDB response"}

        slug, distance = search_result
        threshold = 0.65
        if distance > threshold:
            print(f"[detect] Distance {distance} exceeds threshold {threshold} for {slug} (Finished in {time.time() - start_total:.4f}s)")
            return {"status": "success", "match_found": False, "reason": f"Distance {distance} exceeds threshold {threshold}"}

        t0 = time.time()
        querier = SupabaseQuerier(url=x_supabase_url, key=x_supabase_key)
        product_data = await querier.get_product_by_slug(slug)
        t_supabase = time.time() - t0

        print(f"[detect] Profiling: Read={t_read:.4f}s, Preprocess={t_preprocess:.4f}s, ONNX={t_onnx:.4f}s, Chroma={t_chroma:.4f}s, Supabase={t_supabase:.4f}s. Total={time.time() - start_total:.4f}s")

        if product_data:
            return {
                "status": "success",
                "match_found": True,
                "item": {
                    "sku": product_data.get("sku"),
                    "slug": product_data.get("slug"),
                    "name": product_data.get("name"),
                    "price_rupees": float(product_data.get("price_rupees", 0.0))
                }
            }
        else:
            name_fallback = slug.replace('-', ' ').upper()
            return {
                "status": "success",
                "match_found": True,
                "item": {
                    "sku": "UNLISTED",
                    "slug": slug,
                    "name": name_fallback,
                    "price_rupees": 0.0
                }
            }
    except Exception as e:
        print(f"[detect] Exception: {e}")
        return {"status": "error", "message": str(e)}

@app.get("/captured_images/{filename}")
async def get_captured_image(filename: str):
    filepath = os.path.join(IMAGES_DIR, filename)
    if os.path.exists(filepath):
        return FileResponse(filepath)
    return {"error": "File not found"}

@app.get("/gallery", response_class=HTMLResponse)
async def get_gallery():
    files = []
    if os.path.exists(IMAGES_DIR):
        for f in os.listdir(IMAGES_DIR):
            if f.lower().endswith(('.jpg', '.jpeg', '.png')):
                fp = os.path.join(IMAGES_DIR, f)
                mtime = os.path.getmtime(fp)
                files.append((f, mtime))
    
    files.sort(key=lambda x: x[1], reverse=True)
    
    # Render Scandinavian modern light themed gallery page
    html_content = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Scanned Products Gallery | QLESS</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: #F4F7F8;
            color: #2D3748;
            margin: 0;
            padding: 40px 24px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        .container {
            width: 100%;
            max-width: 1100px;
        }
        header {
            margin-bottom: 40px;
            text-align: center;
        }
        h1 {
            font-size: 2.25rem;
            font-weight: 700;
            color: #1A202C;
            margin: 0 0 8px 0;
            letter-spacing: -0.025em;
        }
        p {
            color: #718096;
            font-size: 1.1rem;
            margin: 0;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
            gap: 24px;
            margin-top: 20px;
        }
        .card {
            background: #FFFFFF;
            border-radius: 18px;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.03);
            border: 1px solid rgba(0, 0, 0, 0.04);
            transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .card:hover {
            transform: translateY(-4px);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.06);
        }
        .card-img-wrapper {
            position: relative;
            width: 100%;
            padding-top: 100%; /* 1:1 Aspect Ratio */
            background-color: #EDF2F7;
        }
        .card img {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .info {
            padding: 16px;
            font-size: 0.85rem;
            color: #718096;
            font-weight: 500;
            text-align: center;
            background: #FAFCFC;
            border-top: 1px solid #E2E8F0;
        }
        .empty-state {
            grid-column: 1 / -1;
            text-align: center;
            padding: 80px 20px;
            background: #FFFFFF;
            border-radius: 18px;
            border: 1px dashed #E2E8F0;
            color: #A0AEC0;
            font-size: 1.1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Product Scan History</h1>
            <p>A history of all product images captured by the AI Shopping Assistant.</p>
        </header>
        <div class="grid">
    """
    
    for f, mtime in files:
        dt = datetime.datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S')
        html_content += f"""
            <div class="card">
                <a href="/captured_images/{f}" target="_blank">
                    <div class="card-img-wrapper">
                        <img src="/captured_images/{f}" alt="Scan from {dt}">
                    </div>
                </a>
                <div class="info">{dt}</div>
            </div>
        """
        
    if not files:
        html_content += """
            <div class="empty-state">
                No scanned images found yet. Start scanning from the app!
            </div>
        """
        
    html_content += """
        </div>
    </div>
</body>
</html>
    """
    return html_content

@app.api_route("/health", methods=["GET", "HEAD"])
def health_check():
    return {"status": "ok"}

@app.get("/")
def read_root():
    return {
        "status": "running", 
        "model": model_id,
        "device": device
    }

