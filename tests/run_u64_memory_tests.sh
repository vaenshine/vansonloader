#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun clang++ -std=c++17 -fblocks -g -O1 \
  -fsanitize=address,undefined -fno-sanitize-recover=all \
  "$ROOT/tests/U64MemoryScanTests.cpp" "$ROOT/src/Core/VLMemCore.cpp" \
  -o "$TEST_DIR/u64-memory-tests"
"$TEST_DIR/u64-memory-tests" "$TEST_DIR"
