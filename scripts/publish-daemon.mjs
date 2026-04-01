/**
 * publish-daemon.mjs (Zenn版)
 *
 * 常駐公開デーモン: queue.jsonを60秒ごとに監視し、
 * scheduled_at が現在時刻を過ぎた記事を自動的にZenn.devに公開する。
 *
 * 公開方法: frontmatter の published: false → true に変更 + Git push
 *
 * 実行タイミング: 常駐（launchd KeepAliveで自動再起動）
 *
 * エラーハンドリング:
 * - 公開失敗時は最大3回リトライ（即時/5分後/15分後）
 * - 3回失敗後は status="failed" にマークしてTelegram通知
 *
 * 使い方（手動テスト）:
 *   node scripts/publish-daemon.mjs [--dry-run] [--once]
 */

import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '..');
const QUEUE_FILE = join(ROOT_DIR, 'data', 'queue.json');
const CHECK_INTERVAL = 60 * 60 * 1000; // 1時間

// リトライ設定
const RETRY_DELAYS = [0, 5 * 60 * 1000, 15 * 60 * 1000]; // 即時, 5分後, 15分後
const MAX_RETRY = 3;

// === ユーティリティ ========================================

function log(msg) {
  const now = new Date();
  const ts = now.toISOString().replace('T', ' ').substring(0, 19);
  console.log(`[${ts}] ${msg}`);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function readQueue() {
  try {
    const json = readFileSync(QUEUE_FILE, 'utf-8');
    return JSON.parse(json);
  } catch (err) {
    log(`queue.json読み込みエラー: ${err.message}`);
    return null;
  }
}

function writeQueue(queue) {
  try {
    const json = JSON.stringify(queue, null, 2);
    writeFileSync(QUEUE_FILE, json, 'utf-8');
  } catch (err) {
    log(`queue.json書き込みエラー: ${err.message}`);
  }
}

function readArticle(filepath) {
  const fullPath = join(ROOT_DIR, filepath);
  try {
    const content = readFileSync(fullPath, 'utf-8');
    return content;
  } catch (err) {
    throw new Error(`記事ファイル読み込みエラー: ${err.message}`);
  }
}

function writeArticle(filepath, content) {
  const fullPath = join(ROOT_DIR, filepath);
  try {
    writeFileSync(fullPath, content, 'utf-8');
  } catch (err) {
    throw new Error(`記事ファイル書き込みエラー: ${err.message}`);
  }
}

// === 公開対象記事の検出 ====================================

function findDueArticles(queue) {
  const now = new Date();
  const dueArticles = [];

  for (const entry of queue.queue) {
    if (entry.status !== 'queued') continue;

    const scheduledAt = new Date(entry.scheduled_at);
    if (scheduledAt <= now) {
      dueArticles.push(entry);
    }
  }

  return dueArticles;
}

// === Zenn公開処理（Git push版） ============================

async function publishArticle(entry, dryRun = false) {
  log(`公開処理開始: "${entry.title}"`);

  if (dryRun) {
    log('[dry-run] 実際の公開はスキップします');
    return { success: true, url: 'https://zenn.dev/dry-run' };
  }

  try {
    // 1. 記事ファイルを読み込み
    const content = readArticle(entry.filepath);

    // 2. frontmatter の published を true に変更
    const lines = content.split('\n');
    if (lines[0] !== '---') {
      throw new Error('frontmatter が見つかりません');
    }

    let updatedLines = [];
    let inFrontmatter = false;
    let publishedUpdated = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (i === 0 && line === '---') {
        inFrontmatter = true;
        updatedLines.push(line);
        continue;
      }

      if (inFrontmatter && line === '---') {
        if (!publishedUpdated) {
          // published フィールドがなかった場合は追加
          updatedLines.push('published: true');
        }
        inFrontmatter = false;
        updatedLines.push(line);
        continue;
      }

      if (inFrontmatter && line.startsWith('published:')) {
        updatedLines.push('published: true');
        publishedUpdated = true;
        continue;
      }

      updatedLines.push(line);
    }

    const updatedContent = updatedLines.join('\n');

    // 3. 記事ファイルに書き込み
    writeArticle(entry.filepath, updatedContent);
    log(`published: true に更新しました`);

    // 4. Git add + commit + push
    execSync(`git add ${entry.filepath}`, { cwd: ROOT_DIR, stdio: 'inherit' });
    log('git add 完了');

    const commitMessage = `zenn: publish "${entry.title}"`;
    execSync(`git commit -m "${commitMessage}"`, { cwd: ROOT_DIR, stdio: 'inherit' });
    log('git commit 完了');

    execSync('git push origin main', { cwd: ROOT_DIR, stdio: 'inherit' });
    log('git push 完了');

    // 5. Zenn URL を生成（slug はファイル名から抽出）
    const slug = entry.filename.replace(/\.md$/, '');
    // zenn.dev のユーザー名を取得（.git/config から）
    let zennUsername = 'ryuryu_game'; // デフォルト
    try {
      const gitConfig = execSync('git config --get remote.origin.url', { cwd: ROOT_DIR }).toString().trim();
      const match = gitConfig.match(/github\.com[:/](.+?)\/zenn/);
      if (match) {
        zennUsername = match[1];
      }
    } catch {}

    const publishedUrl = `https://zenn.dev/${zennUsername}/articles/${slug}`;
    log(`公開完了! URL: ${publishedUrl}`);

    return { success: true, url: publishedUrl };

  } catch (error) {
    throw error;
  }
}

// === リトライ処理 ==========================================

async function publishWithRetry(entry, queue, dryRun = false) {
  let lastError = null;

  for (let attempt = 0; attempt < MAX_RETRY; attempt++) {
    if (attempt > 0) {
      const delayMs = RETRY_DELAYS[attempt];
      log(`リトライ ${attempt + 1}/${MAX_RETRY} を ${delayMs / 60000}分後に実行します...`);
      await sleep(delayMs);
    }

    try {
      const result = await publishArticle(entry, dryRun);

      // 成功: queue.json を更新
      entry.status = 'published';
      entry.published_at = new Date().toISOString();
      entry.published_url = result.url;
      writeQueue(queue);

      return { success: true, url: result.url };

    } catch (error) {
      lastError = error;
      log(`公開失敗 (試行 ${attempt + 1}/${MAX_RETRY}): ${error.message}`);
    }
  }

  // 3回失敗後
  log(`公開失敗（最大リトライ到達）: "${entry.title}"`);

  entry.status = 'failed';
  entry.last_publish_error = lastError.message;
  writeQueue(queue);

  return { success: false, error: lastError.message };
}

// === Git コミット（queue.json） ============================

function gitCommitQueue(entry, success, dryRun = false) {
  if (dryRun) return;

  try {
    execSync('git add data/queue.json', { cwd: ROOT_DIR, stdio: 'inherit' });

    const status = success ? 'published' : 'failed';
    const message = `zenn: auto-publish ${status} - ${entry.filename}`;
    execSync(`git commit -m "${message}"`, { cwd: ROOT_DIR, stdio: 'inherit' });

    log('queue.json Gitコミット完了');
  } catch (err) {
    log(`Gitコミットエラー: ${err.message}`);
  }
}

// === Telegram通知 ==========================================

function sendTelegram(entry, result, dryRun = false) {
  if (dryRun) return;

  try {
    let message = '';

    if (result.success) {
      message = `✅ <b>Zenn記事を自動公開しました！</b>\n\n`;
      message += `<b>タイトル:</b>\n${entry.title}\n\n`;
      message += `<b>URL:</b>\n${result.url}\n\n`;
      message += `<b>公開日時:</b>\n${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })}`;
    } else {
      message = `❌ <b>Zenn自動公開に失敗しました</b>\n\n`;
      message += `<b>記事:</b> ${entry.filename}\n${entry.title}\n\n`;
      message += `<b>エラー:</b>\n${result.error}\n\n`;
      message += `<b>対処:</b>\n手動で published: true に変更してpushしてください`;
    }

    const scriptPath = join(ROOT_DIR, 'scripts/telegram-notify.sh');
    execSync(`bash "${scriptPath}" "${message.replace(/"/g, '\\"')}"`, { cwd: ROOT_DIR });

    log('Telegram通知送信完了');
  } catch (err) {
    log(`Telegram通知エラー: ${err.message}`);
  }
}

// === メインループ ==========================================

async function checkAndPublish(dryRun = false) {
  const queue = readQueue();
  if (!queue) return;

  const dueArticles = findDueArticles(queue);

  if (dueArticles.length === 0) {
    log('公開対象記事なし');
    return;
  }

  log(`公開対象記事 ${dueArticles.length}件 を検出`);

  // 1日1本制限: 本日すでに公開済みの記事があればスキップ
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const alreadyPublishedToday = queue.queue.some(e =>
    e.status === 'published' &&
    e.published_at &&
    e.published_at.slice(0, 10) === today
  );
  if (alreadyPublishedToday) {
    log('本日はすでに1本公開済みのため、残りは翌日以降に公開します');
    return;
  }

  for (const entry of dueArticles) {
    // status を "publishing" に更新（ロック）
    entry.status = 'publishing';
    writeQueue(queue);

    // 公開処理（リトライ含む）
    const result = await publishWithRetry(entry, queue, dryRun);

    // Git コミット（queue.json）
    gitCommitQueue(entry, result.success, dryRun);

    // Telegram 通知
    sendTelegram(entry, result, dryRun);

    // 1日1本制限: 1本公開したらループを終了
    if (result.success) {
      log('1日1本制限のため、残りの記事は次回以降に公開します');
      break;
    }
  }
}

// === メイン ===============================================

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const once = process.argv.includes('--once');

  if (dryRun) {
    log('[dry-run] テストモード: 実際の公開は行いません');
  }

  log('publish-daemon 起動 (Zenn版)');

  while (true) {
    try {
      await checkAndPublish(dryRun);
    } catch (err) {
      log(`エラー: ${err.message}`);
    }

    if (once) {
      log('--once モードのため終了します');
      break;
    }

    await sleep(CHECK_INTERVAL);
  }
}

main();
