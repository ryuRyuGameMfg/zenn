# zenn-engine

Zenn記事リポジトリの自律コンテンツエンジン。4日ローテーションで記事生成・分析・改善・リライトを自動実行する。

## 実行フロー

[ヘッドレス] zenn-engine.sh (launchd定期実行)
  claude -p でmode-{X}.mdプロンプトを渡す（フレッシュセッション）
  SOUL→STRATEGY→MEMORY→AGENT読み込み
  モード判定(data/state.json): create→analyze→improve→rewrite（4日ローテーション）
  create/rewrite完了後: git push

[Telegram] telegram-daemon.sh → telegram-react.sh
  telegram-claude-runner.sh (--resume) → 指示処理 → Telegram返信

[CLI] ユーザーが直接 claude を起動して実行

## 実行モード

- ヘッドレス: フレッシュセッション。state.jsonでモード判定
- Telegram: --resume でセッション継続。HOT読み込み不要
- CLI: 通常のclaude会話

## ワークスペースファイル

| ファイル | 役割 | 更新者 |
|---------|------|--------|
| SOUL.md | 不変原則 | ユーザーのみ |
| STRATEGY.md | 記事戦略・KPI | AI提案→ユーザー承認 |
| MEMORY.md | 常時コンテキスト（~100行） | AI（rewriteモードで管理） |
| HEARTBEAT.md | チェックリスト | AI自己更新 |
| AGENT.md | 行動アルゴリズム | AI自己更新 |
| data/state.json | 実行状態 | zenn-engine.sh が管理 |

SOUL.md はAIが変更してはならない。Write/Edit ツールでSOUL.mdを対象にすることは禁止。

## 4日ローテーション

| モード | 内容 | クールダウン |
|--------|------|------------|
| create | 新規記事作成 + git push | 24時間 |
| analyze | 統計収集 + metrics.json 更新 | 24時間 |
| improve | 戦略分析 + テーマキュー補充 | 24時間 |
| rewrite | 低PV記事リライト + 新規1本 | 24時間（サイクル完了） |

## 記事命名規則

新規記事は必ず `YYYY-MM-DD-{slug}.md` 形式を使用する。

slug ルール:
- 英小文字・ハイフン区切り（kebab-case）
- 最大60文字
- 特殊文字・日本語を含めない

## 主要ディレクトリ

- articles/ : Zenn 記事本体
- drafts/ : 未公開・作業中（Zennへは同期されない）
- data/ : queue.json, state.json
- prompts/ : mode-create/analyze/improve/rewrite.md
- memory/ : metrics.json, insights.md, hot/, cold/

## 記事公開フロー（重要）

**新規記事作成時の必須手順**:

1. **published: false で作成**: frontmatter は必ず `published: false` に設定
2. **予約投稿キューに追加**: `data/queue.json` に記事情報を追加（優先度は末尾）
3. **Git コミット・プッシュ**: 記事ファイル + queue.json を同時にコミット

**予約投稿キュー（queue.json）の構造**:

```json
{
  "filepath": "articles/{slug}.md",
  "filename": "{slug}.md",
  "title": "記事タイトル",
  "scheduled_at": "YYYY-MM-DDTHH:mm:ss.sssZ",
  "status": "queued",
  "queued_at": "YYYY-MM-DDTHH:mm:ss.sssZ",
  "priority": N
}
```

**公開タイミング**: publish-daemon.mjs が scheduled_at に達したら自動的に `published: true` に変更

**禁止事項**: 新規記事を `published: true` で即座に公開することは禁止（予約投稿キューを経由すること）

## 禁止事項

- SOUL.md の変更
- articles/ 内の既存記事の削除
- git push は articles/ への変更がある場合のみ
- プロジェクト外のファイル操作
- sudo コマンドの実行
- **新規記事を published: true で即公開すること（必ず queue.json 経由）**
