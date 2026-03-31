# Playwright PV取得 実装完了ドキュメント

## 概要

Playwright MCP を使用してZennダッシュボードからPV統計を自動取得する機能を実装しました。

## 実装日

2026-04-01

## 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/fetch-zenn-analytics.mjs` | Playwright実行スクリプト（メイン処理） |
| `prompts/mode-analyze.md` | analyze モードのプロンプト（Playwright実行手順を追加） |
| `STRATEGY.md` | OKR定義（PV取得方法を明記） |
| `MEMORY.md` | 常時コンテキスト（実装完了を記録） |

## アーキテクチャ

```
[土曜 analyze モード実行]
         ↓
[zenn-engine.sh]
         ↓
[prompts/mode-analyze.md] → Claude が以下を実行:
         ↓
[1. Playwright スクリプト実行]
   node scripts/fetch-zenn-analytics.mjs
         ↓
[2. スクリーンショット取得]
   /tmp/zenn-dashboard.png
         ↓
[3. LLM解析でデータ抽出]
   Claude Code の Read ツールで画像読み込み
         ↓
[4. metrics.json 更新]
   memory/metrics.json に保存
         ↓
[土曜レポート生成]
   Telegram に統計送信
```

## セキュリティ考慮事項

### 認証情報管理

環境変数で認証情報を管理します:

```bash
# ~/.zshrc または ~/.bashrc に追加
export ZENN_EMAIL="your-github-email@example.com"
export ZENN_PASSWORD="your-github-password"
```

**重要**: これらの環境変数は `.env` ファイルには記載しないこと（Gitに含まれるリスク）

### スクリーンショット管理

- `/tmp/` に一時保存（システム再起動で自動削除）
- Git管理対象外
- 解析後は手動削除を推奨

## 実行方法

### 手動テスト

```bash
# 1. 環境変数設定（初回のみ）
export ZENN_EMAIL="your-github-email@example.com"
export ZENN_PASSWORD="your-github-password"

# 2. スクリプト実行
cd ~/repository/zenn-engine/scripts
node fetch-zenn-analytics.mjs

# 3. スクリーンショット確認
open /tmp/zenn-dashboard.png

# 4. Claude Code で LLM解析
# Read ツールで /tmp/zenn-dashboard.png を読み込み
# 以下のプロンプトでデータ抽出:
```

### LLM解析プロンプト

```
このZennダッシュボードのスクリーンショットから以下のデータを抽出してJSON形式で返してください:

{
  "total": {
    "pv": 累計PV数（数値）,
    "likes": 累計スキ数（数値）,
    "followers": フォロワー数（数値）
  },
  "articles": [
    {
      "slug": "記事スラッグ",
      "pv": PV数（数値）,
      "likes": スキ数（数値）
    }
  ]
}

注意:
- PV数が表示されていない場合は null を返す
- スクリーンショットに表示されている記事だけを抽出する
- 数値のカンマは除去する（例: "1,234" -> 1234）
```

### 自動実行（土曜 analyze モード）

毎週土曜17:00に以下が自動実行されます:

1. `zenn-engine.sh` が `mode-analyze.md` を実行
2. Claude が Playwright スクリプトを呼び出し
3. スクリーンショット取得 → LLM解析 → metrics.json 更新
4. 土曜レポート生成 → Telegram 通知

## トラブルシューティング

### 問題1: 環境変数が設定されていない

**エラー**:
```
環境変数 ZENN_EMAIL / ZENN_PASSWORD が設定されていません
```

**解決策**:
```bash
export ZENN_EMAIL="your-github-email@example.com"
export ZENN_PASSWORD="your-github-password"

# 永続化（推奨）
echo 'export ZENN_EMAIL="your-email"' >> ~/.zshrc
echo 'export ZENN_PASSWORD="your-password"' >> ~/.zshrc
source ~/.zshrc
```

### 問題2: Playwright がインストールされていない

**エラー**:
```
Cannot find module 'playwright'
```

**解決策**:
```bash
cd ~/repository/zenn-engine
npm install playwright
```

### 問題3: ログインに失敗する

**原因**:
- 2要素認証が有効になっている
- GitHub パスワードが間違っている

**解決策**:
1. GitHub の Personal Access Token を使用
2. Playwright の `storageState` で Cookie を永続化

```javascript
// Cookie 保存（初回ログイン後）
await page.context().storageState({ path: 'auth.json' });

// Cookie 読み込み（2回目以降）
const browser = await chromium.launch();
const context = await browser.newContext({ storageState: 'auth.json' });
const page = await context.newPage();
```

## 次のステップ

### Phase 1 完了項目

- ✅ Playwright スクリプト作成
- ✅ mode-analyze.md にPlaywright実行手順追加
- ✅ STRATEGY.md / MEMORY.md 更新
- ✅ セキュリティ考慮（環境変数管理）

### Phase 2 実装予定

- [ ] Cookie 永続化（2要素認証対応）
- [ ] エラーハンドリング強化（ログイン失敗時のリトライ）
- [ ] metrics.json の自動バックアップ
- [ ] PV推移グラフの生成（オプション）

### Phase 3 最適化予定

- [ ] スクリーンショット解析の精度向上
- [ ] 複数記事ページの自動スクロール
- [ ] 実行時間の短縮（並列処理）

## 参考資料

- [Playwright公式ドキュメント](https://playwright.dev/)
- [Claude Code Playwright MCP](https://modelcontextprotocol.io/clients/claude-code)
- [Zennダッシュボード統計機能](https://zenn.dev/spiegel/articles/20211225-zenn-analytics)

## 更新履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-04-01 | 初版作成（Playwright実装完了） |
