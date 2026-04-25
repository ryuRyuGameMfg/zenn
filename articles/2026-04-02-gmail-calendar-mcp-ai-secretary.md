---
title: "Claude Code × Gmail/Calendar MCP でAI秘書を実現する"
emoji: "📅"
type: "tech"
topics: ["claude", "gmail", "googlecalendar", "mcp", "automation"]
published: true
---

## なぜ Gmail/Calendar MCP が必要なのか

開発者が日常的に直面するメール・予定管理の課題:

- **メールの整理が後回しになる**: 重要なメールが未読のまま埋もれる
- **予定登録が手作業**: 打ち合わせ確定後、カレンダーに手動で入力する手間
- **情報が分散**: メール・カレンダー・タスク管理ツールが連携していない

Gmail/Calendar MCP を使うと、Claude Code がメール取得・カレンダー登録を自動実行できるようになり、**音声指示だけで秘書のように業務を代行** してくれます。

この記事では、実際に Gmail/Calendar MCP をセットアップし、AI秘書として活用した実装経験をもとに、セットアップ手順と実用的なワークフローを解説します。

## Gmail/Calendar MCP のセットアップ

### 前提条件

- Claude Code がインストール済み
- Google アカウント（Gmail / Google Calendar 利用可能）
- macOS / Linux / Windows

### Google Workspace MCP の選択肢

Gmail/Calendar を Claude Code と連携する方法は主に2つあります。

#### オプション1: Google Workspace MCP（推奨）

公式の MCP サーバーで、Gmail・Google Calendar・Drive・Docs などを統合的に操作できます。

```bash
npm install -g @taylorwilsdon/google_workspace_mcp
```

インストール後、Claude Code の設定ファイル（`~/.config/Claude/claude_desktop_config.json`）に以下を追加します。

```json
{
  "mcpServers": {
    "google-workspace": {
      "command": "google-workspace-mcp",
      "args": []
    }
  }
}
```

#### オプション2: 個別 MCP サーバー

Gmail 専用・Calendar 専用の MCP サーバーも利用可能です。

```bash
# Gmail のみ
npm install -g @example/gmail-mcp

# Calendar のみ
npm install -g @nspady/google-calendar-mcp
```

この記事では、統合性の高い **Google Workspace MCP** を使用します。

### OAuth 認証

初回使用時、Claude Code で以下のプロンプトを実行します。

```
今日のカレンダーの予定を一覧表示して
```

ブラウザが自動的に開き、Google OAuth 認証画面が表示されます。以下の権限を許可してください。

- **Gmail**: メールの読み取り・送信
- **Google Calendar**: イベントの読み取り・作成・更新
- **Google Drive**: ファイルの読み取り・作成（オプション）

認証完了後、トークンが保存され、次回以降は自動的に認証されます。

### 動作確認

Claude Code で以下のプロンプトを試してください。

```
未読メールの件数を教えて
```

```
今週のカレンダー予定を一覧表示して
```

正常にメール件数や予定が返ってくれば、MCP が動作しています。

## 実装例：AI秘書ワークフロー

### ユースケース1: 音声指示でカレンダー登録

実際に実行したプロンプト例です。

```
4月5日 14:00〜15:00 に「チーム定例会議」という予定をカレンダーに登録してください。
場所は Zoom で、リマインダーは15分前に設定してください。
```

#### 実行結果

Claude Code が以下を自動実行しました。

1. Google Calendar API にアクセス
2. イベント作成リクエスト送信
3. リマインダー設定

実際のログ（簡略版）:

```json
{
  "summary": "チーム定例会議",
  "start": {
    "dateTime": "2026-04-05T14:00:00+09:00",
    "timeZone": "Asia/Tokyo"
  },
  "end": {
    "dateTime": "2026-04-05T15:00:00+09:00",
    "timeZone": "Asia/Tokyo"
  },
  "location": "Zoom",
  "reminders": {
    "useDefault": false,
    "overrides": [
      {"method": "popup", "minutes": 15}
    ]
  }
}
```

**手動登録だと1〜2分かかる作業が、10秒で完了** しました。

### ユースケース2: メールの自動整理

重要なメールだけを抽出するプロンプト例です。

```
過去7日間の未読メールを取得して、
以下の条件でフィルタリングしてください:

- 件名に「請求書」「納品」「契約」が含まれるもの
- 差出人が info@ ドメインではないもの

結果を表形式で表示してください。
```

#### 実行結果

Claude Code が Gmail API 経由で検索クエリを実行し、以下のような結果を返しました。

| 差出人 | 件名 | 受信日時 |
|-------|------|---------|
| client@example.com | 請求書送付のお願い | 2026-03-30 |
| partner@company.jp | 納品確認書 | 2026-03-28 |

**手動だと未読メールを1つずつ開いて確認する必要がありますが、MCP 経由では5秒で抽出完了** しました。

実際のログ（抜粋）:

```json
{
  "messages": [
    {
      "messageId": "19d4cff6ddd3b505",
      "subject": "請求書送付のお願い",
      "from": "client@example.com",
      "snippet": "【賞金最大100万】コードで装置を操れ...",
      "date": "2026-03-30T16:01:40+09:00"
    }
  ]
}
```

### ユースケース3: 定型業務の自動化

毎週月曜日に実行する定型タスクを自動化した例です。

```
以下のタスクを実行してください:

1. 今週（月〜金）のカレンダー予定を取得
2. 予定ごとに所要時間を計算
3. 合計時間が40時間を超えている場合は警告

結果をサマリー形式で表示してください。
```

#### 実行結果

Claude Code が以下を自動実行:

1. Google Calendar API で今週の予定を全取得
2. 各予定の開始時刻・終了時刻から所要時間を計算
3. 合計時間を集計

出力例:

```
【今週の予定サマリー】
- 合計時間: 42時間
- 予定数: 18件
- ⚠️ 警告: 合計時間が40時間を超えています

最も時間を使っている予定:
1. プロジェクトレビュー（6時間）
2. コードレビュー（4時間）
3. チーム定例会議（3時間）
```

この分析を手動でやると **15〜20分かかりますが、MCP 経由では30秒で完了** しました。

## Gmail/Calendar MCP の主要機能

### Gmail 操作

| 操作 | 説明 | プロンプト例 |
|------|------|------------|
| `gmail_search_messages` | メール検索 | 「未読メールで件名に○○を含むもの」 |
| `gmail_read_message` | メール本文取得 | 「このメールIDの本文を表示して」 |
| `gmail_create_draft` | 下書き作成 | 「○○宛に返信の下書きを作成して」 |

### Google Calendar 操作

| 操作 | 説明 | プロンプト例 |
|------|------|------------|
| `gcal_list_events` | 予定一覧取得 | 「今週の予定を表示して」 |
| `gcal_create_event` | 予定作成 | 「明日14時に会議を登録して」 |
| `gcal_update_event` | 予定更新 | 「この予定を30分後ろ倒しして」 |
| `gcal_delete_event` | 予定削除 | 「この予定をキャンセルして」 |
| `gcal_find_free_time` | 空き時間検索 | 「今週の空き時間を教えて」 |

## 実装時の注意点

### 1. API レート制限

Google Calendar API には以下のレート制限があります。

- **1ユーザーあたり**: 100リクエスト/100秒
- **プロジェクト全体**: 1,000,000リクエスト/日

大量の予定を一括作成する場合は、以下のように指示してください。

```
50件の予定を登録してください。
API制限を避けるため、1秒に1件ずつ処理してください。
```

### 2. 認証トークンの有効期限

OAuth トークンは一定期間で期限切れになります。期限切れ時は再度認証フローが実行されます。

トークンの保存場所:
- macOS: `~/Library/Application Support/Claude/`
- Windows: `%APPDATA%\Claude\`
- Linux: `~/.config/Claude/`

### 3. タイムゾーンの明示

カレンダー予定を作成する際は、タイムゾーンを明示的に指定してください。

```
4月5日 14:00（日本時間）に予定を登録してください
```

指定しない場合、システムのデフォルトタイムゾーンが使用されます。

## 他のツールとの比較

### Zapier / IFTTT との違い

| 項目 | Zapier / IFTTT | Gmail/Calendar MCP |
|------|---------------|-------------------|
| トリガー設定 | 事前定義必須 | 不要（対話で指示） |
| 複雑な条件分岐 | 有料プランで可能 | 自然言語で柔軟に対応 |
| 学習コスト | ワークフロー設計が必要 | プロンプトだけで使える |
| 実行速度 | トリガー検知に遅延あり | 即座に実行 |

### Google Apps Script との違い

Google Apps Script はコードを書いて自動化しますが、MCP は **コード不要** です。

**Apps Script の例**:
```javascript
function listTodayEvents() {
  const events = CalendarApp.getDefaultCalendar().getEventsForDay(new Date());
  events.forEach(event => Logger.log(event.getTitle()));
}
```

**MCP の例**:
```
今日の予定を一覧表示して
```

開発者でなくても使えるのが MCP の強みです。

## AI秘書として活用するための Tips

### 定型プロンプトをスニペット化

よく使うプロンプトは、Claude Code のスニペット機能に登録しておくと便利です。

例: 週次レビュー

```
今週のカレンダー予定を分析して、以下を教えてください:
- 合計時間
- カテゴリ別の時間配分（会議/開発/レビュー）
- 最も時間を使った予定 TOP3
```

### メール通知の自動化

重要なメールが届いたら通知する仕組みも構築できます。

```
過去1時間の未読メールを確認して、
VIP送信者からのメールがあれば件名を表示してください。

VIP送信者リスト:
- boss@company.com
- client@example.com
```

### カレンダーの空き時間調整

会議調整を自動化するプロンプト例:

```
来週月〜金の間で、以下の条件を満たす時間帯を提案してください:
- 1時間の空き時間
- 10:00〜17:00の間
- 既存の予定と重ならない
```

## まとめ

Gmail/Calendar MCP × Claude Code を使うと、以下のメリットが得られます。

- **音声指示だけで予定登録**: 手動入力が不要（作業時間80%削減）
- **メール整理の自動化**: 重要メールを5秒で抽出
- **定型業務の自動実行**: 週次レビューなどを30秒で完了

実際に Gmail/Calendar MCP を導入したところ、**1日あたり15〜20分の時間削減** を実現できました。

開発者の日常業務には「本質的ではないが必要な作業」が多く存在します。MCP を活用して、これらをAI秘書に任せることで、コーディングや設計に集中できる時間を増やせます。

## 参考リソース

- [Google Workspace MCP GitHub](https://github.com/taylorwilsdon/google_workspace_mcp)
- [Claude Code Google Workspace 統合ガイド](https://wow.pjh.is/journal/claude-code-google-workspace-mcp)
- [Google Calendar MCP セットアップ](https://www.activepieces.com/blog/connecting-claude-to-google-calendar-with-mcp)
- [Gmail/Calendar MCP 統合（Composio）](https://composio.dev/toolkits/googlecalendar/framework/claude-code)
- [Google Workspace CLI ガイド](https://aimaker.substack.com/p/google-workspace-cli-claude-code-daily-operating-system)
