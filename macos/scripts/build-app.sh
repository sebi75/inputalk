#!/bin/bash
set -e

# Load .env (check repo root first, then macos/)
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

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

APP_NAME="Inputalk"
BUNDLE_ID="com.inputalk.app"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
UNIVERSAL="${UNIVERSAL:-true}"

echo -e "${BLUE}Building $APP_NAME...${NC}"

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cd "$PROJECT_DIR"

# Build release binary
if [ "$UNIVERSAL" = "true" ]; then
    echo -e "${BLUE}Building release binary (universal)...${NC}"
    swift build -c release --arch arm64 --arch x86_64
    BUILD_DIR=".build/apple/Products/Release"
else
    echo -e "${BLUE}Building release binary (host arch only)...${NC}"
    swift build -c release
    BUILD_DIR="$(swift build -c release --show-bin-path)"
fi

# Verify binary was created
if [ ! -f "$BUILD_DIR/Inputalk" ]; then
    echo -e "${RED}Error: Binary not found at $BUILD_DIR/Inputalk${NC}"
    exit 1
fi

# Create app bundle structure
echo -e "${BLUE}Creating app bundle structure...${NC}"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/Inputalk" "$APP_BUNDLE/Contents/MacOS/Inputalk"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy resource bundle if it exists (contains bundled resources)
RESOURCE_BUNDLE="$BUILD_DIR/Inputalk_Inputalk.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    echo -e "${BLUE}Copying resource bundle...${NC}"
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    echo -e "${BLUE}Copying app icon...${NC}"
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
else
    echo -e "${YELLOW}Warning: AppIcon.icns not found. Using default icon.${NC}"
fi

# Set executable permissions
chmod +x "$APP_BUNDLE/Contents/MacOS/Inputalk"

echo -e "${GREEN}App bundle created at: $APP_BUNDLE${NC}"

# Show binary info
echo -e "${BLUE}Binary info:${NC}"
file "$APP_BUNDLE/Contents/MacOS/Inputalk"
lipo -info "$APP_BUNDLE/Contents/MacOS/Inputalk"

# Code signing
if [ ! -z "$CODE_SIGN_IDENTITY" ]; then
    echo -e "${BLUE}Code signing with identity: $CODE_SIGN_IDENTITY${NC}"

    # Sign inside-out: nested bundles first, then the main app
    RESOURCE_BUNDLE_PATH="$APP_BUNDLE/Contents/Resources/Inputalk_Inputalk.bundle"
    if [ -d "$RESOURCE_BUNDLE_PATH" ]; then
        echo -e "${BLUE}Signing nested resource bundle...${NC}"
        codesign --force --sign "$CODE_SIGN_IDENTITY" \
            --timestamp \
            "$RESOURCE_BUNDLE_PATH"
    fi

    echo -e "${BLUE}Signing main app bundle...${NC}"
    codesign --force --sign "$CODE_SIGN_IDENTITY" \
        --entitlements "Resources/Inputalk.entitlements" \
        --options runtime \
        --timestamp \
        "$APP_BUNDLE"

    echo -e "${GREEN}Code signing complete!${NC}"

    # Verify code signature
    echo -e "${BLUE}Verifying code signature...${NC}"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

    # Notarize the app
    if [ "${SKIP_NOTARIZE:-false}" != "true" ]; then
        echo -e "${BLUE}Submitting for notarization...${NC}"
        NOTARIZE_ZIP="$DIST_DIR/Inputalk.zip"
        ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

        NOTARIZE_OUTPUT=$(xcrun notarytool submit "$NOTARIZE_ZIP" \
            --keychain-profile "notarytool-profile" \
            --wait --timeout 30m 2>&1) || true

        echo "$NOTARIZE_OUTPUT"

        SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep "  id:" | head -1 | awk '{print $2}')

        if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
            rm -f "$NOTARIZE_ZIP"

            echo -e "${BLUE}Stapling notarization ticket...${NC}"
            xcrun stapler staple "$APP_BUNDLE"
            echo -e "${GREEN}Notarization complete!${NC}"
        else
            rm -f "$NOTARIZE_ZIP"

            if [ -n "$SUBMISSION_ID" ]; then
                echo -e "${YELLOW}Fetching notarization log...${NC}"
                xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "notarytool-profile" 2>&1 || true
            fi

            echo -e "${RED}Notarization failed or timed out.${NC}"
            exit 1
        fi
    fi
else
    # Ad-hoc sign for local use
    echo -e "${YELLOW}No CODE_SIGN_IDENTITY set. Ad-hoc signing for local use...${NC}"
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo -e "${GREEN}Ad-hoc signing complete!${NC}"
    echo -e "${YELLOW}Note: Users will see a Gatekeeper warning on first launch.${NC}"
fi

echo -e "${GREEN}Build complete!${NC}"
