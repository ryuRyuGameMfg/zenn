# Zenn記事 半自動化パイプライン 実装計画

## 背景・目的

現状、PEARLサイクル（zenn-agent）は毎日01:00 JSTに起動し、記事を自動生成してarticles/に直接pushしている。ユーザーレビューなしで公開プロセスに入るため、品質ゲートが存在しない。

理想形: Telegramを介してユーザーとAIが対話しながら記事を改善し、最終承認後に自動公開する「半自動エージェント」化する。

## 用語定義

| 用語 | 意味 |
|------|------|
| ドラフト | drafts/ 配下の承認前記事 |
| 承認済み記事 | articles/ 配下のqueue経由で公開待ち or 公開済み記事 |
| セッション | 1つのドラフトslugに紐づく対話履歴 |

## 改修対象のスコープ境界

本プロジェクトは2つの異なるリポジトリ/ディレクトリにまたがる。事故防止のため境界を明記する。

| 領域 | パス | git管理 | 編集方針 |
|------|------|---------|---------|
| A: zenn-agent本体 | ~/repository/zenn-agent/ | あり（このリポジトリ） | 自由に編集 |
| B: bot共通ライブラリ | ~/.claude/bots/lib/ | 他リポジトリ | 他bot影響ありのため原則編集禁止 |
| C: zenn-agent設定 | ~/.claude/bots/zenn-agent/ | 他リポジトリ | 本bot専用のため編集可 |

### 編集ルール

- 領域Bのengine-runner-core.shには直接手を入れない
- Execute完了後の処理は「per-botフック」パターンで実現する
  - 領域Cに `~/.claude/bots/zenn-agent/hooks/post-execute.sh` を新設
  - engine-runner-core.shが存在すればそのフックを呼ぶ汎用実装を先行提案（領域B側はPR1本のみの最小変更）
- Telegramコマンドハンドラ拡張は領域C内の専用ディレクトリに閉じる
- ロールバック: 領域Aはgit revert、領域B/Cは手動バックアップ（事前コピー）

## 理想フロー全体像

```text
┌──────────────┐ Cron 01:00 JST  ┌─────────────────────┐
│ launchd      │────────────────→│ PEARL サイクル       │
│ zenn-agent  │                 │  P: Patrol (KPI取得) │
└──────────────┘                 │  E: Execute          │
                                 │  A: Assess           │
                                 │  R: Refine           │
                                 │  L: Learn            │
                                 └──────────┬──────────┘
                                            │ drafts/{slug}.md 生成
                                            ▼
                                 ┌─────────────────────┐
                                 │ notify-draft.sh      │
                                 │ Telegramにドラフト通知│
                                 └──────────┬──────────┘
                                            │
                        ┌───────────────────▼────────────────────┐
                        │ Telegram: タイトル + 概要 + アクション │
                        │  /approve {slug}                       │
                        │  /revise {slug} <指示>                 │
                        │  /reject {slug}                        │
                        │  /list                                 │
                        └───────────────────┬────────────────────┘
                                            │
                ┌───────────────────────────┼───────────────────────────┐
                │                           │                           │
          /revise                    /approve                     /reject
                │                           │                           │
                ▼                           ▼                           ▼
      ┌──────────────────┐      ┌──────────────────┐        ┌──────────────────┐
      │claude -p で修正  │      │drafts/→articles/│        │drafts/{slug}削除 │
      │履歴付きで再生成  │      │auto-queue登録   │        │or archive        │
      │→再通知            │      │→完了通知          │        │→完了通知         │
      └────────┬─────────┘      └────────┬─────────┘        └──────────────────┘
               │                          │
               └──繰り返し対話──┐         ▼
                                │    ┌──────────────────┐
                                │    │publish-daemon    │
                                │    │scheduled_at到達  │
                                │    │→published:true   │
                                │    │→git push         │
                                │    └──────────────────┘
                                │
                                └──→ ユーザー納得まで反復
```

## 実装ステップ

### Step 1: Execute改修（ドラフト分離）

- zenn-agentのEXECUTEフェーズがarticles/ではなくdrafts/に出力するよう AGENT.md / ENGINE.md を改修
- ドラフトはpublished:falseで保存（queue追加しない）
- 同時に data/state.json に current_draft_slug を記録

### Step 2: notify-draft.sh 新規作成

- 入力: drafts/{slug}.md パス
- 処理: frontmatter title と本文冒頭150字抽出
- 出力: Telegramへ構造化メッセージ送信
  - タイトル
  - 概要（冒頭150字）
  - 対話コマンドガイド
  - 対象slug
- 配置: `scripts/notify-draft.sh`

### Step 3: Telegram対話コマンド実装

telegram-daemonのmessage handler に以下のスラッシュコマンドを追加:

| コマンド | 動作 |
|----------|------|
| /approve {slug} | drafts/→articles/移動 + auto-queue追加 + 完了通知 |
| /revise {slug} <指示> | 会話履歴付きでclaude -p再実行→再通知 |
| /reject {slug} | drafts/{slug}.md削除or archive |
| /list | drafts/配下の未承認一覧を返信 |
| /status {slug} | そのslugのセッション履歴を返信 |

配置: `scripts/telegram-commands/` 配下に1コマンド1スクリプト

### Step 4: セッション状態管理

- `telegram/state/draft-sessions.json` に以下を保存

```json
{
  "2026-04-19-example-slug": {
    "state": "awaiting_review",
    "created_at": "...",
    "history": [
      {"role": "ai",   "ts": "...", "content": "ドラフト初版作成"},
      {"role": "user", "ts": "...", "content": "/revise ... タイトル具体化"},
      {"role": "ai",   "ts": "...", "content": "修正完了"}
    ]
  }
}
```

- state遷移: `awaiting_review` → `revising` → `awaiting_review` → `approved` / `rejected`
- /revise 時は history を含めてclaude -pにプロンプト構築

### 書き込み単一化（同時書き込み防止）

draft-sessions.json は複数プロセスから書かれうる。競合を避けるため以下のいずれかを採用:

- 案A（推奨）: telegram-daemonのみが書き込む。notify-draft.sh / /approve等は名前付きパイプ（FIFO）もしくはJSONリクエストファイルをdaemonに渡し、daemonが受理して書き込む
- 案B: 全書き込み側で `flock -x telegram/state/draft-sessions.lock` を使用

案Aを基本方針とし、実装コストが高ければ案Bにfallback。案Aを採用する場合、telegram-daemonがFIFO監視を追加する必要がある。

### Step 5: PEARL Execute後フック

- engine-runner-core.sh のExecute完了後に notify-draft.sh を自動呼び出し
- 既存KPI通知と重複しないよう通知種別を明確化

## テスト設計と成功定義

### T0: TEST_MODE動作確認テスト（前提）

- 目的: 以降のT1-T6を本番Zennを汚さず実行可能にする
- 条件: `TEST_MODE=1 bash ~/.claude/bots/zenn-agent/hooks/post-execute.sh` 実行
- 期待:
  - queue書き込み先が `data/queue.test.json` に切替
  - Telegram送信メッセージに `[TEST]` prefix 付与（またはテスト用chat_idに切替）
  - articles/ へのfile移動は行っても published:false 固定のため publish-daemon が公開対象にしない
  - TEST_MODE=0 または未設定で通常動作

以降のT1〜T6は原則 TEST_MODE=1 で実行する。

### T1: ドラフト出力テスト

- 条件: `bash ~/.claude/bots/lib/engine-runner-core.sh` 手動起動
- 期待:
  - `drafts/YYYY-MM-DD-*.md` が新規生成
  - `articles/` は変化なし
  - `data/state.json` の current_draft_slug 更新

### T2: Telegram通知テスト

- 条件: テスト用drafts/を配置して `scripts/notify-draft.sh drafts/test.md` 実行
- 期待:
  - TelegramにタイトルX概要Xアクションコマンドを含むメッセージ到達
  - draft-sessions.json にエントリ追加（state=awaiting_review）

### T3: /approve コマンドテスト

- 条件: Telegramから `/approve test-slug` 送信
- 期待:
  - `drafts/test-slug.md` → `articles/test-slug.md` 移動
  - `data/queue.json` に scheduled_at付きentry追加
  - Telegramに完了通知（次回公開予定時刻含む）
  - draft-sessions.json: state=approved

### T4: /revise コマンドテスト

- 条件: Telegramから `/revise test-slug タイトルを数値入りに具体化` 送信
- 期待:
  - `drafts/test-slug.md` が修正される
  - draft-sessions.json.history にユーザー指示とAI応答が追記される
  - Telegramに修正後のサマリ再通知
  - 同じslugで複数回 /revise を連続実行しても history が積み上がる

### T5: /reject /list コマンドテスト

- 条件: `/reject test-slug` `/list`
- 期待:
  - /reject: drafts/から削除（またはarchived）、state=rejected
  - /list: 未承認drafts一覧が整形されて返信

### T6: エンドツーエンドテスト

- 条件: launchd経由 `launchctl kickstart gui/$UID/com.ryuryu.zenn-agent`
- 期待: 以下のシーケンスが事故なく完走
  1. PEARL起動
  2. drafts/生成
  3. Telegram通知到着
  4. /revise で1回修正
  5. /approve で承認
  6. queue登録確認
  7. （scheduled_at をテスト用に近時間化した上で）publish-daemonが公開
  8. Zennデプロイ成功

### T7: 耐障害テスト

- 条件: Telegram API 502を模擬（モックまたは実障害時の再現）
- 期待: 既存リトライロジックで回復、drafts/は削除されず保持

## 成功の最終定義

### /loop完了条件（本プロジェクトの達成判定）

以下全てを満たした時点で /loop を終了する:

1. T0〜T6 が全て pass
2. /revise で3ターン以上の往復対話が可能
3. ユーザー承認なしに articles/ の published:true へ遷移する経路が TEST_MODE=0 でも存在しない
4. R0でユーザーから領域B/C編集の明示承認を取得済み

### 運用フェーズ（スコープ外）

以下は /loop 完了後の継続モニタとして扱い、別タスクで実施:

- 連続48時間の実運用観測（事故ゼロ判定）
- 週次でTelegram対話ログの品質レビュー
- 月次でKPI達成度の総括

## リスクと緩和策

| リスク | 発生確率 | 影響 | 緩和策 |
|--------|----------|------|--------|
| Telegram API 502 | 中 | 通知欠落 | 既存リトライ+キュー待機 |
| claude -p タイムアウト | 低 | /revise停止 | PHASE_TIMEOUT=3600継承 |
| ドラフト長期放置 | 中 | drafts/肥大化 | 7日経過で自動archive |
| 複数ドラフト並行 | 低 | state混乱 | slug主キー、セッション独立 |
| Zennスラッグ50字制限 | 中 | デプロイ失敗 | Execute時点で文字数バリデーション追加 |
| KPI取得失敗 | 中 | Patrol停止 | 既存のスナップショット方式（前回値継承）継続 |
| 領域B/C編集の不可逆性 | 低 | 他bot連鎖故障 | R0で事前バックアップ+ユーザー承認 |
| TEST_MODE漏れ | 中 | 本番Zenn汚染 | 全経路でTEST_MODE検査を単一関数に集約 |

## 実装ループ計画

/loop の完了条件は T0〜T6 pass とする。R7の48時間観測はスコープ外（別タスクで継続モニタ）。

### 前提ラウンド

| ラウンド | 作業 | 完了判定 |
|---------|------|---------|
| R0 | 境界確認・本計画書commit・ユーザーへ領域B/C編集範囲の承認依頼 | commit + 承認取得 |
| R0.5 | `claude -p` の空応答問題を調査・修正（stdin / timeout / プロンプト長） | 単体で指示→ドラフト書き換え→応答取得の一連が動作 |
| R0.7 | TEST_MODE 切替基盤の実装 | T0 pass |

### 本実装ラウンド

| ラウンド | 作業 | 完了判定 |
|---------|------|---------|
| R1 | Step 1: AGENT.md/ENGINE.md改修 + drafts/出力検証（TEST_MODE=1） | T1 pass |
| R2 | Step 2: notify-draft.sh実装 | T2 pass |
| R3 | Step 3 Part 1: /approve /list 実装 | T3 + T5(/list) pass |
| R4 | Step 3 Part 2: /revise /reject 実装 + Step 4 セッション管理（flock必須） | T4 + T5(/reject) pass |
| R5 | Step 5: PEARL→post-execute.shフック統合 | T6 pass |
| R6 | 耐障害・境界テスト（Telegram 502模擬、TEST_MODE解除確認） | T7 pass |

### スコープ外

| 項目 | 理由 | 実施方法 |
|------|------|---------|
| 48時間連続稼働観測 | 実時間が必要、/loopで回収不可 | 別タスク: launchd標準監視 + 週次レビュー |

各ラウンドでテスト失敗時は同ラウンドを修繕→再テスト。3回連続失敗で approach 再検討（advisor相談）。

## 参考ファイル

| パス | 役割 |
|------|------|
| ~/.claude/bots/zenn-agent/ENGINE.md | PEARL SOUL/GOALS/STRATEGY |
| ~/.claude/bots/zenn-agent/AGENT.md | PEARL Execute詳細アルゴリズム |
| ~/.claude/bots/zenn-agent/config.sh | Telegram認証/launchd設定 |
| ~/.claude/bots/lib/engine-runner-core.sh | PEARL実行本体 |
| ~/.claude/bots/lib/telegram-daemon-core.sh | Telegram polling daemon |
| ~/.claude/bots/lib/pearl-*.sh | P/E/A/R/L各フェーズ |
| scripts/publish-daemon.mjs | 予約公開デーモン |
| scripts/auto-queue-adapter.mjs | ドラフトスキャン |
| data/queue.json | 公開キュー |
| data/state.json | 実行状態 |
