# zenn-engine

Zenn記事リポジトリ。記事執筆には `/zenn` スキルを使用。

## ワークスペースファイル

| ファイル | 役割 | 更新者 |
|---------|------|--------|
| SOUL.md | 不変原則 | ユーザーのみ |
| STRATEGY.md | 記事戦略・KPI | AI提案→ユーザー承認 |
| MEMORY.md | 常時コンテキスト（~100行） | AI（rewriteモードで管理） |
| HEARTBEAT.md | チェックリスト | AI自己更新 |
| AGENT.md | 行動アルゴリズム | AI自己更新 |
| data/state.json | 実行状態 | zenn-engine.sh が管理 |

## 記事命名規則

`YYYY-MM-DD-{slug}.md` 形式。slug: 英小文字・ハイフン区切り・12〜50文字・日本語不可。

## 出力先

| パス | 用途 |
|------|------|
| `articles/` | Zenn 記事本体 |
| `drafts/` | 未公開・作業中 |
| `data/queue.json` | 予約投稿キュー |

## 禁止事項

- articles/ 内の既存記事の削除
- 新規記事を `published: true` で即公開（必ず `data/queue.json` 経由）
- git push は articles/ への変更がある場合のみ
