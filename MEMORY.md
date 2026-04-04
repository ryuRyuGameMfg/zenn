# MEMORY - zenn-engine

## メモリ構造

| 層 | パス | ロード | 説明 |
|----|------|--------|------|
| HOT | memory/hot/ | デーモン起動時のみ | 直近20件の日次記録 |
| WARM | memory/warm/ | 常時 | 週次サマリー |
| COLD | memory/cold/ | 要求時 | 月次サマリー |
| INSIGHTS | memory/insights.md | 常時 | 学習パターン |

## HOT（直近コンテキスト）
- 最新: 2026-04-04
- 件数: 6件

## 現在のフォーカス
- モード: improve 完了 → rewrite へ遷移
- 4日ローテーション稼働中（Iter2 improve 完了）
- フォロワー: 37（目標 1000、進捗 3.7%）
- 直近投稿: 2026-04-03 `unity-architecture-ai-code-instruction`（scheduled）
- OKR: フォロワー 37/1000（3.7%）、累計スキ 350/1000（35%）
- 2026年0スキ問題: タイトル訴求力不足が主因。問題提起型・N選形式への変換が急務
- テーマキュー: uLoopMCP（最優先）→ 初心者罠5選 → ScriptableObject5選（新規追加）

## テーマキュー（上位3件）
1. uLoopMCP + Claude Code で Unity 自律開発サイクルを実現する方法
2. Unity C#でやりがちな「初心者の罠」5選
3. ScriptableObjectを使いこなす5つの実践パターン

## WARM サマリー
未生成

## COLD アーカイブ
- ai-design-research.md

## メモリ参照方針
- Telegram経由（--resume）: HOT読み込み不要（セッション継続で代替）
- WARM: memory/warm/ を必要に応じてGrep参照（~90日）
- COLD: memory/cold/ を必要に応じてGrep参照（永続）
