#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/.build/LightsOut.app"

echo "Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/LightsOut" "$APP_DIR/Contents/MacOS/LightsOut"
cp "$BUILD_DIR/LightsOutHelper" "$APP_DIR/Contents/MacOS/LightsOutHelper"
cp "$PROJECT_DIR/resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/resources/com.lightsout.helper.plist" "$APP_DIR/Contents/Resources/com.lightsout.helper.plist"

echo "App bundle created at: $APP_DIR"
echo "Run with: open $APP_DIR"
