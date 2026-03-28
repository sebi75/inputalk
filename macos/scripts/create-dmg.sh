#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$PROJECT_DIR")"

# Load .env (check repo root first, then macos/)
for ENV_FILE in "$ROOT_DIR/.env" "$PROJECT_DIR/.env"; do
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
        break
    fi
done

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Read version from Info.plist
VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Resources/Info.plist" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not read version from Info.plist${NC}"
    exit 1
fi

APP_NAME="Inputalk"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_FINAL="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo -e "${BLUE}Creating DMG installer for $APP_NAME v$VERSION...${NC}"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}Error: App bundle not found at $APP_BUNDLE${NC}"
    echo -e "${RED}Run ./scripts/build-app.sh first${NC}"
    exit 1
fi

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo -e "${RED}Error: create-dmg not found. Install with: brew install create-dmg${NC}"
    exit 1
fi

# Clean previous DMG
rm -f "$DMG_FINAL"

# Build optional args
ICON_FILE="$PROJECT_DIR/Resources/AppIcon.icns"
EXTRA_ARGS=()
if [ -f "$ICON_FILE" ]; then
    EXTRA_ARGS+=(--volicon "$ICON_FILE")
fi

# Create DMG
echo -e "${BLUE}Creating DMG image...${NC}"
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 160 \
    --icon "$APP_NAME.app" 160 185 \
    --app-drop-link 500 185 \
    --no-internet-enable \
    --hide-extension "$APP_NAME.app" \
    "${EXTRA_ARGS[@]}" \
    "$DMG_FINAL" \
    "$APP_BUNDLE"

echo -e "${GREEN}DMG created: $DMG_FINAL${NC}"

FILE_SIZE=$(du -h "$DMG_FINAL" | cut -f1)
echo -e "${GREEN}File size: $FILE_SIZE${NC}"

# Code sign DMG if identity is set
if [ ! -z "$CODE_SIGN_IDENTITY" ]; then
    echo -e "${BLUE}Code signing DMG...${NC}"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "$DMG_FINAL"
    echo -e "${GREEN}DMG code signing complete!${NC}"
    codesign --verify --verbose=2 "$DMG_FINAL"
fi

echo -e "${GREEN}Done! Distribute: $DMG_FINAL${NC}"
