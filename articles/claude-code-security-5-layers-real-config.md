---
title: "Claude Codeで機密情報漏洩ゼロを実現した5層セキュリティ設計【実設定公開】"
emoji: "🛡"
type: "tech"
topics: ["claudecode", "security", "hooks", "bash", "devtools"]
published: false
---

## はじめに

AIコーディングツールの普及に伴い、機密情報の漏洩リスクが深刻化しています。Claude Codeはデフォルト設定のままでは、`.env`ファイルを読み込ませればAPIキーがそのままAPIに送信されます。

私は61エージェント・22スキルの大規模なClaude Code環境で、260件以上の顧客情報を扱っています。本記事では、**実際に運用している多層防御のセキュリティ設計**を、設定ファイルの中身も含めて公開します。

:::message
対象読者: Claude Codeユーザー、AIコーディングツールを業務で使う方。
実運用で漏洩インシデントゼロを継続中の設定をそのまま掲載しています。
:::

## 背景：なぜデフォルトでは危険なのか

機密情報が外部に送信される経路は3つあります。

- ユーザーがメッセージにAPIキーを含めて送信
- Claude Codeが`.env`や`credentials`ファイルを読み込んでAPI送信
- `git push`で機密情報を含むコミットがリモートに公開

`permissions`のデフォルト設定では`.env`読み込みをブロックしません。自分で防衛線を張る必要があります。

## 5層防御の全体像

```text
ユーザー入力
  │
  ├─ 第1層: permissions.deny（ファイルアクセス遮断）
  │    → .env / .secrets / 認証情報への Read/Write/Edit を全面禁止
  │
  ├─ 第2層: realtime-sanitize.sh（メモリ内サニタイズ）
  │    → 794件の置換辞書で顧客情報を自動マスク
  │
  ├─ 第3層: onsubmit-prepare.sh（APIキー検出・送信ブロック）
  │    → AWS/OpenAI/GitHub等のキーパターンを検出 → exit 2で送信停止
  │
  ├─ 第4層: pretool-security.sh（Git push検閲）
  │    → push前にdiff全体をスキャン、機密検出でブロック
  │
  └─ 第5層: sensitive_patterns（設定ファイルベース検出）
       → Claude Code本体の検出機能、フックと独立した二重検出網
```

## 第1層：permissions.deny（ファイルアクセスブロック）

`settings.json`で機密ファイルへのRead/Write/Editを完全遮断します。以下は実際に運用中の設定全文です。

```json
{
  "permissions": {
    "deny": [
      "Read(**/.env)", "Read(**/.env.*)",
      "Read(**/.secrets/**)", "Read(**/secrets/**)",
      "Read(**/*.sensitive.json)", "Read(**/sensitive.json)",
      "Read(**/.credentials/**)",
      "Read(**/.aws/credentials)",
      "Read(**/.ssh/id_*)",
      "Read(**/*.pem)", "Read(**/*.key)",

      "Write(**/.env)", "Write(**/.env.*)",
      "Write(**/.secrets/**)", "Write(**/secrets/**)",
      "Write(**/*.sensitive.json)", "Write(**/sensitive.json)",
      "Write(**/.credentials/**)",
      "Write(**/.aws/credentials)",
      "Write(**/.ssh/id_*)",
      "Write(**/*.pem)", "Write(**/*.key)",

      "Edit(**/.env)", "Edit(**/.env.*)",
      "Edit(**/.secrets/**)", "Edit(**/secrets/**)",
      "Edit(**/*.sensitive.json)", "Edit(**/sensitive.json)",
      "Edit(**/.credentials/**)",
      "Edit(**/.aws/credentials)",
      "Edit(**/.ssh/id_*)",
      "Edit(**/*.pem)", "Edit(**/*.key)"
    ]
  }
}
```

:::message
**設計意図**: Read/Write/Editの3操作全てをブロックしています。`**/.env.*`のようなglobパターンで`.env.local`や`.env.production`も網羅。`.secrets/`と`secrets/`の両方をカバーしているのは、プロジェクトによってディレクトリ名が異なるためです。
:::

## 第2層：realtime-sanitize.sh（メモリ内サニタイズ）

`UserPromptSubmit`フックで、ユーザー入力に含まれる機密情報を送信前に自動置換します。

```text
処理フロー:

1. ユーザーがメッセージを入力
2. UserPromptSubmitイベント発火
3. realtime-sanitize.sh が起動（処理時間: 約50ms）
4. privacy-map.json（794件の置換辞書）を読み込み
5. メッセージ内の顧客名・メール・電話番号等をプレースホルダーに置換
   例: "田中太郎" → "[CUSTOMER_NAME_A042]"
   例: "tanaka@example.com" → "[CUSTOMER_EMAIL_A042]"
6. 正規表現パターンマッチも並行実行
   - メールアドレス: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
   - 電話番号: /0\d{1,4}-\d{1,4}-\d{4}/
   - APIキー: /sk-[a-zA-Z0-9]{20,}/ 等
7. サニタイズ済みメッセージをClaude APIに送信
```

ファイルを生成せず、**メモリ内のみで処理が完結**する点が特徴です。

### privacy-map.jsonの生成方法

置換辞書は`generate-privacy-map.js`で自動生成します。

```javascript
// generate-privacy-map.js の処理概要
const SENSITIVE_FIELDS = {
  email: 'CUSTOMER_EMAIL',
  phone: 'CUSTOMER_PHONE',
  contactUrl: 'CONTACT_URL',
  customerName: 'CUSTOMER_NAME',
  companyName: 'COMPANY_NAME',
  projectDetails: 'PROJECT_DETAIL'
};

// sensitive.json/metadata.jsonから機密情報を抽出
// → 一意なプレースホルダーに変換するマップを生成
// → .secrets/privacy-map.json に出力（Git管理外）
```

```bash
# 辞書の更新（月1回推奨、顧客追加時に実行）
cd ~/repository/customer-db/scripts
node generate-privacy-map.js
```

:::message
現在794件の置換ルールが登録されています。顧客の名前・メールアドレス・電話番号・企業名・プロジェクト詳細が対象です。
:::

## 第3層：onsubmit-prepare.sh（APIキー検出・ブロック）

第2層をすり抜けたAPIキーパターンを検出し、`exit 2`で**送信自体をブロック**します。

検出対象パターン:

| プロバイダー | プレフィックス | 例 |
|------------|-------------|-----|
| AWS Access Key | `AKIA` | AKIAIOSFODNN7EXAMPLE |
| OpenAI API Key | `sk-` | sk-proj-xxxxx |
| GitHub Token | `ghp_` / `gho_` / `ghs_` | ghp_xxxxxxxxxxxx |
| Google API Key | `AIza` | AIzaSyxxxxxxxxxx |
| Slack Token | `xoxb-` / `xoxp-` | xoxb-xxxxxxxxxxxx |

:::message alert
**重要**: サニタイズ（置換）ではなく`exit 2`で送信自体を停止します。うっかりAPIキーを貼り付けた場合の最後の砦です。Claude Codeは`exit 2`を受け取るとメッセージ送信をキャンセルします。
:::

## 第4層：pretool-security.sh（Git push検閲）

`PostToolUse(Bash)`フックで、`git push`実行時にコミット差分をスキャンします。

チェック対象の4カテゴリ:

1. **APIキー・トークンパターン** -- AWS、OpenAI、GitHub、Google等
2. **メールアドレス** -- business/配下のファイルに含まれるもの
3. **機密ファイル** -- .env、sensitive.json、.pem、.key等
4. **パスワード・シークレット変数名** -- `password=`、`secret=`等のパターン

検出時はpushをブロックし、問題箇所をターミナルに表示します。

## 第5層：sensitive_patterns（設定ファイルベース）

`settings.json`にカスタムの検出パターンを定義します。Claude Code本体が認識するパターンで、フックとは独立して動作するため**二重の検出網**として機能します。

## Hooks一覧と役割

現在運用中の8つのHooksの全体像です。

```text
セキュリティ系（3本）:
  realtime-sanitize.sh  ← UserPromptSubmit  機密情報の自動置換
  onsubmit-prepare.sh   ← UserPromptSubmit  APIキー検出・送信ブロック
  pretool-security.sh   ← PostToolUse(Bash) Git push検閲

UI/UX系（4本）:
  onstop-tab-working.sh ← UserPromptSubmit  タブに「処理中」表示
  onstop-tab-complete.sh← Stop              タブに「完了」通知
  onstop-tab-idle.sh    ← Stop              10秒後に「待機中」表示
  posttool-ask-question.sh ← PostToolUse(AskUserQuestion) 質問通知

自動化系（1本）:
  session-commit.sh     ← SessionEnd        セッション終了時に自動コミット
```

## 運用実績とパフォーマンス

5層全てを有効にしても、体感への影響はありません。

| 防衛線 | 処理時間 | トリガー |
|-------|---------|---------|
| permissions.deny | 0ms | ファイルアクセス時 |
| realtime-sanitize.sh | ~50ms | メッセージ送信時 |
| onsubmit-prepare.sh | ~10ms | メッセージ送信時 |
| pretool-security.sh | ~100ms | git push時 |
| sensitive_patterns | 0ms | 設定読み込み時 |

**合計遅延は160ms以下**で、普段の操作で遅延を感じることはありません。

### 導入の優先順位

手軽さとインパクトの順に並べています。

1. **permissions.deny** -- 設定のみ、コード不要。今すぐできる
2. **sensitive_patterns** -- settings.jsonに追記するだけ
3. **onsubmit-prepare.sh** -- APIキー送信を確実にブロック
4. **realtime-sanitize.sh** -- 顧客情報を扱う場合に必須
5. **pretool-security.sh** -- git pushを使う場合に追加

:::message
**Tips**: `privacy-map.json`は月1回の更新を推奨。顧客追加時に`node generate-privacy-map.js`を実行して辞書を最新に保ちましょう。
:::

## まとめ

5つの防衛線を導入した結果、260件の受注を通じて顧客情報を扱い続けていますが、**機密情報の漏洩インシデントはゼロ**です。61エージェント・22スキルという大規模環境でも、160ms以下の遅延で透過的に動作しています。

Claude Codeはデフォルトでは機密情報を守ってくれません。AIに強力な権限を与えるなら、その分だけ防御も自分で実装する必要があります。最低限、`permissions.deny`の設定だけでも今日中にやってください。settings.jsonに数行追加するだけで、`.env`の漏洩リスクを根絶できます。

:::message
**CLAUDE.mdシリーズ 関連記事**
- [CLAUDE.mdで失敗しまくった7つのパターンと解決策【2026年版】](https://zenn.dev/ryuryu/articles/claude-md-7-failure-patterns-2026)
- [Claude Codeの出力が読めない問題をCLAUDE.mdのASCII図ルールで解決した](https://zenn.dev/ryuryu/articles/2026-04-01-claude-md-ascii-diagram-output)
:::

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
