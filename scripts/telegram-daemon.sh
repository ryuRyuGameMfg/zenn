#!/bin/bash
# telegram-daemon.sh - zenn-engine Telegram デーモン（ラッパー）
# 共通ロジック: ~/.claude/scripts/telegram-daemon-core.sh

WORK_DIR="$HOME/repository/zenn-engine"
mkdir -p "$WORK_DIR/logs"

exec ~/.claude/scripts/telegram-daemon-core.sh \
  "$WORK_DIR/.telegram.conf" \
  "$WORK_DIR/scripts/telegram-react.sh" \
  "$WORK_DIR/scripts/telegram-notify.sh" \
  "$WORK_DIR/.telegram-offset" \
  "$WORK_DIR/.telegram-daemon.pid" \
  "$WORK_DIR/logs/telegram-daemon.log" \
  "$WORK_DIR/input.md"
