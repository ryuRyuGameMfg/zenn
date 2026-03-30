#!/bin/bash
# telegram-notify.sh - Telegram通知送信スクリプト
# Usage: bash telegram-notify.sh "メッセージ本文"
# zenn-engineの処理を止めないよう常にexit 0で終わる

WORK_DIR="${WORK_DIR:-$HOME/repository/zenn-engine}"
TELEGRAM_CONF="$WORK_DIR/.telegram.conf"
LOG_DIR="$WORK_DIR/logs"

if [[ ! -f "$TELEGRAM_CONF" ]]; then
  exit 0
fi

source "$TELEGRAM_CONF"

MESSAGE="${1:-}"
if [[ -z "$MESSAGE" ]]; then
  exit 0
fi

# サイレント送信（通知バッジ・音なし）: bash notify.sh "msg" "silent"
SILENT="${2:-}"
DISABLE_NOTIF=""
[[ "$SILENT" == "silent" ]] && DISABLE_NOTIF="-d disable_notification=true"

RESPONSE=$(curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "parse_mode=HTML" \
  ${DISABLE_NOTIF} \
  --data-urlencode "text=${MESSAGE}" 2>/dev/null) || true

OK=$(echo "$RESPONSE" | grep -o '"ok":true' 2>/dev/null || echo "")
if [[ -z "$OK" ]]; then
  DAILY_LOG_DIR="$LOG_DIR/$(date '+%Y-%m-%d')"
  mkdir -p "$DAILY_LOG_DIR" 2>/dev/null || true
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [WARN] Telegram送信失敗: $RESPONSE" >> "$DAILY_LOG_DIR/zenn-engine.log" 2>/dev/null || true
fi

exit 0
