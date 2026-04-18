/**
 * publish-adapter.mjs (zenn-agent版)
 *
 * zenn-agent固有の公開ロジック（frontmatter更新 + Git push）。
 * ~/.claude/bots/lib/publish-core.mjs が要求するアダプターインターフェースを実装する。
 */

import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync, spawnSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '..');

// === ユーティリティ ========================================

function log(msg) {
  const now = new Date();
  const ts = now.toISOString().replace('T', ' ').substring(0, 19);
  console.log(`[${ts}] ${msg}`);
}

function readArticle(filepath) {
  const fullPath = join(ROOT_DIR, filepath);
  try {
    return readFileSync(fullPath, 'utf-8');
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

// === アダプター実装 ========================================

export default {
  getWorkDir: () => ROOT_DIR,

  getConfigPath: () => `/Users/okamotoryuya/.claude/bots/zenn-agent/config.sh`,

  getCommitPrefix: () => 'zenn',

  getCheckInterval: () => 60 * 60 * 1000, // 1時間

  getGitCommitArgs: (entry, success) => 'data/queue.json',

  shouldStopAfterPublish: () => true, // 1日1本制限

  checkDailyLimit: (queue) => {
    const today = new Date().toISOString().slice(0, 10);
    return queue.queue.some(e =>
      e.status === 'published' &&
      e.published_at &&
      e.published_at.slice(0, 10) === today
    );
  },

  publishArticle: async (entry, dryRun = false) => {
    log(`公開処理開始: "${entry.title}"`);

    if (dryRun) {
      log('[dry-run] 実際の公開はスキップします');
      return { success: true, url: 'https://zenn.dev/dry-run' };
    }

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
    spawnSync('git', ['add', entry.filepath], { cwd: ROOT_DIR, stdio: 'inherit' });
    log('git add 完了');

    const commitMessage = `zenn: publish "${entry.title}"`;
    const commitResult = spawnSync('git', ['commit', '-m', commitMessage], { cwd: ROOT_DIR, stdio: 'pipe' });
    if (commitResult.status !== 0) {
      const stderr = commitResult.stderr?.toString() ?? '';
      const stdout = commitResult.stdout?.toString() ?? '';
      if (stderr.includes('nothing to commit') || stdout.includes('nothing to commit')) {
        log('git commit スキップ: 変更なし（既に published: true）');
      } else {
        throw new Error(`git commit failed with exit code ${commitResult.status}: ${stderr}`);
      }
    } else {
      log('git commit 完了');
    }

    execSync('git push origin main', { cwd: ROOT_DIR, stdio: 'inherit' });
    log('git push 完了');

    // 5. Zenn URL を生成（slug はファイル名から抽出）
    const slug = entry.filename.replace(/\.md$/, '');
    let zennUsername = 'ryuryu_game';
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
  },

  // zennはfrontmatter更新+pushが publishArticle 内で完結するため
  // onPublishSuccess/onPublishFailed は不要

  getSuccessTelegramMessage: (entry, result) => {
    let message = `✅ <b>Zenn記事を自動公開しました！</b>\n\n`;
    message += `<b>タイトル:</b>\n${entry.title}\n\n`;
    message += `<b>URL:</b>\n${result.url}\n\n`;
    message += `<b>公開日時:</b>\n${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })}`;
    return message;
  },

  getFailureTelegramMessage: (entry, result) => {
    let message = `❌ <b>Zenn自動公開に失敗しました</b>\n\n`;
    message += `<b>記事:</b> ${entry.filename}\n${entry.title}\n\n`;
    message += `<b>エラー:</b>\n${result.error}\n\n`;
    message += `<b>対処:</b>\n手動で published: true に変更してpushしてください`;
    return message;
  },
};
