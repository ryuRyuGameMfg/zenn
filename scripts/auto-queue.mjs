/**
 * auto-queue.mjs (Zenn版)
 *
 * 日次ドラフトスキャナー: articles/ から published=false の記事を検出し、
 * 次の金曜・土曜17:00に自動スケジュールしてqueue.jsonに追加する。
 *
 * 実行タイミング: 毎日深夜02:00（launchdで自動実行）
 *
 * 使い方（手動テスト）:
 *   node scripts/auto-queue.mjs [--dry-run]
 */

import { readFileSync, writeFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '..');
const QUEUE_FILE = join(ROOT_DIR, 'queue.json');
const ARTICLES_DIR = join(ROOT_DIR, 'articles');

// === ユーティリティ ========================================

function log(msg) {
  const now = new Date();
  const ts = now.toISOString().replace('T', ' ').substring(0, 19);
  console.log(`[${ts}] ${msg}`);
}

function readQueue() {
  try {
    const json = readFileSync(QUEUE_FILE, 'utf-8');
    return JSON.parse(json);
  } catch (err) {
    log(`queue.json読み込みエラー: ${err.message}`);
    process.exit(1);
  }
}

function writeQueue(queue) {
  try {
    const json = JSON.stringify(queue, null, 2);
    writeFileSync(QUEUE_FILE, json, 'utf-8');
  } catch (err) {
    log(`queue.json書き込みエラー: ${err.message}`);
    process.exit(1);
  }
}

function parseFrontmatter(content) {
  const lines = content.split('\n');
  if (lines[0] !== '---') return null;

  const frontmatter = {};
  let i = 1;
  while (i < lines.length && lines[i] !== '---') {
    const line = lines[i].trim();
    if (line) {
      const match = line.match(/^(\w+):\s*(.+)$/);
      if (match) {
        const key = match[1];
        let value = match[2];

        // boolean変換
        if (value === 'true') value = true;
        else if (value === 'false') value = false;
        // 配列変換
        else if (value.startsWith('[') && value.endsWith(']')) {
          value = value.slice(1, -1).split(',').map(s => s.trim().replace(/^["']|["']$/g, ''));
        }
        // 文字列のクオート除去
        else if ((value.startsWith('"') && value.endsWith('"')) ||
                 (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }

        frontmatter[key] = value;
      }
    }
    i++;
  }

  return frontmatter;
}

function readArticle(filename) {
  const filepath = join(ARTICLES_DIR, filename);
  try {
    const content = readFileSync(filepath, 'utf-8');
    const frontmatter = parseFrontmatter(content);

    if (!frontmatter) return null;

    return {
      filename,
      filepath: `articles/${filename}`,
      title: frontmatter.title || filename.replace(/\.md$/, ''),
      published: frontmatter.published !== false, // デフォルトtrue
      emoji: frontmatter.emoji || '📝',
      type: frontmatter.type || 'tech',
      topics: frontmatter.topics || [],
    };
  } catch (err) {
    return null;
  }
}

// === 日付計算 =============================================

/**
 * 次の金曜 or 土曜 17:00 を計算
 *
 * ロジック:
 * - 最後にスケジュールされたのが金曜 → 次は土曜
 * - 最後にスケジュールされたのが土曜 → 次は金曜
 * - 既存スロットがない → 次の金曜
 * - 厳密に金→土→金→土と交互にスケジュール
 */
function calculateNextSlot(existingSlots = []) {
  const now = new Date();
  const FRIDAY = 5;
  const SATURDAY = 6;
  const TARGET_HOUR = 17;
  const TARGET_MINUTE = 0;

  // 基準時刻
  let candidate = new Date();
  candidate.setHours(TARGET_HOUR, TARGET_MINUTE, 0, 0);

  // 既存スロットがない場合は次の金曜を返す
  if (existingSlots.length === 0) {
    const currentDay = now.getDay();
    const daysUntilFriday = (FRIDAY - currentDay + 7) % 7;
    const nextFriday = new Date(candidate);
    nextFriday.setDate(nextFriday.getDate() + (daysUntilFriday === 0 ? 7 : daysUntilFriday));

    if (nextFriday <= now) {
      nextFriday.setDate(nextFriday.getDate() + 7);
    }

    return nextFriday.toISOString();
  }

  // 最後にスケジュールされたスロットを取得
  const sortedSlots = existingSlots
    .map(s => new Date(s))
    .sort((a, b) => a - b);

  const lastSlot = sortedSlots[sortedSlots.length - 1];
  const lastDay = lastSlot.getDay();

  // 最後が金曜なら次は土曜（+1日）
  // 最後が土曜なら次は金曜（+6日）
  const nextSlot = new Date(lastSlot);

  if (lastDay === FRIDAY) {
    // 金曜 → 土曜（+1日）
    nextSlot.setDate(nextSlot.getDate() + 1);
  } else if (lastDay === SATURDAY) {
    // 土曜 → 金曜（+6日）
    nextSlot.setDate(nextSlot.getDate() + 6);
  } else {
    // 想定外の曜日（エラーケース）
    // 次の金曜を返す
    const currentDay = nextSlot.getDay();
    const daysUntilFriday = (FRIDAY - currentDay + 7) % 7;
    nextSlot.setDate(nextSlot.getDate() + (daysUntilFriday === 0 ? 7 : daysUntilFriday));
  }

  return nextSlot.toISOString();
}

// === スキャン処理 ==========================================

function scanDrafts(queue) {
  const drafts = [];

  try {
    const files = readdirSync(ARTICLES_DIR).filter(f => f.endsWith('.md'));

    for (const file of files) {
      const article = readArticle(file);
      if (!article) continue;

      // published=false かつ queue未登録
      if (article.published) continue;

      const alreadyQueued = queue.queue.some(q => q.filepath === article.filepath);
      if (alreadyQueued) continue;

      drafts.push({
        filename: article.filename,
        filepath: article.filepath,
        title: article.title,
        emoji: article.emoji,
        type: article.type,
        topics: article.topics,
      });
    }
  } catch (err) {
    log(`記事スキャンエラー: ${err.message}`);
    return [];
  }

  // ファイル名でソート（作成順）
  drafts.sort((a, b) => a.filename.localeCompare(b.filename));

  return drafts;
}

// === キュー追加 ============================================

function addToQueue(queue, drafts, dryRun = false) {
  if (drafts.length === 0) {
    log('新規ドラフトなし');
    return 0;
  }

  log(`新規ドラフト ${drafts.length}件 を検出`);

  let addedCount = 0;

  // 既存キューのスケジュール一覧
  const existingSlots = queue.queue
    .filter(q => q.status === 'queued')
    .map(q => q.scheduled_at);

  for (const draft of drafts) {
    const scheduled_at = calculateNextSlot(existingSlots);
    existingSlots.push(scheduled_at); // 次の計算に反映

    const queueEntry = {
      filepath: draft.filepath,
      filename: draft.filename,
      title: draft.title,
      scheduled_at,
      status: 'queued',
      queued_at: new Date().toISOString(),
      priority: queue.queue.length + 1,
    };

    log(`  "${draft.title}" → ${scheduled_at}`);

    if (!dryRun) {
      queue.queue.push(queueEntry);
    }

    addedCount++;
  }

  return addedCount;
}

// === Git コミット ==========================================

function gitCommit(addedCount, dryRun = false) {
  if (addedCount === 0 || dryRun) return;

  try {
    execSync('git add queue.json', { cwd: ROOT_DIR, stdio: 'inherit' });

    const message = `zenn: auto-queue added ${addedCount} article${addedCount > 1 ? 's' : ''} to publish queue`;
    execSync(`git commit -m "${message}"`, { cwd: ROOT_DIR, stdio: 'inherit' });

    log('Gitコミット完了');
  } catch (err) {
    log(`Gitコミットエラー: ${err.message}`);
  }
}

// === Telegram通知 ==========================================

function sendTelegram(addedCount, queue, dryRun = false) {
  if (addedCount === 0 || dryRun) return;

  try {
    const addedEntries = queue.queue.slice(-addedCount);

    let message = `📝 <b>Zenn記事 ${addedCount}件 を公開キューに追加</b>\n\n`;

    addedEntries.forEach((entry, idx) => {
      const date = new Date(entry.scheduled_at);
      const dayName = ['日', '月', '火', '水', '木', '金', '土'][date.getDay()];
      const dateStr = `${date.getMonth() + 1}/${date.getDate()}(${dayName}) ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;

      message += `<b>${idx + 1}.</b> ${entry.title}\n`;
      message += `   📅 ${dateStr}\n\n`;
    });

    const scriptPath = join(ROOT_DIR, 'scripts/telegram-notify.sh');
    execSync(`bash "${scriptPath}" "${message.replace(/"/g, '\\"')}"`, { cwd: ROOT_DIR });

    log('Telegram通知送信完了');
  } catch (err) {
    log(`Telegram通知エラー: ${err.message}`);
  }
}

// === メイン ===============================================

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  if (dryRun) {
    log('[dry-run] テストモード: 実際の変更は行いません');
  }

  log('auto-queue 開始 (Zenn版)');

  // 1. queue.json 読み込み
  const queue = readQueue();

  // 2. ドラフトスキャン
  const drafts = scanDrafts(queue);

  // 3. キューに追加
  const addedCount = addToQueue(queue, drafts, dryRun);

  // 4. queue.json 保存
  if (!dryRun && addedCount > 0) {
    queue.last_scan = new Date().toISOString();
    writeQueue(queue);
    log('queue.json 更新完了');
  }

  // 5. Git コミット
  gitCommit(addedCount, dryRun);

  // 6. Telegram 通知
  sendTelegram(addedCount, queue, dryRun);

  log(`auto-queue 完了: ${addedCount}件追加`);
}

main();
