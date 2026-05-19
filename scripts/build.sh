#!/bin/bash
# Build CleanX and assemble .app bundle
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

CONFIG="${CONFIG:-release}"
APP_NAME="CleanX"
BUILD_DIR=".build"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "→ swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"
EXEC_SRC="${BIN_PATH}/${APP_NAME}"
RESOURCE_BUNDLE="${BIN_PATH}/${APP_NAME}_${APP_NAME}.bundle"

if [[ ! -f "${EXEC_SRC}" ]]; then
    echo "ERROR: built binary not found at ${EXEC_SRC}" >&2
    exit 1
fi

echo "→ assembling ${BUNDLE_DIR}"
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

cp "${EXEC_SRC}" "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"
cp "Info.plist" "${BUNDLE_DIR}/Contents/Info.plist"

if [[ -d "${RESOURCE_BUNDLE}" ]]; then
    cp -R "${RESOURCE_BUNDLE}/" "${BUNDLE_DIR}/Contents/Resources/"
fi

# App icon: regenerate .icns if source script newer or icon missing
if [[ ! -f "AppIcon.icns" || "scripts/make-icon.swift" -nt "AppIcon.icns" ]]; then
    echo "→ generating AppIcon.icns"
    rm -rf build-icon.iconset
    mkdir -p build-icon.iconset
    swift scripts/make-icon.swift build-icon.iconset >/dev/null
    iconutil -c icns -o AppIcon.icns build-icon.iconset
    rm -rf build-icon.iconset
fi
cp "AppIcon.icns" "${BUNDLE_DIR}/Contents/Resources/AppIcon.icns"

cat > "${BUNDLE_DIR}/Contents/PkgInfo" <<EOF
APPL????
EOF

SIGN_IDENTITY="${SIGN_IDENTITY:-CleanX Developer}"
if security find-certificate -c "${SIGN_IDENTITY}" >/dev/null 2>&1; then
    echo "→ codesign with '${SIGN_IDENTITY}' (stable identity — TCC persists across rebuilds)"
    codesign --force --deep --sign "${SIGN_IDENTITY}" "${BUNDLE_DIR}" 2>&1 | sed 's/^/   /' || true
else
    echo "→ ad-hoc codesign (TCC will re-prompt each rebuild)"
    echo "  Run scripts/create-signing-cert.sh once to make permissions persist."
    codesign --force --deep --sign - "${BUNDLE_DIR}" 2>&1 | sed 's/^/   /' || true
fi

echo "✓ built ${BUNDLE_DIR}"
echo
echo "Run with:"
echo "    open '${BUNDLE_DIR}'"
echo "or:"
echo "    '${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}'"
