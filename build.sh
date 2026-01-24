#!/bin/bash
set -e

# Build configuration
APP_NAME="VibeCap"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Step 0: Localization integrity check (hard gate)
echo "🌍 Checking localization integrity..."
if [ -f "scripts/check-localization.sh" ]; then
    ./scripts/check-localization.sh VibeCapture/Resources
    echo ""
fi

# Clean and create app bundle structure directly in dist
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Collect all Swift source files
SWIFT_FILES=$(find VibeCapture -name "*.swift" -type f)

echo "📦 Compiling Swift files..."

# Keep module caches inside workspace (required for sandboxed builds)
SWIFT_MODULE_CACHE="$DIST_DIR/.swift-module-cache"
CLANG_MODULE_CACHE="$DIST_DIR/.clang-module-cache"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

# Compile with swiftc (use xcrun to match SDK/toolchain)
xcrun --sdk macosx swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macosx13.0 \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$SWIFT_MODULE_CACHE" \
    -Xcc "-fmodules-cache-path=$CLANG_MODULE_CACHE" \
    -framework AppKit \
    -framework CoreGraphics \
    -framework Carbon \
    -framework StoreKit \
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

# Copy localization files (.lproj directories)
echo "🌍 Copying localization files..."
LPROJ_COUNT=0
for lproj in VibeCapture/Resources/*.lproj; do
    if [ -d "$lproj" ]; then
        cp -R "$lproj" "$APP_BUNDLE/Contents/Resources/"
        ((LPROJ_COUNT++))
    fi
done
echo "🌍 Copied $LPROJ_COUNT language bundles"

# Copy UI SVG icons
if ls VibeCapture/Resources/*.svg >/dev/null 2>&1; then
    cp VibeCapture/Resources/*.svg "$APP_BUNDLE/Contents/Resources/"
    echo "🎨 UI icons copied"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [ "${SKIP_SIGN:-0}" = "1" ]; then
    echo "⏭️  Skipping code signing (SKIP_SIGN=1)"
else
    CODESIGN_ID="${CODESIGN_ID:-Developer ID Application: Nan Wang (2257B2LRRF)}"
    echo "🔏 Signing app with Developer ID..."
    # Sign the app with Developer ID certificate + Hardened Runtime (required for notarization)
    if codesign --force --deep --sign "$CODESIGN_ID" \
        --options runtime \
        --entitlements VibeCapture/VibeCapture.entitlements \
        "$APP_BUNDLE"; then
        echo "✅ Signed with Developer ID"
    else
        # Fallback: ad-hoc signing for restricted environments (no Keychain access)
        echo "⚠️  Developer ID signing failed; falling back to ad-hoc signing"
        codesign --force --deep --sign - \
            --entitlements VibeCapture/VibeCapture.entitlements \
            "$APP_BUNDLE"
        echo "✅ Signed with ad-hoc identity"
    fi
fi

echo "✅ Build complete!"
echo "📍 App: $APP_BUNDLE"

if [ "${SKIP_INSTALL:-0}" = "1" ]; then
    echo "⏭️  Skipping install to /Applications (SKIP_INSTALL=1)"
else
    # Install to /Applications for persistent permissions
    echo "📲 Installing to /Applications..."
    cp -R "$APP_BUNDLE" /Applications/
    echo "✅ Installed to /Applications/$APP_NAME.app"
fi
