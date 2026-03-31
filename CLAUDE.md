# zenn-engine

## 概要

zenn-engine は Zenn 記事リポジトリに自律コンテンツエンジン機能を追加したものです。
heartbeat (~/repository/heartbeat/) と同じ OpenClaw ワークスペース設計を採用しています。

## 自律エンジン（OpenClaw設計）

| ファイル | 役割 | 更新者 |
|---------|------|--------|
| SOUL.md | 不変原則 | ユーザーのみ |
| STRATEGY.md | 記事戦略・KPI | AI提案→ユーザー承認 |
| MEMORY.md | 常時コンテキスト（~100行） | AI（rewriteモードで管理） |
| HEARTBEAT.md | チェックリスト | AI自己更新 |
| AGENT.md | 行動アルゴリズム | AI自己更新 |
| data/state.json | 実行状態 | zenn-engine.sh が管理 |

## 4日ローテーション

| モード | 内容 | クールダウン |
|--------|------|------------|
| create | 新規記事作成 + git push | 24時間 |
| analyze | 統計収集 + metrics.json 更新 | 24時間 |
| improve | 戦略分析 + テーマキュー補充 | 24時間 |
| rewrite | 低PV記事リライト + 新規1本 | 24時間（サイクル完了） |

## ディレクトリ構造

```
zenn-engine/
├── articles/           # Zenn 記事本体（既存76本 + 自律生成分）
├── books/              # Zenn 本（既存）
├── SOUL.md             # 不変原則
├── STRATEGY.md         # 記事戦略・OKR
├── MEMORY.md           # 常時コンテキスト（~100行）
├── HEARTBEAT.md        # 自律チェックリスト
├── AGENT.md            # 行動アルゴリズム
├── data/               # ランタイムデータ（queue.json, state.json）
│   ├── queue.json      # 公開キュー
│   └── state.json      # 実行状態管理
├── zenn-engine.sh      # デーモンスクリプト
├── com.ryuryu.zenn-engine.plist  # launchd 設定
├── prompts/
│   ├── mode-create.md  # 新規記事作成プロンプト
│   ├── mode-analyze.md # 統計収集プロンプト
│   ├── mode-improve.md # 戦略改善プロンプト
│   └── mode-rewrite.md # リライトプロンプト
├── memory/
│   ├── metrics.json    # 記事パフォーマンスデータ
│   ├── insights.md     # テーマキュー・高PVパターン（統合）
│   ├── hot/            # 日次実行記録（YYYY-MM-DD.md）
│   └── cold/           # 長期保存データ
└── logs/               # 実行ログ（日付別フォルダ）
```

## デーモン起動・停止

```bash
# 起動
launchctl load ~/Library/LaunchAgents/com.ryuryu.zenn-engine.plist

# 停止
launchctl unload ~/Library/LaunchAgents/com.ryuryu.zenn-engine.plist

# 手動テスト
bash ~/repository/zenn-engine/zenn-engine.sh --dry-run
```

## plist 登録

```bash
# LaunchAgents にコピー
cp ~/repository/zenn-engine/com.ryuryu.zenn-engine.plist ~/Library/LaunchAgents/

# 起動
launchctl load ~/Library/LaunchAgents/com.ryuryu.zenn-engine.plist
```

## ユーザー操作ガイド

### 方針指示を出す

`memory/hot/` に `[user]` タグ付きで指示を記録する。次のモード実行時に反映される。

### テーマを手動追加する

`memory/insights.md` のキューに直接追記する。

### 戦略を変更する

`STRATEGY.md` を直接編集する（OKR・テーマ優先順位・投稿ペース等）。

## 注意事項

- `articles/` 内の既存記事は削除しない
- `SOUL.md` は AI が変更してはならない（ユーザーのみ）
- git push は `articles/` への変更がある場合のみ実行
