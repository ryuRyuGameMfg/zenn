#!/bin/bash
# zenn-engine.sh - Zenn 自律コンテンツエンジン
# Usage: ./zenn-engine.sh [--dry-run]
# Architecture: Patrol -> Steering -> Executor -> Reviewer -> Transition
# Mode Cycle: create -> analyze -> improve -> rewrite -> create (loop)

# NOTE: -e は意図的に省略。エラーはコマンド単位で明示的に処理する。
set -uo pipefail

# ---------------------------------------------------------------------------
# 定数・設定
# ---------------------------------------------------------------------------
WORK_DIR="$HOME/repository/zenn-engine"
STATE_FILE="$WORK_DIR/state.json"
LOG_DIR="$WORK_DIR/logs"
PROMPT_DIR="$WORK_DIR/prompts"
INPUT_FILE="$WORK_DIR/input.md"

# Workspace files (OpenClaw-inspired)
SOUL_FILE="$WORK_DIR/SOUL.md"
STRATEGY_FILE="$WORK_DIR/STRATEGY.md"
MEMORY_FILE="$WORK_DIR/MEMORY.md"
HEARTBEAT_FILE="$WORK_DIR/HEARTBEAT.md"
AGENT_FILE="$WORK_DIR/AGENT.md"
MEMORY_DIR="$WORK_DIR/memory"
DAILY_DIR="$MEMORY_DIR/daily"

COOLDOWN_SECONDS=86400       # 24時間（モード完了後のクールダウン）
ERROR_RETRY_SECONDS=1800     # 30分（エラー後リトライ待機）
CYCLE_INTERVAL_SECONDS=86400 # 24時間（全モード完了後のクールダウン）
MAX_MODES=4                  # create / analyze / improve / rewrite
MODE_TIMEOUT=3600            # 60分（claude -p 呼び出しタイムアウト）
MAX_CONSECUTIVE_ERRORS=3

ALLOWED_TOOLS="Read,Write,Edit,Bash,Glob,Grep,WebSearch,WebFetch,Agent,Task"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# Global steering state variables
CURRENT_CHECK=""
CURRENT_PLAN=""

# ---------------------------------------------------------------------------
# タイムアウトコマンド検出 (macOS対応)
# ---------------------------------------------------------------------------
TIMEOUT_CMD="timeout"
if ! command -v timeout &>/dev/null; then
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  else
    TIMEOUT_CMD=""  # タイムアウト機能なし
  fi
fi

# ---------------------------------------------------------------------------
# シグナルハンドラ
# ---------------------------------------------------------------------------
SHUTDOWN=false

cleanup() {
  log "INFO" "シャットダウンシグナルを受信しました。安全に停止します..."
  SHUTDOWN=true
  update_state_status "idle" || true
}

trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# ユーティリティ
# ---------------------------------------------------------------------------
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%dT%H:%M:%S')
  local line="[$timestamp] [$level] $message"
  echo "$line"
  local daily_log_dir="$LOG_DIR/$(date '+%Y-%m-%d')"
  mkdir -p "$daily_log_dir" 2>/dev/null || true
  local daily_log="$daily_log_dir/zenn-engine.log"
  if [[ -f "$daily_log" ]]; then
    local tmp
    tmp=$(mktemp)
    { echo "$line"; cat "$daily_log"; } > "$tmp" && mv "$tmp" "$daily_log"
  else
    echo "$line" > "$daily_log"
  fi
}

log_section() {
  local title="$1"
  local content="$2"
  local daily_log_dir="$LOG_DIR/$(date '+%Y-%m-%d')"
  mkdir -p "$daily_log_dir" 2>/dev/null || true
  local daily_log="$daily_log_dir/zenn-engine.log"
  local section="━━━ ${title} Start ━━━
${content}
━━━ ${title} End ━━━"
  if [[ -f "$daily_log" ]]; then
    local tmp
    tmp=$(mktemp)
    { echo "$section"; cat "$daily_log"; } > "$tmp" && mv "$tmp" "$daily_log"
  else
    echo "$section" > "$daily_log"
  fi
}

get_state() {
  local key="$1"
  jq -r ".$key // empty" "$STATE_FILE" 2>/dev/null || echo ""
}

update_state() {
  local key="$1"
  local value="$2"
  local tmp
  tmp=$(mktemp)
  if jq ".$key = $value" "$STATE_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"
    log "WARN" "state.json更新失敗: $key = $value"
  fi
}

update_state_str() {
  local key="$1"
  local value="$2"
  local tmp
  tmp=$(mktemp)
  if jq ".$key = \"$value\"" "$STATE_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$STATE_FILE"
  else
    rm -f "$tmp"
    log "WARN" "state.json更新失敗: $key = $value"
  fi
}

update_state_status() {
  update_state_str "status" "$1"
}

update_last_run() {
  update_state_str "last_run" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}

mode_name() {
  case "$1" in
    1) echo "create" ;;
    2) echo "analyze" ;;
    3) echo "improve" ;;
    4) echo "rewrite" ;;
    *) echo "unknown" ;;
  esac
}

mode_to_number() {
  case "$1" in
    "create")  echo "1" ;;
    "analyze") echo "2" ;;
    "improve") echo "3" ;;
    "rewrite") echo "4" ;;
    *)         echo "1" ;;
  esac
}

next_mode() {
  case "$1" in
    "create")  echo "analyze" ;;
    "analyze") echo "improve" ;;
    "improve") echo "rewrite" ;;
    "rewrite") echo "create" ;;
    *)         echo "create" ;;
  esac
}

# ---------------------------------------------------------------------------
# git commit + push
# ---------------------------------------------------------------------------
git_commit_and_push() {
  local mode="$1"
  local iteration="$2"
  cd "$WORK_DIR" || return 1

  # articles/ への変更があるか確認
  git add -A
  local changed_files
  changed_files=$(git diff --cached --name-only 2>/dev/null) || changed_files=""

  if [[ -z "$changed_files" ]]; then
    log "INFO" "変更なし、コミットをスキップ"
    return 0
  fi

  local current_article_slug
  current_article_slug=$(get_state "current_article.slug") || current_article_slug=""
  local slug_suffix=""
  if [[ -n "$current_article_slug" ]]; then
    slug_suffix=" $current_article_slug"
  fi

  local msg="zenn: iter$(printf '%02d' "$iteration")_${mode}${slug_suffix}"
  if ! git commit -m "$msg" 2>/dev/null; then
    log "WARN" "コミット失敗"
    return 1
  fi

  if ! git push origin main 2>/dev/null && ! git push origin master 2>/dev/null; then
    log "WARN" "プッシュ失敗（リモート未設定?）"
  fi
  log "INFO" "自動コミット+プッシュ完了: $msg"
  return 0
}

# ---------------------------------------------------------------------------
# build_context: ワークスペースファイルからコンテキストを構築
# ---------------------------------------------------------------------------
build_context() {
  local context=""

  # Tier 0: SOUL (immutable principles)
  if [[ -f "$SOUL_FILE" ]]; then
    context="# SOUL (不変原則 - 変更禁止)
$(cat "$SOUL_FILE")

---
"
  fi

  # STRATEGY
  if [[ -f "$STRATEGY_FILE" ]]; then
    context="${context}# STRATEGY (記事戦略)
$(cat "$STRATEGY_FILE")

---
"
  fi

  # Tier 1: MEMORY (always loaded ~100 lines)
  if [[ -f "$MEMORY_FILE" ]]; then
    context="${context}# MEMORY (常時コンテキスト)
$(cat "$MEMORY_FILE")

---
"
  fi

  # Tier 2: Daily memory (today + yesterday)
  local today yesterday
  today=$(date '+%Y-%m-%d')
  yesterday=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null || echo "")

  if [[ -f "$DAILY_DIR/$today.md" ]]; then
    context="${context}# Daily Memory (今日: $today)
$(cat "$DAILY_DIR/$today.md")

---
"
  fi

  if [[ -n "$yesterday" && -f "$DAILY_DIR/$yesterday.md" ]]; then
    context="${context}# Daily Memory (昨日: $yesterday)
$(cat "$DAILY_DIR/$yesterday.md")

---
"
  fi

  # AGENT (behavior rules)
  if [[ -f "$AGENT_FILE" ]]; then
    context="${context}# AGENT (行動アルゴリズム)
$(cat "$AGENT_FILE")

---
"
  fi

  echo "$context"
}

# ---------------------------------------------------------------------------
# Patrol: 健全性監視
# ---------------------------------------------------------------------------
patrol() {
  log "INFO" "Patrol: HEARTBEAT.md チェック開始"

  # 1. HEARTBEAT.md 読み込み確認
  if [[ -f "$HEARTBEAT_FILE" ]]; then
    log "INFO" "Patrol: HEARTBEAT.md 読み込み完了"
  fi

  # 2. state.json validity
  if ! jq . "$STATE_FILE" > /dev/null 2>&1; then
    log "ERROR" "state.jsonが不正です"
    return 1
  fi

  # 3. Stuck detection
  local current_status
  current_status=$(get_state "status")
  if [[ -n "$current_status" && "$current_status" != "idle" ]]; then
    log "WARN" "Patrol: 前回の実行が status=$current_status で停止。リセットします"
    update_state_status "idle"
  fi

  # 4. Git check
  cd "$WORK_DIR" || true
  local git_uncommitted=0
  git_uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') || git_uncommitted=0
  if [[ "$git_uncommitted" -gt 50 ]]; then
    log "WARN" "Patrol: 未コミットファイルが ${git_uncommitted} 件"
  fi

  # 5. MEMORY.md size check
  if [[ -f "$MEMORY_FILE" ]]; then
    local mem_lines
    mem_lines=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
    if [[ "$mem_lines" -gt 120 ]]; then
      log "WARN" "Patrol: MEMORY.md が ${mem_lines} 行（100行目標を超過）"
    fi
  fi

  # 6. Log size
  local log_size=0
  log_size=$(du -sm "$LOG_DIR" 2>/dev/null | cut -f1) || log_size=0

  log "INFO" "Patrol: チェック完了 (uncommitted=$git_uncommitted, log=${log_size}MB)"
  return 0
}

# ---------------------------------------------------------------------------
# Housekeeping: 定期メンテナンス（create モードのみ実行）
# ---------------------------------------------------------------------------
housekeeping() {
  local mode="$1"
  local iteration="$2"

  if [[ "$mode" != "create" ]]; then
    return 0
  fi

  log "INFO" "Housekeeping: 定期メンテナンス開始"

  # 1. 古いログ日付フォルダを削除 (7日以上)
  local cutoff_date=""
  cutoff_date=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || echo "")

  if [[ -n "$cutoff_date" ]]; then
    local deleted=0
    for log_date_dir in "$LOG_DIR"/????-??-??; do
      [[ ! -d "$log_date_dir" ]] && continue
      local dir_date
      dir_date=$(basename "$log_date_dir")
      if [[ "$dir_date" < "$cutoff_date" ]]; then
        rm -rf "$log_date_dir"
        deleted=$((deleted + 1))
      fi
    done
    if [[ "$deleted" -gt 0 ]]; then
      log "INFO" "Housekeeping: ${deleted}日分の古いログを削除"
    fi

    # 古い daily memory を削除 (7日以上)
    for daily_file in "$DAILY_DIR"/????-??-??.md; do
      [[ ! -f "$daily_file" ]] && continue
      local file_date
      file_date=$(basename "$daily_file" .md)
      if [[ "$file_date" < "$cutoff_date" ]]; then
        rm -f "$daily_file"
        log "INFO" "Housekeeping: 古い日次メモリ削除: $file_date"
      fi
    done
  fi

  # 2. 空のログ日付フォルダを削除
  for log_date_dir in "$LOG_DIR"/????-??-??; do
    [[ ! -d "$log_date_dir" ]] && continue
    if [[ -z "$(ls -A "$log_date_dir" 2>/dev/null)" ]]; then
      rmdir "$log_date_dir" 2>/dev/null || true
    fi
  done

  log "INFO" "Housekeeping: 完了"
  return 0
}

# ---------------------------------------------------------------------------
# Steering: Check -> Plan
# ---------------------------------------------------------------------------

# 初期化: input.md を読み込み、グローバル変数を準備
steering_init() {
  mkdir -p "$DAILY_DIR" "$MEMORY_DIR/long-term"

  PREV_INPUT=""
  [[ -f "$INPUT_FILE" ]] && PREV_INPUT=$(cat "$INPUT_FILE") || true

  STEERING_TIMESTAMP=$(date '+%Y-%m-%d_%H%M')
  log "INFO" "Steering初期化完了 (timestamp=$STEERING_TIMESTAMP)"
}

# Check: 現状分析結果を CURRENT_CHECK 変数に格納
steering_check() {
  local mode="$1"
  local iteration="$2"

  log "INFO" "Check開始: 現状分析..."

  local context
  context=$(build_context)

  local check_prompt="${context}
あなたは Zenn コンテンツエンジンの現状チェック担当です。
SOUL.md の原則と STRATEGY.md の OKR を意識して分析してください。

CRITICAL: 絶対に Write/Edit/Bash ツールを使わないこと。マークダウンテキストをそのまま標準出力に出力するだけでよい。

- 現在のMode: ${mode}
- 現在のIteration: ${iteration}
- 作業ディレクトリ: ${WORK_DIR}

## やること
1. state.json を読んで現在の状態を確認
2. STRATEGY.md の OKR 進捗を確認
3. memory/long-term/topics.md のキュー残数を確認
4. 以下の形式で出力:

# Check - Mode:${mode} Iter${iteration}
日時: $(date '+%Y-%m-%d %H:%M')

## STRATEGY OKR進捗
## 現在の状態
## テーマキュー残数
## 前回の成果
## 問題点・課題
## 次にやるべきこと

重要: 上記フォーマットのマークダウンだけを出力すること。"

  if [[ "$DRY_RUN" == "true" ]]; then
    CURRENT_CHECK="[DRY-RUN] Check - Mode:${mode} Iter${iteration}"
  else
    CURRENT_CHECK=$(echo "$check_prompt" | claude -p --allowedTools "Read,Glob,Grep" 2>/dev/null) || CURRENT_CHECK=""
  fi

  if [[ -z "$CURRENT_CHECK" ]]; then
    log "WARN" "Check結果が空。フォールバック"
    CURRENT_CHECK="# Check - Mode:${mode} Iter${iteration} (自動生成失敗)
日時: $(date '+%Y-%m-%d %H:%M')
自動チェックが失敗しました。"
  fi

  log_section "Check Iter${iteration} Mode:${mode}" "$CURRENT_CHECK"
  log "INFO" "Check完了"
}

# Plan: check 結果 + input.md を元に計画を立てて CURRENT_PLAN 変数に格納
steering_make_plan() {
  local mode="$1"
  local iteration="$2"

  log "INFO" "Plan策定開始..."

  local context
  context=$(build_context)

  local input_content=""
  if [[ -n "$PREV_INPUT" && "$PREV_INPUT" != *"<!-- 全ての指示が完了した"* && "$PREV_INPUT" != *"<!-- 新しい指示を"* ]]; then
    input_content="$PREV_INPUT"
  fi

  local plan_prompt="${context}
あなたは Zenn コンテンツエンジンの計画担当です。
SOUL.md の原則を遵守し、STRATEGY.md の OKR 達成に向けた計画を立ててください。

CRITICAL: 絶対に Write/Edit/Bash ツールを使わないこと。

- 現在のMode: ${mode}
- 現在のIteration: ${iteration}

## Check結果
${CURRENT_CHECK}

## ユーザーからの方針指示 (input.md)
$(if [[ -n "$input_content" ]]; then echo "$input_content"; else echo "なし（STRATEGY.md の方針を継続）"; fi)

## 出力フォーマット

# Plan - Mode:${mode} Iter${iteration}
日時: $(date '+%Y-%m-%d %H:%M')

## STRATEGY OKR との整合
## 目標
## 実行内容
1. ...
2. ...
## ユーザー指示への対応
## リスク・注意点"

  if [[ "$DRY_RUN" == "true" ]]; then
    CURRENT_PLAN="[DRY-RUN] Plan - Mode:${mode} Iter${iteration}"
  else
    CURRENT_PLAN=$(echo "$plan_prompt" | claude -p --allowedTools "Read,Glob,Grep" 2>/dev/null) || CURRENT_PLAN=""
  fi

  if [[ -z "$CURRENT_PLAN" ]]; then
    log "WARN" "Plan生成失敗。フォールバック"
    CURRENT_PLAN="# Plan - Mode:${mode} Iter${iteration} (fallback)
Mode ${mode} のデフォルト処理を実行"
  fi

  log_section "Plan Iter${iteration} Mode:${mode}" "$CURRENT_PLAN"
  log "INFO" "Plan策定完了"
}

# ---------------------------------------------------------------------------
# Executor: モード実行（タイムアウト付き）
# ---------------------------------------------------------------------------
executor() {
  local mode="$1"
  local iteration="$2"

  log "INFO" "Executor: Mode $mode 開始 (iter=$iteration)"
  update_state_status "executing"

  local prompt_file="$PROMPT_DIR/mode-${mode}.md"
  if [[ ! -f "$prompt_file" ]]; then
    log "ERROR" "プロンプトファイルが見つかりません: $prompt_file"
    return 1
  fi

  # ワークスペースコンテキスト + プラン + モードプロンプトを結合
  local context
  context=$(build_context)

  local prompt
  prompt=$(cat "$prompt_file")
  prompt=$(echo "$prompt" | sed "s/{{ITERATION}}/$iteration/g")

  # プランを注入
  if [[ -n "$CURRENT_PLAN" ]]; then
    prompt="$prompt

---
# 今回の実行計画
$CURRENT_PLAN"
  fi

  # ワークスペースコンテキストを先頭に付加
  prompt="${context}
---
${prompt}"

  # モード完了時の必須作業を追記
  local is_last_mode="false"
  if [[ "$mode" == "rewrite" ]]; then
    is_last_mode="true"
  fi

  prompt="${prompt}

---
# モード完了時の必須作業
1. memory/daily/$(date '+%Y-%m-%d').md に今回のモードの観察・成果・課題を追記すること
2. state.json の status を更新すること
$(if [[ "$is_last_mode" == "true" ]]; then
echo "3. rewrite モード完了: MEMORY.md の昇格/降格を検討し、100行以下を維持すること"
echo "4. rewrite モード完了: HEARTBEAT.md のチェック項目を見直し、必要なら更新すること"
fi)"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "INFO" "[DRY-RUN] Mode $mode をシミュレート"
    log_section "Mode $mode Iter$iteration" "[DRY-RUN] Mode $mode prompt sent to claude -p"
    sleep 2
    log "INFO" "Executor: Mode $mode 完了 (DRY-RUN)"
    return 0
  fi

  # タイムアウト付きで実行
  local mode_output=""
  local exit_code=0
  if [[ -n "$TIMEOUT_CMD" ]]; then
    mode_output=$("$TIMEOUT_CMD" "$MODE_TIMEOUT" bash -c 'echo "$1" | claude -p --allowedTools "$2"' _ "$prompt" "$ALLOWED_TOOLS" 2>&1) || exit_code=$?
  else
    log "WARN" "Executor: タイムアウトコマンドなし"
    mode_output=$(echo "$prompt" | claude -p --allowedTools "$ALLOWED_TOOLS" 2>&1) || exit_code=$?
  fi

  if [[ -n "$mode_output" ]]; then
    log_section "Mode $mode Iter$iteration" "$mode_output"
  fi

  if [[ $exit_code -ne 0 ]]; then
    if [[ $exit_code -eq 124 ]]; then
      log "ERROR" "Executor: Mode $mode タイムアウト (${MODE_TIMEOUT}秒)"
    else
      log "ERROR" "Executor: Mode $mode エラー (exit=$exit_code)"
    fi
    return 1
  fi

  log "INFO" "Executor: Mode $mode 完了"
  return 0
}

# ---------------------------------------------------------------------------
# Reviewer: 成果確認・コミット
# ---------------------------------------------------------------------------
reviewer() {
  local mode="$1"
  local iteration="$2"

  log "INFO" "Reviewer: Mode $mode 成果確認"
  update_state_status "reviewing"

  git_commit_and_push "$mode" "$iteration" || true
  CONSECUTIVE_ERRORS=0

  log "INFO" "Reviewer: 完了"
  return 0
}

# ---------------------------------------------------------------------------
# Input Lifecycle: input.md の指示対応状況を追跡・クリア（rewrite モードのみ）
# ---------------------------------------------------------------------------
input_lifecycle() {
  local mode="$1"
  local iteration="$2"

  if [[ "$mode" != "rewrite" ]]; then
    return 0
  fi

  log "INFO" "InputLifecycle: rewrite モード - 振り返りと自己改善"

  # input.md のアクティブな指示を確認
  if [[ -f "$INPUT_FILE" ]] && grep -q "^[0-9]" "$INPUT_FILE" 2>/dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "INFO" "[DRY-RUN] InputLifecycle: 評価スキップ"
    else
      local eval_prompt
      eval_prompt="$(build_context)
あなたは Zenn コンテンツエンジンのインプット管理担当です。

以下のユーザー指示(input.md)の各項目が対応されているかを評価してください。
作業ディレクトリ: ${WORK_DIR}

## ユーザー指示
$(cat "$INPUT_FILE")

## 出力フォーマット
CRITICAL: Write/Edit/Bash ツールを使わないこと。

# Input Status - Iter${iteration}

| # | 指示内容 | 状態 | 備考 |
|---|---------|------|------|

## 全指示完了判定
(全てdoneなら「YES - input.mdをクリア可能」、そうでなければ「NO - 残タスクあり」)"

      local status_content=""
      if [[ -n "$TIMEOUT_CMD" ]]; then
        status_content=$("$TIMEOUT_CMD" 300 bash -c 'echo "$1" | claude -p --allowedTools "Read,Glob,Grep"' _ "$eval_prompt" 2>/dev/null) || true
      else
        status_content=$(echo "$eval_prompt" | claude -p --allowedTools "Read,Glob,Grep" 2>/dev/null) || true
      fi

      if [[ -n "$status_content" ]] && echo "$status_content" | grep -q "YES.*クリア可能" 2>/dev/null; then
        log "INFO" "InputLifecycle: 全指示完了。input.md をクリア"
        cat > "$INPUT_FILE" <<'CLEAR_EOF'
# User Input - 方針指示

<!-- 全ての指示が完了したため、自動クリアされました -->
<!-- 新しい指示を記入してください -->

CLEAR_EOF
      fi
    fi
  else
    log "INFO" "InputLifecycle: アクティブな指示なし"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Transition: 次モードへ遷移
# Returns: 0 = フルイテレーション完了 (rewrite→create), 1 = まだモードが残る
# ---------------------------------------------------------------------------
transition() {
  local mode="$1"
  local iteration="$2"

  local next
  next=$(next_mode "$mode")

  if [[ "$mode" == "rewrite" ]]; then
    # サイクル完了: iteration をインクリメントして create に戻る
    local next_iteration=$((iteration + 1))
    log "INFO" "Transition: 全モード完了。Iter $iteration → Iter $next_iteration (rewrite→create)"
    update_state_str "mode" "create"
    update_state "iteration" "$next_iteration"
    # current_article をリセット
    local tmp
    tmp=$(mktemp)
    if jq '.current_article = {"slug": "", "title": "", "topic": ""}' "$STATE_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$STATE_FILE"
    else
      rm -f "$tmp"
    fi
    return 0  # フルイテレーション完了
  else
    log "INFO" "Transition: $mode → $next"
    update_state_str "mode" "$next"
    return 1  # まだモードが残る
  fi
}

# ---------------------------------------------------------------------------
# メインループ
# ---------------------------------------------------------------------------
main() {
  log "INFO" "=== zenn-engine.sh 起動 (dry_run=$DRY_RUN) ==="
  log "INFO" "作業ディレクトリ: $WORK_DIR"

  if [[ -n "$TIMEOUT_CMD" ]]; then
    log "INFO" "タイムアウトコマンド: $TIMEOUT_CMD (${MODE_TIMEOUT}秒)"
  else
    log "WARN" "タイムアウトコマンドが見つかりません。'brew install coreutils' でgtimeoutをインストール推奨"
  fi

  # ディレクトリ検証
  if [[ ! -d "$WORK_DIR" ]]; then
    log "ERROR" "作業ディレクトリが存在しません: $WORK_DIR"
    exit 1
  fi
  if [[ ! -f "$STATE_FILE" ]]; then
    log "ERROR" "state.jsonが見つかりません: $STATE_FILE"
    exit 1
  fi

  mkdir -p "$LOG_DIR" "$DAILY_DIR" "$MEMORY_DIR/long-term"

  CONSECUTIVE_ERRORS=0

  while [[ "$SHUTDOWN" == "false" ]]; do
    local mode iteration
    mode=$(get_state "mode")
    iteration=$(get_state "iteration")

    if [[ -z "$mode" || -z "$iteration" ]]; then
      log "ERROR" "state.jsonからmode/iterationを読み取れません"
      sleep "$ERROR_RETRY_SECONDS"
      continue
    fi

    log "INFO" "━━━ Iter $iteration / Mode: $mode 開始 ━━━"
    update_last_run

    # 1. Patrol - 健全性チェック
    if ! patrol; then
      log "WARN" "Patrol失敗。${ERROR_RETRY_SECONDS}秒後にリトライ"
      sleep "$ERROR_RETRY_SECONDS"
      continue
    fi

    # 1.5. Housekeeping (create モードのみ)
    housekeeping "$mode" "$iteration"

    # 2. Steering - Check + Plan
    steering_init
    steering_check "$mode" "$iteration"
    steering_make_plan "$mode" "$iteration"

    # 3. Executor - モード実行
    if executor "$mode" "$iteration"; then
      # 4. Reviewer - 成果確認 + コミット
      reviewer "$mode" "$iteration"

      # 4.5. Input Lifecycle (rewrite モードのみ)
      input_lifecycle "$mode" "$iteration"

      # 5. Transition - 次モードへ
      if transition "$mode" "$iteration"; then
        # フルイテレーション完了 - 長めのクールダウン
        if [[ "$SHUTDOWN" == "false" ]]; then
          log "INFO" "サイクル完了。次サイクルまで ${CYCLE_INTERVAL_SECONDS}秒（$(( CYCLE_INTERVAL_SECONDS / 3600 ))時間）休憩します..."
          sleep "$CYCLE_INTERVAL_SECONDS"
        fi
      else
        # モード完了、続きあり - クールダウン
        if [[ "$SHUTDOWN" == "false" ]]; then
          log "INFO" "クールダウン ${COOLDOWN_SECONDS}秒（$(( COOLDOWN_SECONDS / 3600 ))時間）..."
          sleep "$COOLDOWN_SECONDS"
        fi
      fi

      update_state_status "idle"
    else
      # エラーハンドリング（エラーバジェット方式）
      CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
      log "WARN" "Mode $mode 失敗 (連続エラー: $CONSECUTIVE_ERRORS/$MAX_CONSECUTIVE_ERRORS)"

      if [[ "$CONSECUTIVE_ERRORS" -ge "$MAX_CONSECUTIVE_ERRORS" ]]; then
        log "WARN" "エラー上限到達。Mode $mode をスキップして次へ進みます"
        CONSECUTIVE_ERRORS=0
        git_commit_and_push "$mode" "$iteration" || true

        # 強制遷移
        if transition "$mode" "$iteration"; then
          if [[ "$SHUTDOWN" == "false" ]]; then
            sleep "$CYCLE_INTERVAL_SECONDS"
          fi
        else
          if [[ "$SHUTDOWN" == "false" ]]; then
            sleep "$COOLDOWN_SECONDS"
          fi
        fi
      else
        git_commit_and_push "$mode" "$iteration" || true
        if [[ "$SHUTDOWN" == "false" ]]; then
          log "INFO" "エラーリトライ待機 ${ERROR_RETRY_SECONDS}秒..."
          sleep "$ERROR_RETRY_SECONDS"
        fi
      fi

      update_state_status "idle"
    fi
  done

  log "INFO" "=== zenn-engine.sh 停止完了 ==="
}

# ---------------------------------------------------------------------------
# エントリポイント
# ---------------------------------------------------------------------------
cd "$WORK_DIR" || exit 1
main
