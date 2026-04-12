#!/bin/sh
# Run mocha tests against a coverage-instrumented XCUITest server.
# Usage: scripts/test-coverage.sh <project> <scheme> <simulator-udid> <build-dir>

set -e

PROJECT="$1"
SCHEME="$2"
BOOTED="$3"
BUILD_DIR="$4"
RESULT_BUNDLE="${BUILD_DIR}/coverage.xcresult"

# Clean previous result bundle
rm -rf "$RESULT_BUNDLE"

# Start xcodebuild test with coverage in the background
echo "Starting XCUITest server with coverage enabled..."
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$BOOTED" \
    -derivedDataPath "$BUILD_DIR/local" \
    -enableCodeCoverage YES \
    -resultBundlePath "$RESULT_BUNDLE" \
    > /dev/null 2>&1 &
XCODEBUILD_PID=$!

# Wait for the server to be ready
echo "Waiting for server on localhost:12004..."
RETRIES=0
MAX_RETRIES=120
while [ $RETRIES -lt $MAX_RETRIES ]; do
    if ! kill -0 $XCODEBUILD_PID 2>/dev/null; then
        echo "error: xcodebuild process ($XCODEBUILD_PID) exited before server became ready"
        exit 1
    fi
    if curl -s http://localhost:12004/health > /dev/null 2>&1; then
        echo "Server is ready"
        break
    fi
    RETRIES=$((RETRIES + 1))
    sleep 1
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    echo "error: Server did not start within ${MAX_RETRIES}s"
    kill $XCODEBUILD_PID 2>/dev/null || true
    exit 1
fi

# Run mocha tests
echo "Running mocha tests..."
cd tests && npm test
TEST_EXIT=$?
cd ..

# Shutdown the server gracefully and let xcodebuild collect coverage
echo "Stopping XCUITest server..."
curl -s -X POST http://localhost:12004/shutdown > /dev/null 2>&1 || true
echo "Waiting for xcodebuild to finish and collect coverage..."
wait $XCODEBUILD_PID 2>/dev/null || true

# Generate coverage report from profdata
PROFDATA=$(find "$BUILD_DIR/local/Build/ProfileData" -name "Coverage.profdata" 2>/dev/null | head -1)
BINARY="$BUILD_DIR/local/Build/Products/Debug-iphonesimulator/${SCHEME}UITests-Runner.app/PlugIns/${SCHEME}UITests.xctest/${SCHEME}UITests"

if [ -n "$PROFDATA" ] && [ -f "$BINARY" ]; then
    echo ""
    echo "=== Coverage Report ==="
    xcrun llvm-cov report "$BINARY" -instr-profile "$PROFDATA" -ignore-filename-regex='build/local/SourcePackages|DerivedSources'
    echo ""
    echo "For detailed line coverage:"
    echo "  xcrun llvm-cov show $BINARY -instr-profile $PROFDATA -format=html -output-dir=coverage-html"
else
    echo "warning: Coverage data not found"
fi

exit $TEST_EXIT
