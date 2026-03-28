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
            echo "  --dry-run       Show what would be done"
            echo "  --help          Show this help"
            exit 0
            ;;
    esac
done

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Inputalk Release Publisher          ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check required env vars
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_S3_BUCKET_NAME" ]; then
    echo -e "${RED}Error: AWS credentials not set in .env${NC}"
    echo -e "${RED}Required: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_S3_BUCKET_NAME${NC}"
    exit 1
fi

# Read version from Info.plist
VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Resources/Info.plist" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not read version from Info.plist${NC}"
    exit 1
fi

DMG_FILE="Inputalk-$VERSION.dmg"
DMG_PATH="$PROJECT_DIR/dist/$DMG_FILE"
S3_BUCKET="$AWS_S3_BUCKET_NAME"
S3_DMG_KEY="releases/$VERSION/$DMG_FILE"
S3_LATEST_KEY="releases/latest.json"

echo -e "${BLUE}Version:${NC}  $VERSION"
echo -e "${BLUE}DMG:${NC}      $DMG_FILE"
echo -e "${BLUE}S3 Key:${NC}   s3://$S3_BUCKET/$S3_DMG_KEY"
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

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo -e "${GREEN}DMG ready:${NC} $DMG_PATH ($DMG_SIZE)"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would upload:${NC}"
    echo -e "  DMG  → s3://$S3_BUCKET/$S3_DMG_KEY"
    echo -e "  JSON → s3://$S3_BUCKET/$S3_LATEST_KEY"
    exit 0
fi

# Step 2: Upload DMG to S3
echo -e "${BLUE}Step 2: Uploading DMG to S3...${NC}"
aws s3 cp "$DMG_PATH" "s3://$S3_BUCKET/$S3_DMG_KEY" \
    --region "${AWS_REGION:-us-east-1}" \
    --content-type "application/octet-stream"

echo -e "${GREEN}DMG uploaded!${NC}"

# Step 3: Upload latest.json manifest
echo -e "${BLUE}Step 3: Updating latest.json...${NC}"

DMG_SIZE_BYTES=$(stat -f%z "$DMG_PATH")
RELEASE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DMG_URL="https://$S3_BUCKET.s3.${AWS_REGION:-us-east-1}.amazonaws.com/$S3_DMG_KEY"

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

echo "$LATEST_JSON" | aws s3 cp - "s3://$S3_BUCKET/$S3_LATEST_KEY" \
    --region "${AWS_REGION:-us-east-1}" \
    --content-type "application/json" \
    --cache-control "max-age=60"

echo -e "${GREEN}latest.json updated!${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying upload...${NC}"
aws s3 ls "s3://$S3_BUCKET/$S3_DMG_KEY" --region "${AWS_REGION:-us-east-1}" > /dev/null 2>&1
echo -e "${GREEN}DMG verified in S3${NC}"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Release published successfully!     ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "  Version:  ${GREEN}$VERSION${NC}"
echo -e "  DMG URL:  ${GREEN}$DMG_URL${NC}"
echo -e "  Manifest: ${GREEN}https://$S3_BUCKET.s3.${AWS_REGION:-us-east-1}.amazonaws.com/$S3_LATEST_KEY${NC}"
echo ""
