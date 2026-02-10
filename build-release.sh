#!/bin/bash

# Build Release version of Typeasy.app
# This script creates a signed .app bundle ready for distribution

set -e

echo "🏗️  Building Typeasy Release..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build/release
rm -rf .build/apple

# Build for release
echo "📦 Building with Swift Package Manager..."
swift build -c release --arch arm64

# Create app bundle structure
APP_NAME="Typeasy"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR=".build/release"
DIST_DIR="dist"

echo "📁 Creating app bundle..."
rm -rf "$DIST_DIR/$APP_BUNDLE"
mkdir -p "$DIST_DIR/$APP_BUNDLE/Contents/MacOS"
mkdir -p "$DIST_DIR/$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$DIST_DIR/$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$DIST_DIR/$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Typeasy</string>
    <key>CFBundleIdentifier</key>
    <string>com.typeasy.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Typeasy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Typeasy needs microphone access to record your voice for transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Typeasy needs to control other applications to insert transcribed text.</string>
</dict>
</plist>
EOF

# Create icon (using SF Symbol as placeholder)
# In production, you'd use iconutil to create proper .icns
echo "🎨 Creating app icon..."
mkdir -p "$DIST_DIR/$APP_BUNDLE/Contents/Resources/$APP_NAME.iconset"
# Note: For real distribution, create proper icon with iconutil

# Sign the app (ad-hoc signature, no developer account needed)
echo "✍️  Signing app bundle..."
codesign --force --deep --sign - "$DIST_DIR/$APP_BUNDLE"

# Verify signature
echo "✅ Verifying signature..."
codesign --verify --verbose "$DIST_DIR/$APP_BUNDLE"

echo ""
echo "✅ Build complete!"
echo "📦 App bundle: $DIST_DIR/$APP_BUNDLE"
echo ""
echo "Next steps:"
echo "  1. Test the app: open $DIST_DIR/$APP_BUNDLE"
echo "  2. Create DMG: ./create-dmg.sh"
echo ""
