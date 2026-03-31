# Zenn Analytics Fetcher - Playwright実装計画

## 概要

Playwright MCP を使用してZennダッシュボードから統計情報（PV、スキ数、フォロワー数）を自動取得するスクリプト。

## アーキテクチャ

```
[zenn-engine.sh] → [fetch-zenn-analytics.js] → [Playwright MCP]
                                                        ↓
                                              [Zenn Dashboard]
                                                        ↓
                                              [スクリーンショット]
                                                        ↓
                                              [LLM解析（Claude）]
                                                        ↓
                                              [metrics.json更新]
```

## 実装ステップ

### Phase 1: Playwrightでダッシュボードアクセス

**目標**: ログイン→ダッシュボード閲覧→スクリーンショット取得

**実装:**
```javascript
// scripts/fetch-zenn-analytics.js
const { chromium } = require('playwright');

async function fetchZennAnalytics() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  // 1. Zennログイン（GitHub OAuth）
  await page.goto('https://zenn.dev/dashboard/login');
  // TODO: ログイン処理（認証情報は環境変数から取得）

  // 2. ダッシュボードへ移動
  await page.goto('https://zenn.dev/dashboard/analytics');
  await page.waitForSelector('.analytics-table'); // セレクタ要確認

  // 3. スクリーンショット取得
  const screenshot = await page.screenshot({ fullPage: true });
  await fs.writeFile('/tmp/zenn-dashboard.png', screenshot);

  await browser.close();
  return '/tmp/zenn-dashboard.png';
}
```

### Phase 2: スクリーンショットからデータ抽出

**目標**: 画像→テキスト変換→JSON化

**実装:**
```javascript
async function extractMetrics(screenshotPath) {
  // Claude Code の Read ツールで画像読み込み
  // LLMにプロンプトでデータ抽出を依頼
  const prompt = `
    このZennダッシュボードのスクリーンショットから以下のデータを抽出してJSON形式で返してください:
    - 記事ごとのPV数（slug: PV数のマップ）
    - 累計PV
    - 累計スキ数
    - フォロワー数
  `;

  // Task tool で専用エージェント（csv-analyzer等）を呼び出し
  // または直接Read + LLM解析
}
```

### Phase 3: metrics.json 更新

**目標**: 抽出データを構造化して保存

**フォーマット:**
```json
{
  "last_updated": "2026-04-05T17:00:00Z",
  "total": {
    "pv": 10234,
    "likes": 350,
    "followers": 37
  },
  "articles": [
    {
      "slug": "2026-03-26-unity-claude-code-auto-test-generation",
      "pv": 1234,
      "likes": 26,
      "published_at": "2026-03-26"
    }
  ]
}
```

## 認証方法の検討

### オプション1: GitHub OAuth（推奨）
- Playwrightで自動ログイン
- 認証情報は環境変数（.env）に格納
- セキュリティ: permissions.deny で保護

### オプション2: Cookie永続化
- 初回手動ログイン→Cookie保存
- 2回目以降は保存Cookieで認証
- 定期的な再認証が必要

### オプション3: API Token（未確認）
- Zenn公式API Tokenがあれば使用
- 調査が必要

## セキュリティ考慮事項

1. **認証情報の保護**
   - `.env` に格納（permissions.deny で保護済み）
   - `~/.zenn-credentials` を使用しない（漏洩リスク）

2. **スクリーンショットの扱い**
   - `/tmp/` に一時保存→解析後削除
   - Git管理対象外

3. **実行頻度**
   - 週1回（土曜analyze）のみ実行
   - レート制限を考慮

## 実装優先度

**High（必須）:**
- [ ] Playwright基本実装（ログイン→スクリーンショット）
- [ ] LLM解析（画像→JSON）
- [ ] metrics.json更新

**Medium（推奨）:**
- [ ] エラーハンドリング（ログイン失敗、タイムアウト）
- [ ] 差分検出（前回との比較）

**Low（オプション）:**
- [ ] リトライロジック
- [ ] 複数アカウント対応

## テスト計画

### 手動テスト
```bash
# 1. スクリプト実行
node ~/repository/zenn-engine/scripts/fetch-zenn-analytics.js

# 2. スクリーンショット確認
open /tmp/zenn-dashboard.png

# 3. metrics.json確認
cat ~/repository/zenn-engine/memory/metrics.json | jq
```

### 自動テスト（土曜17:00）
```bash
# zenn-engine.sh の analyze モードで実行
bash ~/repository/zenn-engine/zenn-engine.sh --dry-run
```

## 次のステップ

1. **ダッシュボードHTML構造調査**（手動）
   - セレクタ特定（.analytics-table等）
   - データ表示形式の確認

2. **Playwright実装**（Phase 1）
   - ログイン処理
   - スクリーンショット取得

3. **LLM解析実装**（Phase 2）
   - 画像読み込み
   - データ抽出プロンプト

4. **metrics.json統合**（Phase 3）
   - 既存フォーマットに統合
   - analyze/improve モードで活用

## 参考資料

- [Playwright公式ドキュメント](https://playwright.dev/)
- [Claude Code Playwright MCP](https://modelcontextprotocol.io/clients/claude-code)
- [Zennダッシュボード統計機能](https://zenn.dev/spiegel/articles/20211225-zenn-analytics)
