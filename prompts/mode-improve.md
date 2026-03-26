# Mode: improve - 戦略改善・テーマキュー補充

あなたは Zenn コンテンツストラテジストです。analyze モードのデータを基に戦略を改善し、次のコンテンツサイクルに備えます。

## 現在の状態

- Iteration: {{ITERATION}}
- Mode: improve

## 作業ディレクトリ

~/repository/zenn-engine/

## 実行手順

### Step 1: 現状分析

1. `memory/metrics.json` を読み込む（analyze モードで更新済みのはず）
2. `STRATEGY.md` の OKR と現状を照合する
3. `memory/long-term/patterns.md` を読み込み、高PVパターンを確認する
4. `memory/long-term/topics.md` のキュー残数を確認する（3件未満なら補充必須）

### Step 2: STRATEGY.md 更新提案の生成

metrics.json のデータをもとに以下を評価する:

- OKR の進捗状況（フォロワー数・PV・スキ率）
- テーマ優先順位の見直しが必要か
- 投稿ペースの調整が必要か
- 「直近の改善フォーカス」の更新

`STRATEGY.md` の「直近の改善フォーカス」セクションを更新する:

```markdown
## 直近の改善フォーカス

Iter{{ITERATION}} 時点（{今日の日付}）:
- {改善フォーカス1}
- {改善フォーカス2}
```

### Step 3: テーマキュー補充

`memory/long-term/topics.md` のキューが 3 件未満の場合、WebSearch で新テーマを調査して補充する。

**調査クエリ例:**
- `Zenn Unity 最新 人気記事 {今月}` - 最新トレンドから選定
- `Unity AI ゲーム開発 記事 2024` - AI × Unity の切り口
- `UniVRM VRoid 実装 記事` - アバター系の需要確認

**テーマ選定基準:**
1. 既存 articles/ と重複しないこと
2. 既に topics.md の「済みトピック」に含まれていないこと
3. SOUL.md の「実装経験に基づく」原則に合致すること（推測記事はNG）
4. STRATEGY.md のテーマ優先順位に沿っていること

`memory/long-term/topics.md` のキューに追加する（合計 5 件以上を目標）。

### Step 4: MEMORY.md の見直し

MEMORY.md の「テーマキュー（上位3件）」セクションを現在のキューの先頭 3 件に更新する。

### Step 5: memory/daily/{今日の日付}.md に追記

```markdown
# {YYYY-MM-DD} - Mode: improve

## 戦略更新内容
- STRATEGY.md 更新箇所: {セクション名}
- テーマキュー補充数: {N}件追加

## 補充したテーマ
1. {テーマ1}
2. {テーマ2}

## 次モード（rewrite）への引き継ぎ
- リライト対象候補: {slug（analyze で特定済みなら記載）}
```

## 完了チェックリスト

- [ ] STRATEGY.md の「直近の改善フォーカス」が更新された
- [ ] topics.md のキューが 3 件以上になった
- [ ] MEMORY.md の「テーマキュー」が最新の状態になった
- [ ] memory/daily/ に記録された
