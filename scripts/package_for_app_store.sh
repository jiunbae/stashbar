#!/usr/bin/env bash
#
# Build, sign, and package Stashbar for the Mac App Store.
#
# This script wraps build_app.sh with App Store-specific signing, then runs
# productbuild to produce an installer .pkg. Optionally validates or uploads
# to App Store Connect.
#
# REQUIRED env vars:
#   SIGN_IDENTITY        e.g., "Apple Distribution: Jiun Bae (TEAMID)"
#   INSTALLER_IDENTITY   e.g., "3rd Party Mac Developer Installer: Jiun Bae (TEAMID)"
#
# OPTIONAL env vars (for upload/validate):
#   ACTION               package | validate | upload   (default: package)
#
#   For Apple ID + app-specific password auth (older):
#     APPLE_ID            your Apple ID email
#     APPLE_APP_PASSWORD  app-specific password (appleid.apple.com → Sign-In and Security)
#
#   For App Store Connect API key auth (recommended):
#     APPLE_API_KEY       key ID (e.g., ABC123XYZ4)
#     APPLE_API_ISSUER    issuer ID (UUID)
#     The corresponding AuthKey_<APPLE_API_KEY>.p8 file must be at one of:
#       ~/.appstoreconnect/private_keys/  or  ./private_keys/
#
# Examples:
#   # Just build the .pkg (no upload, no validate)
#   SIGN_IDENTITY="Apple Distribution: Jiun Bae (XXXXXX)" \
#   INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Jiun Bae (XXXXXX)" \
#     ./scripts/package_for_app_store.sh
#
#   # Validate before uploading
#   ACTION=validate APPLE_API_KEY=... APPLE_API_ISSUER=... \
#   SIGN_IDENTITY="..." INSTALLER_IDENTITY="..." \
#     ./scripts/package_for_app_store.sh
#
#   # Upload to App Store Connect
#   ACTION=upload APPLE_API_KEY=... APPLE_API_ISSUER=... \
#   SIGN_IDENTITY="..." INSTALLER_IDENTITY="..." \
#     ./scripts/package_for_app_store.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

ACTION="${ACTION:-package}"
APP_NAME="${APP_DISPLAY_NAME:-Stashbar}"
APP_BUNDLE_PATH="${PROJECT_ROOT}/dist/${APP_NAME}.app"
PKG_PATH="${PROJECT_ROOT}/dist/${APP_NAME}.pkg"

# --- Validate required vars ---------------------------------------------------

missing=()
[[ -z "${SIGN_IDENTITY:-}" || "${SIGN_IDENTITY}" == "-" ]] && missing+=("SIGN_IDENTITY")
[[ -z "${INSTALLER_IDENTITY:-}" ]] && missing+=("INSTALLER_IDENTITY")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: missing required env vars: ${missing[*]}" >&2
    echo "" >&2
    echo "  SIGN_IDENTITY      e.g., 'Apple Distribution: Jiun Bae (TEAMID)'" >&2
    echo "  INSTALLER_IDENTITY e.g., '3rd Party Mac Developer Installer: Jiun Bae (TEAMID)'" >&2
    echo "" >&2
    echo "Run \`security find-identity -v -p basic\` to list installed certificates." >&2
    exit 1
fi

# --- Build the signed .app ----------------------------------------------------

echo "==> Building .app with App Store signing"
SIGN_IDENTITY="${SIGN_IDENTITY}" PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}" "${SCRIPT_DIR}/build_app.sh"

if [[ ! -d "${APP_BUNDLE_PATH}" ]]; then
    echo "error: expected app bundle not found at ${APP_BUNDLE_PATH}" >&2
    exit 1
fi

# --- Package as .pkg ----------------------------------------------------------

echo "==> Packaging .pkg with installer signing"
productbuild \
    --component "${APP_BUNDLE_PATH}" /Applications \
    --sign "${INSTALLER_IDENTITY}" \
    "${PKG_PATH}"

echo "==> Verifying .pkg signature"
pkgutil --check-signature "${PKG_PATH}" | sed 's/^/    /'

# --- Determine auth method ----------------------------------------------------

AUTH_ARGS=()
if [[ -n "${APPLE_API_KEY:-}" && -n "${APPLE_API_ISSUER:-}" ]]; then
    AUTH_ARGS=(--apiKey "${APPLE_API_KEY}" --apiIssuer "${APPLE_API_ISSUER}")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    AUTH_ARGS=(-u "${APPLE_ID}" -p "${APPLE_APP_PASSWORD}")
fi

# --- Action: package | validate | upload --------------------------------------

case "${ACTION}" in
    package)
        echo ""
        echo "✅ Package created: ${PKG_PATH}"
        echo ""
        echo "Next steps:"
        echo "  1. Validate:  ACTION=validate APPLE_API_KEY=... APPLE_API_ISSUER=... \\"
        echo "                  SIGN_IDENTITY=... INSTALLER_IDENTITY=... $0"
        echo "  2. Upload:    ACTION=upload   (same env vars)"
        echo "  3. Or open Transporter.app and drag the .pkg into it."
        ;;

    validate)
        if [[ ${#AUTH_ARGS[@]} -eq 0 ]]; then
            echo "error: validate requires APPLE_API_KEY+APPLE_API_ISSUER or APPLE_ID+APPLE_APP_PASSWORD" >&2
            exit 1
        fi
        echo "==> Validating with App Store Connect"
        xcrun altool --validate-app -f "${PKG_PATH}" -t macos "${AUTH_ARGS[@]}"
        echo "✅ Validation passed"
        ;;

    upload)
        if [[ ${#AUTH_ARGS[@]} -eq 0 ]]; then
            echo "error: upload requires APPLE_API_KEY+APPLE_API_ISSUER or APPLE_ID+APPLE_APP_PASSWORD" >&2
            exit 1
        fi
        echo "==> Uploading to App Store Connect (may take several minutes)"
        xcrun altool --upload-app -f "${PKG_PATH}" -t macos "${AUTH_ARGS[@]}"
        echo "✅ Upload complete"
        echo "   Track processing at https://appstoreconnect.apple.com → My Apps → ${APP_NAME}"
        ;;

    *)
        echo "error: unknown ACTION '${ACTION}' (expected: package | validate | upload)" >&2
        exit 1
        ;;
esac
