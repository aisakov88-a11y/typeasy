#!/bin/bash

# Create DMG installer for Typeasy
# This creates a drag-and-drop DMG with installation instructions

set -e

APP_NAME="Typeasy"
APP_BUNDLE="$APP_NAME.app"
DIST_DIR="dist"
DMG_NAME="Typeasy-Installer.dmg"
VOLUME_NAME="Typeasy Installer"
SOURCE_FOLDER="dmg-contents"

echo "📀 Creating DMG installer..."
echo ""

# Check if app bundle exists
if [ ! -d "$DIST_DIR/$APP_BUNDLE" ]; then
    echo "❌ App bundle not found. Run ./build-release.sh first"
    exit 1
fi

# Create temporary folder for DMG contents
echo "📁 Preparing DMG contents..."
rm -rf "$SOURCE_FOLDER"
mkdir -p "$SOURCE_FOLDER"

# Copy app bundle
cp -R "$DIST_DIR/$APP_BUNDLE" "$SOURCE_FOLDER/"

# Copy installation script
cp download-whisper-model.sh "$SOURCE_FOLDER/"

# Create README for installation
cat > "$SOURCE_FOLDER/README.txt" << 'EOF'
Typeasy - Voice-to-Text для macOS
==================================

УСТАНОВКА:

1. Перетащите Typeasy.app в папку Applications (или любую другую)

2. Скачайте WhisperKit модель:
   - Откройте Terminal
   - Выполните: ~/Applications/download-whisper-model.sh
   (или укажите путь где вы сохранили скрипт)

3. Установите LM Studio:
   - Скачайте с https://lmstudio.ai/
   - Загрузите любую модель (Qwen 2.5 7B, Llama 3.2 3B и т.д.)
   - Запустите локальный сервер (Local Server → Start Server)

4. Запустите Typeasy и дайте разрешения:
   - Microphone (появится диалог при первой записи)
   - Accessibility (System Settings → Privacy & Security → Accessibility)

ИСПОЛЬЗОВАНИЕ:

1. Нажмите Cmd+Shift+D чтобы начать запись
2. Говорите на русском или английском
3. Нажмите Cmd+Shift+D чтобы остановить
4. Текст вставится в активное поле ввода

Документация: https://github.com/yourusername/typeasy
EOF

# Create symbolic link to Applications folder
ln -s /Applications "$SOURCE_FOLDER/Applications"

# Create DMG
echo "📦 Creating DMG..."
rm -f "$DIST_DIR/$DMG_NAME"

hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$SOURCE_FOLDER" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# Clean up
echo "🧹 Cleaning up..."
rm -rf "$SOURCE_FOLDER"

echo ""
echo "✅ DMG created successfully!"
echo "📦 Location: $DIST_DIR/$DMG_NAME"
echo ""
echo "Распространение:"
echo "  - Отправьте коллегам файл $DIST_DIR/$DMG_NAME"
echo "  - Размер: $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
echo ""
echo "⚠️  Важно: Пользователи увидят предупреждение при первом запуске."
echo "   Инструкция обхода: System Settings → Privacy & Security → Open Anyway"
echo ""
