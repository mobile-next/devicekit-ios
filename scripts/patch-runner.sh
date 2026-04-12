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

# Set display name
/usr/bin/plutil -replace CFBundleDisplayName -string "Device Kit" "${RUNNER_APP}/Info.plist"

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
