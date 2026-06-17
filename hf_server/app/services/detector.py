import io
import numpy as np
import onnxruntime as ort
from PIL import Image
from huggingface_hub import hf_hub_download
from transformers import CLIPProcessor
from ..config import MODEL_ID, PROCESSOR_ID, INTRA_OP_NUM_THREADS, INTER_OP_NUM_THREADS, DEVICE

print(f"Loading CLIP processor '{PROCESSOR_ID}'...")
processor = CLIPProcessor.from_pretrained(PROCESSOR_ID)

print(f"Downloading ONNX model '{MODEL_ID}'...")
model_file = hf_hub_download(repo_id=MODEL_ID, filename="onnx/vision_model.onnx")

print("Initializing ONNX Runtime session...")
# Limit intra-op and inter-op threads to match environment core count (typically 2 on free space CPU)
ort_options = ort.SessionOptions()
ort_options.intra_op_num_threads = INTRA_OP_NUM_THREADS
ort_options.inter_op_num_threads = INTER_OP_NUM_THREADS
session = ort.InferenceSession(model_file, sess_options=ort_options, providers=["CPUExecutionProvider"])
print("Model loaded successfully!")

def get_image_embedding(contents: bytes) -> list[float]:
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    image = image.resize((224, 224), Image.Resampling.BILINEAR)
    inputs = processor(images=image, return_tensors="np")
    pixel_values = inputs["pixel_values"]
    
    outputs = session.run(["image_embeds"], {"pixel_values": pixel_values})
    image_embeds = outputs[0]
    
    norm = np.linalg.norm(image_embeds, axis=-1, keepdims=True)
    normalized_image_embeds = image_embeds / (norm + 1e-12)
    
    return normalized_image_embeds[0].tolist()
