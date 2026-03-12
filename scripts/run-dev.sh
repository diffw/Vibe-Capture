#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData-run-dev"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug/VibeCap.app"

RETRY_COUNT=1
NO_OPEN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --retry)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: Missing value for --retry"
        exit 1
      fi
      RETRY_COUNT="$2"
      shift 2
      ;;
    --no-open)
      NO_OPEN=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./scripts/run-dev.sh [--retry N] [--no-open]

Description:
  Clear + Run equivalent for local development:
  1) clean derived data
  2) build Debug app with xcodebuild
  3) launch app automatically

Options:
  --retry N   Retry build up to N times after failure (default: 1)
  --no-open   Only clear + build, do not launch the app
  -h, --help  Show this help
EOF
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      cat <<'EOF'
Usage:
  ./scripts/run-dev.sh [--retry N] [--no-open]
EOF
      exit 1
      ;;
  esac
done

if ! [[ "$RETRY_COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --retry must be a non-negative integer"
  exit 1
fi

ATTEMPT=1
MAX_ATTEMPT=$((RETRY_COUNT + 1))
SUCCESS=0

while [[ $ATTEMPT -le $MAX_ATTEMPT ]]; do
  echo "========================================"
  echo " VibeCap Dev Run (attempt $ATTEMPT/$MAX_ATTEMPT)"
  echo "========================================"

  # Ensure previous app instance does not conflict with the new launch.
  pkill -f '/VibeCap.app/Contents/MacOS/VibeCap' >/dev/null 2>&1 || true

  echo "[1/2] Clear build artifacts"
  rm -rf "$DERIVED_DATA_DIR"
  mkdir -p "$DERIVED_DATA_DIR"

  echo "[2/2] Build Debug app"
  if xcodebuild \
      -project "VibeCapture.xcodeproj" \
      -scheme VibeCap \
      -configuration Debug \
      -destination 'platform=macOS' \
      -derivedDataPath "$DERIVED_DATA_DIR" \
      build; then
    SUCCESS=1
    break
  fi

  echo "WARN: Build failed on attempt $ATTEMPT/$MAX_ATTEMPT"
  ATTEMPT=$((ATTEMPT + 1))
done

if [[ "$SUCCESS" -ne 1 ]]; then
  echo "ERROR: Clear + Run failed after $MAX_ATTEMPT attempt(s)."
  exit 1
fi

if [[ "$NO_OPEN" -eq 1 ]]; then
  echo "OK: Clear + Build completed."
  exit 0
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Build succeeded but app was not found: $APP_PATH"
  exit 1
fi

open "$APP_PATH"
echo "OK: Clear + Run completed."
