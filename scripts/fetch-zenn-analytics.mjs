#!/usr/bin/env node
// fetch-zenn-analytics.mjs
// Playwright MCP を使用してZennダッシュボードからPV統計を取得

import { chromium } from 'playwright';
import fs from 'fs/promises';
import path from 'path';

const WORK_DIR = process.env.HOME + '/repository/zenn-agent';
const METRICS_FILE = path.join(WORK_DIR, 'memory/metrics.json');
const SCREENSHOT_PATH = '/tmp/zenn-dashboard.png';

// 環境変数から認証情報を取得（セキュリティ考慮）
const ZENN_EMAIL = process.env.ZENN_EMAIL;
const ZENN_PASSWORD = process.env.ZENN_PASSWORD;

/**
 * Phase 1: Playwrightでダッシュボードアクセス
 */
async function fetchDashboardScreenshot() {
  console.log('[Phase 1] Playwright起動...');

  const browser = await chromium.launch({
    headless: true,
    // デバッグ用: headless: false で実際のブラウザ動作を確認可能
  });

  const page = await browser.newPage();

  try {
    // 1. Zennダッシュボードへ直接アクセス（認証状態確認）
    console.log('[Phase 1] Zennダッシュボードにアクセス...');
    await page.goto('https://zenn.dev/dashboard/analytics', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    // 2. ログインページにリダイレクトされた場合はログイン処理
    const currentUrl = page.url();
    if (currentUrl.includes('/login') || currentUrl.includes('/enter')) {
      console.log('[Phase 1] ログインが必要です。GitHub OAuthでログイン...');

      if (!ZENN_EMAIL || !ZENN_PASSWORD) {
        throw new Error('環境変数 ZENN_EMAIL / ZENN_PASSWORD が設定されていません');
      }

      // GitHub OAuth ログインボタンをクリック
      await page.click('a[href*="github"]', { timeout: 5000 });
      await page.waitForNavigation({ waitUntil: 'networkidle' });

      // GitHubログインフォーム入力
      await page.fill('input[name="login"]', ZENN_EMAIL);
      await page.fill('input[name="password"]', ZENN_PASSWORD);
      await page.click('input[type="submit"]');

      // ダッシュボードへの遷移を待機
      await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 });

      // 再度ダッシュボードへ移動
      await page.goto('https://zenn.dev/dashboard/analytics', {
        waitUntil: 'networkidle',
        timeout: 30000
      });
    }

    console.log('[Phase 1] ダッシュボード表示完了');

    // 3. 統計テーブルの読み込み待機（セレクタは要確認）
    try {
      // Zennダッシュボードの主要要素を待機（複数候補を試行）
      await Promise.race([
        page.waitForSelector('[class*="analytics"]', { timeout: 10000 }),
        page.waitForSelector('[class*="stats"]', { timeout: 10000 }),
        page.waitForSelector('table', { timeout: 10000 }),
      ]);
      console.log('[Phase 1] 統計データ読み込み完了');
    } catch (err) {
      console.warn('[Phase 1] 統計セレクタ待機タイムアウト（続行）');
    }

    // 4. フルページスクリーンショット取得
    console.log('[Phase 1] スクリーンショット撮影...');
    await page.screenshot({
      path: SCREENSHOT_PATH,
      fullPage: true
    });

    console.log(`[Phase 1] スクリーンショット保存: ${SCREENSHOT_PATH}`);

  } catch (error) {
    console.error('[Phase 1] エラー:', error.message);
    throw error;
  } finally {
    await browser.close();
  }

  return SCREENSHOT_PATH;
}

/**
 * Phase 2: スクリーンショットからデータ抽出（LLM解析）
 * NOTE: この部分はClaude Code経由で実行する必要がある
 */
async function extractMetricsFromScreenshot(screenshotPath) {
  console.log('[Phase 2] LLM解析はClaude Code経由で実行します');
  console.log(`[Phase 2] スクリーンショット: ${screenshotPath}`);
  console.log('[Phase 2] 次のステップ: claude コマンドでReadツールを使って画像を読み込み、データ抽出プロンプトを実行してください');

  // LLM解析のプロンプト例を出力
  const extractPrompt = `
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
`;

  console.log('\n=== LLM抽出プロンプト ===');
  console.log(extractPrompt);
  console.log('========================\n');

  return null; // LLM解析結果は手動で取得
}

/**
 * Phase 3: metrics.json 更新
 */
async function updateMetricsJson(extractedData) {
  console.log('[Phase 3] metrics.json更新...');

  if (!extractedData) {
    console.warn('[Phase 3] 抽出データがnullのため、metrics.json更新をスキップ');
    return;
  }

  // 既存のmetrics.jsonを読み込み（存在しない場合は空オブジェクト）
  let metrics = {};
  try {
    const metricsContent = await fs.readFile(METRICS_FILE, 'utf-8');
    metrics = JSON.parse(metricsContent);
  } catch (err) {
    console.log('[Phase 3] metrics.json が存在しないため新規作成');
    metrics = { articles: [] };
  }

  // データをマージ
  metrics.last_updated = new Date().toISOString();
  metrics.total = extractedData.total || metrics.total || {};

  // 記事データをマージ（既存データを保持しつつ更新）
  if (extractedData.articles) {
    const articleMap = new Map();

    // 既存記事をマップに登録
    if (metrics.articles) {
      metrics.articles.forEach(article => {
        articleMap.set(article.slug, article);
      });
    }

    // 新規データで更新
    extractedData.articles.forEach(article => {
      articleMap.set(article.slug, {
        ...articleMap.get(article.slug),
        ...article,
        last_updated: new Date().toISOString()
      });
    });

    metrics.articles = Array.from(articleMap.values());
  }

  // metrics.json に書き込み
  await fs.mkdir(path.dirname(METRICS_FILE), { recursive: true });
  await fs.writeFile(METRICS_FILE, JSON.stringify(metrics, null, 2), 'utf-8');

  console.log(`[Phase 3] metrics.json更新完了: ${METRICS_FILE}`);
  console.log(`[Phase 3] 累計PV: ${metrics.total.pv || 'N/A'}`);
  console.log(`[Phase 3] 累計スキ: ${metrics.total.likes || 'N/A'}`);
  console.log(`[Phase 3] フォロワー: ${metrics.total.followers || 'N/A'}`);
}

/**
 * メイン処理
 */
async function main() {
  console.log('=== Zenn Analytics Fetcher 起動 ===');
  console.log(`作業ディレクトリ: ${WORK_DIR}`);

  try {
    // Phase 1: スクリーンショット取得
    const screenshotPath = await fetchDashboardScreenshot();

    // Phase 2: LLM解析（手動実行が必要）
    await extractMetricsFromScreenshot(screenshotPath);

    // Phase 3: metrics.json更新（LLM解析後に手動実行）
    // const extractedData = { ... }; // LLM解析結果をここに貼り付け
    // await updateMetricsJson(extractedData);

    console.log('\n=== 次のステップ ===');
    console.log('1. スクリーンショットを確認: open /tmp/zenn-dashboard.png');
    console.log('2. Claude Codeで画像を読み込み、上記のプロンプトでデータ抽出');
    console.log('3. 抽出したJSONをこのスクリプトのupdateMetricsJson()に渡して実行');
    console.log('===================\n');

  } catch (error) {
    console.error('エラーが発生しました:', error);
    process.exit(1);
  }
}

// エントリポイント
main();
