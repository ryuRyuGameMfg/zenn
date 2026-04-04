# 高PVパターン

> analyze モードで収集・蓄積する。初期状態は空。

## パターン一覧

（analyze モードで初回収集 2026-04-04）

| パターン | 観測記事数 | 平均スキ | 備考 |
|---------|-----------|--------|------|
| Unity C# 設計パターン系（2025年） | 12 | 9.8 | 2025年2〜3月の記事群。最高32スキ（デザインパターン5選） |
| Unity 入門・初心者向け（2025年） | 3 | 15.7 | ef64c64f1d5f56（15）・029524183c77d9（21）・291ce3a3bf95ee（11） |
| AI/Claude 系（2026年） | 13 | 0 | 2026年記事はいずれも0スキ。まだ認知獲得中 |

## タイトルパターン

高スキタイトル（10スキ以上）:
- 「デザインパターン5選で作る堅牢かつ拡張性の高いゲームシステム」→ 32スキ
- 「Unityエディタ拡張で実現する開発効率の爆上げテクニック」→ 21スキ
- 「Unity初心者必見！C#で効率UPする5つの小技」→ 15スキ
- 「【7ルール】Unity C#による柔軟なロジック分離テクニック」→ 12スキ
- 「【8原則】SOLID実践で目指すUnity C#堅牢ゲームアーキテクチャ」→ 11スキ

傾向:
- 「N選」「N原則」「N技」などリスト数字タイトルが強い
- 「エディタ拡張」「初心者向け」「設計パターン」が高PV
- 2026年記事は未だ0スキ（Zennインデックス待ちの可能性あり）

## 構成パターン

（analyze モードで初回収集 2026-04-04）
- コードサンプル付き実装解説が高スキ
- 概念説明 → コード → まとめ の3段構成が標準

## トピックパターン

（analyze モードで更新）

# テーマキュー

> create/rewrite モードが上から順に消費する。improve モードが補充する。

## キュー（優先順）

1. uLoopMCP + Claude Code で Unity 自律開発サイクルを実現する方法（次回優先）
2. Unity Memory Profiler 実践ワークフロー：GC Alloc 撲滅からメモリリーク根絶まで
3. Unity GPU Instancing 完全実装：DrawMeshInstanced から RenderMeshIndirect まで段階的に理解する
4. Unity ECS × ゲームキャラクター実装：OOP 設計からの段階移行実践ガイド
5. Unity 6.3 Platform Toolkit でマルチプラットフォーム対応を1コードベースで実現する
6. Unity C#でやりがちな「初心者の罠」5選 ― ファイル名・ライフサイクル・null参照を完全解説（入門×N選、20スキ超見込み）
7. ScriptableObjectを使いこなす5つの実践パターン ― ゲームデータ設計の決定版（設計系×N選、2026年空白テーマ）
8. Unityエディタ拡張で作業を自動化する3つのレシピ ― ボタン1つで完結する開発ツール集（エディタ拡張×自動化、競合少）
9. Unity 6.4で変わった開発フロー ― Render Graph・ECS標準化を実務レベルで使う（新バージョン速報性、競合少）
10. Unityでオンライン対戦の基礎を作る ― Netcode for GameObjects 入門5ステップ（2026年3月ヒット記事77スキの追い風あり）

## 済みトピック（重複確認用）

| スラッグ | タイトル | 完了日 |
|---------|---------|--------|
| 2026-03-26-unity-claude-code-auto-test-generation | Unity × Claude Code で自動テスト生成を実装する方法 | 2026-03-26 |
| 2026-03-28-univrm-lipsync-implementation | UniVRM 2.0 で口パク（リップシンク）を実装する方法【VRM 1.0対応】 | 2026-03-28 |
| 2026-03-28-zenn-github-actions-auto-deploy | Zenn × GitHub Actions で自動デプロイを設定する方法【textlint + PR プレビュー対応】 | 2026-03-28 |
| 2026-03-30-claude-code-launchd-autonomous-agent | OpenClawのAPI料金に疲れた人へ：Claude Code × macOS launchd で月額固定の自律AIエージェントを自作する | 2026-03-30 |
| 2026-03-31-why-humans-dislike-ai-design | なぜ人間はAIデザインを嫌うのか：バイアスと実質的傾向の2方向分析【Unity UI実装例付き】 | 2026-03-31 |
| 2026-04-01-claude-md-ascii-diagram-output | Claude Codeの出力が読めない問題をCLAUDE.mdのASCII図ルールで解決した | 2026-04-01 |
| 2026-04-02-claude-code-notion-mcp-root-page-automation | Claude Code × Notion MCP でルートページ整理を自動化する | 2026-04-02 |
| 2026-04-02-claude-code-gmail-calendar-mcp-ai-secretary | Claude Code × Gmail/Calendar MCP でAI秘書を実現する | 2026-04-02 |
| 2026-04-03-unity-architecture-ai-code-instruction | MonoBehaviourベタ書きを卒業したい人へ：AIに設計パターンを指示してUnityコードを整理する方法 | 2026-04-03 |

