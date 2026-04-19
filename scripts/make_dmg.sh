#!/usr/bin/env bash
# Build a signed .app in the "Local" configuration and package it as a
# compressed DMG ready for distribution. No paid Dev Program / notarisation
# involved — macOS will show the standard "unverified developer" Gatekeeper
# prompt on first launch; user can right-click → Open to bypass.
#
# Usage:
#   scripts/make_dmg.sh                       # build + package
#   SIGN_ID="Apple Development: <you>" ./...  # override signing identity

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="KV-TabFinder"
CONFIG="Local"
PRODUCT_NAME="KV-TabFinder"

# Pull version from project.yml so the DMG filename matches the app.
VERSION=$(awk '/MARKETING_VERSION:/ {gsub(/"/,""); print $2; exit}' project.yml)
VERSION="${VERSION:-1.0.0}"

DMG_NAME="${PRODUCT_NAME}-${VERSION}.dmg"
DIST_DIR="dist"
STAGING_DIR="${DIST_DIR}/staging"

# Auto-pick the first "Apple Development" identity from the keychain
# unless the user forced a specific one via SIGN_ID.
if [[ -z "${SIGN_ID:-}" ]]; then
    SIGN_ID=$(security find-identity -p codesigning -v \
        | awk -F'"' '/Apple Development/{print $2; exit}')
fi
if [[ -z "${SIGN_ID}" ]]; then
    echo "error: no Apple Development signing identity found in keychain."
    echo "       Install one via Xcode → Settings → Accounts → Manage Certificates."
    exit 1
fi

echo "==> Version:          ${VERSION}"
echo "==> Signing identity: ${SIGN_ID}"

# Regenerate the Xcode project so any recent project.yml changes are in.
if command -v xcodegen >/dev/null 2>&1; then
    echo "==> xcodegen"
    xcodegen >/dev/null
fi

# Fresh build output so we're not packaging yesterday's binary.
rm -rf "${DIST_DIR}" \
       ~/Library/Developer/Xcode/DerivedData/KV-TabFinder-*
mkdir -p "${DIST_DIR}"
LOG="${DIST_DIR}/xcodebuild.log"

echo "==> Building ${CONFIG} configuration"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
"${XCODEBUILD}" \
    -project KV-TabFinder.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -destination 'platform=macOS' \
    -skipMacroValidation \
    build \
    CODE_SIGN_IDENTITY="${SIGN_ID}" \
    CODE_SIGN_STYLE=Manual \
    > "${LOG}" 2>&1 || {
        echo "error: build failed, see ${LOG}"
        exit 1
    }

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData \
    -maxdepth 6 -type d -name "${PRODUCT_NAME}.app" \
    -path "*/Build/Products/${CONFIG}/*" 2>/dev/null | head -1)

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
    echo "error: built app not found"
    exit 1
fi
echo "==> App:  ${APP_PATH}"

# Verify the signature we just produced before we package it.
echo "==> Signature check"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}" 2>&1 | sed 's/^/    /'

# --- Staging layout for the DMG --------------------------------------------
mkdir -p "${STAGING_DIR}"
rm -rf "${STAGING_DIR:?}/"*
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# --- Create the DMG --------------------------------------------------------
OUT="${DIST_DIR}/${DMG_NAME}"
rm -f "${OUT}"

echo "==> Packaging ${OUT}"
hdiutil create \
    -volname "${PRODUCT_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -fs HFS+ \
    -format UDZO \
    "${OUT}" >/dev/null

rm -rf "${STAGING_DIR}"

echo ""
echo "Done: ${OUT}"
du -h "${OUT}" | awk '{print "Size:  " $1}'
shasum -a 256 "${OUT}" | awk '{print "SHA-256: " $1}'
