/**
 * migrate-naming.mjs
 *
 * articles/ 内のハッシュ型ファイル名を YYYY-MM-DD-{slug}.md 形式にリネームする。
 *
 * 対象: 16進数ハッシュ名のファイル（例: 01f28742eef652.md）
 * 除外: 既に YYYY-MM-DD- 形式で始まるファイル
 *
 * 使い方:
 *   node scripts/migrate-naming.mjs           # dry-run（デフォルト）
 *   node scripts/migrate-naming.mjs --execute # 実際に git mv でリネーム実行
 */

import { readFileSync, readdirSync } from 'fs';
import { join, dirname, basename } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '..');
const ARTICLES_DIR = join(ROOT_DIR, 'articles');

const IS_DRY_RUN = !process.argv.includes('--execute');

// === ユーティリティ ========================================

function log(msg) {
  console.log(msg);
}

/**
 * ハッシュ型ファイル名かどうかを判定する。
 * 16進数文字のみで構成された名前（拡張子除く）をハッシュ型と判定。
 */
function isHashFile(filename) {
  const name = basename(filename, '.md');
  return /^[0-9a-f]{10,}$/.test(name);
}

/**
 * ファイル先頭からfrontmatterを解析してオブジェクトを返す。
 * YAMLパーサーは使わず、シンプルな正規表現で処理。
 */
function parseFrontmatter(filePath) {
  try {
    const content = readFileSync(filePath, 'utf-8');
    const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!match) return {};

    const raw = match[1];
    const result = {};

    // title
    const titleMatch = raw.match(/^title:\s*["']?(.*?)["']?\s*$/m);
    if (titleMatch) result.title = titleMatch[1].replace(/^["']|["']$/g, '').trim();

    // published_at（"2026-01-13 18:00" 形式など）
    const pubAtMatch = raw.match(/^published_at:\s*["']?(\d{4}-\d{2}-\d{2})[^"'\n]*["']?/m);
    if (pubAtMatch) result.published_at = pubAtMatch[1];

    // topics（配列）
    const topicsMatch = raw.match(/^topics:\s*\[([^\]]*)\]/m);
    if (topicsMatch) {
      result.topics = topicsMatch[1]
        .split(',')
        .map(t => t.trim().replace(/^["']|["']$/g, ''));
    } else {
      // YAML block形式
      const topicsBlockMatch = raw.match(/^topics:\s*\n((?:\s+-\s+.*\n?)+)/m);
      if (topicsBlockMatch) {
        result.topics = topicsBlockMatch[1]
          .split('\n')
          .filter(l => l.trim().startsWith('-'))
          .map(l => l.replace(/^\s*-\s*/, '').replace(/^["']|["']$/g, '').trim());
      }
    }

    return result;
  } catch {
    return {};
  }
}

/**
 * git log から対象ファイルの初回コミット日を取得する。
 * @returns {string|null} "YYYY-MM-DD" 形式、または null
 */
function getGitInitialDate(filePath) {
  try {
    const rel = filePath.replace(ROOT_DIR + '/', '');
    const output = execSync(
      `git -C "${ROOT_DIR}" log --follow --format='%ai' -- "${rel}" | tail -1`,
      { encoding: 'utf-8' }
    ).trim();
    if (!output) return null;
    // "2026-01-13 18:00:00 +0900" → "2026-01-13"
    const match = output.match(/(\d{4}-\d{2}-\d{2})/);
    return match ? match[1] : null;
  } catch {
    return null;
  }
}

/**
 * 英語タイトルをkebab-caseのslugに変換する。
 */
function titleToSlug(title, hashName) {
  if (!title) return hashName;

  // 日本語タイトルから英語キーワードを抽出するマッピング
  const jaToEnMap = [
    [/Unity\s*エディタ拡張/gi, 'unity-editor-extension'],
    [/Unity/gi, 'unity'],
    [/エディタ拡張/gi, 'editor-extension'],
    [/開発効率/gi, 'dev-efficiency'],
    [/C#/gi, 'csharp'],
    [/async\/await/gi, 'async-await'],
    [/async/gi, 'async'],
    [/await/gi, 'await'],
    [/自動化/gi, 'automation'],
    [/全自動/gi, 'full-automation'],
    [/自律/gi, 'autonomous'],
    [/戦略/gi, 'strategy'],
    [/記事/gi, 'article'],
    [/完全ガイド/gi, 'complete-guide'],
    [/ガイド/gi, 'guide'],
    [/入門/gi, 'beginner'],
    [/実装/gi, 'implementation'],
    [/活用/gi, 'utilization'],
    [/解説/gi, 'explanation'],
    [/まとめ/gi, 'summary'],
    [/比較/gi, 'comparison'],
    [/分析/gi, 'analysis'],
    [/生成AI/gi, 'generative-ai'],
    [/AI/gi, 'ai'],
    [/ゲーム/gi, 'game'],
    [/セキュリティ/gi, 'security'],
    [/テスト/gi, 'test'],
    [/デプロイ/gi, 'deploy'],
    [/パフォーマンス/gi, 'performance'],
    [/最適化/gi, 'optimization'],
    [/システム/gi, 'system'],
    [/ツール/gi, 'tool'],
    [/機能/gi, 'feature'],
    [/設計/gi, 'design'],
    [/構築/gi, 'build'],
    [/管理/gi, 'management'],
    [/効率/gi, 'efficiency'],
    [/改善/gi, 'improvement'],
    [/開発/gi, 'development'],
    [/方法/gi, 'method'],
    [/技術/gi, 'tech'],
    [/手順/gi, 'steps'],
    [/注意点/gi, 'notes'],
    [/ポイント/gi, 'points'],
    [/仕組み/gi, 'mechanism'],
    [/理解/gi, 'understanding'],
    [/使い方/gi, 'usage'],
    [/紹介/gi, 'introduction'],
    [/Claude/gi, 'claude'],
    [/GitHub/gi, 'github'],
    [/Git/gi, 'git'],
    [/Docker/gi, 'docker'],
    [/Python/gi, 'python'],
    [/JavaScript/gi, 'javascript'],
    [/TypeScript/gi, 'typescript'],
    [/React/gi, 'react'],
    [/Node/gi, 'node'],
    [/API/gi, 'api'],
    [/LLM/gi, 'llm'],
    [/GPT/gi, 'gpt'],
    [/Zenn/gi, 'zenn'],
    [/note/gi, 'note'],
  ];

  let slug = title;

  // 日本語変換適用
  for (const [pattern, replacement] of jaToEnMap) {
    slug = slug.replace(pattern, ' ' + replacement + ' ');
  }

  // 残った日本語文字を除去
  slug = slug.replace(/[\u3000-\u9fff\uff00-\uffef]/g, ' ');

  // 英数字・ハイフン以外を除去してkebab-caseに
  slug = slug
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');

  // slug が空または短すぎる場合はハッシュ名を使用
  if (!slug || slug.length < 3) return hashName;

  // 最大60文字
  if (slug.length > 60) {
    slug = slug.substring(0, 60).replace(/-[^-]*$/, '');
  }

  return slug;
}

// === メイン処理 ==========================================

async function main() {
  log(`=== migrate-naming.mjs ===`);
  log(`モード: ${IS_DRY_RUN ? 'DRY-RUN（実際のリネームは行いません）' : 'EXECUTE（git mv でリネーム実行）'}`);
  log('');

  const files = readdirSync(ARTICLES_DIR)
    .filter(f => f.endsWith('.md'))
    .sort();

  const hashFiles = files.filter(isHashFile);
  const alreadyNamed = files.filter(f => /^\d{4}-\d{2}-\d{2}-/.test(f));
  const otherFiles = files.filter(f => !isHashFile(f) && !/^\d{4}-\d{2}-\d{2}-/.test(f));

  log(`スキャン結果:`);
  log(`  総ファイル数: ${files.length}`);
  log(`  既に命名済み (YYYY-MM-DD-*): ${alreadyNamed.length} 件（スキップ）`);
  log(`  その他の命名 (slug等): ${otherFiles.length} 件（スキップ）`);
  log(`  リネーム対象 (ハッシュ型): ${hashFiles.length} 件`);
  log('');

  if (hashFiles.length === 0) {
    log('リネーム対象ファイルはありません。');
    return;
  }

  const results = [];

  for (const filename of hashFiles) {
    const hashName = basename(filename, '.md');
    const filePath = join(ARTICLES_DIR, filename);
    const fm = parseFrontmatter(filePath);

    // 日付決定: frontmatter published_at → git log → 今日
    let date = fm.published_at || getGitInitialDate(filePath);
    if (!date) {
      const today = new Date();
      date = today.toISOString().substring(0, 10);
      log(`  [警告] ${filename}: 日付取得失敗 → ${date} (今日) を使用`);
    }

    // slug生成
    const slug = titleToSlug(fm.title, hashName);

    const newFilename = `${date}-${slug}.md`;
    const newFilePath = join(ARTICLES_DIR, newFilename);

    results.push({
      from: filename,
      to: newFilename,
      date,
      title: fm.title || '(タイトルなし)',
      slug,
    });

    if (!IS_DRY_RUN) {
      try {
        execSync(
          `git -C "${ROOT_DIR}" mv "articles/${filename}" "articles/${newFilename}"`,
          { encoding: 'utf-8' }
        );
        log(`  [RENAMED] ${filename} → ${newFilename}`);
      } catch (err) {
        log(`  [ERROR] ${filename}: ${err.message}`);
      }
    }
  }

  // サマリー出力
  log('');
  log('=== リネーム計画サマリー ===');
  log('');
  for (const r of results) {
    log(`  ${r.from}`);
    log(`    → ${r.to}`);
    log(`     title: ${r.title}`);
    log('');
  }

  if (IS_DRY_RUN) {
    log(`[DRY-RUN] 上記 ${results.length} 件のリネームは実行されていません。`);
    log('実行する場合: node scripts/migrate-naming.mjs --execute');
  } else {
    log(`[EXECUTE] ${results.length} 件のリネームを実行しました。`);
    log('確認: git status');
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
