#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData-local-ci"
rm -rf "$DERIVED_DATA_DIR"
mkdir -p "$DERIVED_DATA_DIR"

stop_running_vibecap() {
  pkill -f '/VibeCap.app/Contents/MacOS/VibeCap' >/dev/null 2>&1 || true
}

echo "========================================"
echo " VibeCap Local CI (build + tests)"
echo "========================================"

echo ""
echo "[1/5] Localization integrity check"
./scripts/check-localization.sh VibeCapture/Resources

echo ""
echo "[2/5] App build (dist package)"
./build.sh

echo ""
echo "[3/5] Unit tests"
stop_running_vibecap
xcodebuild \
  -scheme VibeCap \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  test \
  -only-testing:VibeCapTests \
  -skip-testing:VibeCapTests/PurchaseFlowTests \
  -skip-testing:VibeCapTests/LibraryFlowIntegrationTests

echo ""
echo "[4/5] Integration tests"
stop_running_vibecap
xcodebuild \
  -scheme VibeCap \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  test \
  -only-testing:VibeCapTests/LibraryFlowIntegrationTests

echo ""
echo "[5/5] UI tests"
stop_running_vibecap
xcodebuild \
  -scheme VibeCap \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  test \
  -only-testing:VibeCapUITests

echo ""
echo "✅ Local CI completed."
