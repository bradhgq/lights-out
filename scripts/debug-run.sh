#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/.build/debug/LightsOut.app"

cd "$PROJECT_DIR"
swift build

# Create a minimal .app bundle around the debug binary
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp .build/debug/LightsOut "$APP_DIR/Contents/MacOS/LightsOut"
cp .build/debug/LightsOutHelper "$APP_DIR/Contents/MacOS/LightsOutHelper"
cp resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp resources/com.lightsout.helper.plist "$APP_DIR/Contents/Resources/com.lightsout.helper.plist"

# Launch the app
exec "$APP_DIR/Contents/MacOS/LightsOut"
