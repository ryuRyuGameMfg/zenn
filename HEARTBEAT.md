# HEARTBEAT.md - 自律チェックリスト

> iterate モード（rewrite→create 遷移時）で AI が自己更新する。

## 品質チェック

- [ ] 前回記事のコードサンプルは動作するか（frontmatter の topics と一致しているか）
- [ ] 誤字脱字スキャン: 前回作成・リライト記事を再読して確認
- [ ] コードブロックの言語タグが付いているか（```csharp, ```bash 等）
- [ ] 見出し数が 3 つ以上あるか
- [ ] 文字数が 2,000 字以上あるか

## 戦略チェック

- [ ] テーマキュー（memory/long-term/topics.md）は 3 件以上残っているか
  - 3件未満の場合: improve モードで補充
- [ ] STRATEGY.md の OKR 進捗を確認（フォロワー数・PV・スキ率）
- [ ] 前回の analyze で更新した metrics.json は 7 日以内か
- [ ] STRATEGY.md の「直近の改善フォーカス」は最新か

## 自己改善チェック

- [ ] エラーが続いているモードはないか（state.json の consecutive_errors を確認）
- [ ] prompts/ のプロンプトを改善すべき点はないか
- [ ] AGENT.md のアルゴリズムに改善点はないか
- [ ] MEMORY.md が 100 行を超えていないか（超過していれば降格処理）

## データチェック

- [ ] memory/metrics.json は最新か（7 日以内）
- [ ] memory/long-term/topics.md は 3 件以上あるか
- [ ] memory/daily/ に今日の記録があるか（前回モード実行後に作成されているはず）
