#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Building File Stack (release configuration)"
swift build --configuration release --package-path "$PROJECT_ROOT"

echo "✅ Build finished. Artifacts are in .build/release"
