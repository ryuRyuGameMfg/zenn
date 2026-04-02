#!/bin/bash
# telegram-react.sh - Telegramリアクティブ実行エンジン
# Usage: bash telegram-react.sh "ユーザーメッセージ"
# zenn-engineのOpenClaw設計を踏襲

set -u  # エラーで失敗せずログして続行

WORK_DIR="$HOME/repository/zenn-engine"
TELEGRAM_CONF="$WORK_DIR/telegram/.telegram.conf"
NOTIFY_SCRIPT="$WORK_DIR/scripts/telegram-notify.sh"
STATE_FILE="$WORK_DIR/data/state.json"
SOUL_FILE="$WORK_DIR/SOUL.md"
STRATEGY_FILE="$WORK_DIR/STRATEGY.md"
MEMORY_FILE="$WORK_DIR/MEMORY.md"
AGENT_FILE="$WORK_DIR/AGENT.md"
ARTICLES_DIR="$WORK_DIR/articles"
PROMPT_FILE="$WORK_DIR/prompts/telegram-react.md"
LOG_DIR="$WORK_DIR/logs"
LOG_FILE="$LOG_DIR/telegram-react.log"

# 動的メッセージ用ライブラリ
INTERACTIVE_CORE="$HOME/.claude/scripts/telegram-interactive-core.sh"
if [[ -f "$INTERACTIVE_CORE" ]]; then
  source "$INTERACTIVE_CORE"
  source "$TELEGRAM_CONF" 2>/dev/null
  USE_DYNAMIC=true
else
  USE_DYNAMIC=false
fi

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

# ---- リマインダー検知（共通基盤） ----
REMINDER_PARSE_CORE="$HOME/.claude/scripts/reminder-parse-core.sh"
REMINDERS_FILE="$WORK_DIR/reminders.json"

is_reminder_command() {
  local msg="$1"
  echo "$msg" | grep -qiE 'リマインド|リマインダー|remind'
}

is_reminder_list_command() {
  local msg="$1"
  echo "$msg" | grep -qiE 'リマインダー一覧|リマインド一覧|予定一覧|リマインダー確認|リマインド確認'
}

# ---- 対象記事候補を特定（zenn-engine用） ----
find_article_candidate() {
  # 1. state.json の current_article.slug からパス構築
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

# ---- メイン ----

# リマインダー一覧表示
if is_reminder_list_command "$USER_MESSAGE"; then
  LIST_REPLY=$(python3 << PYEOF
import json, os
from datetime import datetime

f = "$REMINDERS_FILE"
if not os.path.exists(f):
    print("リマインダーはありません。")
else:
    with open(f) as fp:
        data = json.load(fp)
    active = [r for r in data.get("reminders", []) if r.get("status") == "active"]
    if not active:
        print("リマインダーはありません。")
    else:
        dow = ['月','火','水','木','金','土','日']
        lines = [f"リマインダー一覧（{len(active)}件）\n"]
        lines.append("<b>登録済みリマインダー</b>\n")
        for i, r in enumerate(sorted(active, key=lambda x: x.get("datetime", "")), 1):
            try:
                t = datetime.fromisoformat(r["datetime"])
                d = f"{t.month}/{t.day}({dow[t.weekday()]}) {t.hour:02d}:{t.minute:02d}"
            except:
                d = r.get("datetime", "不明")
            lines.append(f"<code>{i}.</code> {r.get('message','')}")
            lines.append(f"   <code>{d}</code>\n")
        print("\n".join(lines))
PYEOF
  )
  bash "$NOTIFY_SCRIPT" "$LIST_REPLY" 2>>"$LOG_FILE" || true
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] END: reminder list" >> "$LOG_FILE"
  exit 0
fi

# リマインダー登録
if is_reminder_command "$USER_MESSAGE"; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] REMINDER: detected reminder command" >> "$LOG_FILE"
  PARSE_RESULT=$(bash "$REMINDER_PARSE_CORE" "$USER_MESSAGE" "$TELEGRAM_CONF" "$LOG_FILE" "$REMINDERS_FILE" 2>>"$LOG_FILE")
  PARSE_EXIT=$?

  if [[ $PARSE_EXIT -eq 0 ]] && echo "$PARSE_RESULT" | grep -q "^REMINDER_SET|"; then
    IFS='|' read -r _ DISP_DATE DISP_MSG DISP_ID <<< "$PARSE_RESULT"
    REPLY_MSG="リマインダー登録完了

<b>${DISP_MSG}</b>

<blockquote>${DISP_DATE} に
お知らせします。</blockquote>

ID: <code>${DISP_ID}</code>"
  else
    REPLY_MSG="リマインダー登録エラー

<blockquote>${PARSE_RESULT}</blockquote>

例:
<code>来週月曜10時に
ミーティング準備リマインド</code>

<code>明日15時に
クライアントに連絡リマインド</code>"
  fi

  bash "$NOTIFY_SCRIPT" "$REPLY_MSG" 2>>"$LOG_FILE" || true
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] END: reminder processing" >> "$LOG_FILE"
  exit 0
fi

# 2. 記事候補特定
ARTICLE_CANDIDATE=$(find_article_candidate)
if [[ -z "$ARTICLE_CANDIDATE" ]]; then
  ARTICLE_CANDIDATE="(特定できませんでした。ユーザーに確認してください)"
fi

# 3. プロンプト構築
CONTEXT=$(build_context)

PROMPT="${CONTEXT}
---
## 対象記事
${ARTICLE_CANDIDATE}
---
## ユーザーメッセージ
${USER_MESSAGE}"

# 4. Claude実行
CLAUDE_OUTPUT=""
EXEC_START=$(date '+%Y-%m-%dT%H:%M:%S')
echo "[${EXEC_START}] START: claude execution" >> "$LOG_FILE"

# 共通ランナーで実行（監視・サイレント経過通知・エラー検知）
CLAUDE_TMP=$(mktemp /tmp/zenn-engine-claude-output.XXXXXX)
PROGRESS_MSG_ID=""
if [[ "$USE_DYNAMIC" == "true" ]]; then
  PROGRESS_MSG_ID=$(tg_send_message "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "思考中..." 2>/dev/null || echo "")
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] DYNAMIC: progress_msg_id=${PROGRESS_MSG_ID}" >> "$LOG_FILE"
fi
export WORK_DIR
export CLAUDE_PATH BOT_NAME="zenn-engine GM" LOG_FILE NOTIFY_SCRIPT
export ALLOWED_TOOLS="Read,Write,Edit,Glob,Grep,Bash"
export MAX_BUDGET="3.00"
export SESSION_ID_FILE="$WORK_DIR/telegram/.telegram-session-id"
export SYSTEM_PROMPT_FILE="$WORK_DIR/prompts/telegram-react.md"
export PROGRESS_MSG_ID TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
echo "$PROMPT" | bash ~/.claude/scripts/telegram-claude-runner.sh "$CLAUDE_TMP"
RUNNER_EXIT=$?
CLAUDE_OUTPUT=$(cat "$CLAUDE_TMP" 2>/dev/null || echo "")
rm -f "$CLAUDE_TMP"

if [[ $RUNNER_EXIT -ne 0 ]]; then
  exit 0
fi

echo "[$(date '+%Y-%m-%dT%H:%M:%S')] OK: claude execution completed" >> "$LOG_FILE"

# 5. TELEGRAM_REPLY抽出
TELEGRAM_REPLY=$(echo "$CLAUDE_OUTPUT" | \
  awk '/TELEGRAM_REPLY_START/{found=1; next} /TELEGRAM_REPLY_END/{found=0} found{print}' | \
  head -500)

if [[ -z "$TELEGRAM_REPLY" ]]; then
  # マーカーがない場合は最後の数行を返信に使う
  TELEGRAM_REPLY=$(echo "$CLAUDE_OUTPUT" | tail -5)
fi

# 6. Telegramに返信
if [[ "$USE_DYNAMIC" == "true" && -n "$PROGRESS_MSG_ID" ]]; then
  tg_edit_message "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$PROGRESS_MSG_ID" "$TELEGRAM_REPLY" 2>/dev/null || {
    bash "$NOTIFY_SCRIPT" "$TELEGRAM_REPLY" 2>>"$LOG_FILE" || true
  }
else
  bash "$NOTIFY_SCRIPT" "$TELEGRAM_REPLY" 2>>"$LOG_FILE" || echo "[$(date '+%Y-%m-%dT%H:%M:%S')] WARN: telegram-notify.sh failed" >> "$LOG_FILE"
fi

# AI応答をhot/に記録
HOT_DIR="$WORK_DIR/memory/hot"
HOT_FILE="$HOT_DIR/$(date '+%Y-%m-%d').md"
mkdir -p "$HOT_DIR"
if [[ ! -f "$HOT_FILE" ]]; then
  printf '# Daily Log - %s\n\n' "$(date '+%Y-%m-%d')" > "$HOT_FILE"
fi
PLAIN_REPLY=$(echo "$TELEGRAM_REPLY" | sed 's/<[^>]*>//g')
printf '[%s] [ai] %s\n' "$(date '+%H:%M')" "$PLAIN_REPLY" >> "$HOT_FILE"

echo "[$(date '+%Y-%m-%dT%H:%M:%S')] END: telegram-react.sh completed" >> "$LOG_FILE"
exit 0
