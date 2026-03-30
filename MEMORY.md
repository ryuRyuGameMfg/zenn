# MEMORY - 常時コンテキスト

**管理方針: iterate モードで昇格/降格。100行以下を維持。**
**3層構造: hot（毎回参照）/ warm（数週間有効）/ cold（アーカイブ）**

---

## [HOT] 直近の状態（常時参照）

- **モード**: create → analyze → improve → rewrite → create（ループ）稼働中
- **稼働状況**: 4日ローテーション稼働中（Iter0 完了、Iter1 開始）
- **フォロワー**: 37（目標 1000、進捗 3.7%）
- **直近投稿**:
  - 2026-03-31 `2026-03-31-why-humans-dislike-ai-design`（create）
  - 2026-03-28 `2026-03-28-zenn-github-actions-auto-deploy`（rewrite）
  - 2026-03-28 `2026-03-28-univrm-lipsync-implementation`（create）

---

## [WARM] 有効な戦略情報（数週間スパン）

**テーマキュー（上位3件）**:
1. uLoopMCP + Claude Code で Unity 自律開発サイクルを実現する方法
2. Unity Memory Profiler 実践ワークフロー：GC Alloc 撲滅からメモリリーク根絶まで
3. Unity GPU Instancing 完全実装：DrawMeshInstanced から RenderMeshIndirect まで段階的に理解する

**直近の高注目テーマ（2026-03-31追加）**:
- AIデザイン心理学 × Unity UI実装：バイアスと実質的傾向の2方向分析が競合に存在せず、差別化に成功

**高PVパターン（競合分析 2026-03-27）**:

| パターン | 観察回数 | 備考 |
|---------|---------|------|
| AI x Unity MCP連携（実験記録形式） | 3件 | スキ18〜33。uLoopMCP/Claude/Gemini |
| Unity 6.x 新機能解説 | 2件 | スキ18前後。公式情報まとめ系 |
| 非エンジニア体験記 + AI | 2件 | スキ5〜26。再現性高いほど拡散 |

---

## [WARM] 記事 DB 状態

- **ローカル記事数**: 69本（うち Zenn 公開済 32本相当）
- **リポジトリ**: ~/repository/zenn-engine/
- **累計スキ**: 350（平均 12.1/記事、公開 29本ベース）
- **OKR**:
  - O1 フォロワー 1000人: 37/1000（3.7%）
  - O2 月間 PV 10,000: 未取得（Zenn 非公開）
  - O3 スキ率 5%以上: PV 未取得 / 平均スキ 12.1/記事

---

## [COLD] 避けるべきトピック・学んだパターン

**重複回避リスト**:

| トピック | 理由 |
|---------|------|
| Unity × Claude Code 自動テスト生成 | 2026-03-26 に作成済み |
| UniVRM 2.0 リップシンク実装 | 2026-03-28 に作成済み |
| Zenn × GitHub Actions 自動デプロイ | 2026-03-28 に作成済み |
| AIデザイン心理学 × Unity UI実装 | 2026-03-31 に作成済み |

**長期有効な知見**:
- AI x Unity MCP 連携記事が競合で最高スキ（26〜33）。実験記録・限界検証フォーマットが有効。
- rewrite モードで metrics.json 空の場合：リライトスキップ → キュー先頭で新規作成が安定した代替フロー。
- textlint + GitHub Actions 組み合わせ記事は検索ボリューム安定。CI/CD 系は実装コードが具体的なほどスキが取れる。

---

## 昇格/降格ルール

| 判定 | 処理 |
|------|------|
| 30日以上価値がある情報 | HOT/WARM に昇格 |
| 2週間参照されない HOT 情報 | WARM に降格 |
| 1ヶ月参照されない WARM 情報 | COLD または削除 |
| 100行超過時 | COLD を memory/long-term/ に移動 |
