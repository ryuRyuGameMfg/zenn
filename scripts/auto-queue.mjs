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

import { runAutoQueue } from '/Users/okamotoryuya/.claude/bots/lib/auto-queue-core.mjs';
import adapter from './auto-queue-adapter.mjs';

await runAutoQueue(adapter, process.argv);
