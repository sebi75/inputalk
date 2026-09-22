#!/bin/bash
set -euo pipefail

# Launch a real .app so TCC (microphone, accessibility) attaches to this
# development build instead of the Inputalk copy in /Applications.
# `swift run` starts a raw executable with no bundle ID of its own.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$PROJECT_DIR")"

for ENV_FILE in "$ROOT_DIR/.env" "$PROJECT_DIR/.env"; do
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
        break
    fi
done

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

APP_NAME="Inputalk Dev"
BUNDLE_ID="com.inputalk.app.dev"
DIST_DIR="$PROJECT_DIR/.build/dev"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

cd "$PROJECT_DIR"

echo -e "${BLUE}Building $APP_NAME...${NC}"
swift build

BUILD_DIR="$(swift build --show-bin-path)"
if [ ! -f "$BUILD_DIR/Inputalk" ]; then
    echo "Error: Binary not found at $BUILD_DIR/Inputalk" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/Inputalk" "$APP_BUNDLE/Contents/MacOS/Inputalk"
chmod +x "$APP_BUNDLE/Contents/MacOS/Inputalk"

cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"
PLIST="$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks false" "$PLIST"
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$PLIST" 2>/dev/null || true

RESOURCE_BUNDLE="$BUILD_DIR/Inputalk_Inputalk.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

SPARKLE_FRAMEWORK=$(find "$PROJECT_DIR/.build" -path "*/Sparkle.framework" -type d -print -quit)
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
    if ! otool -l "$APP_BUNDLE/Contents/MacOS/Inputalk" | grep -q "@executable_path/../Frameworks"; then
        install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/Inputalk"
    fi
fi

codesign_dev_app() {
    local identity="${CODE_SIGN_IDENTITY:-}"
    if [ -n "$identity" ]; then
        echo -e "${BLUE}Signing $APP_NAME with $identity so Accessibility survives rebuilds.${NC}"
        if [ -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]; then
            codesign --force --sign "$identity" --options runtime --timestamp=none \
                "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
        fi
        codesign --force --sign "$identity" \
            --entitlements "$PROJECT_DIR/Resources/Inputalk.entitlements" \
            --options runtime \
            --timestamp=none \
            "$APP_BUNDLE"
    else
        echo -e "${YELLOW}No CODE_SIGN_IDENTITY set. Ad-hoc signing; Accessibility may reset each launch.${NC}"
        codesign --force --sign - --entitlements "$PROJECT_DIR/Resources/Inputalk.entitlements" \
            "$APP_BUNDLE"
    fi
}

codesign_dev_app

# Reuse production Whisper models so the first Dev launch does not re-download.
PROD_SUPPORT="$HOME/Library/Application Support/com.inputalk.app"
DEV_SUPPORT="$HOME/Library/Application Support/$BUNDLE_ID"
if [ -L "$DEV_SUPPORT/Models" ] && [ ! -e "$DEV_SUPPORT/Models" ]; then
    rm "$DEV_SUPPORT/Models"  # dangling link from a removed production install
fi
if [ -d "$PROD_SUPPORT/Models" ] && [ ! -e "$DEV_SUPPORT/Models" ]; then
    mkdir -p "$DEV_SUPPORT"
    ln -s "$PROD_SUPPORT/Models" "$DEV_SUPPORT/Models"
    echo -e "${YELLOW}Linked Whisper models from the installed Inputalk app.${NC}"
fi

# Own the shortcut. Other Inputalk copies install the same event tap.
osascript -e 'quit app "Inputalk Dev"' 2>/dev/null || true
osascript -e 'quit app "Inputalk"' 2>/dev/null || true
pkill -f 'Inputalk.app/Contents/MacOS/Inputalk' 2>/dev/null || true
pkill -f 'Inputalk Dev.app/Contents/MacOS/Inputalk' 2>/dev/null || true
pkill -f '[.]build/.*/debug/Inputalk$' 2>/dev/null || true
sleep 0.4

echo -e "${GREEN}Opening $APP_BUNDLE${NC}"
echo -e "${YELLOW}Grant Microphone and Accessibility to Inputalk Dev in System Settings (not the Inputalk entry from /Applications).${NC}"
open "$APP_BUNDLE"
