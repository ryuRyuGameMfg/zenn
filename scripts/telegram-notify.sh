#!/bin/bash
# telegram-notify.sh - zenn-engine Telegram通知（ラッパー）
# 共通ロジック: ~/.claude/scripts/telegram-notify-core.sh

WORK_DIR="${WORK_DIR:-$HOME/repository/zenn-engine}"
CONF_FILE="$WORK_DIR/telegram/.telegram.conf"
LOG_DIR="$WORK_DIR/logs/$(date '+%Y-%m-%d')"
LOG_FILE="$LOG_DIR/zenn-engine.log"

mkdir -p "$LOG_DIR"

exec ~/.claude/scripts/telegram-notify-core.sh \
  "$CONF_FILE" "$LOG_FILE" "${1:-}" "${2:-}"
