#!/bin/bash

# Typeasy Setup Script
# Автоматическая настройка всех зависимостей

set -e

echo "🎤 Typeasy Setup"
echo "================="
echo ""

# Check macOS version
OS_VERSION=$(sw_vers -productVersion)
echo "📋 macOS version: $OS_VERSION"

if [[ "$OS_VERSION" < "14.0" ]]; then
    echo "❌ Typeasy requires macOS 14.0 (Sonoma) or newer"
    exit 1
fi

# Check architecture
ARCH=$(uname -m)
echo "💻 Architecture: $ARCH"

if [ "$ARCH" != "arm64" ]; then
    echo "⚠️  Warning: Typeasy is optimized for Apple Silicon (M1/M2/M3)"
    echo "    It may not work properly on Intel Macs"
fi

echo ""
echo "📥 Installing dependencies..."
echo ""

# 1. Check Python 3
echo "1️⃣  Checking Python 3..."
if ! command -v python3 &> /dev/null; then
    echo "   ❌ Python 3 not found"
    echo "   Installing via Homebrew..."

    if ! command -v brew &> /dev/null; then
        echo "   Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew install python3
else
    echo "   ✅ Python 3 found: $(python3 --version)"
fi

# 2. Install huggingface_hub
echo ""
echo "2️⃣  Installing huggingface_hub..."
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
    pip3 install --break-system-packages huggingface_hub || pip3 install --user huggingface_hub
    echo "   ✅ huggingface_hub installed"
else
    echo "   ✅ huggingface_hub already installed"
fi

# 3. Download WhisperKit model
echo ""
echo "3️⃣  Downloading WhisperKit model (~954MB)..."
CACHE_DIR="$HOME/Library/Caches/huggingface/hub"
MODEL_NAME="openai_whisper-large-v3_turbo"

# Check if model already exists
if [ -d "$CACHE_DIR" ] && ls -d "$CACHE_DIR"/*whisperkit*"$MODEL_NAME"* 2>/dev/null | grep -q .; then
    echo "   ✅ Model already downloaded"
else
    echo "   📥 Downloading... (this may take several minutes)"
    python3 << 'EOF'
import os
from huggingface_hub import snapshot_download

model_name = "openai_whisper-large-v3_turbo"
repo_id = "argmaxinc/whisperkit-coreml"
cache_dir = os.path.expanduser("~/Library/Caches/huggingface/hub")

try:
    local_path = snapshot_download(
        repo_id=repo_id,
        allow_patterns=f"{model_name}/*",
        cache_dir=cache_dir,
        local_dir_use_symlinks=False
    )
    print(f"   ✅ Model downloaded to: {local_path}")
except Exception as e:
    print(f"   ❌ Download failed: {e}")
    exit(1)
EOF
fi

# 4. Check LM Studio
echo ""
echo "4️⃣  Checking LM Studio..."
if [ -d "/Applications/LM Studio.app" ]; then
    echo "   ✅ LM Studio found"
    echo "   ⚠️  Make sure to:"
    echo "      - Download a model (Qwen 2.5 7B, Llama 3.2 3B, etc.)"
    echo "      - Start local server (Local Server → Start Server)"
else
    echo "   ⚠️  LM Studio not found"
    echo "   Please install from: https://lmstudio.ai/"
    echo "   Or via Homebrew: brew install --cask lm-studio"
fi

# 5. Check Typeasy app
echo ""
echo "5️⃣  Checking Typeasy.app..."
if [ -d "/Applications/Typeasy.app" ]; then
    echo "   ✅ Typeasy installed in /Applications"
elif [ -d "$HOME/Applications/Typeasy.app" ]; then
    echo "   ✅ Typeasy installed in ~/Applications"
else
    echo "   ⚠️  Typeasy.app not found"
    echo "   Please drag Typeasy.app to Applications folder"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Start LM Studio and enable local server"
echo "2. Launch Typeasy.app"
echo "3. Grant permissions when prompted:"
echo "   - Microphone (automatic dialog)"
echo "   - Accessibility (System Settings → Privacy & Security → Accessibility)"
echo ""
echo "4. Use Cmd+Shift+D to record voice"
echo ""
echo "For help, visit: https://github.com/yourusername/typeasy"
echo ""
