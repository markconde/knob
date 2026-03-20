#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WHISPER_DIR="$REPO_ROOT/vendor/whisper.cpp"
BUILD_DIR="$WHISPER_DIR/build"
INSTALL_DIR="$BUILD_DIR/install"

# Skip rebuild if libwhisper.a is newer than CMakeLists.txt
if [ -f "$INSTALL_DIR/lib/libwhisper.a" ] && \
   [ "$INSTALL_DIR/lib/libwhisper.a" -nt "$WHISPER_DIR/CMakeLists.txt" ]; then
    echo "whisper.cpp already up to date, skipping build."
    exit 0
fi

echo "Building whisper.cpp..."

cmake -S "$WHISPER_DIR" -B "$BUILD_DIR" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DWHISPER_COREML=OFF \
    -DBUILD_SHARED_LIBS=OFF

cmake --build "$BUILD_DIR" --config Release -- -j$(sysctl -n hw.logicalcpu)
cmake --install "$BUILD_DIR" --config Release

echo "whisper.cpp built and installed to $INSTALL_DIR"
