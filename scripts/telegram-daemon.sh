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

  # アップデート処理（テキスト・音声の両方を抽出）
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
    voice = msg.get('voice', {})
    if text:
        messages.append({'type': 'text', 'content': text})
    elif voice:
        file_id = voice.get('file_id', '')
        if file_id:
            messages.append({'type': 'voice', 'file_id': file_id})
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
  MSG_COUNT=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('messages',[])))" 2>/dev/null || echo "0")

  # offset 更新
  if [[ -n "$NEW_OFFSET" && "$NEW_OFFSET" =~ ^[0-9]+$ ]]; then
    echo "$NEW_OFFSET" > "$OFFSET_FILE"
    NEXT_OFFSET=$((NEW_OFFSET + 1))
  fi

  # メッセージがある場合は処理（最後の1件）
  if [[ "$MSG_COUNT" -gt "0" ]]; then
    MSG_TYPE=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['messages'][-1].get('type',''))" 2>/dev/null || echo "")

    if [[ "$MSG_TYPE" == "text" ]]; then
      LAST_MESSAGE=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['messages'][-1].get('content',''))" 2>/dev/null || echo "")
      if [[ -n "$LAST_MESSAGE" ]]; then
        TIMESTAMP=$(date '+%H:%M')
        EXISTING=""
        if [[ -f "$INPUT_FILE" ]]; then
          EXISTING=$(cat "$INPUT_FILE" 2>/dev/null || echo "")
        fi
        printf '[%s] %s\n%s' "$TIMESTAMP" "$LAST_MESSAGE" "$EXISTING" > "$INPUT_FILE"
        log "Text message: ${LAST_MESSAGE:0:80}"
        log "Launching telegram-react.sh"
        bash "$WORK_DIR/scripts/telegram-notify.sh" "思考中..." || true
        /bin/bash "$WORK_DIR/scripts/telegram-react.sh" "$LAST_MESSAGE" &
      fi

    elif [[ "$MSG_TYPE" == "voice" ]]; then
      FILE_ID=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['messages'][-1].get('file_id',''))" 2>/dev/null || echo "")
      if [[ -n "$FILE_ID" ]]; then
        log "Voice message: file_id=${FILE_ID:0:30}..."
        bash "$WORK_DIR/scripts/telegram-notify.sh" "音声を文字起こし中..." || true
        bash "$HOME/.claude/scripts/telegram-voice.sh" \
          "$FILE_ID" \
          "$TELEGRAM_CONF" \
          "$WORK_DIR/scripts/telegram-notify.sh" \
          "$WORK_DIR/scripts/telegram-react.sh" \
          "$INPUT_FILE" &
      fi
    fi
  fi

  # long polling なのでエラー時以外はsleepしない
done
