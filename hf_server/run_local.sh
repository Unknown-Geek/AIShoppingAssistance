#!/bin/bash
# Stop and remove the existing container if running
echo "[*] Stopping existing container..."
docker stop ai-shopping-assistance-server 2>/dev/null || true
docker rm ai-shopping-assistance-server 2>/dev/null || true

# Rebuild the image
echo "[*] Building Docker image..."
docker build -t ai-shopping-assistance-server .

# Run the container mapping port 7860 to 6082
echo "[*] Running container..."
docker run -d \
  --name ai-shopping-assistance-server \
  -p 127.0.0.1:6082:7860 \
  -e GROQ_API_KEY="$GROQ_API_KEY" \
  -e CHROMA_API_KEY="$CHROMA_API_KEY" \
  -e SUPABASE_URL="$SUPABASE_URL" \
  -e SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  -e GROQ_MODEL="$GROQ_MODEL" \
  -v /home/ubuntu/AIShoppingAssistance_Server/captured_images:/code/captured_images \
  -v /home/ubuntu/.cache/huggingface:/root/.cache/huggingface \
  --restart unless-stopped \
  ai-shopping-assistance-server

echo "[*] Done! Server is running and accessible locally at http://127.0.0.1:6082"