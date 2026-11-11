#!/usr/bin/env bash
# llama.cpp を iOS 用の xcframework にして Vendor/llama.xcframework に置く（ひび手帳と同じ版）。
# Usage: scripts/build-llama.sh [ios-device | ios-sim | "ios-device ios-sim"]
#   CI は ios-device だけ。Xcode のシミュレータでも動かしたいときは "ios-device ios-sim"。
set -euo pipefail
REF="${LLAMA_CPP_REF:-v0.9.0}"
BUILDS="${1:-ios-device}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${RUNNER_TEMP:-$(mktemp -d)}/llama.cpp"
rm -rf "$WORK"
git clone -q --depth 1 --branch "$REF" https://github.com/ggml-org/llama.cpp "$WORK"
cd "$WORK"
# shellcheck disable=SC2086
./build-xcframework.sh $BUILDS
mkdir -p "$ROOT/Vendor"
rm -rf "$ROOT/Vendor/llama.xcframework"
cp -R build-apple/llama.xcframework "$ROOT/Vendor/"
echo "Vendor/llama.xcframework ($REF, $BUILDS)"
