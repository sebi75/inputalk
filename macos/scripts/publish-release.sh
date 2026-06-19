#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$PROJECT_DIR")"
APP_BUNDLE="$PROJECT_DIR/dist/Inputalk.app"

# Load .env (check repo root first, then macos/)
for ENV_FILE in "$ROOT_DIR/.env" "$PROJECT_DIR/.env"; do
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        set +a
        break
    fi
done

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Parse arguments
SKIP_BUILD=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --skip-build) SKIP_BUILD=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo "Usage: ./scripts/publish-release.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-build    Skip building (use existing dist/)"
            echo "  --dry-run       Build and render release artifacts locally (no upload)"
            echo "  --help          Show this help"
            exit 0
            ;;
    esac
done

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Inputalk Release Publisher          ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Will render local artifacts only (no upload)${NC}"
    echo ""
fi

# Read version from Info.plist
VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Resources/Info.plist" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not read version from Info.plist${NC}"
    exit 1
fi

DMG_FILE="Inputalk-$VERSION.dmg"
DMG_PATH="$PROJECT_DIR/dist/$DMG_FILE"
TAG="v$VERSION"

if [ "$DRY_RUN" != true ]; then
    if ! command -v gh > /dev/null 2>&1; then
        echo -e "${RED}Error: GitHub CLI (gh) not found. Install it: brew install gh${NC}"
        exit 1
    fi
fi

REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "sebi75/inputalk")
DMG_URL="https://github.com/$REPO_SLUG/releases/download/$TAG/$DMG_FILE"

echo -e "${BLUE}Version:${NC}  $VERSION"
echo -e "${BLUE}DMG:${NC}      $DMG_FILE"
echo -e "${BLUE}Tag:${NC}      $TAG"
echo -e "${BLUE}DMG URL:${NC}  $DMG_URL"
echo ""

# Step 1: Build
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${BLUE}Step 1: Building release...${NC}"
    echo ""
    "$SCRIPT_DIR/release.sh"
    echo ""
else
    echo -e "${YELLOW}Step 1: Skipping build (--skip-build)${NC}"
    echo ""
fi

# Check DMG exists
if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}Error: DMG not found at $DMG_PATH${NC}"
    exit 1
fi

if [ ! -f "$APP_BUNDLE/Contents/Info.plist" ]; then
    echo -e "${RED}Error: App bundle Info.plist not found at $APP_BUNDLE/Contents/Info.plist${NC}"
    exit 1
fi

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo -e "${GREEN}DMG ready:${NC} $DMG_PATH ($DMG_SIZE)"
echo ""

# Preflight Sparkle appcast before uploading anything.
echo -e "${BLUE}Preparing Sparkle appcast...${NC}"

SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-sign_update}"
if ! command -v "$SPARKLE_SIGN_UPDATE" > /dev/null 2>&1; then
    echo -e "${RED}Error: Sparkle sign_update tool not found.${NC}"
    echo -e "${RED}Install Sparkle tools or set SPARKLE_SIGN_UPDATE=/path/to/sign_update${NC}"
    exit 1
fi

PUBLIC_KEY=$(grep -A1 "SUPublicEDKey" "$PROJECT_DIR/Resources/Info.plist" | tail -1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
if [ -z "$PUBLIC_KEY" ] || [ "$PUBLIC_KEY" = "REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY" ]; then
    echo -e "${RED}Error: SUPublicEDKey is not configured in Resources/Info.plist${NC}"
    exit 1
fi

BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_BUNDLE/Contents/Info.plist")
if [ -z "$BUILD_NUMBER" ]; then
    echo -e "${RED}Error: Could not read build number from app bundle Info.plist${NC}"
    exit 1
fi

if [ -z "$DMG_URL" ]; then
    echo -e "${RED}Error: DMG_URL is empty${NC}"
    exit 1
fi

SIGNATURE_ATTRS=$("$SPARKLE_SIGN_UPDATE" "$DMG_PATH")
PUB_DATE=$(date -Ru)
DMG_SIZE_BYTES=$(stat -f%z "$DMG_PATH")
RELEASE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

APPCAST_XML=$(cat <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Inputalk Updates</title>
    <link>https://inputalk.com/</link>
    <description>Inputalk release updates</description>
    <item>
      <title>Inputalk $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure url="$DMG_URL"
        $SIGNATURE_ATTRS
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF
)

LATEST_JSON=$(cat <<EOF
{
  "version": "$VERSION",
  "date": "$RELEASE_DATE",
  "dmg": {
    "url": "$DMG_URL",
    "size": $DMG_SIZE_BYTES,
    "filename": "$DMG_FILE"
  }
}
EOF
)

mkdir -p "$PROJECT_DIR/dist"
echo "$APPCAST_XML" > "$PROJECT_DIR/dist/appcast.xml"
echo "$LATEST_JSON" > "$PROJECT_DIR/dist/latest.json"

if command -v xmllint > /dev/null 2>&1; then
    xmllint --noout "$PROJECT_DIR/dist/appcast.xml"
fi

echo -e "${GREEN}Sparkle appcast ready${NC}"
echo -e "${GREEN}Wrote:${NC} $PROJECT_DIR/dist/appcast.xml"
echo -e "${GREEN}Wrote:${NC} $PROJECT_DIR/dist/latest.json"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Skipping GitHub upload${NC}"
    echo ""
    echo -e "  Would publish release ${GREEN}$TAG${NC} with assets:"
    echo -e "    $DMG_FILE"
    echo -e "    appcast.xml"
    echo -e "    latest.json"
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  Dry run complete!                   ${NC}"
    echo -e "${GREEN}======================================${NC}"
    exit 0
fi

# Step 2: Publish to GitHub Releases (create the release or add assets to it)
echo -e "${BLUE}Step 2: Publishing to GitHub Releases ($TAG)...${NC}"
if gh release view "$TAG" > /dev/null 2>&1; then
    echo -e "${BLUE}Release $TAG exists; uploading assets...${NC}"
    gh release upload "$TAG" \
        "$DMG_PATH" \
        "$PROJECT_DIR/dist/appcast.xml" \
        "$PROJECT_DIR/dist/latest.json" \
        --clobber
else
    echo -e "${BLUE}Creating release $TAG...${NC}"
    gh release create "$TAG" \
        "$DMG_PATH" \
        "$PROJECT_DIR/dist/appcast.xml" \
        "$PROJECT_DIR/dist/latest.json" \
        --title "Inputalk $VERSION" \
        --notes "Inputalk $VERSION"
fi

echo -e "${GREEN}Release published!${NC}"
echo ""

# Verify the DMG asset is attached to the release
echo -e "${BLUE}Verifying release assets...${NC}"
gh release view "$TAG" --json assets --jq '.assets[].name' | grep -q "$DMG_FILE"
echo -e "${GREEN}DMG verified on GitHub release${NC}"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Release published successfully!     ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "  Version:  ${GREEN}$VERSION${NC}"
echo -e "  Build:    ${GREEN}$BUILD_NUMBER${NC}"
echo -e "  DMG URL:  ${GREEN}$DMG_URL${NC}"
echo -e "  Manifest: ${GREEN}https://github.com/$REPO_SLUG/releases/latest/download/latest.json${NC}"
echo -e "  Appcast:  ${GREEN}https://github.com/$REPO_SLUG/releases/latest/download/appcast.xml${NC}"
echo ""
