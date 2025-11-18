#!/usr/bin/env bash
set -euo pipefail

echo "===== postbuild_upload.sh START ====="
echo "PWD          : $(pwd)"
echo "BUILD_PATH   : ${BUILD_PATH:-'(not set)'}"

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

# --- Transporter の場所を確認（まず xcrun を使う） ---
if ! command -v xcrun >/dev/null 2>&1; then
  echo "[ERROR] xcrun not found. Cannot run iTMSTransporter."
  exit 1
fi

ITMS=$(xcrun -f iTMSTransporter 2>/dev/null || true)
if [[ -z "$ITMS" || ! -x "$ITMS" ]]; then
  echo "[WARN] xcrun -f で iTMSTransporter の実行パスが取れませんでした。"
  echo "[WARN] fallback パスを順番にチェックします。"
  for CAND in \
    "/usr/local/itms/bin/iTMSTransporter" \
    "/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"
  do
    if [[ -x "$CAND" ]]; then
      ITMS="$CAND"
      break
    fi
  done
fi

if [[ -z "$ITMS" ]]; then
  echo "[ERROR] iTMSTransporter not found in any known location."
  exit 1
fi
echo "Using iTMSTransporter: $ITMS"

# --- 一時キー作成＆後始末 ---
KEY_FILE="$(mktemp /tmp/asc_key_XXXXXX.p8)"
cleanup() {
  echo "Cleaning up key file: $KEY_FILE"
  rm -f "$KEY_FILE"
}
trap cleanup EXIT

echo "Decoding ASC_KEY_CONTENT_BASE64 to temporary key file..."
# decode に失敗した場合もメッセージを出す
if ! echo "$ASC_KEY_CONTENT_BASE64" | base64 --decode > "$KEY_FILE" 2>/tmp/asc_key_decode.log; then
  echo "[ERROR] Failed to base64-decode ASC_KEY_CONTENT_BASE64."
  echo "decode log:"
  cat /tmp/asc_key_decode.log
  exit 1
fi
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

# --- アップロード ---
echo "Starting upload via iTMSTransporter..."
# ログを抑えめに、オプションも最小限に（問題なければ後で増やせる）
if ! "$ITMS" -m upload \
  -assetFile "$IPA_PATH" \
  -apiKey "$ASC_KEY_ID" \
  -apiIssuer "$ASC_ISSUER_ID"; then
  echo "[ERROR] iTMSTransporter upload failed."
  exit 1
fi

echo "== Upload submitted. Check App Store Connect → TestFlight =="
echo "===== postbuild_upload.sh END ====="
