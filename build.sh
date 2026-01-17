#!/bin/bash
set -e

# Build configuration
APP_NAME="VibeCap"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Clean and create app bundle structure directly in dist
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Collect all Swift source files
SWIFT_FILES=$(find VibeCapture -name "*.swift" -type f)

echo "📦 Compiling Swift files..."

# Compile with swiftc
swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macosx13.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework AppKit \
    -framework CoreGraphics \
    -framework Carbon \
    -framework ServiceManagement \
    -framework ScreenCaptureKit \
    -O \
    -whole-module-optimization \
    $SWIFT_FILES

echo "📋 Creating Info.plist..."

# Copy Info.plist
cp VibeCapture/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Copy App Icon
if [ -f "VibeCapture/Resources/AppIcon.icns" ]; then
    cp VibeCapture/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "🎨 App icon copied"
fi

# Copy Menu Bar Icon
if [ -f "VibeCapture/Resources/MenuBarIcon.png" ]; then
    cp VibeCapture/Resources/MenuBarIcon.png "$APP_BUNDLE/Contents/Resources/MenuBarIcon.png"
    cp "VibeCapture/Resources/MenuBarIcon@2x.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon@2x.png" 2>/dev/null || true
    echo "🎨 Menu bar icon copied"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "🔏 Signing app with Developer ID..."

# Sign the app with Developer ID certificate + Hardened Runtime (required for notarization)
codesign --force --deep --sign "Developer ID Application: Nan Wang (2257B2LRRF)" \
    --options runtime \
    --entitlements VibeCapture/VibeCapture.entitlements \
    "$APP_BUNDLE"

echo "✅ Build complete!"
echo "📍 App: $APP_BUNDLE"

# Install to /Applications for persistent permissions
echo "📲 Installing to /Applications..."
cp -R "$APP_BUNDLE" /Applications/
echo "✅ Installed to /Applications/$APP_NAME.app"
