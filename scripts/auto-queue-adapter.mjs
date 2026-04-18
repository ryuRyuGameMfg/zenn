/**
 * auto-queue-adapter.mjs (zenn-agent版)
 *
 * zenn-agent固有のスキャンロジック。
 * ~/.claude/bots/lib/auto-queue-core.mjs が要求するアダプターインターフェースを実装する。
 */

import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '..');
const ARTICLES_DIR = join(ROOT_DIR, 'articles');

// === ユーティリティ ========================================

function log(msg) {
  const now = new Date();
  const ts = now.toISOString().replace('T', ' ').substring(0, 19);
  console.log(`[${ts}] ${msg}`);
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

        if (value === 'true') value = true;
        else if (value === 'false') value = false;
        else if (value.startsWith('[') && value.endsWith(']')) {
          value = value.slice(1, -1).split(',').map(s => s.trim().replace(/^["']|["']$/g, ''));
        } else if ((value.startsWith('"') && value.endsWith('"')) ||
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
      published: frontmatter.published !== false,
      archived: frontmatter.archived === true,
      emoji: frontmatter.emoji || '📝',
      type: frontmatter.type || 'tech',
      topics: frontmatter.topics || [],
    };
  } catch (err) {
    return null;
  }
}

// === アダプター実装 ========================================

export default {
  getWorkDir: () => ROOT_DIR,

  getConfigPath: () => `/Users/okamotoryuya/.claude/bots/zenn-agent/config.sh`,

  getGitStageArgs: () => 'data/queue.json',

  getCommitPrefix: () => 'zenn',

  scanDrafts: (queue) => {
    const drafts = [];

    try {
      const files = readdirSync(ARTICLES_DIR).filter(f => f.endsWith('.md'));

      for (const file of files) {
        const article = readArticle(file);
        if (!article) continue;

        if (article.published) continue;
        if (article.archived) continue;

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
  },

  buildQueueEntry: (draft, scheduled_at, priority) => ({
    filepath: draft.filepath,
    filename: draft.filename,
    title: draft.title,
    scheduled_at,
    status: 'queued',
    queued_at: new Date().toISOString(),
    priority,
  }),

  // onDraftQueued は不要 (zennはfrontmatterで管理するためキュー追加時の副作用なし)

  getTelegramMessage: (addedCount, entries) => {
    let message = `📝 <b>Zenn記事 ${addedCount}件 を公開キューに追加</b>\n\n`;

    entries.forEach((entry, idx) => {
      const date = new Date(entry.scheduled_at);
      const dayName = ['日', '月', '火', '水', '木', '金', '土'][date.getDay()];
      const dateStr = `${date.getMonth() + 1}/${date.getDate()}(${dayName}) ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;

      message += `<b>${idx + 1}.</b> ${entry.title}\n`;
      message += `   📅 ${dateStr}\n\n`;
    });

    return message;
  },
};
