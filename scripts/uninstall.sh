#!/usr/bin/env bash
set -euo pipefail

pkill -f '/MeowVault.app/Contents/MacOS/MeowVault' 2>/dev/null || true
rm -rf /Applications/MeowVault.app
rm -rf "$HOME/Library/Application Support/MeowVault"
echo "MeowVault uninstalled"
