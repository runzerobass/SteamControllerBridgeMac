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

echo "==> Building Release..."
xcodebuild -project "$PROJECT" -target "$SCHEME_TARGET" -configuration Release \
    SYMROOT="$PWD/build" build >/dev/null

echo "==> Ad-hoc signing with the VirtualHID entitlement..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"

echo "==> Embedded entitlements:"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -A1 hid.virtual || true

echo
echo "Built: $APP"
echo "Runs only with AMFI disabled. Move it to /Applications and launch from there"
echo "so Input Monitoring / Accessibility grants stick to a stable path."
