# Zenn 自動投稿システム

note-engineと同じ自動投稿キューシステムをZenn用に実装しました。

## 概要

- 下書き記事（`published: false`）を自動検出
- 次の金曜・土曜 17:00に自動スケジュール
- Git push で Zenn.dev に自動公開
- 完全自動化（手動操作不要）

## システム構成

| コンポーネント | 説明 | 実行タイミング |
|--------------|------|--------------|
| **auto-queue.mjs** | ドラフトスキャナー | 毎日深夜 2:00 |
| **publish-daemon.mjs** | 公開デーモン | 常駐（60秒ごとチェック） |
| **queue.json** | 公開キュー | 自動更新 |

## 使い方（自動）

### 1. 記事を書く

```bash
# articles/ に記事を作成
# frontmatter で published: false にする
---
title: 記事タイトル
emoji: 🎨
type: tech
topics: ["unity", "ai"]
published: false
---
```

### 2. 自動検出

毎日深夜 2:00 に `auto-queue.mjs` が起動し、`published: false` の記事を検出してキューに追加します。

### 3. 自動公開

指定日時（金曜 or 土曜 17:00）に `publish-daemon.mjs` が以下を実行:

1. `published: false` → `published: true` に変更
2. `git add` + `git commit` + `git push`
3. Telegram 通知送信

## 使い方（手動テスト）

### ドラフトスキャン（テスト）

```bash
cd ~/repository/zenn-engine
node scripts/auto-queue.mjs --dry-run
```

### ドラフトをキューに追加

```bash
node scripts/auto-queue.mjs
```

### 公開デーモン（1回だけ実行）

```bash
node scripts/publish-daemon.mjs --dry-run --once
```

### キューの確認

```bash
cat queue.json
```

## スケジュール

- **公開頻度**: 週2回（金曜・土曜）
- **公開時刻**: 17:00（JST）
- **交互パターン**: 金 → 土 → 金 → 土

## フロー図

```
記事作成（published: false）
    ↓
深夜 2:00: auto-queue.mjs
    ↓
queue.json に追加
    ↓
金/土 17:00 到達
    ↓
publish-daemon.mjs
    ↓
published: true + Git push
    ↓
Zenn.dev 自動公開
    ↓
Telegram 通知
```

## launchd 管理

### 起動

```bash
launchctl load ~/Library/LaunchAgents/com.ryuryu.zenn-auto-queue.plist
launchctl load ~/Library/LaunchAgents/com.ryuryu.zenn-publish-daemon.plist
```

### 停止

```bash
launchctl unload ~/Library/LaunchAgents/com.ryuryu.zenn-auto-queue.plist
launchctl unload ~/Library/LaunchAgents/com.ryuryu.zenn-publish-daemon.plist
```

### 状態確認

```bash
launchctl list | grep zenn
```

### ログ確認

```bash
# auto-queue ログ
tail -f logs/auto-queue-stdout.log
tail -f logs/auto-queue-stderr.log

# publish-daemon ログ
tail -f logs/publish-daemon-stdout.log
tail -f logs/publish-daemon-stderr.log
```

## トラブルシューティング

### キューに追加されない

- `published: false` になっているか確認
- `auto-queue.mjs --dry-run` でテスト実行
- `queue.json` を確認

### 公開されない

- `publish-daemon.mjs` が起動しているか確認: `launchctl list | grep zenn-publish-daemon`
- ログを確認: `tail -f logs/publish-daemon-stderr.log`
- Git リポジトリの状態を確認: `git status`

### Telegram 通知が来ない

- `scripts/telegram-notify.sh` の実行権限を確認: `ls -la scripts/telegram-notify.sh`
- `.telegram.conf` が存在するか確認

## note-engine との違い

| 項目 | note-engine | zenn-engine |
|------|-------------|-------------|
| 公開方法 | Playwright（ブラウザ操作） | Git push |
| 記事管理 | articles/{ID}_{slug}/ | articles/{slug}.md |
| メタデータ | meta.json | frontmatter |
| セッション | .auth-state.json | 不要 |

## 実装ファイル

- `scripts/auto-queue.mjs` - ドラフトスキャナー
- `scripts/publish-daemon.mjs` - 公開デーモン
- `queue.json` - 公開キュー
- `launchd/com.ryuryu.zenn-auto-queue.plist` - auto-queue launchd設定
- `launchd/com.ryuryu.zenn-publish-daemon.plist` - publish-daemon launchd設定
- `scripts/telegram-notify.sh` - Telegram 通知（共通化）

## セットアップ完了

✅ 自動投稿システム実装完了（2026-03-31）

- 2件の記事がキューに登録済み
- 次回公開: 4/3（金）17:00、4/4（土）17:00
- システム稼働中
