#!/bin/bash
# Build libwg-go.a for the current Xcode platform target.
# Called from the PacketTunnel target's "Build libwg-go" Run Script build phase.
#
# Behavior:
#   - iOS device (iphoneos): runs upstream Makefile → arm64 static lib
#   - iOS Simulator: skips build; WireGuardKit code is stubbed out via
#                    #if !targetEnvironment(simulator) so the symbols are
#                    never referenced on simulator anyway
#   - Any other platform: skips build
#
# Requires: Go installed (brew install go)

set -euo pipefail

WG_GO_DIR="${SRCROOT}/wireguard-apple/Sources/WireGuardKitGo"

if [ ! -d "${WG_GO_DIR}" ]; then
    echo "warning: wireguard-apple not found at ${WG_GO_DIR} — skipping libwg-go build"
    exit 0
fi

if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
    echo "note: platform ${PLATFORM_NAME:-unknown} — skipping libwg-go build (simulator uses stubbed code path)"
    exit 0
fi

if ! command -v go > /dev/null 2>&1; then
    echo "error: Go toolchain missing. Install with: brew install go"
    exit 1
fi

cd "${WG_GO_DIR}"

echo "Building libwg-go.a for ${PLATFORM_NAME} ${ARCHS}…"
make PLATFORM_NAME="${PLATFORM_NAME}" ARCHS="${ARCHS}"

# SPM's Package.swift links -lwg-go from the WireGuardKitGo source dir.
cp out/libwg-go.a libwg-go.a
echo "libwg-go.a ready at ${WG_GO_DIR}/libwg-go.a"
