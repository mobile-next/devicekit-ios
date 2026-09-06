#!/bin/sh
# Patch the auto-generated UITests-Runner app with display name and icon.
# Usage: scripts/patch-runner.sh <build-products-dir> [runner-dir]
#   build-products-dir: directory containing devicekit-ios.app (for icons)
#   runner-dir: directory containing the runner app (defaults to build-products-dir)

BUILD_DIR="${1:?Usage: $0 <build-products-dir> [runner-dir]}"
RUNNER_DIR="${2:-$BUILD_DIR}"

RUNNER_APP="${RUNNER_DIR}/devicekit-iosUITests-Runner.app"
HOST_APP="${BUILD_DIR}/devicekit-ios.app"

if [ ! -d "${RUNNER_APP}" ] || [ ! -f "${RUNNER_APP}/Info.plist" ]; then
    echo "error: Runner app not found at ${RUNNER_APP}"
    exit 1
fi

# Newer Xcode versions split XCTest/Swift Testing support into separate runtime
# artifacts. Xcode supplies them through its DYLD paths for normal test runs,
# but a standalone runner must carry its own copies.
PLATFORM_NAME=$(/usr/libexec/PlistBuddy -c "Print :DTPlatformName" "${RUNNER_APP}/Info.plist")
case "${PLATFORM_NAME}" in
    iphonesimulator)
        XCODE_PLATFORM="iPhoneSimulator"
        ;;
    iphoneos)
        XCODE_PLATFORM="iPhoneOS"
        ;;
    *)
        XCODE_PLATFORM=""
        ;;
esac

if [ -n "${XCODE_PLATFORM}" ]; then
    SELECTED_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
    TESTING_INTEROP_LIBRARY="${SELECTED_DEVELOPER_DIR}/Platforms/${XCODE_PLATFORM}.platform/Developer/usr/lib/lib_TestingInterop.dylib"
    TESTING_FOUNDATION_FRAMEWORK="${SELECTED_DEVELOPER_DIR}/Platforms/${XCODE_PLATFORM}.platform/Developer/Library/Frameworks/_Testing_Foundation.framework"
    if [ -f "${TESTING_INTEROP_LIBRARY}" ]; then
        mkdir -p "${RUNNER_APP}/Frameworks"
        cp "${TESTING_INTEROP_LIBRARY}" "${RUNNER_APP}/Frameworks/"
    fi
    if [ -d "${TESTING_FOUNDATION_FRAMEWORK}" ]; then
        mkdir -p "${RUNNER_APP}/Frameworks"
        cp -R "${TESTING_FOUNDATION_FRAMEWORK}" "${RUNNER_APP}/Frameworks/"
    fi
fi

# Below iOS 15 XCTest needs libswift_Concurrency in the runner's Frameworks too, or it hangs.
for lib in "${RUNNER_APP}"/PlugIns/*.xctest/Frameworks/libswift*.dylib; do
    [ -f "${lib}" ] || continue
    mkdir -p "${RUNNER_APP}/Frameworks"
    cp "${lib}" "${RUNNER_APP}/Frameworks/"
    echo "note: mirrored $(basename "${lib}") into runner Frameworks"
done

# Set display name
/usr/bin/plutil -replace CFBundleDisplayName -string "Device Kit" "${RUNNER_APP}/Info.plist"

# Set version from VERSION env var (e.g. set by CI from git tag)
if [ -n "${VERSION}" ]; then
    /usr/bin/plutil -replace CFBundleShortVersionString -string "${VERSION}" "${RUNNER_APP}/Info.plist"
    XCTEST_PLIST="${RUNNER_APP}/PlugIns/devicekit-iosUITests.xctest/Info.plist"
    if [ -f "${XCTEST_PLIST}" ]; then
        /usr/bin/plutil -replace CFBundleShortVersionString -string "${VERSION}" "${XCTEST_PLIST}"
    fi
fi

# Copy icon files from host app
if [ -d "${HOST_APP}" ]; then
    for icon in "${HOST_APP}"/AppIcon*.png; do
        [ -f "$icon" ] && cp "$icon" "${RUNNER_APP}/"
    done
    /usr/bin/plutil -replace CFBundleIcons -json \
        '{"CFBundlePrimaryIcon":{"CFBundleIconFiles":["AppIcon60x60"],"CFBundleIconName":"AppIcon"}}' \
        "${RUNNER_APP}/Info.plist"
    /usr/bin/plutil -replace "CFBundleIcons~ipad" -json \
        '{"CFBundlePrimaryIcon":{"CFBundleIconFiles":["AppIcon60x60","AppIcon76x76"],"CFBundleIconName":"AppIcon"}}' \
        "${RUNNER_APP}/Info.plist"
fi

echo "Patched runner: display name and icon applied"
