#!/bin/bash
# telegram-daily-report.sh - 日次進捗レポート
# Usage: bash telegram-daily-report.sh [--progress "進捗メッセージ"]

WORK_DIR="$HOME/repository/zenn-engine"
source "$WORK_DIR/.telegram.conf" 2>/dev/null || exit 0

STATE_FILE="$WORK_DIR/data/state.json"
NOTIFY_SCRIPT="$WORK_DIR/scripts/telegram-notify.sh"

html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  echo "$s"
}

# 進捗通知モード
if [[ "${1:-}" == "--progress" ]]; then
  PROGRESS_MSG=$(html_escape "${2:-}")
  MSG="<b>進捗報告</b>

${PROGRESS_MSG}"
  bash "$NOTIFY_SCRIPT" --html "$MSG"
  exit 0
fi

# state.json から情報取得
MODE=$(jq -r '.mode // ""' "$STATE_FILE" 2>/dev/null || echo "")
ITER=$(jq -r '.iteration // "?"' "$STATE_FILE" 2>/dev/null || echo "?")
STATUS=$(jq -r '.status // ""' "$STATE_FILE" 2>/dev/null || echo "")
LAST_ARTICLE_RAW=$(jq -r '.history[-1].title // "なし"' "$STATE_FILE" 2>/dev/null || echo "なし")
LAST_ARTICLE=$(html_escape "$LAST_ARTICLE_RAW")

DATE=$(date '+%-m月%-d日')

# MODEを自然文に変換
case "${MODE}" in
  "create")   MODE_JP="新規記事作成";;
  "analyze")  MODE_JP="分析";;
  "improve")  MODE_JP="改善";;
  "rewrite")  MODE_JP="リライト";;
  *)          MODE_JP="${MODE}";;
esac

# STATUSで3パターン分岐
case "${STATUS}" in
  "running"|"active")
    MSG="<b>${DATE}の報告</b>

現在、記事の${MODE_JP}を進めています。
これまでに${ITER}サイクルを完了しました。

<blockquote>直近の記事: ${LAST_ARTICLE}</blockquote>

引き続き作業を進めます。"
    ;;
  "error")
    MSG="<b>${DATE}の報告</b>

エラーが発生しており、対応が必要な状態です。
これまでに${ITER}サイクルを完了しています。

<blockquote>直近の記事: ${LAST_ARTICLE}</blockquote>

確認をお願いします。"
    ;;
  *)
    MSG="<b>${DATE}の報告</b>

次のサイクルの開始を待機しています。
これまでに${ITER}サイクルを完了しました。

<blockquote>直近の記事: ${LAST_ARTICLE}</blockquote>

何かあればいつでもご連絡ください。"
    ;;
esac

bash "$NOTIFY_SCRIPT" --html "$MSG"
exit 0
