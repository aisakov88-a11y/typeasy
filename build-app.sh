#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHERPA_ONNX_VERSION="v1.12.23"
SHERPA_ONNX_SRC="$SCRIPT_DIR/sherpa-onnx"
SHERPA_ONNX_LIBS="$SCRIPT_DIR/Typeasy/Libraries/sherpa-onnx"

echo "🔨 Building Typeasy.app with GigaAM-v3 support..."

# ── Step 0: Download & build sherpa-onnx if libraries are missing ──
if [ ! -f "$SHERPA_ONNX_LIBS/libsherpa-onnx.a" ] || [ ! -f "$SHERPA_ONNX_LIBS/libonnxruntime.a" ]; then
    echo ""
    echo "📥 sherpa-onnx libraries not found. Building from source..."

    # Clone if not present
    if [ ! -d "$SHERPA_ONNX_SRC" ]; then
        echo "   Cloning sherpa-onnx ${SHERPA_ONNX_VERSION}..."
        git clone --depth 1 --branch "$SHERPA_ONNX_VERSION" \
            https://github.com/k2-fsa/sherpa-onnx.git "$SHERPA_ONNX_SRC"
    fi

    # Build static libraries for macOS
    echo "   Compiling sherpa-onnx (this may take a few minutes)..."
    cd "$SHERPA_ONNX_SRC"
    bash build-swift-macos.sh
    cd "$SCRIPT_DIR"

    BUILD_DIR="$SHERPA_ONNX_SRC/build-swift-macos"

    # Copy built artifacts into Typeasy/Libraries/sherpa-onnx
    mkdir -p "$SHERPA_ONNX_LIBS/include"
    cp "$BUILD_DIR/install/lib/libsherpa-onnx.a" "$SHERPA_ONNX_LIBS/"
    cp "$BUILD_DIR/install/lib/libonnxruntime.a" "$SHERPA_ONNX_LIBS/"
    cp -R "$BUILD_DIR/install/include/"* "$SHERPA_ONNX_LIBS/include/"

    echo "   ✅ sherpa-onnx libraries ready"
else
    echo "✅ sherpa-onnx libraries found"
fi

echo ""

# Build release binary
echo "📦 Compiling release build..."
swift build -c release

# Create .app structure
APP_DIR="Typeasy.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

echo "📋 Copying executable..."
cp .build/release/Typeasy "$APP_DIR/Contents/MacOS/"
chmod +x "$APP_DIR/Contents/MacOS/Typeasy"

echo "📋 Copying and processing Info.plist..."
if [ -f "Typeasy/Resources/Info.plist" ]; then
    sed 's/\$(EXECUTABLE_NAME)/Typeasy/g' "Typeasy/Resources/Info.plist" > "$APP_DIR/Contents/Info.plist"
elif [ -f "Info.plist" ]; then
    sed 's/\$(EXECUTABLE_NAME)/Typeasy/g' "Info.plist" > "$APP_DIR/Contents/Info.plist"
else
    echo "❌ Info.plist not found!"
    exit 1
fi

echo "📋 Creating PkgInfo..."
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Copy entitlements if exists
if [ -f "Typeasy.entitlements" ]; then
    cp "Typeasy.entitlements" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
fi

echo "✅ Build complete: Typeasy.app"
echo ""
echo "🚀 To run:"
echo "   open Typeasy.app"
echo ""
echo "📱 To install:"
echo "   cp -R Typeasy.app /Applications/"
echo ""
echo "🔐 After first launch, grant permissions in System Settings:"
echo "   • Privacy & Security → Microphone → Enable Typeasy"
echo "   • Privacy & Security → Accessibility → Enable Typeasy"
echo ""
echo "💡 Accessibility permission allows Typeasy to insert transcribed text"
