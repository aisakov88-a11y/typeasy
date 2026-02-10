#!/bin/bash
set -e

echo "🔨 Building Typeasy.app with GigaAM-v3 support..."

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
