#!/bin/bash

# WhisperKit Model Downloader
# This script downloads the WhisperKit model to the local cache
#
# Usage:
#   ./download-whisper-model.sh [model]
#
# Available models:
#   tiny          - ~40MB, very fast (~1-2s), less accurate
#   base          - ~140MB, fast (~2-3s), balanced (default)
#   small         - ~466MB, medium (~3-5s), accurate
#   large-v3-turbo - ~954MB, slow (~5-10s), most accurate

set -e

# Default to base model (good balance of speed and accuracy)
MODEL_SIZE="${1:-base}"
MODEL_NAME="openai_whisper-${MODEL_SIZE}"
REPO="argmaxinc/whisperkit-coreml"
CACHE_DIR="$HOME/Library/Caches/huggingface/hub"

echo "🔽 Downloading WhisperKit model: $MODEL_NAME"
echo "📦 Repository: $REPO"
echo "💾 Cache directory: $CACHE_DIR"
echo ""

# Show model size
case "$MODEL_SIZE" in
    "tiny")
        echo "⏳ Model size: ~40MB (Very fast)"
        ;;
    "base")
        echo "⏳ Model size: ~140MB (Recommended: Fast & Accurate)"
        ;;
    "small")
        echo "⏳ Model size: ~466MB (Accurate)"
        ;;
    "large-v3-turbo")
        echo "⏳ Model size: ~954MB (Most Accurate, Slow)"
        ;;
    *)
        echo "❌ Unknown model size: $MODEL_SIZE"
        echo "Available: tiny, base, small, large-v3-turbo"
        exit 1
        ;;
esac
echo ""

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found"
    echo "Please install Python 3: brew install python3"
    exit 1
fi

# Install huggingface_hub if not already installed
echo "📦 Checking for huggingface_hub..."
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
    echo "Installing huggingface_hub..."
    pip3 install --break-system-packages huggingface_hub || pip3 install --user huggingface_hub
fi

echo "📥 Starting download (this may take a few minutes)..."
echo ""

# Download using Python
python3 << EOF
import os
import sys
from huggingface_hub import snapshot_download
from pathlib import Path

model_name = "$MODEL_NAME"
repo_id = "argmaxinc/whisperkit-coreml"
cache_dir = os.path.expanduser("~/Library/Caches/huggingface/hub")

print(f"📥 Downloading {model_name} from {repo_id}...")

try:
    local_path = snapshot_download(
        repo_id=repo_id,
        allow_patterns=f"{model_name}/*",
        cache_dir=cache_dir,
        local_dir_use_symlinks=False
    )

    print(f"\n✅ Model downloaded successfully!")
    print(f"📂 Location: {local_path}")

except Exception as e:
    print(f"\n❌ Download failed: {e}")
    print("\nTrying alternative method with individual files...")

    # Alternative: download with huggingface-cli
    import subprocess
    result = subprocess.run([
        "huggingface-cli", "download", repo_id,
        "--include", f"{model_name}/*",
        "--cache-dir", cache_dir
    ], capture_output=True, text=True)

    if result.returncode == 0:
        print("✅ Model downloaded successfully with huggingface-cli!")
    else:
        print(f"❌ Failed: {result.stderr}")
        exit(1)

EOF

echo ""
echo "✅ Model download complete!"
echo "🎉 You can now run Typeasy.app"
echo ""
echo "To verify the model was downloaded, run:"
echo "  ls -lah ~/Library/Caches/huggingface/hub/"
