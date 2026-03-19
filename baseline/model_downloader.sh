#!/bin/bash
# Fetch Qwen2-0.5B-GGUF for the baseline image.
# We will download it directly to the baseline directory to be COPY'd by Dockerfile.heavy.

set -e

cd "$(dirname "$0")"

MODEL_URL="https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_0.gguf"
FILE_NAME="mock_model.gguf"

if [ ! -f "$FILE_NAME" ]; then
    echo "Downloading a mock ~350MB GGUF model for testing bloat..."
    
    # Try primary HuggingFace link
    if curl -L -f -o "$FILE_NAME" "$MODEL_URL"; then
        echo "Download successful from primary HuggingFace server."
    else
        echo "Primary download failed (Connection reset or timeout)."
        echo "Attempting fallback via huggingface mirror (hf-mirror.com)..."
        MIRROR_URL="https://hf-mirror.com/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_0.gguf"
        
        if curl -L -f -o "$FILE_NAME" "$MIRROR_URL"; then
             echo "Download via mirror successful."
        else
             echo "Mirror also failed. Attempting final Python download fallback..."
             python3 -c "import urllib.request; print('Downloading via Python urllib...'); urllib.request.urlretrieve('$MIRROR_URL', '$FILE_NAME')" && echo "Python fallback successful!" || echo "All download methods failed. Please check your network or ISP firewall."
        fi
    fi
else
    echo "Model $FILE_NAME already exists in baseline/."
fi
