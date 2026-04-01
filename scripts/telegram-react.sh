#!/bin/bash
# telegram-react.sh - Telegramリアクティブ実行エンジン
# Usage: bash telegram-react.sh "ユーザーメッセージ"
# zenn-engineのOpenClaw設計を踏襲

set -u  # エラーで失敗せずログして続行

WORK_DIR="$HOME/repository/zenn-engine"
TELEGRAM_CONF="$WORK_DIR/telegram/.telegram.conf"
NOTIFY_SCRIPT="$WORK_DIR/scripts/telegram-notify.sh"
CONV_FILE="$WORK_DIR/telegram/.telegram-conversation.json"
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
  local summary
  summary=$(jq -r '.summary // ""' "$CONV_FILE" 2>/dev/null || echo "")
  local recent
  recent=$(jq -r '.thread[-10:] | map("[\(.role)] \(.text)") | join("\n")' "$CONV_FILE" 2>/dev/null || echo "(会話履歴なし)")
  if [[ -n "$summary" ]]; then
    printf '=== 過去の会話まとめ ===\n%s\n=== 直近10件 ===\n%s' "$summary" "$recent"
  else
    echo "$recent"
  fi
}

# ---- メイン ----

# ---- コールバック（ボタン押下）処理 ----
if [[ "$USER_MESSAGE" =~ ^\[CALLBACK:(.+):([0-9]+)\]$ ]]; then
  CB_DATA="${BASH_REMATCH[1]}"
  CB_MSG_ID="${BASH_REMATCH[2]}"

  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] CALLBACK: data=${CB_DATA}, msg_id=${CB_MSG_ID}" >> "$LOG_FILE"

  case "$CB_DATA" in
    approve|approve:*)
      if [[ "$USE_DYNAMIC" == "true" ]]; then
        tg_remove_buttons "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$CB_MSG_ID" 2>/dev/null || true
      fi
      USER_MESSAGE="承認します。計画通り進めてください。"
      append_thread "user" "[ボタン] 承認"
      update_conv_str "last_updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
      ;;
    revise|revise:*)
      if [[ "$USE_DYNAMIC" == "true" ]]; then
        tg_remove_buttons "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$CB_MSG_ID" 2>/dev/null || true
      fi
      USER_MESSAGE="計画を見直してください。別のアプローチを提案してください。"
      append_thread "user" "[ボタン] 計画見直し"
      update_conv_str "last_updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
      ;;
    detail|detail:*)
      if [[ "$USE_DYNAMIC" == "true" ]]; then
        tg_remove_buttons "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$CB_MSG_ID" 2>/dev/null || true
      fi
      USER_MESSAGE="もう少し詳しく説明してください。"
      append_thread "user" "[ボタン] 詳細希望"
      update_conv_str "last_updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
      ;;
    *)
      USER_MESSAGE="ボタン操作: ${CB_DATA}"
      append_thread "user" "[ボタン] ${CB_DATA}"
      update_conv_str "last_updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
      ;;
  esac
fi

# 1. ユーザーメッセージをスレッドに追加
append_thread "user" "$USER_MESSAGE"
update_conv_str "last_updated" "$(date '+%Y-%m-%dT%H:%M:%S')"
update_conv_str "status" "processing"

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
  append_thread "assistant" "$LIST_REPLY" || true
  update_conv_str "status" "idle"
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
  append_thread "assistant" "$REPLY_MSG" || true
  update_conv_str "status" "idle"
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

# 共通ランナーで実行（監視・サイレント経過通知・エラー検知）
CLAUDE_TMP=$(mktemp /tmp/zenn-engine-claude-output.XXXXXX)
PROGRESS_MSG_ID=""
if [[ "$USE_DYNAMIC" == "true" ]]; then
  PROGRESS_MSG_ID=$(tg_send_message "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "思考中..." 2>/dev/null || echo "")
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] DYNAMIC: progress_msg_id=${PROGRESS_MSG_ID}" >> "$LOG_FILE"
fi
export CLAUDE_PATH BOT_NAME="zenn-engine GM" LOG_FILE NOTIFY_SCRIPT ALLOWED_TOOLS="Read,Write,Edit,Glob,Grep,Bash"
export PROGRESS_MSG_ID TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
echo "$PROMPT" | bash ~/.claude/scripts/telegram-claude-runner.sh "$CLAUDE_TMP"
RUNNER_EXIT=$?
CLAUDE_OUTPUT=$(cat "$CLAUDE_TMP" 2>/dev/null || echo "")
rm -f "$CLAUDE_TMP"

if [[ $RUNNER_EXIT -ne 0 ]]; then
  update_conv_str "status" "idle"
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
  HAS_PLAN=false
  if echo "$TELEGRAM_REPLY" | grep -qiE '計画|提案|方針|プラン|アプローチ|設計|実装予定|進め方'; then
    HAS_PLAN=true
  fi

  if [[ "$HAS_PLAN" == "true" ]]; then
    BUTTONS='[[{"text":"承認する","callback_data":"approve"},{"text":"計画見直し","callback_data":"revise"}],[{"text":"詳しく聞く","callback_data":"detail"}]]'
    tg_edit_message_with_buttons "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$PROGRESS_MSG_ID" "$TELEGRAM_REPLY" "$BUTTONS" 2>/dev/null || {
      bash "$NOTIFY_SCRIPT" "$TELEGRAM_REPLY" 2>>"$LOG_FILE" || true
    }
  else
    tg_edit_message "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$PROGRESS_MSG_ID" "$TELEGRAM_REPLY" 2>/dev/null || {
      bash "$NOTIFY_SCRIPT" "$TELEGRAM_REPLY" 2>>"$LOG_FILE" || true
    }
  fi
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

# 7. アシスタント返信をスレッドに追加
append_thread "assistant" "$TELEGRAM_REPLY" || echo "[$(date '+%Y-%m-%dT%H:%M:%S')] WARN: append_thread failed" >> "$LOG_FILE"
update_conv_str "status" "idle"

# 8. target_article更新（記事パスが有効なら記録）
if [[ -n "$ARTICLE_CANDIDATE" && -f "$ARTICLE_CANDIDATE" ]]; then
  update_conv_str "target_article" "$ARTICLE_CANDIDATE"
fi

# 9. スレッドが25件超えたらサマリー生成・トリム
THREAD_LEN=$(jq '.thread | length' "$CONV_FILE" 2>/dev/null || echo "0")
if [[ "$THREAD_LEN" -gt 15 ]]; then
  log_sum() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [SUMMARY] $1" >> "$LOG_FILE"; }
  log_sum "スレッド${THREAD_LEN}件 → サマリー生成開始"
  OLD_MESSAGES=$(jq -r '.thread[:-10] | map("[\(.role)] \(.text)") | join("\n")' "$CONV_FILE" 2>/dev/null || echo "")
  EXISTING_SUMMARY=$(jq -r '.summary // ""' "$CONV_FILE" 2>/dev/null || echo "")
  # 共通サマリープロンプト読み込み
  SUMMARY_TEMPLATE_FILE="$HOME/.claude/scripts/prompts/thread-summary.md"
  if [[ -f "$SUMMARY_TEMPLATE_FILE" ]]; then
    SUMMARY_PROMPT=$(cat "$SUMMARY_TEMPLATE_FILE")
    SUMMARY_PROMPT="${SUMMARY_PROMPT//\{\{EXISTING_SUMMARY\}\}/$EXISTING_SUMMARY}"
    SUMMARY_PROMPT="${SUMMARY_PROMPT//\{\{OLD_MESSAGES\}\}/$OLD_MESSAGES}"
  else
    # フォールバック: ファイルがない場合はインラインで
    SUMMARY_PROMPT="以下の会話履歴を簡潔にまとめてください。

既存のまとめ:
${EXISTING_SUMMARY}

新しい会話履歴:
${OLD_MESSAGES}"
  fi
  NEW_SUMMARY=$(echo "$SUMMARY_PROMPT" | "$CLAUDE_PATH" -p 2>>"$LOG_FILE" || echo "")
  if [[ -n "$NEW_SUMMARY" ]]; then
    TMP_CONV=$(mktemp)
    jq --arg s "$NEW_SUMMARY" '.summary = $s | .thread = .thread[-10:]' "$CONV_FILE" > "$TMP_CONV" 2>/dev/null && mv "$TMP_CONV" "$CONV_FILE" || rm -f "$TMP_CONV"
    log_sum "サマリー更新完了。thread を10件にトリム"
  fi
fi

echo "[$(date '+%Y-%m-%dT%H:%M:%S')] END: telegram-react.sh completed" >> "$LOG_FILE"
exit 0
