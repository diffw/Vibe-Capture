#!/bin/bash
set -e

# Build configuration
APP_NAME="Vibe Capture"
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

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "🔏 Signing app..."

# Sign the app with entitlements (ad-hoc signing for local use)
codesign --force --deep --sign - --entitlements VibeCapture/VibeCapture.entitlements "$APP_BUNDLE"

echo "✅ Build complete!"
echo "📍 App: $APP_BUNDLE"
