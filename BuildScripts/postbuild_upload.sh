#!/usr/bin/env bash
set -euo pipefail

# --- 必須環境変数チェック（設定漏れ早期発見） ---
: "${ASC_KEY_ID:?ASC_KEY_ID is required}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required}"
: "${ASC_KEY_CONTENT_BASE64:?ASC_KEY_CONTENT_BASE64 is required}"

# --- Transporter の場所を自動検出（環境差異対策） ---
ITMS=""
for CAND in \
  "/usr/local/itms/bin/iTMSTransporter" \
  "/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter" \
  "$(xcrun -f iTMSTransporter 2>/dev/null || true)"
do
  [[ -x "$CAND" ]] && ITMS="$CAND" && break
done
if [[ -z "$ITMS" ]]; then
  echo "iTMSTransporter not found"; exit 1
fi
echo "Using iTMSTransporter: $ITMS"

# --- 一時キー作成＆後始末 ---
KEY_FILE="$(mktemp /tmp/asc_key_XXXXXX.p8)"
cleanup(){ rm -f "$KEY_FILE"; }
trap cleanup EXIT
echo "$ASC_KEY_CONTENT_BASE64" | base64 --decode > "$KEY_FILE"

# --- IPA パス探索（最初の1つを採用） ---
#   UCBの出力は BUILD_PATH 配下に置かれる想定
IPA_PATH="$(find "${BUILD_PATH:-.}" -type f -name '*.ipa' | head -n1 || true)"
if [[ -z "${IPA_PATH:-}" ]]; then
  echo "IPA not found under ${BUILD_PATH:-.}"
  exit 1
fi
echo "IPA: $IPA_PATH"

# --- アップロード ---
#   -v eXtreme は冗長ログ（必要なければ外してOK）
#   -k はアップロード同時接続（環境によって未対応なら外す）
"$ITMS" -m upload \
  -assetFile "$IPA_PATH" \
  -apiKey "$ASC_KEY_ID" \
  -apiIssuer "$ASC_ISSUER_ID" \
  -v eXtreme \
  -k 1000000

echo "== Upload submitted. Check App Store Connect → TestFlight =="
