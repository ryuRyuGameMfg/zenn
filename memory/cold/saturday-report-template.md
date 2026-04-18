# 土曜レポートテンプレート（Telegram送信用）

## 出力フォーマット

**Telegram HTML形式（スマホ最適化）:**
- 1行目: タイトル（プレーンテキスト）
- 2行目以降: HTMLタグで装飾
- 見出し: `<b>テキスト</b>`
- 強調値: `<code>値</code>`
- 補足: `<blockquote>テキスト</blockquote>`
- 1行30〜40文字以内
- テーブル禁止（スマホで崩れる）

---

## セクション1: 実行サマリー

<b>zenn-agent GMです。</b>

<b>今週の統計収集・戦略分析が完了しました</b>

―――――――――――――――――

## セクション2: OKR進捗

<b>【OKR進捗】</b>

<b>O1: フォロワー1000人達成</b>
現在 <code>{follower_count}</code> / 目標 <code>1000</code>
進捗 <code>{progress_pct}%</code>
前週比 <code>{follower_diff}</code>

<b>O2: 累計スキ数1000達成</b>
現在 <code>{total_likes}</code> / 目標 <code>1000</code>
進捗 <code>{likes_progress_pct}%</code>
前週比 <code>{likes_diff}</code>

<b>O3: 平均スキ数15以上維持</b>
現在 <code>{avg_likes_per_article}</code>
目標 <code>15</code>
判定 <code>{avg_likes_status}</code>

―――――――――――――――――

## セクション3: 記事パフォーマンス

<b>【今週のハイライト】</b>

<b>高評価記事TOP3</b>
1. <code>{title1}</code>
   スキ <code>{likes1}</code>

2. <code>{title2}</code>
   スキ <code>{likes2}</code>

3. <code>{title3}</code>
   スキ <code>{likes3}</code>

<b>総記事数</b>
公開済: <code>{published_count}</code>
ストック: <code>{draft_count}</code>

―――――――――――――――――

## セクション4: テーマキュー状態

<b>【次週の記事候補】</b>

<b>キュー残数</b>
<code>{queue_count}</code>件

<b>上位3件</b>
1. {theme1}
2. {theme2}
3. {theme3}

<blockquote>キュー補充状況: {queue_status}</blockquote>

―――――――――――――――――

## セクション5: 戦略改善提案

<b>【戦略改善提案】</b>

<b>高PVパターン</b>
・{pattern1}
・{pattern2}
・{pattern3}

<b>推奨アクション</b>
・{action1}
・{action2}
・{action3}

<blockquote>{gm_comment}</blockquote>

―――――――――――――――――

## セクション6: 次のステップ

<b>【次週の予定】</b>

<b>公開スケジュール</b>
<code>{next_friday_date}</code> 17:00
{next_friday_title}

<code>{next_saturday_date}</code> 17:00
{next_saturday_title}

<b>次回レポート</b>
<code>{next_report_date}</code> 17:00

―――――――――――――――――

## データソース

- metrics.json: 統計データ
- state.json: 実行状態
- STRATEGY.md: OKR定義
- memory/insights.md: テーマキュー
