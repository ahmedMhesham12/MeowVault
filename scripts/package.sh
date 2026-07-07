#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MeowVault"
BUILD_DIR="$ROOT/.build/apple/Products/Release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_STAGE="$DIST_DIR/dmg-stage"
TMP_DMG="$DIST_DIR/$APP_NAME-tmp.dmg"

cd "$ROOT"
swift build -c release --arch x86_64 --arch arm64

rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
LOGO_SQUARE="$DIST_DIR/logo-square.png"
sips -c 1024 1024 "$ROOT/packaging/logo.png" --out "$LOGO_SQUARE" >/dev/null
cp "$LOGO_SQUARE" "$APP_DIR/Contents/Resources/logo.png"

ICONSET="$DIST_DIR/MeowVaultIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16 "$LOGO_SQUARE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$LOGO_SQUARE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$LOGO_SQUARE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$LOGO_SQUARE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$LOGO_SQUARE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$LOGO_SQUARE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$LOGO_SQUARE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$LOGO_SQUARE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$LOGO_SQUARE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$LOGO_SQUARE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/MeowVaultIcon.icns"

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR"

mkdir -p "$DMG_STAGE"
cp -R "$APP_DIR" "$DMG_STAGE/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE/Applications"
mkdir -p "$DMG_STAGE/.background"
swift "$ROOT/scripts/MakeDMGBackground.swift" "$DMG_STAGE/.background/background.png"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$TMP_DMG"

hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null || true
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen
MOUNT_DIR="/Volumes/$APP_NAME"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 760, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 104
    set background picture of viewOptions to POSIX file "$MOUNT_DIR/.background/background.png"
    set position of item "$APP_NAME.app" of container window to {180, 185}
    set position of item "Applications" of container window to {500, 185}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH"
rm -f "$TMP_DMG"

lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
echo "$DMG_PATH"
