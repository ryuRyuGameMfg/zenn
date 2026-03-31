#!/bin/bash
# zenn-engine.sh - Zenn 自律コンテンツエンジン
# Usage: ./zenn-engine.sh [--dry-run]
# Architecture: Patrol -> Steering -> Executor -> Reviewer -> Transition
# Schedule: 金曜 17:00 = create、土曜 17:00 = analyze -> improve -> report

# NOTE: -e は意図的に省略。エラーはコマンド単位で明示的に処理する。
set -uo pipefail

# ---------------------------------------------------------------------------
# 定数・設定
# ---------------------------------------------------------------------------
WORK_DIR="$HOME/repository/zenn-engine"
STATE_FILE="$WORK_DIR/state.json"
LOG_DIR="$WORK_DIR/logs"
PROMPT_DIR="$WORK_DIR/prompts"
INPUT_FILE="$WORK_DIR/INPUT.md"

# Workspace files (OpenClaw-inspired)
SOUL_FILE="$WORK_DIR/SOUL.md"
STRATEGY_FILE="$WORK_DIR/STRATEGY.md"
MEMORY_FILE="$WORK_DIR/MEMORY.md"
HEARTBEAT_FILE="$WORK_DIR/HEARTBEAT.md"
AGENT_FILE="$WORK_DIR/AGENT.md"
MEMORY_DIR="$WORK_DIR/memory"
DAILY_DIR="$MEMORY_DIR/daily"

ERROR_RETRY_SECONDS=1800     # 30分（エラー後リトライ待機）
SHORT_PAUSE=300              # 5分（モード間の短い待機）
MAX_MODES=4                  # create / analyze / improve / rewrite
MODE_TIMEOUT=3600            # 60分（claude -p 呼び出しタイムアウト）
MAX_CONSECUTIVE_ERRORS=3

ALLOWED_TOOLS="Read,Write,Edit,Bash,Glob,Grep,WebSearch,WebFetch,Agent,Task"

TELEGRAM_CONF="$WORK_DIR/.telegram.conf"
TELEGRAM_NOTIFY="$WORK_DIR/scripts/telegram-notify.sh"

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
  SHUTDOWN=true
}

trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# ユーティリティ
# ---------------------------------------------------------------------------
telegram_notify() {
  local message="$1"
  if [[ -f "$TELEGRAM_NOTIFY" && -f "$TELEGRAM_CONF" ]]; then
    bash "$TELEGRAM_NOTIFY" "$message" || true
  fi
}

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

# 初期化: INPUT.md を読み込み、グローバル変数を準備
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
    CURRENT_CHECK=$("$TIMEOUT_CMD" 1800 bash -c 'echo "$1" | claude -p --allowedTools "Read,Glob,Grep"' _ "$check_prompt" 2>/dev/null) || CURRENT_CHECK=""
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

# Plan: check 結果 + INPUT.md を元に計画を立てて CURRENT_PLAN 変数に格納
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

## ユーザーからの方針指示 (INPUT.md)
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
    CURRENT_PLAN=$("$TIMEOUT_CMD" 1800 bash -c 'echo "$1" | claude -p --allowedTools "Read,Glob,Grep"' _ "$plan_prompt" 2>/dev/null) || CURRENT_PLAN=""
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
# Input Lifecycle: INPUT.md の指示対応状況を追跡・クリア（rewrite モードのみ）
# ---------------------------------------------------------------------------
input_lifecycle() {
  local mode="$1"
  local iteration="$2"

  if [[ "$mode" != "rewrite" ]]; then
    return 0
  fi

  log "INFO" "InputLifecycle: rewrite モード - 振り返りと自己改善"

  # INPUT.md のアクティブな指示を確認
  if [[ -f "$INPUT_FILE" ]] && grep -q "^[0-9]" "$INPUT_FILE" 2>/dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "INFO" "[DRY-RUN] InputLifecycle: 評価スキップ"
    else
      local eval_prompt
      eval_prompt="$(build_context)
あなたは Zenn コンテンツエンジンのインプット管理担当です。

以下のユーザー指示(INPUT.md)の各項目が対応されているかを評価してください。
作業ディレクトリ: ${WORK_DIR}

## ユーザー指示
$(cat "$INPUT_FILE")

## 出力フォーマット
CRITICAL: Write/Edit/Bash ツールを使わないこと。

# Input Status - Iter${iteration}

| # | 指示内容 | 状態 | 備考 |
|---|---------|------|------|

## 全指示完了判定
(全てdoneなら「YES - INPUT.mdをクリア可能」、そうでなければ「NO - 残タスクあり」)"

      local status_content=""
      if [[ -n "$TIMEOUT_CMD" ]]; then
        status_content=$("$TIMEOUT_CMD" 300 bash -c 'echo "$1" | claude -p --allowedTools "Read,Glob,Grep"' _ "$eval_prompt" 2>/dev/null) || true
      else
        status_content=$(echo "$eval_prompt" | claude -p --allowedTools "Read,Glob,Grep" 2>/dev/null) || true
      fi

      if [[ -n "$status_content" ]] && echo "$status_content" | grep -q "YES.*クリア可能" 2>/dev/null; then
        log "INFO" "InputLifecycle: 全指示完了。INPUT.md をクリア"
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
# run_single_mode: 単一モードの実行（Patrol -> Steering -> Executor -> Reviewer）
# ---------------------------------------------------------------------------
run_single_mode() {
  local mode="$1"
  local iteration="$2"

  log "INFO" "━━━ Mode: $mode (iter=$iteration) 開始 ━━━"
  update_last_run

  patrol || { log "WARN" "Patrol失敗。スキップ"; return 1; }
  housekeeping "$mode" "$iteration"
  steering_init
  steering_check "$mode" "$iteration"
  steering_make_plan "$mode" "$iteration"

  if executor "$mode" "$iteration"; then
    reviewer "$mode" "$iteration"
    update_state_str "mode" "$mode"  # 完了したモードを記録
    log "INFO" "Mode $mode 完了"
    local _mode_jp; _mode_jp=$(case "$mode" in create) echo "新規記事作成";; analyze) echo "記事分析";; improve) echo "記事改善";; rewrite) echo "記事リライト";; *) echo "${mode}";; esac)
    telegram_notify "Zenn担当PMです。
第${iteration}サイクルの${_mode_jp}が完了しました。
次のサイクルに移行します。"
  else
    log "ERROR" "Mode $mode 失敗"
    local _mode_jp; _mode_jp=$(case "$mode" in create) echo "新規記事作成";; analyze) echo "記事分析";; improve) echo "記事改善";; rewrite) echo "記事リライト";; *) echo "${mode}";; esac)
    telegram_notify "Zenn担当PMです。
第${iteration}サイクルの${_mode_jp}で問題が発生しました。
ご確認ください。"
    git_commit_and_push "$mode" "$iteration" || true
    return 1
  fi
}

# ---------------------------------------------------------------------------
# 土曜レポート生成: analyze+improve結果をTelegramに送信
# ---------------------------------------------------------------------------
generate_saturday_report() {
  local iteration="$1"
  log "INFO" "土曜レポート生成中..."

  local context
  context=$(build_context)

  local report_prompt="${context}
あなたは zenn-engine の General Manager です。社長（岡本竜哉）に今週の統計分析・戦略改善の結果をTelegramで報告します。

CRITICAL: 以下のルールを厳守すること:
1. システム内部用語（Step数・Cycle数・status値）は使わない
2. 「何をやっていて、どういう状態か、次は何か」を人間の言葉で伝える
3. 成果・進捗・課題・次のアクションの4点を自然な文章で伝える
4. 技術的正確さだけでなく、読者価値・エンジニアコミュニティへの貢献観点も含める
5. 冒頭に役職・名前を名乗ることは禁止

## 報告内容

memory/saturday-report-template.md のフォーマットに従って、以下のデータを使って報告書を作成してください:

- metrics.json: 最新の統計データ
- state.json: 実行状態
- STRATEGY.md: OKR定義
- memory/long-term/topics.md: テーマキュー

## 出力フォーマット（必須）

Telegram HTML形式で出力すること:
- 1行目: タイトル（プレーンテキスト、HTMLタグなし）
- 2行目以降: HTMLタグで装飾（<b>, <code>, <blockquote>のみ使用）
- 1行30〜40文字以内
- テーブル禁止（スマホで崩れる）

出力は以下のマーカーで囲むこと:

TELEGRAM_REPLY_START
（1行目: プレーンテキストのタイトル）
（2行目以降: HTMLタグで装飾した本文）
TELEGRAM_REPLY_END

CRITICAL: Write/Edit/Bash ツールを使わないこと。テキスト出力のみ。"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "INFO" "[DRY-RUN] 土曜レポート生成スキップ"
    return 0
  fi

  local report_output=""
  if [[ -n "$TIMEOUT_CMD" ]]; then
    report_output=$("$TIMEOUT_CMD" 600 bash -c 'echo "$1" | claude -p --allowedTools "Read,Glob,Grep"' _ "$report_prompt" 2>/dev/null) || report_output=""
  else
    report_output=$(echo "$report_prompt" | claude -p --allowedTools "Read,Glob,Grep" 2>/dev/null) || report_output=""
  fi

  if [[ -z "$report_output" ]]; then
    log "WARN" "土曜レポート生成失敗"
    telegram_notify "zenn-engine GMです。

<b>今週の分析・改善が完了しました</b>

レポート生成に失敗しました。
memory/metrics.json を手動確認してください。"
    return 1
  fi

  # TELEGRAM_REPLY_START/END マーカーを抽出
  local telegram_message=""
  if echo "$report_output" | grep -q "TELEGRAM_REPLY_START"; then
    telegram_message=$(echo "$report_output" | sed -n '/TELEGRAM_REPLY_START/,/TELEGRAM_REPLY_END/p' | sed '1d;$d')
  else
    # マーカーがない場合は全文を使用
    telegram_message="$report_output"
  fi

  if [[ -n "$telegram_message" ]]; then
    # Telegram HTML形式でそのまま送信
    if [[ -f "$TELEGRAM_NOTIFY" && -f "$TELEGRAM_CONF" ]]; then
      echo "$telegram_message" | bash "$TELEGRAM_NOTIFY" - || log "WARN" "Telegram送信失敗"
    fi
    log_section "Saturday Report Iter${iteration}" "$telegram_message"
    log "INFO" "土曜レポート送信完了"
  else
    log "WARN" "レポート内容が空"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# 予約公開チェック: scheduled_publish を確認して published: true に変更
# ---------------------------------------------------------------------------
check_scheduled_publish() {
  # 予約公開配列を取得（配列または単一オブジェクトに対応）
  local scheduled_json
  scheduled_json=$(jq -r '.scheduled_publish' "$STATE_FILE" 2>/dev/null)

  # scheduled_publish が配列でない場合は配列化
  if echo "$scheduled_json" | jq -e 'type != "array"' > /dev/null 2>&1; then
    if echo "$scheduled_json" | jq -e 'has("slug")' > /dev/null 2>&1; then
      # 単一オブジェクトの場合は配列化
      scheduled_json="[$scheduled_json]"
    else
      # 空または無効な場合はスキップ
      return 0
    fi
  fi

  local current_time
  current_time=$(date -u '+%Y-%m-%dT%H:%M:%S')

  local published_slugs=()

  # 配列をループ処理
  local count
  count=$(echo "$scheduled_json" | jq 'length')

  for ((i=0; i<count; i++)); do
    local scheduled_slug
    local scheduled_date
    local scheduled_status

    scheduled_slug=$(echo "$scheduled_json" | jq -r ".[$i].slug")
    scheduled_date=$(echo "$scheduled_json" | jq -r ".[$i].scheduled_date")
    scheduled_status=$(echo "$scheduled_json" | jq -r ".[$i].status")

    if [[ -z "$scheduled_slug" || "$scheduled_status" != "scheduled" ]]; then
      continue
    fi

    # 予約時刻をUTC基準で比較（日本時間の17:00 = UTC 08:00）
    if [[ "$current_time" > "$scheduled_date" ]] || [[ "$current_time" == "$scheduled_date" ]]; then
      log "INFO" "予約公開時刻到達: $scheduled_slug"

      # 記事ファイルを探す
      local article_file="$WORK_DIR/articles/${scheduled_slug}.md"

      if [[ -f "$article_file" ]]; then
        # published: false を published: true に変更
        if grep -q "published: false" "$article_file"; then
          sed -i '' 's/published: false/published: true/g' "$article_file"
          log "INFO" "予約公開実行: $scheduled_slug -> published: true"

          # git commit + push
          cd "$WORK_DIR" || return 1
          git add "$article_file"
          git commit -m "zenn: 予約公開 $scheduled_slug"
          git push origin main || git push origin master

          published_slugs+=("$scheduled_slug")

          telegram_notify "zenn-engine GMです。

<b>予約公開が完了しました</b>

<b>記事</b>
<code>$scheduled_slug</code>

<b>予定時刻</b>
$(date -j -f '%Y-%m-%dT%H:%M:%S' "${scheduled_date%%+*}" '+%Y年%m月%d日 %H:%M' 2>/dev/null || echo "$scheduled_date")

記事が公開されました。"

          log "INFO" "予約公開完了: $scheduled_slug"
        else
          log "WARN" "記事がすでに公開済み: $scheduled_slug"
          published_slugs+=("$scheduled_slug")
        fi
      else
        log "ERROR" "予約公開対象の記事が見つかりません: $article_file"
      fi
    else
      log "INFO" "予約公開はまだ先です: $scheduled_slug -> $scheduled_date (現在: $current_time)"
    fi
  done

  # 公開完了した予約をstate.jsonから削除
  if [[ ${#published_slugs[@]} -gt 0 ]]; then
    local tmp
    tmp=$(mktemp)
    local filter_expr=""
    for slug in "${published_slugs[@]}"; do
      if [[ -z "$filter_expr" ]]; then
        filter_expr=".slug != \"$slug\""
      else
        filter_expr="$filter_expr and .slug != \"$slug\""
      fi
    done
    jq ".scheduled_publish = [.scheduled_publish[] | select($filter_expr)]" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    log "INFO" "公開完了した予約を削除: ${published_slugs[*]}"
  fi
}

# ---------------------------------------------------------------------------
# メイン: 曜日判定付き単発実行
# ---------------------------------------------------------------------------
main() {
  log "INFO" "=== zenn-engine.sh 起動 (dry_run=$DRY_RUN) ==="
  log "INFO" "作業ディレクトリ: $WORK_DIR"

  if [[ -n "$TIMEOUT_CMD" ]]; then
    log "INFO" "タイムアウトコマンド: $TIMEOUT_CMD (${MODE_TIMEOUT}秒)"
  else
    log "WARN" "タイムアウトコマンドが見つかりません。'brew install coreutils' でgtimeoutをインストール推奨"
  fi

  # ディレクトリ・state.json の検証
  if [[ ! -d "$WORK_DIR" ]]; then
    log "ERROR" "作業ディレクトリが存在しません: $WORK_DIR"
    exit 1
  fi
  if [[ ! -f "$STATE_FILE" ]]; then
    log "ERROR" "state.jsonが見つかりません: $STATE_FILE"
    exit 1
  fi

  mkdir -p "$LOG_DIR"

  # 予約公開チェック（毎回実行）
  check_scheduled_publish

  # 曜日判定（1=月, 2=火, 3=水, 4=木, 5=金, 6=土, 7=日）
  local dow
  dow=$(date +%u)
  log "INFO" "本日の曜日: $dow (5=金, 6=土)"

  local iteration
  iteration=$(get_state "iteration")

  case "$dow" in
    5)  # 金曜: create
      log "INFO" "=== 金曜モード: create ==="
      run_single_mode "create" "$iteration"
      ;;
    6)  # 土曜: analyze -> improve -> report
      log "INFO" "=== 土曜モード: analyze -> improve -> report ==="
      run_single_mode "analyze" "$iteration"
      [[ "$SHUTDOWN" == "false" ]] && sleep "$SHORT_PAUSE"
      run_single_mode "improve" "$iteration"
      [[ "$SHUTDOWN" == "false" ]] && sleep "$SHORT_PAUSE"

      # 土曜レポート生成（Telegram送信）
      log "INFO" "土曜レポート生成開始"
      generate_saturday_report "$iteration"

      # 土曜完了 = 1週間サイクル完了 -> iteration インクリメント
      local next_iter=$(( $(get_state "iteration") + 1 ))
      update_state "iteration" "$next_iter"
      update_state_str "mode" "create"
      log "INFO" "週次サイクル完了。Iteration $next_iter へ"
      ;;
    *)
      log "INFO" "本日(曜日=$dow)は実行対象外です"
      exit 0
      ;;
  esac

  log "INFO" "=== zenn-engine.sh 完了 ==="
}

# ---------------------------------------------------------------------------
# エントリポイント
# ---------------------------------------------------------------------------
cd "$WORK_DIR" || exit 1
main
