#!/bin/bash
# telegram-daily-report.sh - zenn-engine 日次進捗レポート
# Usage: bash telegram-daily-report.sh [--progress "進捗メッセージ"]

WORK_DIR="$HOME/repository/zenn-engine"
source "$WORK_DIR/.telegram.conf" 2>/dev/null || exit 0

STATE_FILE="$WORK_DIR/state.json"
NOTIFY_SCRIPT="$WORK_DIR/scripts/telegram-notify.sh"

# 進捗通知モード
if [[ "${1:-}" == "--progress" ]]; then
  MSG="<b>zenn-engine</b> 進捗

${2:-}"
  bash "$NOTIFY_SCRIPT" "$MSG"
  exit 0
fi

# state.json から情報取得
MODE=$(jq -r '.mode // "?"' "$STATE_FILE" 2>/dev/null || echo "?")
ITER=$(jq -r '.iteration // "?"' "$STATE_FILE" 2>/dev/null || echo "?")
STATUS=$(jq -r '.status // "?"' "$STATE_FILE" 2>/dev/null || echo "?")
LAST_RUN=$(jq -r '.last_run // "?"' "$STATE_FILE" 2>/dev/null | cut -c1-10 || echo "?")
LAST_ARTICLE=$(jq -r '.history[-1].title // "なし"' "$STATE_FILE" 2>/dev/null || echo "なし")
LAST_ARTICLE_DATE=$(jq -r '.history[-1].date // ""' "$STATE_FILE" 2>/dev/null || echo "")

DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M')

# STATUSをPM言語に変換
case "${STATUS}" in
  "idle"|"waiting")    STATUS_JP="次のサイクルの開始を待機中";;
  "running"|"active")  STATUS_JP="現在サイクル実行中";;
  "error")             STATUS_JP="エラーが発生しています（要確認）";;
  *)                   STATUS_JP="${STATUS}";;
esac

MSG="Zenn担当PMです。${DATE} ${TIME}の定期報告です。

【現在の状況】
${STATUS_JP}です。これまでに合計${ITER}サイクルを完了しました。

【直近の成果】
直近で扱った記事: ${LAST_ARTICLE}

【次のアクション】
次サイクルで新たな記事の作成または既存記事の改善を予定しています。

特別な連絡事項があればいつでもメッセージください。"

bash "$NOTIFY_SCRIPT" "$MSG"
exit 0
