# AGENT.md - 行動アルゴリズム

> iterate モード（rewrite→create 遷移時）で AI が結晶化・更新する。

## モード判定

state.json の `mode` フィールド（文字列）で判定する。

| mode 値 | 実行内容 |
|---------|---------|
| `"create"` | 新規記事作成 + git push |
| `"analyze"` | 統計収集 + metrics.json 更新 |
| `"improve"` | 戦略分析 + テーマキュー補充 |
| `"rewrite"` | 低PV記事リライト（最大2本）+ 新規1本 |

## テーマ選定基準

1. `memory/long-term/topics.md` のキュー先頭から順に消費する
2. キューが空（0件）になった場合: WebSearch で Unity/AI 最新トレンドを調査して 5 件追加
3. キュー選定後、`articles/` 既存記事の slug 一覧と照合して重複がないことを確認
4. 重複があればキューの次のテーマへ（スキップして topics.md に「済み」マークを付ける）

## リライト対象選定

1. `memory/metrics.json` を読み込む
2. PV 下位 10% の記事を抽出する
3. かつ公開から 30 日以上経過している記事に絞る
4. 最大 2 本を選定（最も PV が低いものから優先）
5. metrics.json が空（未収集）の場合はリライトをスキップし、代わりに新規記事を作成する

## コミットメッセージ規約

```
zenn: iter{N}_{mode} {slug}
```

例:
- `zenn: iter01_create unity-claude-code-auto-test`
- `zenn: iter02_rewrite unity-drawcall-optimization`
- `zenn: iter03_analyze metrics-update`

## 記事品質基準（必須）

| 項目 | 基準 |
|------|------|
| コードサンプル | 1つ以上（言語タグ付きコードブロック） |
| 文字数 | 2,000字以上（目標: 2,000〜4,000字） |
| 見出し数 | 3つ以上 |
| frontmatter.published | `true` |
| frontmatter.type | `"tech"` |
| frontmatter.topics | 1〜5個の配列 |

## state.json モード遷移ルール

```
create → analyze → improve → rewrite → create（ループ）
```

- rewrite → create 遷移時: `iteration` をインクリメントする
- 遷移後: `current_article` をリセット（slug/title/topic を空文字に）

## エラーハンドリング

- `consecutive_errors` が 3 に達した場合: 現在のモードをスキップして次モードへ遷移
- エラー後のクールダウン: 1800秒（30分）
- エラーリセット: モード成功後に `consecutive_errors` を 0 にリセット

## memory/daily/ の記録形式

```markdown
# {YYYY-MM-DD} - Mode: {mode}

## 実行結果
- 作成/更新記事: {slug}
- 実行時刻: {HH:MM}

## 観察・メモ
- {観察内容}

## 課題
- {課題があれば記載}
```
