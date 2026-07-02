#!/bin/sh
# Embed the Swift Testing support libraries that the tvOS Simulator runtime does
# not ship in its dyld shared cache. Without this, the XCTest runner links
# (transitively, via XCTestCore) against Testing.framework -> lib_TestingInterop.dylib
# and _Testing_Foundation.framework, which are present on iOS simulators but missing
# on tvOS simulators. The runner therefore launches fine via `xcodebuild
# test-without-building` (which injects toolchain search paths) but aborts at dyld
# time when started directly via `simctl launch` (how mobilecli starts the agent).
#
# This script makes the runner self-contained by copying the missing libraries into
# the bundle's Frameworks directory, adding an @rpath so they resolve as siblings,
# and re-signing the modified Mach-O files ad-hoc for the simulator.
#
# It also patches the display name and app icon on the auto-generated Runner.app,
# mirroring what scripts/patch-runner.sh does for the iOS runner. tvOS icons only
# work through a compiled asset catalog (Assets.car), so instead of copying loose
# PNGs we reuse the Assets.car + CFBundleIcons/CFBundleDisplayName that Xcode already
# compiled into the nested .xctest bundle (from the "App Icon & Top Shelf Image"
# brandassets in DeviceKitTests/Assets.xcassets) and copy them to the Runner.app root,
# where the Home Screen actually looks for them.
#
# The Swift Testing libraries are pulled from the AppleTVSimulator platform for
# simulator runners and from the AppleTVOS platform for real-device runners. The
# ad-hoc signature applied here to the copied binaries is a placeholder for the
# simulator; real-device runners are re-signed with a provisioning profile at
# install time (mobilecli's ResignIPA deep-signs Frameworks/), which replaces it.
#
# Usage: scripts/patch-tvos-runner.sh <path-to-devicekit-tvosUITests-Runner.app> [simulator|device]
set -e

APP="${1:?Usage: $0 <runner-app> [simulator|device]}"
TARGET="${2:-simulator}"
FW="$APP/Frameworks"

case "$TARGET" in
    device)
        TVDIR="$(xcode-select -p)/Platforms/AppleTVOS.platform/Developer"
        ;;
    simulator)
        TVDIR="$(xcode-select -p)/Platforms/AppleTVSimulator.platform/Developer"
        ;;
    *)
        echo "error: unknown target '$TARGET' (expected 'simulator' or 'device')"
        exit 1
        ;;
esac

if [ ! -d "$APP" ]; then
    echo "error: runner app not found at $APP"
    exit 1
fi

cp "$TVDIR/usr/lib/lib_TestingInterop.dylib" "$FW/"
cp -R "$TVDIR/Library/Frameworks/_Testing_Foundation.framework" "$FW/"

# Make each Swift Testing binary resolve its @rpath siblings from Frameworks/.
add_rpath() {
    install_name_tool -add_rpath '@loader_path/..' "$1" 2>/dev/null || true
}
add_rpath "$FW/Testing.framework/Testing"
add_rpath "$FW/_Testing_Foundation.framework/_Testing_Foundation"

# Re-sign modified Mach-O files (ad-hoc) for the simulator.
codesign --force --sign - "$FW/lib_TestingInterop.dylib"
codesign --force --sign - "$FW/Testing.framework"
codesign --force --sign - "$FW/_Testing_Foundation.framework"

echo "Patched tvOS runner with Swift Testing support libraries"

# Set display name to match the iOS runner.
/usr/bin/plutil -replace CFBundleDisplayName -string "Device Kit" "${APP}/Info.plist"

# Copy the compiled app icon catalog from the nested .xctest bundle to the
# Runner.app root and point the Runner's Info.plist at it, so the icon shows
# up on the Home Screen instead of the default placeholder.
XCTEST_DIR="${APP}/PlugIns/devicekit-tvosUITests.xctest"
if [ -f "${XCTEST_DIR}/Assets.car" ]; then
    cp "${XCTEST_DIR}/Assets.car" "${APP}/Assets.car"
    /usr/bin/plutil -replace CFBundleIcons -json \
        '{"CFBundlePrimaryIcon":"App Icon"}' \
        "${APP}/Info.plist"
    echo "Patched tvOS runner: display name and icon applied"
else
    echo "warning: no Assets.car found in ${XCTEST_DIR}, skipping icon patch"
fi
