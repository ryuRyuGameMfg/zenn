---
title: "Claude Codeの機密情報漏洩を防ぐ5つのHooksセキュリティ設計"
emoji: "🛡"
type: "tech"
topics: ["claudecode", "security", "hooks", "bash", "devtools"]
published: true
published_at: 2026-02-28 18:00
---

## はじめに

AIコーディングツールの普及に伴い、機密情報の漏洩リスクが深刻化しています。Claude Codeはデフォルト設定のままでは、`.env`ファイルを読み込ませればAPIキーがそのままAPIに送信されます。

私は60エージェント・34スキルの大規模なClaude Code環境で顧客情報を扱っています。本記事では、**多層防御のセキュリティシステム**を5つの防衛線として解説します。

:::message
対象読者: Claude Codeユーザー、AIコーディングツールを業務で使う方。
:::

## 背景：なぜデフォルトでは危険なのか

機密情報が外部に送信される経路は3つあります。

- ユーザーがメッセージにAPIキーを含めて送信
- Claude Codeが`.env`や`credentials`ファイルを読み込んでAPI送信
- `git push`で機密情報を含むコミットがリモートに公開

`permissions`のデフォルト設定では`.env`読み込みをブロックしません。自分で防衛線を張る必要があります。

## 5つの防衛線

### 第1層：permissions.deny（ファイルアクセスブロック）

`settings.json`で機密ファイルへのRead/Write/Editを完全遮断します。

```json
{
  "permissions": {
    "deny": [
      "Read(**/.env)", "Read(**/.env.*)",
      "Read(**/.secrets/**)", "Read(**/sensitive.json)",
      "Write(**/.env)", "Write(**/.env.*)",
      "Edit(**/.env)", "Edit(**/.env.*)"
    ]
  }
}
```

:::message
**ポイント**: Read/Write/Editの3操作全てをブロック。globパターン `**/.env.*` で `.env.local` や `.env.production` も網羅できます。
:::

### 第2層：realtime-sanitize.sh（メモリ内サニタイズ）

`UserPromptSubmit`フックで、ユーザー入力に含まれる機密情報を送信前に自動置換します。

仕組みは以下の通りです。

1. `privacy-map.json`（794件の置換辞書）を事前に生成
2. メッセージに `business/` 等のキーワードが含まれたら自動サニタイズ
3. メールアドレス・電話番号・APIキーのパターンマッチも実行
4. ファイルを生成せず、メモリ内のみで処理が完結

### 第3層：onsubmit-prepare.sh（APIキー検出・ブロック）

第2層をすり抜けたAPIキーパターンを検出し、`exit 2`で**送信自体をブロック**します。検出対象はAWS Access Key（`AKIA`）、OpenAI API Key（`sk-`）、GitHub Token（`ghp_`/`gho_`/`ghs_`）などです。サニタイズ（置換）ではなく送信を止める点が第2層との違いです。

:::message alert
**重要**: `exit 2`でClaude Codeはメッセージ送信をブロックします。うっかりAPIキーを貼り付けた場合の最後の砦です。
:::

### 第4層：pretool-security.sh（Git push検閲）

`PreToolUse(Bash)`フックで、`git push`実行前にコミット差分をスキャンします。チェック対象は以下の4カテゴリです。

1. APIキー・トークンパターン
2. メールアドレス（business/配下のファイルのみ）
3. 機密ファイル（.env、sensitive.json等）
4. パスワード・シークレット変数名

### 第5層：sensitive_patterns（設定ファイルベース）

`settings.json`にカスタムの検出パターンを定義します。Claude Code本体が認識するパターンで、フックとは独立して動作するため**二重の検出網**として機能します。

## 運用のコツとパフォーマンス

5層全てを有効にしても、体感への影響はありません。

| 防衛線 | 処理時間 | トリガー |
|-------|---------|---------|
| permissions.deny | 0ms | ファイルアクセス時 |
| realtime-sanitize.sh | ~50ms | メッセージ送信時 |
| onsubmit-prepare.sh | ~10ms | メッセージ送信時 |
| pretool-security.sh | ~100ms | git push時 |
| sensitive_patterns | 0ms | 設定読み込み時 |

**合計遅延は160ms以下**で、普段の操作で遅延を感じることはありません。

:::message
**Tips**: `privacy-map.json`は月1回の更新を推奨。顧客追加時に`node generate-privacy-map.js`を実行して辞書を最新に保ちましょう。
:::

導入の優先順位は以下の通りです。

1. **permissions.deny** -- 設定のみ、コード不要。今すぐできる
2. **sensitive_patterns** -- settings.jsonに追記するだけ
3. **onsubmit-prepare.sh** -- APIキー送信を確実にブロック
4. **realtime-sanitize.sh** -- 顧客情報を扱う場合に必須
5. **pretool-security.sh** -- git pushを使う場合に追加

## まとめ

5つの防衛線を導入した結果、260件の受注を通じて顧客情報を扱い続けていますが、**機密情報の漏洩インシデントはゼロ**です。

Claude Codeはデフォルトでは機密情報を守ってくれません。AIに強力な権限を与えるなら、その分だけ防御も自分で実装する必要があります。最低限、`permissions.deny`の設定だけでも今日中にやってください。settings.jsonに数行追加するだけで、`.env`の漏洩リスクを根絶できます。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
