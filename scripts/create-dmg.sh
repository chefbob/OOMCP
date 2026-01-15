#!/bin/bash
#
# Create a DMG installer for OOMCP
# Uses only built-in macOS tools (no Homebrew required)
#
# Prerequisites:
# 1. Build and archive the app in Xcode (Product → Archive)
# 2. Export the notarized app (Distribute App → Developer ID → Export)
# 3. Run this script with the path to the exported .app
#
# Usage: ./scripts/create-dmg.sh /path/to/OOMCP.app
#

set -e

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/OOMCP.app"
    echo ""
    echo "The app should be the notarized export from Xcode."
    exit 1
fi

APP_PATH="$1"
APP_NAME="OOMCP"
DMG_NAME="OOMCP"
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

# Verify the app exists and is actually an app bundle
if [ ! -d "$APP_PATH" ] || [[ "$APP_PATH" != *.app ]]; then
    echo "Error: '$APP_PATH' is not a valid .app bundle"
    echo "Please provide the path to OOMCP.app, not a directory containing it"
    exit 1
fi

# Verify the app is signed
if ! codesign -v "$APP_PATH" 2>/dev/null; then
    echo "Warning: App does not appear to be properly signed"
    echo "Make sure you exported a notarized app from Xcode"
fi

# Output directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../build"
mkdir -p "$OUTPUT_DIR"

DMG_PATH="$OUTPUT_DIR/${DMG_NAME}-${VERSION}.dmg"
TEMP_DIR=$(mktemp -d)
STAGING_DIR="$TEMP_DIR/staging"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Creating DMG..."
echo "  App: $APP_PATH"
echo "  Output: $DMG_PATH"

# Create staging directory
mkdir -p "$STAGING_DIR"

# Copy app to staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"

# Remove existing DMG if present
rm -f "$DMG_PATH"

# Create DMG using hdiutil (built into macOS)
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "DMG created successfully: $DMG_PATH"
echo ""
echo "Next steps:"
echo "1. Test the DMG - double-click to mount"
echo "2. Drag the app to Applications"
echo "3. Launch and verify it works"
echo "4. Test with OmniOutliner open"
