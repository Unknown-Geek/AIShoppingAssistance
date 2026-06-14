# Qless

**AI shopping assistance for frictionless retail checkout**

Qless is a Flutter and FastAPI scan-and-go prototype for supermarket product recognition. A shopper captures an item from the mobile camera surface, the backend converts the image into a normalized CLIP vision embedding with ONNX Runtime, the embedding is matched against the configured vector catalog, and the resulting product slug is resolved into cart-ready retail metadata.

> Current repository state: the implemented hot path is `hf_server/app.py` plus Chroma Cloud, Supabase, and client-side `inventory.json` metadata lookup. Embedded Chroma, SQLite `metadata_catalog.db`, 224x224 WebP client compression, 50-variation synthetic augmentation, `generate_catalog_db.py`, `ingest_to_chroma.py`, and `test_client.py` are not present in this checkout.

## 1. TITLE & ARCHITECTURE OVERVIEW

```text
  ___  _     ___ ___ ___ ___
 / _ \| |   | __/ __/ __/ __|
| (_) | |__ | _|\__ \__ \__ \
 \__\_\____||___|___/___/___/

AI-assisted scan-and-go retail checkout
```

### Runtime Image Path

```text
Flutter portrait camera
lib/screens/dashboard_screen.dart
  CameraController + ResolutionPreset.low
  FittedBox(BoxFit.cover) + AspectRatio(1 / camera.aspectRatio)
          |
          | takePicture()
          v
ProductDetectionService
lib/services/product_detection_service.dart
  HuggingFaceProxyDetectionService.detectItem(XFile photo)
  http.MultipartRequest('POST', "$HF_SPACE_URL-without-/embed/detect")
  header: X-Chroma-Token: $CHROMA_API_KEY
          |
          | multipart/form-data image.jpg
          | optional ngrok edge tunnel
          v
FastAPI ASGI app
hf_server/app.py
  POST /detect
  async file read
  background save to captured_images/capture_<epoch>.jpg
          |
          v
Memory preprocessor
  PIL.Image.open(...).convert("RGB")
  CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
  processor(images=image, return_tensors="np")
          |
          v
ONNX vision encoder
  Xenova/clip-vit-base-patch32
  onnx/vision_model.onnx
  ort.InferenceSession(..., providers=["CPUExecutionProvider"])
  output: image_embeds -> normalized 512-float vector
          |
          v
Vector identity lookup
  Current: Chroma Cloud collection c1102322-920e-4775-96c1-e324bdadaa1d
          |
          v
Metadata intersection
  Current hot path: InventoryService().getProductFromLocal(slug)
                    reads inventory.json loaded at app startup
  Current optional path: Supabase inventory table
          |
          v
Cart mutation
lib/services/cart_service.dart
  CartService.addItem(CartItemModel)
  SharedPreferences key: cart_items_v1
  optional Supabase user_carts background sync
```

### Implemented Backend Endpoints

| Endpoint | Method | Purpose | Response shape |
| --- | --- | --- | --- |
| `/` | `GET` | Server status and active model id | `{ "status": "running", "model": "Xenova/clip-vit-base-patch32", "device": "cpu" }` |
| `/health` | `GET`, `HEAD` | Liveness probe | `{ "status": "ok" }` |
| `/embed` | `POST` | Return only the CLIP embedding for an uploaded image | `{ "status": "success", "embedding": [...] }` |
| `/detect` | `POST` | Full recognition path: embed, vector query, threshold, metadata response | `{ "status": "success", "match_found": true, "item": {...} }` |
| `/gallery` | `GET` | Browser gallery of background-saved captures | HTML |
| `/captured_images/{filename}` | `GET` | Retrieve a saved scan image | image file |

### Retail Data Model

The mobile app loads `inventory.json` during `main()` through `InventoryService().initLocalCatalog()`.

| Field | Source | Example | Used by |
| --- | --- | --- | --- |
| `sku` | `inventory.json`, Supabase `inventory.sku` | `QLS-0004` | `CartItemModel.details` |
| `slug` | `inventory.json`, Chroma metadata normalization | `american-style-cream-and-onion-chips-lays` | Vector match to metadata join key |
| `name` | `inventory.json`, Supabase `inventory.name` | `Lay's American Style Cream and Onion Chips` | Cart display |
| `price_rupees` | `inventory.json`, Supabase `inventory.price_rupees` | `20` | Cart totals |
| `staging_dirs` | `inventory.json`, Supabase `inventory.staging_dirs` | `["american-style-cream-and-onion-chips-lays"]` | Catalog image/embedding staging |
| `thumbnail_url` | Supabase `inventory.thumbnail_url` | Supabase Storage public URL | Product image cache |

## 2. TECHNICAL HIGHLIGHTS & LATENCY OPTIMIZATION DESIGN

### Why the Hot Path Is Fast

| Optimization | Code location | Latency impact |
| --- | --- | --- |
| **Model initialized once per process** | `hf_server/app.py` creates `CLIPProcessor`, downloads `onnx/vision_model.onnx`, and builds `ort.InferenceSession` at module import time | Avoids per-request model loading |
| **ONNX Runtime CPU execution** | `ort.InferenceSession(..., providers=["CPUExecutionProvider"])` | Uses compiled graph execution instead of Python model inference |
| **Thread caps** | `ort_options.intra_op_num_threads = 2`, `ort_options.inter_op_num_threads = 2` | Prevents oversubscription on small CPU hosts |
| **Async connection pooling** | `http_client: httpx.AsyncClient` created in `startup_event()` | Reuses outbound sockets for Chroma Cloud and optional Supabase calls |
| **Background image persistence** | `BackgroundTasks.add_task(save_image_task, contents, filepath)` | Capture logging does not block the response |
| **Client-local retail metadata** | `InventoryService().getProductFromLocal(slug)` | Bypasses Supabase on the item confirmation path |
| **Low-resolution capture** | `ResolutionPreset.low` on mobile in `_initializeCamera()` | Reduces camera write and upload size before backend inference |
| **Confidence thresholding** | `/detect` rejects distances over `0.65` | Prevents cart mutation from weak visual matches |

The current implementation is latency-conscious but still has a Chroma Cloud network hop. A true sub-30ms backend execution profile would require moving the vector index and metadata store into the server process:

```text
Target production path:
image bytes -> CLIP preprocessing -> ONNX session.run -> embedded Chroma HNSW -> SQLite join -> response

Network calls inside backend: 0
External database hops:       0
Model reloads per request:    0
```

### Local Embedded Database Target

These local stores are architectural targets, not implemented files in the current repository:

| Layer | Target component | Reason |
| --- | --- | --- |
| Vector identity | Embedded Chroma DB with in-memory HNSW index and cosine distance | ANN lookup stays inside the FastAPI process; no Chroma Cloud round trip |
| Retail metadata | SQLite `metadata_catalog.db` | Serverless local transactional reads for SKU, price, stock, and promotion joins |

The current checkout uses `inventory.json` as the zero-hop retail metadata cache and optional Supabase only for thumbnail enrichment. That mirrors the role a future SQLite metadata catalog would play without adding an implemented SQLite dependency today.

### Offline Catalog Augmentation

Production ingestion can generate multiple embeddings per SKU before runtime. This is a planned ingestion contract, not an implemented script in this checkout:

```text
source SKU image
  -> offline synthetic data augmentation
  -> 50 variations per item
  -> CLIP image embedding per variation
  -> Chroma collection metadata.product_name = inventory slug
```

This would shift visual variance handling out of the shopper request path. The current repository contains staged product images in `Images (2)` and slug groups in `inventory.json`, but no augmentation script.

### Mobile Payload Compression

The current Flutter implementation reduces payload pressure with `ResolutionPreset.low` because CLIP consumes 224x224 model inputs after preprocessing. Explicit 224x224 WebP compression is not currently implemented; it is the production mobile capture target:

```text
camera frame -> crop/resize to 224x224 -> WebP encode -> multipart upload
```

That would keep transport cost predictable before ngrok or LAN delivery. The current code sends `image.jpg` via `http.MultipartFile.fromBytes`.

## 3. PREREQUISITES & ISOLATED ENVIRONMENT INITIALIZATION

### Required Toolchain

| Component | Purpose |
| --- | --- |
| Flutter SDK `^3.12.2` | Mobile/web client from `pubspec.yaml` |
| Python 3.9+ | FastAPI embedding server; `hf_server/Dockerfile` uses `python:3.9-slim` |
| PowerShell or POSIX shell | Local environment setup |
| ngrok | HTTPS tunnel for phone-to-local backend testing |
| Chroma API key | Current vector search path |
| Supabase URL and anon key | Auth, inventory thumbnails, and cart sync |

### Clone and Install Flutter Dependencies

```powershell
flutter pub get
```

Create `.env` at the repository root using the keys from `.env.example`:

```dotenv
CHROMA_API_KEY=your_chroma_api_key_here
HF_SPACE_URL=https://<your-hf-space>.hf.space/embed
HF_API_TOKEN=your_hf_api_token_here
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

`HuggingFaceProxyDetectionService` strips `/embed` from `HF_SPACE_URL` and calls `/detect`, so both of these forms are acceptable as long as the base host serves `hf_server/app.py`:

```text
https://<host>/embed
https://<host>
```

### Python Virtual Environment: Windows PowerShell

```powershell
cd X:\UST\projects\AIShoppingAssistance
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r hf_server\requirements.txt
```

Optional script dependencies for `scripts/upload_thumbnails.py`:

```powershell
python -m pip install supabase python-dotenv
```

### Python Virtual Environment: macOS/Linux

```bash
cd /path/to/AIShoppingAssistance
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r hf_server/requirements.txt
```

Optional script dependencies for `scripts/upload_thumbnails.py`:

```bash
python -m pip install supabase python-dotenv
```

### Backend Dependencies

`hf_server/requirements.txt` pins the server stack:

| Package | Version | Role |
| --- | --- | --- |
| `fastapi` | `0.111.0` | ASGI API |
| `uvicorn` | `0.30.1` | ASGI runtime |
| `python-multipart` | `0.0.9` | Multipart image upload parsing |
| `onnxruntime` | `1.19.2` | Local CLIP vision inference |
| `huggingface-hub` | `0.23.4` | Downloads `onnx/vision_model.onnx` |
| `transformers` | `4.41.2` | `CLIPProcessor` preprocessing |
| `pillow` | `10.3.0` | Image decode and RGB conversion |
| `httpx` | `0.27.0` | Async outbound HTTP client |

## 4. SYSTEM SEEDING & INGESTION DATA FLOW

### Current Catalog Source

`inventory.json` contains 56 demo products in INR. It is included as a Flutter asset in `pubspec.yaml` and is loaded into `_localProducts` during startup:

```dart
await Future.wait([
  InventoryService().initLocalCatalog(),
  CartService().load(),
]);
```

### Supabase Seed Script

The repository includes `scripts/generate_seed.py`, which converts `inventory.json` into SQL for the Supabase `public.inventory` table and writes `artifacts/supabase_seed.sql`.

Current caveat: the script contains absolute Linux paths:

```python
'/home/gowtham-r-nair/AIShoppingAssistance/inventory.json'
'/home/gowtham-r-nair/AIShoppingAssistance/artifacts/supabase_seed.sql'
```

Run it from an environment where those paths exist, or patch the paths to the repository root before executing:

```powershell
python scripts\generate_seed.py
```

```bash
python scripts/generate_seed.py
```

The generated table schema is:

```sql
CREATE TABLE IF NOT EXISTS public.inventory (
  sku TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  price_rupees NUMERIC NOT NULL,
  staging_dirs TEXT[] NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Thumbnail Upload Script

`scripts/upload_thumbnails.py` uploads `.webp` files from `Images (2)` into Supabase Storage bucket `product-images` and writes the public URL back to `inventory.thumbnail_url`.

The generated seed SQL creates `sku`, `slug`, `name`, `price_rupees`, `staging_dirs`, and `created_at`. Add `thumbnail_url` before running the upload script:

```sql
ALTER TABLE public.inventory ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;
```

Required secret:

```dotenv
SUPABASE_SERVICE_ROLE_KEY=<server-side-service-role-key>
```

Run:

```powershell
python scripts\upload_thumbnails.py
```

```bash
python scripts/upload_thumbnails.py
```

### Not Yet Implemented: Local SQLite and Embedded Chroma Pipeline

The requested local pipeline names are not currently present in the repo. If added later, the intended flow is:

```text
inventory.json
  -> generate_catalog_db.py
  -> metadata_catalog.db
  -> ingest_to_chroma.py
  -> embedded Chroma collection with cosine HNSW index
```

Do not run the following until the scripts exist:

```powershell
python generate_catalog_db.py
python ingest_to_chroma.py
```

```bash
python generate_catalog_db.py
python ingest_to_chroma.py
```

During the first embedding-server run, `huggingface_hub.hf_hub_download()` downloads the ONNX model from:

```text
repo_id:  Xenova/clip-vit-base-patch32
filename: onnx/vision_model.onnx
```

The model binary is downloaded into the Hugging Face Hub cache and is not stored in this repository. Subsequent server starts reuse the local cache unless the cache is cleared.

## 5. DEPLOYMENT & RUNTIME INVOCATION

### Start the Backend Locally

From the repository root with the virtual environment activated:

```powershell
uvicorn hf_server.app:app --host 0.0.0.0 --port 8000 --workers 1
```

```bash
uvicorn hf_server.app:app --host 0.0.0.0 --port 8000 --workers 1
```

Use a **single worker** so the ONNX session and processor objects are created once in the server process. Multiple workers duplicate the model in RAM.

Health check:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

```bash
curl http://127.0.0.1:8000/health
```

### Expose the Local ASGI App With ngrok

```powershell
ngrok http 8000
```

Copy the HTTPS forwarding URL and set:

```dotenv
HF_SPACE_URL=https://<your-ngrok-host>.ngrok-free.app/embed
```

The Flutter service will call:

```text
https://<your-ngrok-host>.ngrok-free.app/detect
```

### Bypass ngrok Browser Warning for HTTP Clients

For direct verification requests through ngrok, include:

```http
ngrok-skip-browser-warning: true
```

PowerShell example:

```powershell
Invoke-WebRequest `
  -Uri "https://<your-ngrok-host>.ngrok-free.app/health" `
  -Headers @{ "ngrok-skip-browser-warning" = "true" }
```

`test_client.py` is not present in this checkout. Verify `/detect` with a multipart request:

```bash
curl -X POST "https://<your-ngrok-host>.ngrok-free.app/detect" \
  -H "ngrok-skip-browser-warning: true" \
  -H "X-Chroma-Token: $CHROMA_API_KEY" \
  -F "file=@Images (2)/Quaker Oats.webp"
```

### Run the Flutter App

Mobile or attached device:

```powershell
flutter run
```

Web debugging is captured in `start.sh`:

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

### Operational Notes

| Area | Current behavior |
| --- | --- |
| Capture gallery | Backend saves uploads under `captured_images` relative to the server working directory and serves `/gallery` |
| Product confirmation | User confirms the detected item before `CartService.addItem()` mutates state |
| Cart persistence | `SharedPreferences` key `cart_items_v1` |
| Auth/cart sync | Supabase `user_carts` table, status values `active` and `processed` |
| Visual threshold | Backend `/detect` threshold is `0.65`; legacy `ChromaDbClient.searchItemByPhoto()` uses `0.95` |
