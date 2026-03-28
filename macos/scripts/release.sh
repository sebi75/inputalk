#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Inputalk Release Build Script       ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the app
"$SCRIPT_DIR/build-app.sh"
echo ""

# Create the DMG
"$SCRIPT_DIR/create-dmg.sh"
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Release build complete!             ${NC}"
echo -e "${GREEN}======================================${NC}"
