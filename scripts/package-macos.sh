#!/usr/bin/env bash
set -euo pipefail

APP_NAME="木简"
EXECUTABLE_NAME="NovelReader"
BUNDLE_ID="local.mujian-reader"
VERSION="${1:-0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
PKG_ROOT="$DIST_DIR/pkg-root"
PKG_PATH="$DIST_DIR/$APP_NAME-$VERSION.pkg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
ICON_FILE="AppIcon.icns"

cleanup() {
  rm -rf "$DMG_ROOT" "$PKG_ROOT"
}
trap cleanup EXIT

copy_app_without_metadata() {
  local destination="$1"
  rm -rf "$destination"
  mkdir -p "$(dirname "$destination")"
  COPYFILE_DISABLE=1 cp -R -X "$APP_BUNDLE" "$destination"
  xattr -cr "$destination" 2>/dev/null || true
  find "$destination" -name '._*' -delete
}

echo "==> Building release executable"
cd "$ROOT_DIR"
swift build -c release

echo "==> Creating app bundle"
rm -rf "$APP_BUNDLE" "$DMG_ROOT" "$PKG_ROOT" "$DMG_PATH" "$PKG_PATH" "$CHECKSUM_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
install -m 644 "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/$ICON_FILE"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null

echo "==> Ad-hoc signing app bundle"
codesign --force --deep --sign - "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Creating DMG"
mkdir -p "$DMG_ROOT"
copy_app_without_metadata "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Creating PKG"
mkdir -p "$PKG_ROOT/Applications"
copy_app_without_metadata "$PKG_ROOT/Applications/$APP_NAME.app"
xattr -cr "$PKG_ROOT" 2>/dev/null || true
find "$PKG_ROOT" -name '._*' -delete
COPYFILE_DISABLE=1 pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG_PATH"

echo "==> Writing checksums"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$PKG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "==> Done"
echo "App: $APP_BUNDLE"
echo "DMG: $DMG_PATH"
echo "PKG: $PKG_PATH"
echo "SHA256: $CHECKSUM_PATH"
echo "Note: app bundle is ad-hoc signed for local use, not Developer ID signed or notarized."
