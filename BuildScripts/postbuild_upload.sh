#!/usr/bin/env bash
set -euo pipefail

echo "===== postbuild_upload.sh START ====="
echo "PWD        : $(pwd)"
echo "BUILD_PATH : ${BUILD_PATH:-'(not set)'}"

# --- 必須環境変数チェック（値は出さずに有無だけログ） ---
if [[ -z "${ASC_KEY_ID:-}" ]]; then
  echo "[ERROR] ASC_KEY_ID is empty"; exit 1
fi
if [[ -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "[ERROR] ASC_ISSUER_ID is empty"; exit 1
fi
if [[ -z "${ASC_KEY_CONTENT_BASE64:-}" ]]; then
  echo "[ERROR] ASC_KEY_CONTENT_BASE64 is empty"; exit 1
fi
echo "Env OK: ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_CONTENT_BASE64 are set."

# --- xcrun / altool の存在チェック ---
if ! command -v xcrun >/dev/null 2>&1; then
  echo "[ERROR] xcrun not found. Cannot run altool."
  exit 1
fi

if ! xcrun --find altool >/dev/null 2>&1; then
  echo "[ERROR] xcrun altool not found. Xcode command line tools may be missing."
  exit 1
fi
echo "Using altool at: $(xcrun --find altool)"

# --- App Store Connect API キーを ~/.appstoreconnect/private_keys に配置 ---
KEYS_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEYS_DIR"

KEY_FILE="$KEYS_DIR/AuthKey_${ASC_KEY_ID}.p8"
echo "Writing API key to: $KEY_FILE"

# decode に失敗した場合も原因ログを出す
if ! echo "$ASC_KEY_CONTENT_BASE64" | base64 --decode > "$KEY_FILE" 2>/tmp/asc_key_decode.log; then
  echo "[ERROR] Failed to base64-decode ASC_KEY_CONTENT_BASE64."
  echo "decode log:"
  cat /tmp/asc_key_decode.log
  exit 1
fi
chmod 600 "$KEY_FILE"
echo "Key file prepared."

# --- IPA パス探索（候補を全部ログに出す） ---
SEARCH_ROOT="${BUILD_PATH:-.}"
echo "Searching IPA under: $SEARCH_ROOT"
echo "IPA candidates:"
find "$SEARCH_ROOT" -maxdepth 6 -type f -name '*.ipa' -print || true

IPA_PATH="$(find "$SEARCH_ROOT" -maxdepth 6 -type f -name '*.ipa' | head -n1 || true)"

if [[ -z "${IPA_PATH:-}" ]]; then
  echo "[ERROR] IPA not found under $SEARCH_ROOT"
  exit 1
fi
echo "Using IPA: $IPA_PATH"

# --- altool でアップロード ---
echo "Starting upload via xcrun altool..."

# 出力を少し詳しく見たいので XML 形式で
if ! xcrun altool \
  --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --output-format xml; then
  echo "[ERROR] altool upload failed."
  echo "Check the XML above for detailed error from App Store Connect."
  exit 1
fi

echo "== Upload submitted. Check App Store Connect → TestFlight =="
echo "===== postbuild_upload.sh END ====="
