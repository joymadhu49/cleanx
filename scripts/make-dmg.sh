#!/bin/bash
# Build CleanX.app and package as a distributable .dmg.
# Uses hdiutil (built into macOS). No external deps.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="CleanX"
BUILD_DIR=".build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist 2>/dev/null || echo "1.0.0")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
STAGE_DIR="${BUILD_DIR}/dmg-stage"

# 1. Build the app first
"${PROJECT_DIR}/scripts/build.sh"

# 2. Stage contents
rm -rf "${STAGE_DIR}" "${DMG_PATH}"
mkdir -p "${STAGE_DIR}"
cp -R "${APP_PATH}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"

# 3. Build dmg
echo "→ creating ${DMG_NAME}"
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGE_DIR}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "${DMG_PATH}" >/dev/null

# 4. Codesign the dmg if a stable identity is available
SIGN_IDENTITY="${SIGN_IDENTITY:-CleanX Developer}"
if security find-certificate -c "${SIGN_IDENTITY}" >/dev/null 2>&1; then
    echo "→ signing dmg with '${SIGN_IDENTITY}'"
    codesign --force --sign "${SIGN_IDENTITY}" "${DMG_PATH}" 2>&1 | sed 's/^/   /' || true
fi

rm -rf "${STAGE_DIR}"

SIZE=$(du -h "${DMG_PATH}" | cut -f1)
echo "✓ built ${DMG_PATH} (${SIZE})"
echo
echo "Open: open '${DMG_PATH}'"
