# STRATEGY.md - Zenn 記事戦略

> AI が analyze/improve モードで更新提案、ユーザーが承認して反映する。

## OKR（2026-03-31 改訂 → 2026-04-01 PV取得方法更新）

| 目標 | 指標 | 現状 | 期限 | 取得方法 |
|------|------|------|------|---------|
| O1: フォロワー1000人達成 | フォロワー数 | 37 | - | Zenn API（非公式） |
| O2: 累計PV 10,000達成 | 累計PV | 測定開始前 | - | Playwright（ダッシュボード自動取得） |
| O3: 平均スキ数15以上維持 | 平均スキ数/記事 | 12.1 | - | Zenn API（非公式） |

**PV取得方法の変更（2026-04-01）:**
- **新方式**: Playwright MCP でZennダッシュボードにログイン → スクリーンショット → LLM解析でPV抽出
- **実現可能性**: Claude Code の Playwright MCP 設定済み（@playwright/mcp@latest）
- **取得データ**: 投稿ごとの合計PV、日別/月別PV推移
- **自動化**: 土曜 analyze モードで統計収集 + metrics.json 更新

**旧方式（非公式API）の限界:**
- Zenn公式APIではPV統計を提供していない
- 非公式APIではスキ数・フォロワー数のみ取得可能
- Google Analytics連携は手動設定が必要（自律運用に不適）

**参考資料:**
- [Zennのダッシュボードに統計情報が表示されるようになるらしい](https://zenn.dev/spiegel/articles/20211225-zenn-analytics)
- [ZennのAPIを使って記事数・いいね数を取得する](https://zenn.dev/karaage0703/articles/c24072adc188a6)
- [ダッシュボードでPVなどの統計データを見れるように](https://github.com/zenn-dev/zenn-roadmap/issues/98)

## テーマ優先順位

1. **Unity × Claude Code**（自動化・AI支援開発）
   - 最も差別化できるテーマ。競合記事が少なく検索流入が見込める。
2. **Unity パフォーマンス最適化**（ドローコール・プロファイラー）
   - 実践的ニーズが高く、検索ボリュームが安定している。
3. **UniVRM / VRoid / Live2D 実装解説**
   - VTuber・アバター系の需要が高まっている。
4. **Zenn 人気記事の Gap 分析から選定**
   - analyze モードで更新。競合上位記事に存在しない切り口を狙う。

## 投稿ペース目標

- 月 7〜8本（4日ローテーション: create→analyze→improve→rewrite）
- 1イテレーション = 4モード = 約4日

## 記事文字数目標

- 2,000〜4,000字（長すぎると離脱率が上がる）

## 直近の改善フォーカス

Iter0 時点（2026-03-28）:
- AI x Unity MCP連携記事が高スキ帯（26〜33）のため、uLoopMCP + Claude Code をキュー上位に配置
- Unity パフォーマンス系（Memory Profiler, GPU Instancing）は競合が入門記事のみ → 実践ワークフロー記事で差別化
- Unity 6.3 Platform Toolkit は Zenn 記事がほぼ空白 → 早期投稿で検索優位性を確保
- ECS × キャラクター実装は「理論記事は多いが実ゲームへの適用例が皆無」という Gap を埋める
- テーマキューを1件 → 6件に補充完了。次サイクルで消費を開始する

## 記事フォーマット方針

- 導入: 課題提起（なぜこの記事が必要か）
- 本文: 解決策の概要 → 実装手順（コードサンプル必須）
- まとめ: 得られた結果・次のステップ
