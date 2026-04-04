# MEMORY - zenn-engine

## メモリ構造

| 層 | パス | ロード | 説明 |
|----|------|--------|------|
| HOT | memory/hot/ | デーモン起動時のみ | 直近20件の日次記録 |
| WARM | memory/warm/ | 常時 | 週次サマリー |
| COLD | memory/cold/ | 要求時 | 月次サマリー |
| INSIGHTS | memory/insights.md | 常時 | 学習パターン |

## HOT（直近コンテキスト）
- 最新: 2026-03-28
- 件数: 3件

## 現在のフォーカス
- モード: create → analyze → improve → rewrite → create（ループ）稼働中
- 4日ローテーション稼働中（Iter2 analyze 完了、improve へ遷移）
- フォロワー: 37（目標 1000、進捗 3.7%）
- 直近投稿: 2026-03-31 `why-humans-dislike-ai-design`（create）、2026-03-28 `zenn-github-actions-auto-deploy`（rewrite）
- AIデザイン心理学 × Unity UI実装：バイアスと実質的傾向の2方向分析が競合に存在せず差別化に成功
- OKR: フォロワー 37/1000（3.7%）、累計スキ 350/1000（35%）

## WARM サマリー
未生成

## COLD アーカイブ
- ai-design-research.md

## メモリ参照方針
- Telegram経由（--resume）: HOT読み込み不要（セッション継続で代替）
- WARM: memory/warm/ を必要に応じてGrep参照（~90日）
- COLD: memory/cold/ を必要に応じてGrep参照（永続）
