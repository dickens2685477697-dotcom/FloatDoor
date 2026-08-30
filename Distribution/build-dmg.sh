#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
VERSION_FILE="$PROJECT_DIR/Distribution/VERSION"
VERSION="${1:-$(tr -d '[:space:]' < "$VERSION_FILE")}" 
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_NAME="Float Door"
BUNDLE_ID="com.floatdoor.app"
PRODUCT_DIR="$PROJECT_DIR/.build/apple/Products/Release"
OUTPUT_DIR="$PROJECT_DIR/dist/v$VERSION"
APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
DMG_PATH="$OUTPUT_DIR/FloatDoor-$VERSION.dmg"
STAGE_DIR="$OUTPUT_DIR/dmg-root"
ICON_SOURCE="$PROJECT_DIR/Sources/FloatDoor/Resources/Icons/glass-icon-master.png"
ICONSET_DIR="$OUTPUT_DIR/AppIcon.iconset"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

mkdir -p "$OUTPUT_DIR" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

env \
  CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/floatdoor-clang-cache" \
  SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/floatdoor-swiftpm-cache" \
  swift build -c release --arch arm64 --arch x86_64 --disable-sandbox

cp "$PRODUCT_DIR/FloatDoor" "$APP_PATH/Contents/MacOS/FloatDoor"
cp -R "$PRODUCT_DIR/FloatDoor_FloatDoor.bundle" "$APP_PATH/Contents/Resources/"
cp "$PROJECT_DIR/Distribution/Info.plist" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST"

mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP_PATH"
  print "警告：未找到 Developer ID，已使用临时签名。此 DMG 不适合无提示公开分发。"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
cp "$PROJECT_DIR/LICENSE" "$STAGE_DIR/LICENSE.md"
cp "$PROJECT_DIR/NOTICE" "$STAGE_DIR/NOTICE.md"
ln -s /Applications "$STAGE_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
rm -rf "$STAGE_DIR" "$ICONSET_DIR"

print "已生成：$DMG_PATH"
print "版本：$VERSION ($BUILD_NUMBER)"
print "架构：$(lipo -archs "$APP_PATH/Contents/MacOS/FloatDoor")"
