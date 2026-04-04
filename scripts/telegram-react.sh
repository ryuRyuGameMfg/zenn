#!/bin/bash
# telegram-react.sh - zenn-engine Telegram 応答（ラッパー）
# CONFIG_SH経由でtelegram-react-runner.shに委譲

export CONFIG_SH="${CONFIG_SH:-$HOME/.claude/bots/zenn-engine/config.sh}"
exec bash "$HOME/.claude/bots/lib/telegram-react-runner.sh" "$@"
