#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
FIXTURE_ROOT="${FILE_STACK_SCREENSHOT_FIXTURE_ROOT:-/Users/Shared/Stashbar}"
OUTPUT_DIR="${FILE_STACK_SCREENSHOT_OUTPUT_DIR:-${PROJECT_ROOT}/AppStore/screenshots-live/mac/ko-KR}"
DOCS_SCREENSHOT_DIR="${PROJECT_ROOT}/docs/assets/screenshots"
EXECUTABLE_PATH="${PROJECT_ROOT}/.build/release/FileStackApp"
CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/file-stack-swift-module-cache}"
export CLANG_MODULE_CACHE_PATH

mkdir -p "${FIXTURE_ROOT}/Screenshots" "${FIXTURE_ROOT}/Downloads" "${FIXTURE_ROOT}/Workspace/Assets" "${FIXTURE_ROOT}/Workspace/Archive"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${DOCS_SCREENSHOT_DIR}"
mkdir -p "${CLANG_MODULE_CACHE_PATH}"

create_text_file() {
    local path="$1"
    local contents="$2"
    printf '%s\n' "${contents}" > "${path}"
}

copy_with_timestamp() {
    local source="$1"
    local destination="$2"
    local timestamp="$3"
    cp "${source}" "${destination}"
    touch -t "${timestamp}" "${destination}"
}

rm -rf "${FIXTURE_ROOT}/Screenshots" "${FIXTURE_ROOT}/Downloads" "${FIXTURE_ROOT}/Workspace"
mkdir -p "${FIXTURE_ROOT}/Screenshots" "${FIXTURE_ROOT}/Downloads" "${FIXTURE_ROOT}/Workspace/Assets" "${FIXTURE_ROOT}/Workspace/Archive"
rm -f "${OUTPUT_DIR}"/*.png 2>/dev/null || true

rm -rf "${FIXTURE_ROOT}/Workspace/Client Assets" "${FIXTURE_ROOT}/Workspace/Archive"
mkdir -p "${FIXTURE_ROOT}/Workspace/Assets" "${FIXTURE_ROOT}/Workspace/Archive"

swift "${PROJECT_ROOT}/scripts/generate_demo_fixture_assets.swift" "${FIXTURE_ROOT}/Screenshots"
touch -t "202605041804" "${FIXTURE_ROOT}/Screenshots/Cover.png"
touch -t "202605041803" "${FIXTURE_ROOT}/Screenshots/Card.jpg"
touch -t "202605041802" "${FIXTURE_ROOT}/Screenshots/Stats.png"

create_text_file "${FIXTURE_ROOT}/Screenshots/Notes.txt" $'Capture a clean top-of-screen slice with the menu bar item and popover centered.'
touch -t "202605041801" "${FIXTURE_ROOT}/Screenshots/Notes.txt"

create_text_file "${FIXTURE_ROOT}/Downloads/Plan.md" $'# Plan\n- Finalize screenshots\n- Confirm localized metadata\n- Attach review notes for sandboxed folder access'
touch -t "202605041805" "${FIXTURE_ROOT}/Downloads/Plan.md"

create_text_file "${FIXTURE_ROOT}/Downloads/Tips.txt" $'Review Notes\n\nStashbar accesses only folders selected by the user and stores security-scoped bookmarks for those choices.'
touch -t "202605041800" "${FIXTURE_ROOT}/Downloads/Tips.txt"

create_text_file "${FIXTURE_ROOT}/Downloads/Sales.csv" $'date,downloads\n2026-05-01,124\n2026-05-02,141\n2026-05-03,166'
touch -t "202605041759" "${FIXTURE_ROOT}/Downloads/Sales.csv"

copy_with_timestamp "${FIXTURE_ROOT}/Screenshots/Stats.png" "${FIXTURE_ROOT}/Workspace/Assets/Stats.png" "202605041758"
copy_with_timestamp "${FIXTURE_ROOT}/Screenshots/Card.jpg" "${FIXTURE_ROOT}/Workspace/Assets/Card.jpg" "202605041757"

create_text_file "${FIXTURE_ROOT}/Workspace/Assets/Copy.md" $'# Copy\n\n- Korean title review\n- Subtitle refinement\n- Accessibility pass'
touch -t "202605041756" "${FIXTURE_ROOT}/Workspace/Assets/Copy.md"

create_text_file "${FIXTURE_ROOT}/Workspace/Archive/Old.txt" $'Previous launch notes kept here for reference.'
touch -t "202605041755" "${FIXTURE_ROOT}/Workspace/Archive/Old.txt"

create_text_file "${FIXTURE_ROOT}/Workspace/ReadMe.md" $'# Workspace\n\nUse hierarchy view to inspect nested launch materials and localized assets.'
touch -t "202605041806" "${FIXTURE_ROOT}/Workspace/ReadMe.md"

swift build -c release --product FileStackApp --package-path "${PROJECT_ROOT}"

# Mirror .lproj folders next to the executable so NSLocalizedString via
# Bundle.main resolves correctly (the SPM resource bundle nests them otherwise).
SPM_BUNDLE_DIR="${PROJECT_ROOT}/.build/release/FileStackApp_FileStackApp.bundle"
if [[ -d "${SPM_BUNDLE_DIR}" ]]; then
    for lproj in "${SPM_BUNDLE_DIR}"/*.lproj; do
        if [[ -d "${lproj}" ]]; then
            cp -R "${lproj}" "${PROJECT_ROOT}/.build/release/"
        fi
    done
fi

scenes=("icon-grid" "folder-switching" "list-view" "hierarchy-view")
outputs=(
    "01-live-icon-grid.png"
    "02-live-folder-switching.png"
    "03-live-list-view.png"
    "04-live-hierarchy-view.png"
)

for index in "${!scenes[@]}"; do
    scene="${scenes[$index]}"
    output="${OUTPUT_DIR}/${outputs[$index]}"
    rm -f "${output}"

    FILE_STACK_SCREENSHOT_MODE=1 \
    FILE_STACK_SCREENSHOT_RENDERER=offscreen \
    FILE_STACK_SCREENSHOT_FIXTURE_ROOT="${FIXTURE_ROOT}" \
    FILE_STACK_SCREENSHOT_SCENE="${scene}" \
    FILE_STACK_SCREENSHOT_OUTPUT_PATH="${output}" \
    "${EXECUTABLE_PATH}" -AppleLanguages "(ko)" -AppleLocale "ko_KR"
done

cp "${OUTPUT_DIR}/01-live-icon-grid.png" "${DOCS_SCREENSHOT_DIR}/01-icon-grid.png"
cp "${OUTPUT_DIR}/02-live-folder-switching.png" "${DOCS_SCREENSHOT_DIR}/02-folder-switching.png"
cp "${OUTPUT_DIR}/03-live-list-view.png" "${DOCS_SCREENSHOT_DIR}/03-list-view.png"
cp "${OUTPUT_DIR}/04-live-hierarchy-view.png" "${DOCS_SCREENSHOT_DIR}/04-hierarchy-view.png"

echo "Generated real screenshots in ${OUTPUT_DIR} and ${DOCS_SCREENSHOT_DIR}"
