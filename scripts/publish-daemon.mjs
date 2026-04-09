/**
 * publish-daemon.mjs (Zenn版)
 *
 * 常駐公開デーモン: queue.jsonを60分ごとに監視し、
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

import { runPublishDaemon } from '/Users/okamotoryuya/.claude/bots/lib/publish-core.mjs';
import adapter from './publish-adapter.mjs';

await runPublishDaemon(adapter, process.argv);
