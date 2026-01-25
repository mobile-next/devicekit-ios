#!/bin/bash
#
# screencapture.sh - Stream iOS device screen to ffplay
#
# This script connects to the DeviceKit iOS H.264 video stream and displays
# it using ffplay. It handles dependency installation and optional USB port
# forwarding via iproxy.
#
# Usage:
#   ./screencapture.sh [OPTIONS]
#
# Options:
#   -h, --host HOST      Host to connect to (default: 127.0.0.1)
#   -p, --port PORT      Port to connect to (default: 12005)
#   -u, --udid UDID      Device UDID for iproxy (enables USB forwarding)
#   -s, --setup-iproxy   Set up iproxy port forwarding before streaming
#   -r, --record FILE    Record stream to file instead of displaying
#   -l, --low-latency    Enable low-latency mode (less buffering)
#   --help               Show this help message
#
# Examples:
#   # Stream from simulator or with existing iproxy
#   ./screencapture.sh
#
#   # Stream with automatic iproxy setup
#   ./screencapture.sh --setup-iproxy
#
#   # Stream from specific device
#   ./screencapture.sh --setup-iproxy --udid 00008030-001234567890402E
#
#   # Record to file
#   ./screencapture.sh --record output.mp4
#
#   # Connect to device over Wi-Fi
#   ./screencapture.sh --host 192.168.1.100
#

set -e

# Default configuration
HOST="127.0.0.1"
PORT="12005"
UDID=""
SETUP_IPROXY=false
RECORD_FILE=""
LOW_LATENCY=false
IPROXY_PID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Show help
show_help() {
    head -45 "$0" | tail -40 | sed 's/^#//' | sed 's/^ //'
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -u|--udid)
                UDID="$2"
                shift 2
                ;;
            -s|--setup-iproxy)
                SETUP_IPROXY=true
                shift
                ;;
            -r|--record)
                RECORD_FILE="$2"
                shift 2
                ;;
            -l|--low-latency)
                LOW_LATENCY=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                error "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}

# Check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        warn "This script is optimized for macOS. Some features may not work on other platforms."
    fi
}

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for Apple Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        success "Homebrew installed"
    fi
}

# Check and install ffmpeg
check_ffmpeg() {
    if ! command -v ffplay &> /dev/null; then
        info "ffmpeg/ffplay not found. Installing via Homebrew..."
        check_homebrew
        brew install ffmpeg
        success "ffmpeg installed"
    else
        success "ffmpeg is available"
    fi
}

# Check and install libimobiledevice (for iproxy)
check_libimobiledevice() {
    if ! command -v iproxy &> /dev/null; then
        info "iproxy not found. Installing libimobiledevice via Homebrew..."
        check_homebrew
        brew install libimobiledevice
        success "libimobiledevice installed"
    else
        success "iproxy is available"
    fi
}

# Setup iproxy port forwarding
setup_iproxy() {
    check_libimobiledevice

    # Kill any existing iproxy on this port
    pkill -f "iproxy.*$PORT" 2>/dev/null || true
    sleep 0.5

    info "Setting up iproxy port forwarding on port $PORT..."

    if [[ -n "$UDID" ]]; then
        iproxy "$PORT:$PORT" -u "$UDID" &
    else
        iproxy "$PORT:$PORT" &
    fi
    IPROXY_PID=$!

    # Wait for iproxy to start
    sleep 1

    if kill -0 "$IPROXY_PID" 2>/dev/null; then
        success "iproxy started (PID: $IPROXY_PID)"
    else
        error "Failed to start iproxy. Is a device connected?"
    fi
}

# Cleanup on exit
cleanup() {
    if [[ -n "$IPROXY_PID" ]] && kill -0 "$IPROXY_PID" 2>/dev/null; then
        info "Stopping iproxy (PID: $IPROXY_PID)..."
        kill "$IPROXY_PID" 2>/dev/null || true
    fi
}

# Test TCP connection
test_connection() {
    info "Testing connection to $HOST:$PORT..."

    if nc -z -w 3 "$HOST" "$PORT" 2>/dev/null; then
        success "Connection successful"
        return 0
    else
        return 1
    fi
}

# Stream with ffplay
stream_ffplay() {
    info "Starting ffplay stream from $HOST:$PORT..."
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Screen Capture Started${NC}"
    echo -e "${GREEN}  Press 'q' in the ffplay window to quit${NC}"
    echo -e "${GREEN}  Press Ctrl+C here to stop${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    local ffplay_opts=(
        -hide_banner
        -loglevel warning
        -stats
        -window_title "DeviceKit iOS Screen"
    )

    if $LOW_LATENCY; then
        ffplay_opts+=(
            -fflags nobuffer
            -flags low_delay
            -framedrop
            -sync ext
        )
    else
        ffplay_opts+=(
            -fflags nobuffer+fastseek
            -flags low_delay
            -probesize 32
            -analyzeduration 0
        )
    fi

    # Use nc to receive TCP stream and pipe to ffplay
    nc "$HOST" "$PORT" | ffplay "${ffplay_opts[@]}" -f h264 -
}

# Record stream to file
record_stream() {
    local output="$1"

    info "Recording stream to $output..."
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Recording Started${NC}"
    echo -e "${GREEN}  Output: $output${NC}"
    echo -e "${GREEN}  Press Ctrl+C to stop recording${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # Use nc to receive TCP stream and pipe to ffmpeg
    nc "$HOST" "$PORT" | ffmpeg \
        -hide_banner \
        -loglevel warning \
        -stats \
        -f h264 \
        -i - \
        -c:v copy \
        -movflags +faststart \
        "$output"
}

# Main function
main() {
    parse_args "$@"

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    DeviceKit iOS Screen Capture        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    check_macos
    check_ffmpeg

    # Setup cleanup trap
    trap cleanup EXIT INT TERM

    # Setup iproxy if requested
    if $SETUP_IPROXY; then
        setup_iproxy
    fi

    # Test connection
    local retries=3
    local connected=false

    for ((i=1; i<=retries; i++)); do
        if test_connection; then
            connected=true
            break
        fi

        if [[ $i -lt $retries ]]; then
            warn "Connection failed. Retrying in 2 seconds... ($i/$retries)"
            sleep 2
        fi
    done

    if ! $connected; then
        echo ""
        error "Could not connect to $HOST:$PORT

Possible solutions:
  1. Make sure the DeviceKit iOS app is running with broadcast started
  2. For real devices, use --setup-iproxy flag or run 'iproxy $PORT:$PORT' manually
  3. Check that port $PORT is not blocked by firewall
  4. For Wi-Fi connection, use --host <DEVICE_IP>

Example:
  ./screencapture.sh --setup-iproxy
"
    fi

    # Start streaming or recording
    if [[ -n "$RECORD_FILE" ]]; then
        record_stream "$RECORD_FILE"
    else
        stream_ffplay
    fi
}

# Run main
main "$@"
