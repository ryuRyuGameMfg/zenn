#!/bin/bash
# telegram-react.sh - Telegramリアクティブ実行エンジン
# Usage: bash telegram-react.sh "ユーザーメッセージ"
# zenn-engineのOpenClaw設計を踏襲

set -u  # エラーで失敗せずログして続行

WORK_DIR="$HOME/repository/zenn-engine"
TELEGRAM_CONF="$WORK_DIR/.telegram.conf"
NOTIFY_SCRIPT="$WORK_DIR/scripts/telegram-notify.sh"
CONV_FILE="$WORK_DIR/.telegram-conversation.json"
STATE_FILE="$WORK_DIR/state.json"
SOUL_FILE="$WORK_DIR/SOUL.md"
STRATEGY_FILE="$WORK_DIR/STRATEGY.md"
MEMORY_FILE="$WORK_DIR/MEMORY.md"
AGENT_FILE="$WORK_DIR/AGENT.md"
ARTICLES_DIR="$WORK_DIR/articles"
PROMPT_FILE="$WORK_DIR/prompts/telegram-react.md"
LOG_DIR="$WORK_DIR/logs"
LOG_FILE="$LOG_DIR/telegram-react.log"

# ログディレクトリ準備
mkdir -p "$LOG_DIR" 2>/dev/null || true

# claude フルパス解決
CLAUDE_PATH="$(which claude 2>/dev/null || echo '/Users/okamotoryuya/.local/bin/claude')"
if [[ ! -x "$CLAUDE_PATH" ]]; then
  CLAUDE_PATH="/Users/okamotoryuya/.local/bin/claude"
fi

# timeout コマンド解決（macOS launchd環境対応）
TIMEOUT_CMD="$(which gtimeout 2>/dev/null || which timeout 2>/dev/null || echo '/opt/homebrew/bin/gtimeout')"

USER_MESSAGE="${1:-}"
if [[ -z "$USER_MESSAGE" ]]; then
  exit 0
fi

# ---- 会話状態読み込み ----
get_conv() {
  jq -r ".$1 // empty" "$CONV_FILE" 2>/dev/null || echo ""
}
update_conv() {
  local key="$1" value="$2"
  local tmp; tmp=$(mktemp)
  jq ".$key = $value" "$CONV_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$CONV_FILE" || rm -f "$tmp"
}
update_conv_str() {
  local key="$1" value="$2"
  local tmp; tmp=$(mktemp)
  jq ".$key = \"$value\"" "$CONV_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$CONV_FILE" || rm -f "$tmp"
}

# ---- 会話スレッドにメッセージ追加 ----
append_thread() {
  local role="$1" text="$2"
  local tmp; tmp=$(mktemp)
  local ts; ts=$(date '+%Y-%m-%d %H:%M')
  jq ".thread += [{\"role\": \"$role\", \"text\": $(echo "$text" | jq -Rs .), \"ts\": \"$ts\"}]" "$CONV_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$CONV_FILE" || rm -f "$tmp"
}

# ---- 対象記事候補を特定（zenn-engine用） ----
find_article_candidate() {
  # 1. CONV_FILE の target_article
  local target; target=$(get_conv "target_article")
  if [[ -n "$target" && -f "$target" ]]; then
    echo "$target"
    return
  fi
  # 2. state.json の current_article.slug からパス構築
  local slug; slug=$(jq -r '.current_article.slug // empty' "$STATE_FILE" 2>/dev/null || echo "")
  if [[ -n "$slug" ]]; then
    local candidate="$ARTICLES_DIR/${slug}/article.md"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  fi
  # 3. articles/ 内で最も新しく更新された article.md または .md ファイル
  local found; found=$(find "$ARTICLES_DIR" -name "article.md" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then
    echo "$found"
    return
  fi
  # 4. フラット構造の場合は最新 .md ファイル
  find "$ARTICLES_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | xargs ls -t 2>/dev/null | head -1
}

# ---- コンテキスト構築（OpenClaw準拠）----
build_context() {
  local ctx=""
  [[ -f "$SOUL_FILE" ]]     && ctx="${ctx}# SOUL\n$(cat "$SOUL_FILE")\n---\n"
  [[ -f "$STRATEGY_FILE" ]] && ctx="${ctx}# STRATEGY\n$(cat "$STRATEGY_FILE")\n---\n"
  [[ -f "$MEMORY_FILE" ]]   && ctx="${ctx}# MEMORY\n$(cat "$MEMORY_FILE")\n---\n"
  [[ -f "$AGENT_FILE" ]]    && ctx="${ctx}# AGENT\n$(cat "$AGENT_FILE")\n---\n"
  echo -e "$ctx"
}

# ---- スレッド文字列生成 ----
build_thread_str() {
  jq -r '.thread[-10:] | map("[\(.role)] \(.text)") | join("\n")' "$CONV_FILE" 2>/dev/null || echo "(会話履歴なし)"
}

# ---- メイン ----

# 1. ユーザーメッセージをスレッドに追加
append_thread "user" "$USER_MESSAGE"
update_conv_str "last_updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
update_conv_str "status" "processing"

# 2. 記事候補特定
ARTICLE_CANDIDATE=$(find_article_candidate)
if [[ -z "$ARTICLE_CANDIDATE" ]]; then
  ARTICLE_CANDIDATE="(特定できませんでした。ユーザーに確認してください)"
fi

# 3. プロンプト構築
CONTEXT=$(build_context)
THREAD_STR=$(build_thread_str)
PROMPT_TEMPLATE=$(cat "$PROMPT_FILE" 2>/dev/null || echo "{{USER_MESSAGE}}")

PROMPT="${CONTEXT}
---
# リアクティブアシスタント指示

${PROMPT_TEMPLATE}"

# プレースホルダー置換
PROMPT="${PROMPT/\{\{USER_MESSAGE\}\}/$USER_MESSAGE}"
PROMPT="${PROMPT/\{\{THREAD\}\}/$THREAD_STR}"
PROMPT="${PROMPT/\{\{ARTICLE_CANDIDATE\}\}/$ARTICLE_CANDIDATE}"

# 4. Claude実行
CLAUDE_OUTPUT=""
EXEC_START=$(date '+%Y-%m-%dT%H:%M:%S')
echo "[${EXEC_START}] START: claude execution" >> "$LOG_FILE"

CLAUDE_OUTPUT=$(\
  echo "$PROMPT" | \
  "$TIMEOUT_CMD" 300 "$CLAUDE_PATH" -p \
  --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
  2>>"$LOG_FILE" \
) || CLAUDE_RESULT=$?

if [[ -z "$CLAUDE_OUTPUT" ]]; then
  EXEC_END=$(date '+%Y-%m-%dT%H:%M:%S')
  echo "[${EXEC_END}] ERROR: claude returned empty output (exit code: ${CLAUDE_RESULT:-unknown})" >> "$LOG_FILE"
  CLAUDE_OUTPUT="TELEGRAM_REPLY_START
処理中にエラーが発生しました（タイムアウト or claude実行エラー）。もう一度お試しください。
TELEGRAM_REPLY_END"
else
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] OK: claude execution completed" >> "$LOG_FILE"
fi

# 5. TELEGRAM_REPLY抽出
TELEGRAM_REPLY=$(echo "$CLAUDE_OUTPUT" | \
  awk '/TELEGRAM_REPLY_START/{found=1; next} /TELEGRAM_REPLY_END/{found=0} found{print}' | \
  head -500)

if [[ -z "$TELEGRAM_REPLY" ]]; then
  # マーカーがない場合は最後の数行を返信に使う
  TELEGRAM_REPLY=$(echo "$CLAUDE_OUTPUT" | tail -5)
fi

# 6. Telegramに返信
bash "$NOTIFY_SCRIPT" "$TELEGRAM_REPLY" 2>>"$LOG_FILE" || echo "[$(date '+%Y-%m-%dT%H:%M:%S')] WARN: telegram-notify.sh failed" >> "$LOG_FILE"

# 7. アシスタント返信をスレッドに追加
append_thread "assistant" "$TELEGRAM_REPLY" || echo "[$(date '+%Y-%m-%dT%H:%M:%S')] WARN: append_thread failed" >> "$LOG_FILE"
update_conv_str "status" "idle"

# 8. target_article更新（記事パスが有効なら記録）
if [[ -n "$ARTICLE_CANDIDATE" && -f "$ARTICLE_CANDIDATE" ]]; then
  update_conv_str "target_article" "$ARTICLE_CANDIDATE"
fi

echo "[$(date '+%Y-%m-%dT%H:%M:%S')] END: telegram-react.sh completed" >> "$LOG_FILE"
exit 0
