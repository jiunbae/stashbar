#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

APP_PRODUCT="FileStackApp"
APP_DISPLAY_NAME=${APP_DISPLAY_NAME:-"File Stack"}
PRODUCT_NAME=${PRODUCT_NAME:-$APP_PRODUCT}
BUILD_CONFIGURATION=${BUILD_CONFIGURATION:-release}
OUTPUT_DIR=${OUTPUT_DIR:-"${PROJECT_ROOT}/dist"}
BUNDLE_IDENTIFIER=${BUNDLE_IDENTIFIER:-"com.jiunbae.FileStack"}
APP_VERSION=${APP_VERSION:-"1.0.0"}
APP_BUILD=${APP_BUILD:-"$(date +%Y%m%d%H%M)"}
APP_ICON_FILE=${APP_ICON_FILE:-"FileStack.icns"}
APP_ICON_NAME=${APP_ICON_NAME:-"FileStack"}
APP_CATEGORY=${APP_CATEGORY:-"public.app-category.utilities"}
APP_COPYRIGHT=${APP_COPYRIGHT:-"Copyright © $(date +%Y) Jiun Bae. All rights reserved."}
RESOURCE_DIR=${RESOURCE_DIR:-"${PROJECT_ROOT}/Resources"}
ENTITLEMENTS_FILE=${ENTITLEMENTS_FILE:-"${SCRIPT_DIR}/FileStack.entitlements"}
# `-` is ad-hoc; for App Store builds set SIGN_IDENTITY to "Apple Distribution: ..."
SIGN_IDENTITY=${SIGN_IDENTITY:--}

APP_BUNDLE_NAME="${APP_DISPLAY_NAME}.app"
APP_BUNDLE_PATH="${OUTPUT_DIR}/${APP_BUNDLE_NAME}"
MACOS_DIR="${APP_BUNDLE_PATH}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE_PATH}/Contents/Resources"

echo "🚀 Building ${PRODUCT_NAME} (${BUILD_CONFIGURATION})"
swift build --configuration "${BUILD_CONFIGURATION}" --product "${PRODUCT_NAME}" --package-path "${PROJECT_ROOT}"

EXECUTABLE_PATH="${PROJECT_ROOT}/.build/${BUILD_CONFIGURATION}/${APP_PRODUCT}"
if [[ ! -f "${EXECUTABLE_PATH}" ]]; then
  echo "error: expected executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

rm -rf "${APP_BUNDLE_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cat >"${APP_BUNDLE_PATH}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_IDENTIFIER}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_PRODUCT}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>${APP_ICON_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>${APP_CATEGORY}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>${APP_COPYRIGHT}</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
EOF

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_PRODUCT}"
chmod +x "${MACOS_DIR}/${APP_PRODUCT}"

if command -v strip >/dev/null 2>&1; then
  echo "Stripping symbols from executable"
  strip -x "${MACOS_DIR}/${APP_PRODUCT}" || true
fi

if [[ -d "${RESOURCE_DIR}" ]]; then
  rsync -a "${RESOURCE_DIR}/" "${RESOURCES_DIR}/"
fi

ICON_DEST="${RESOURCES_DIR}/${APP_ICON_FILE}"
if [[ ! -f "${ICON_DEST}" ]]; then
  SOURCE_ICON_PNG="${RESOURCE_DIR}/${APP_ICON_NAME}Icon.png"
  if [[ ! -f "${SOURCE_ICON_PNG}" ]]; then
    SOURCE_ICON_PNG="${RESOURCE_DIR}/FileStackIcon.png"
  fi

  if [[ -f "${SOURCE_ICON_PNG}" ]]; then
    TEMP_DIR=$(mktemp -d)
    ICONSET_DIR="${TEMP_DIR}/${APP_ICON_NAME}.iconset"
    mkdir -p "${ICONSET_DIR}"
    for size in 16 32 64 128 256 512 1024; do
      sips -z ${size} ${size} "${SOURCE_ICON_PNG}" --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
      half=$((size / 2))
      if [[ ${half} -ge 16 ]]; then
        sips -z ${size} ${size} "${SOURCE_ICON_PNG}" --out "${ICONSET_DIR}/icon_${half}x${half}@2x.png" >/dev/null
      fi
    done
    if command -v iconutil >/dev/null 2>&1; then
      iconutil -c icns "${ICONSET_DIR}" -o "${ICON_DEST}"
    else
      echo "warning: iconutil not found; copying 512px PNG as placeholder icon" >&2
      cp "${ICONSET_DIR}/icon_512x512.png" "${ICON_DEST}"
    fi
    rm -rf "${TEMP_DIR}"
  else
    echo "warning: icon source not found; expected ${SOURCE_ICON_PNG}" >&2
  fi
fi

if command -v codesign >/dev/null 2>&1; then
  CODESIGN_ARGS=(--force --options runtime)
  if [[ -f "${ENTITLEMENTS_FILE}" ]]; then
    CODESIGN_ARGS+=(--entitlements "${ENTITLEMENTS_FILE}")
  fi
  if [[ "${SIGN_IDENTITY}" == "-" ]]; then
    echo "Ad-hoc signing ${APP_BUNDLE_PATH} (with hardened runtime)"
    CODESIGN_ARGS+=(--sign - --timestamp=none --deep)
  else
    echo "Signing ${APP_BUNDLE_PATH} with: ${SIGN_IDENTITY}"
    CODESIGN_ARGS+=(--sign "${SIGN_IDENTITY}")
  fi
  codesign "${CODESIGN_ARGS[@]}" "${APP_BUNDLE_PATH}" >/dev/null
fi

echo "✅ App bundle created at ${APP_BUNDLE_PATH}"
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  echo "ℹ️  For App Store distribution, rebuild with:"
  echo "   SIGN_IDENTITY=\"Apple Distribution: <Your Team>\" $0"
fi
