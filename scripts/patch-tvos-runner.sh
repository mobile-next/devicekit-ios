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
# Usage: scripts/patch-tvos-runner.sh <path-to-devicekit-tvosUITests-Runner.app>
set -e

APP="${1:?Usage: $0 <runner-app>}"
FW="$APP/Frameworks"
TVDIR="$(xcode-select -p)/Platforms/AppleTVSimulator.platform/Developer"

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
