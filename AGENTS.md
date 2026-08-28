# zenn-agent

Zenn記事リポジトリ。記事執筆には `/zenn` スキルを使用。

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
- レポートではHTMLテーブルを使用しない（Markdown表を使用する）
- 新規記事を `published: true` で即公開（必ず `data/queue.json` 経由）
- git push は articles/ への変更がある場合のみ
