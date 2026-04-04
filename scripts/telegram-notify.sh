#!/bin/bash
# telegram-notify.sh - zenn-engine Telegram通知（ラッパー）
# 共通ロジック: ~/.claude/bots/lib/telegram-send.sh

CONF_FILE="$HOME/.claude/bots/zenn-engine/config.sh"
LOG_FILE="$HOME/repository/zenn-engine/telegram/runtime/daemon.log"
MESSAGE="${1:-}"
SILENT="${2:-}"

exec bash "$HOME/.claude/bots/lib/telegram-send.sh" "$CONF_FILE" "$LOG_FILE" "$MESSAGE" "$SILENT"
