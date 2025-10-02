#!/usr/bin/env bash
set -euo pipefail

# VisualInspiration packaging script
# Usage:
#   ./scripts/package.sh            # Simple local build into ./dist (no cert required)
#   DEV_TEAM=YOURTEAMID \
#   SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   ./scripts/package.sh            # Attempts archive + export using ExportOptions.plist

PROJECT_PATH="VisualInspiration.xcodeproj"
SCHEME="VisualInspiration"
CONFIGURATION="Release"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$BUILD_DIR/VisualInspiration.xcarchive"
DERIVED_DATA="$BUILD_DIR/DerivedData"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_PLIST="$ROOT_DIR/ExportOptions.plist"

echo "==> Cleaning output directories"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

if [[ -n "${DEV_TEAM:-}" ]] && [[ -n "${SIGNING_IDENTITY:-}" ]] && [[ -f "$EXPORT_PLIST" ]]; then
  echo "==> Attempting archive + export using Developer ID credentials"

  # Archive
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    DEVELOPMENT_TEAM="$DEV_TEAM" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    -quiet

  # Export .app
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -exportPath "$EXPORT_DIR" \
    -quiet

  APP_PATH=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.app" -print -quit || true)
  if [[ -z "$APP_PATH" ]]; then
    echo "!! Export did not produce an .app; falling back to simple build"
  else
    cp -R "$APP_PATH" "$DIST_DIR/"
    APP_NAME=$(basename "$APP_PATH")
    (cd "$DIST_DIR" && zip -qry "${APP_NAME%.app}.zip" "$APP_NAME")
    echo "==> Success: $DIST_DIR/$APP_NAME"
    echo "==> Zip: $DIST_DIR/${APP_NAME%.app}.zip"
    exit 0
  fi
fi

echo "==> Performing simple Release build (Universal 2 - Intel + Apple Silicon)"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="arm64 x86_64" \
  build \
  -quiet

APP_OUT="$DERIVED_DATA/Build/Products/$CONFIGURATION/$SCHEME.app"
if [[ ! -d "$APP_OUT" ]]; then
  echo "!! Build succeeded but .app not found at: $APP_OUT"
  exit 1
fi

cp -R "$APP_OUT" "$DIST_DIR/"

# Create DMG
echo "==> Creating professional DMG..."
DMG_NAME="$SCHEME-v1.0.0"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
DMG_TEMP_DIR="$BUILD_DIR/dmg_temp"

# Clean up any existing temp directory
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to temp directory
cp -R "$APP_OUT" "$DMG_TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create the DMG with professional settings
hdiutil create -srcfolder "$DMG_TEMP_DIR" -volname "VisualInspiration" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDZO -imagekey zlib-level=9 "$DMG_PATH"

# Clean up temp directory
rm -rf "$DMG_TEMP_DIR"

# Also create ZIP for convenience
(cd "$DIST_DIR" && zip -qry "$SCHEME.zip" "$SCHEME.app")

echo "==> Local build complete"
echo "==> App: $DIST_DIR/$SCHEME.app"
echo "==> DMG: $DMG_PATH"
echo "==> Zip: $DIST_DIR/$SCHEME.zip"


