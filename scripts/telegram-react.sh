#!/bin/bash
export WORK_DIR="$HOME/repository/zenn-engine"
export SYSTEM_PROMPT_FILE="$HOME/.claude/prompts/telegram/system.md"
exec "$HOME/.claude/scripts/telegram-react-core.sh" "$@"
