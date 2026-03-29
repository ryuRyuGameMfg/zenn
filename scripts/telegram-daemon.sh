#!/bin/bash
# telegram-daemon.sh - 常駐型Telegramポーリングデーモン
# long polling (timeout=25) でほぼリアルタイムにメッセージ検知

WORK_DIR="$HOME/repository/zenn-engine"
TELEGRAM_CONF="$WORK_DIR/.telegram.conf"
OFFSET_FILE="$WORK_DIR/.telegram-offset"
INPUT_FILE="$WORK_DIR/input.md"
PID_FILE="$WORK_DIR/.telegram-daemon.pid"
LOG_DIR="$WORK_DIR/logs"

mkdir -p "$LOG_DIR"

log() {
  local DATE_STR
  DATE_STR=$(date '+%Y-%m-%d')
  local LOG_FILE="$LOG_DIR/telegram-daemon.log"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $1" >> "$LOG_FILE"
}

# PIDファイル書き込み
echo $$ > "$PID_FILE"

# graceful shutdown
cleanup() {
  log "SIGTERM/SIGINT received. Shutting down."
  rm -f "$PID_FILE"
  exit 0
}
trap cleanup SIGTERM SIGINT

# .telegram.conf 読み込み
if [[ ! -f "$TELEGRAM_CONF" ]]; then
  log "ERROR: $TELEGRAM_CONF not found. Exiting."
  rm -f "$PID_FILE"
  exit 1
fi

source "$TELEGRAM_CONF" 2>/dev/null
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  log "ERROR: TELEGRAM_BOT_TOKEN not set. Exiting."
  rm -f "$PID_FILE"
  exit 1
fi

# 初期 offset 読み込み
NEXT_OFFSET=0
if [[ -f "$OFFSET_FILE" ]]; then
  STORED=$(cat "$OFFSET_FILE" 2>/dev/null || echo "0")
  if [[ "$STORED" =~ ^[0-9]+$ ]]; then
    NEXT_OFFSET=$((STORED + 1))
  fi
fi

log "Daemon started. PID=$$, NEXT_OFFSET=${NEXT_OFFSET}"

while true; do
  RESPONSE=$(curl -s --max-time 30 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" \
    -d "offset=${NEXT_OFFSET}" \
    -d "timeout=25" 2>/dev/null)

  if [[ -z "$RESPONSE" ]]; then
    log "WARN: Empty response from Telegram API. Retrying in 5s."
    sleep 5
    continue
  fi

  # ok フィールド確認
  OK=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('true' if data.get('ok') else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

  if [[ "$OK" != "true" ]]; then
    log "WARN: Telegram API returned ok=false. Retrying in 5s. Response prefix: ${RESPONSE:0:100}"
    sleep 5
    continue
  fi

  # アップデート処理
  RESULT=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
new_offset = None
messages = []
for update in results:
    update_id = update.get('update_id', 0)
    if new_offset is None or update_id > new_offset:
        new_offset = update_id
    msg = update.get('message', {})
    text = msg.get('text', '')
    if text:
        messages.append(text)
output = {'new_offset': new_offset, 'messages': messages}
print(json.dumps(output, ensure_ascii=False))
" 2>/dev/null
  )

  if [[ -z "$RESULT" ]]; then
    # パース失敗 → 継続
    sleep 1
    continue
  fi

  NEW_OFFSET=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('new_offset',''))" 2>/dev/null || echo "")
  MESSAGES_JSON=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(m) for m in d.get('messages',[])]" 2>/dev/null || echo "")

  # offset 更新
  if [[ -n "$NEW_OFFSET" && "$NEW_OFFSET" =~ ^[0-9]+$ ]]; then
    echo "$NEW_OFFSET" > "$OFFSET_FILE"
    NEXT_OFFSET=$((NEW_OFFSET + 1))
  fi

  # メッセージがある場合は処理
  if [[ -n "$MESSAGES_JSON" ]]; then
    # input.md への追記
    TIMESTAMP=$(date '+%H:%M')
    LINES_TO_PREPEND=""
    while IFS= read -r MSG_LINE; do
      if [[ -n "$MSG_LINE" ]]; then
        log "Message received: ${MSG_LINE:0:80}"
        LINES_TO_PREPEND="${LINES_TO_PREPEND}[${TIMESTAMP}] ${MSG_LINE}"$'\n'
      fi
    done <<< "$MESSAGES_JSON"

    if [[ -n "$LINES_TO_PREPEND" ]]; then
      EXISTING=""
      if [[ -f "$INPUT_FILE" ]]; then
        EXISTING=$(cat "$INPUT_FILE" 2>/dev/null || echo "")
      fi
      printf '%s%s' "$LINES_TO_PREPEND" "$EXISTING" > "$INPUT_FILE"
    fi

    # 最後のメッセージを telegram-react.sh に渡す
    REACT_SCRIPT="$WORK_DIR/scripts/telegram-react.sh"
    if [[ -f "$REACT_SCRIPT" ]]; then
      LAST_MESSAGE=$(echo "$MESSAGES_JSON" | tail -1)
      if [[ -n "$LAST_MESSAGE" ]]; then
        log "Launching telegram-react.sh"
        /bin/bash "$REACT_SCRIPT" "$LAST_MESSAGE" &
      fi
    fi
  fi

  # long polling なのでエラー時以外はsleepしない
done
