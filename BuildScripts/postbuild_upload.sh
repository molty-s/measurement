#!/usr/bin/env bash
set -euxo pipefail

echo "=== postbuild_upload.sh START ==="
echo "PWD: $(pwd)"
echo "BUILD_PATH: ${BUILD_PATH:-<not set>}"

echo "=== ENV (ASC_*) ==="
env | grep '^ASC_' || echo 'no ASC_* env found'

# ここでわざと失敗させる
echo "=== FORCE FAIL in postbuild_upload.sh ==="
exit 1
