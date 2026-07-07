#!/usr/bin/env bash
set -euo pipefail

swift test
swift build -c release --arch x86_64 --arch arm64

echo "Build complete. Run ./scripts/package.sh to create dist/MeowVault.dmg."
