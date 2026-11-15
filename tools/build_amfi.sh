#!/bin/bash
#
# Builds SteamControllerBridgeMac and ad-hoc re-signs it with the
# com.apple.developer.hid.virtual.device entitlement, enabling the virtual
# gamepad WITHOUT a provisioning profile.
#
# This binary only runs on a Mac with AMFI disabled (see the "AMFI route"
# section of the README). On a normal system AMFI will kill it at launch.
# It is NOT for distribution; the clean path uses a provisioning profile.
#
# Usage: tools/build_amfi.sh
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="SteamControllerBridgeMac.xcodeproj"
SCHEME_TARGET="SteamControllerBridgeMac"
ENTITLEMENTS="tools/virtualhid.entitlements"
APP="build/Release/${SCHEME_TARGET}.app"

ICONSET_SRC="${SCHEME_TARGET}/Assets.xcassets/AppIcon.appiconset"

# With AMFI disabled, Xcode's asset catalog compiler (actool -> ibtoold) can
# crash at launch (SIGBUS in a system framework initializer), failing the
# build. Fallback: build without the catalog and package the app icon with
# iconutil, which doesn't go through ibtoold.
build_with_catalog() {
    xcodebuild -project "$PROJECT" -target "$SCHEME_TARGET" -configuration Release \
        SYMROOT="$PWD/build" build >/dev/null 2>&1
}

build_without_catalog() {
    xcodebuild -project "$PROJECT" -target "$SCHEME_TARGET" -configuration Release \
        SYMROOT="$PWD/build" 'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets' \
        ASSETCATALOG_COMPILER_APPICON_NAME= build >/dev/null

    local iconset
    iconset="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
        cp "$ICONSET_SRC/icon_${size}.png" "$iconset/icon_${size}x${size}.png"
        cp "$ICONSET_SRC/icon_${size}@2x.png" "$iconset/icon_${size}x${size}@2x.png"
    done
    iconutil -c icns "$iconset" -o "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
}

echo "==> Building Release..."
if ! build_with_catalog; then
    echo "    Standard build failed (likely actool/ibtoold crashing under AMFI);"
    echo "    retrying without the asset catalog..."
    build_without_catalog
fi

echo "==> Ad-hoc signing with the VirtualHID entitlement..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"

echo "==> Embedded entitlements:"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -A1 hid.virtual || true

echo
echo "Built: $APP"
echo "Runs only with AMFI disabled. Move it to /Applications and launch from there"
echo "so Input Monitoring / Accessibility grants stick to a stable path."
