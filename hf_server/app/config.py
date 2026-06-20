import os

# Model settings
MODEL_ID = "Xenova/clip-vit-base-patch32"
PROCESSOR_ID = "openai/clip-vit-base-patch32"
DEVICE = "cpu"

# ONNX options
INTRA_OP_NUM_THREADS = 4
INTER_OP_NUM_THREADS = 4

# Storage paths
IMAGES_DIR = "captured_images"

# Vector Search
SIMILARITY_THRESHOLD = 0.65
