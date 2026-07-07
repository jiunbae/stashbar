#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Unlocking login keychain (enter your macOS login password)"
security unlock-keychain ~/Library/Keychains/login.keychain-db

echo "==> Starting App Store build & upload"
APPLE_API_KEY="T75A5FYM6V" \
APPLE_API_ISSUER="5d53ebaa-cb10-4e0d-9d91-1819c54c1c18" \
SIGN_IDENTITY="Apple Distribution: Jiun Bae (728FW73BS8)" \
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Jiun Bae (728FW73BS8)" \
PROVISIONING_PROFILE="scripts/File_Stack_App_Store.provisionprofile" \
ACTION=upload ./scripts/package_for_app_store.sh
