#!/bin/bash
# Fetch Qwen2-0.5B-GGUF for the baseline image.
# We will download it directly to the baseline directory to be COPY'd by Dockerfile.heavy.

set -e

cd "$(dirname "$0")"

MODEL_URL="https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_0.gguf"
FILE_NAME="mock_model.gguf"

if [ ! -f "$FILE_NAME" ]; then
    echo "Downloading a mock ~350MB GGUF model for testing bloat..."
    wget -O "$FILE_NAME" "$MODEL_URL"
else
    echo "Model $FILE_NAME already exists in baseline/."
fi
