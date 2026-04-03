#!/bin/bash
export WORK_DIR="$HOME/repository/zenn-engine"
export SYSTEM_PROMPT_FILE="$WORK_DIR/prompts/telegram-react.md"
exec "$HOME/.claude/scripts/telegram-react-core.sh" "$@"
