# 高PVパターン

> analyze モードで収集・蓄積する。初期状態は空。

## パターン一覧

（analyze モードで初回収集 2026-04-04 / 2026-04-17更新）

| パターン | 観測記事数 | 平均スキ | 備考 |
|---------|-----------|--------|------|
| Unity C# 設計パターン系（2025年） | 12 | 9.8 | 2025年2〜3月の記事群。最高32スキ（デザインパターン5選） |
| Unity 入門・初心者向け（2025年） | 3 | 15.7 | ef64c64f1d5f56（15）・029524183c77d9（21）・291ce3a3bf95ee（11） |
| AI/Claude 系（2026年） | 13 | 0 | 重複記事問題が主因。重複除外後の計測が必要 |

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
- 2026年記事0スキ問題の根本原因は重複記事（2026-02-25バッチ + 2026-01系）

## 構成パターン

（analyze モードで初回収集 2026-04-04）
- コードサンプル付き実装解説が高スキ
- 概念説明 → コード → まとめ の3段構成が標準

## 重複記事対策（rewrite モード実行方針）

2026-04-17 analyze で特定された根本原因:
- 2026-02-25バッチ記事（14本以上）：2025年記事の再公開。全て0スキ
- 2026-01系「(重複)」タグ記事（4本）：同様に重複

rewrite モードでの対応方針:
1. 以下の記事スラッグについて `published: false` に変更（削除禁止）
   - 2026-02-25-unity-csharp-5-game-system（e45246との重複）
   - 2026-02-25-7-unity-csharp（178944との重複）
   - 2026-02-25-8-solid-unity-csharp-game（f29446との重複）
   - 2026-02-25-unity-awake-start（291ce3との重複）
   - 2026-02-25-design-unity-csharp（4fd68eとの重複）
   - 2026-02-25-trycatchfinally-unity-csharp-game（af1697との重複）
   - 2026-01-05-ai-m-ai-n-sub-3-design-development（重複）
   - 2026-01-08-unity-monobehaviour-csharp（重複）
   - 2026-01-10-claude-code-method（重複）
   - 2026-01-13-claude-10-article-automation（重複）
2. unpublish後、avg_likes = 349スキ / (47-10)記事 = 9.4スキ/記事に改善見込み
3. さらに新規高品質記事1本追加で平均をさらに引き上げる

KPI効果試算:
- 現在: 47記事、349スキ、avg 7.43
- 重複10本unpublish後: 37記事、349スキ、avg 9.4（+26%改善）
- さらに新規20スキ記事追加後: 38記事、369スキ、avg 9.7

## 2026-04-19 analyze 追加発見：重複記事の二次流出

前回 rewrite サイクル（2026-04-18）で「重複10本をunpublishした」と記録されていたが、実測調査により**実際は6本のみ処理され、残り12本が published: true のまま残存**していることが判明。auto-queue が順次拾って公開しており、KPI停滞（5連続 no_improve）の構造的欠陥と特定。

### 実測データ（2026-04-19）
- Zenn API 公開記事数: 38
- articles/ の published: true ファイル数: 61
- 差分 23本：重複コンテンツペナルティで検索除外された疑い
- 全体 avg_likes: 4.95（2025年のみなら 10.44）

### 4/17〜4/19 の3日間に「順次公開」された重複3本（全て0スキ）
| 公開日 | 重複slug | オリジナル | オリジナルスキ |
|-------|---------|----------|-------------|
| 2026-04-17 | 2026-02-25-unity-csharp-efficiency-up-5 | ef64c64f1d5f56 | 15 |
| 2026-04-18 | 2026-02-25-unity-csharp-gizmos-3d-tech | c885e7524d553b | 5 |
| 2026-04-19 | 2026-02-25-unity-csharp-implementation-design | de962e6675c9d8 | 10 |

特に 4/17 に公開された unity-csharp-efficiency-up-5 は、最高ROIパターン「Unity入門×N選」の頂点（15スキ）のオリジナルと重複しており、自ら最強カードの検索流入を汚染している。

### improve/rewrite で処理すべき残存重複12本 ← **2026-04-21 処理完了**
全て `articles/2026-02-25-*.md` で published: true のもの（全て published: false に変更済み）：
1. ~~2026-02-25-unity-csharp-efficiency-up-5~~（ef64c64f1d5f56: 15スキ）→ unpublished 2026-04-21
2. ~~2026-02-25-unity-csharp-gizmos-3d-tech~~（c885e7524d553b: 5スキ）→ unpublished 2026-04-21
3. ~~2026-02-25-unity-csharp-implementation-design~~（de962e6675c9d8: 10スキ）→ unpublished 2026-04-21
4. ~~2026-02-25-unity-csharp-rpg-management-linq-method~~（1d824bf8916c36: 6スキ）→ unpublished 2026-04-21
5. ~~2026-02-25-unity-csharp-struct-performance~~（bdc84f9b3d210f: 9スキ）→ unpublished 2026-04-21
6. ~~2026-02-25-unity-csharp~~（e0cb9691b32320: 9スキ）→ unpublished 2026-04-21
7. ~~2026-02-25-unity-cursor-ai-design-monobehaviour~~（7f717d158e8231: 7スキ）→ unpublished 2026-04-21
8. ~~2026-02-25-unity-dev-efficiency-method~~（334d4e76182284: 8スキ）→ unpublished 2026-04-21
9. ~~2026-02-25-unity-editor-extension-dev-efficiency~~（029524183c77d9: 21スキ）→ unpublished 2026-04-21
10. ~~2026-02-25-unity-fluent-interface-development~~（ad635d8b9a8f43: 8スキ）→ unpublished 2026-04-21
11. ~~2026-02-25-unity-observer-pattern-system~~（1420c90c011460: 7スキ）→ unpublished 2026-04-21
12. ~~2026-02-25-unity-rigidbody-collider-optimization~~（5c323d05ba6e02: 5スキ）→ unpublished 2026-04-21

### 2026-04-21 improve 実行記録
- 12本全ての `published: true` → `published: false` 変更をコミット
- articles/ 変更あり → git push 実行
- 次サイクルで Zenn 再同期 → 実測avg_likes再測定（analyze モード）

### KPI効果試算（12本全unpublish時）
- 現状: 38記事、188スキ、avg 4.95
- 12本unpublish後: 26記事、188スキ、avg 7.23（**+46%改善**）
- さらに15スキ級の新規記事1本: 27記事、203スキ、avg 7.52
- 重複コンテンツペナルティ解除で既存オリジナル記事の検索流入回復も期待

## トピックパターン

（2026-04-17 WebSearch調査で追加）
- Claude Code × Unity 並列開発（git worktree）がZennでトレンド
- Unity 6.4〜6.8ロードマップ：CoreCLR移行・ECS標準化が大きな変化
- Unite 2026 Tokyo 開催予定（速報性のある記事が有効）

# テーマキュー

> create/rewrite モードが上から順に消費する。improve モードが補充する。

## キュー（優先順）

1. ~~uLoopMCP + Claude Code で Unity 自律開発サイクルを実現する方法~~ 済み→ 2026-04-18
2. Unity Memory Profiler 実践ワークフロー：GC Alloc 撲滅からメモリリーク根絶まで
3. Unity GPU Instancing 完全実装：DrawMeshInstanced から RenderMeshIndirect まで段階的に理解する
4. Unity ECS × ゲームキャラクター実装：OOP 設計からの段階移行実践ガイド
5. Unity 6.3 Platform Toolkit でマルチプラットフォーム対応を1コードベースで実現する
6. ~~Unity C#でやりがちな「初心者の罠」5選 ― ファイル名・ライフサイクル・null参照を完全解説~~ 済み→ 2026-04-19（iter04_create、高PVパターン採用）
7. ~~ScriptableObjectを使いこなす5つの実践パターン ― ゲームデータ設計の決定版（設計系×N選、2026年空白テーマ）~~ 済み→ 2026-04-13
8. Unityエディタ拡張で作業を自動化する3つのレシピ ― ボタン1つで完結する開発ツール集（エディタ拡張×自動化、競合少）
9. Unity 6.4で変わった開発フロー ― Render Graph・ECS標準化を実務レベルで使う（新バージョン速報性、競合少）
10. Unityでオンライン対戦の基礎を作る ― Netcode for GameObjects 入門5ステップ（2026年3月ヒット記事77スキの追い風あり）
11. ~~Claude Codeで並列Unity開発 ― git worktree × 複数セッションで実装速度3倍【実践ガイド】~~ 済み→ 2026-04-23（iter05_create、claudecodeタグクラスタ増強戦略）
12. Unity 6.4〜6.8ロードマップ完全解説 ― CoreCLR移行・ECS標準化・WebGPU対応の全貌（速報性・ロードマップ解説、Unity公式情報ベース）
13. Unity ECS完全入門 ― Unity 6.4でコアパッケージ化！基礎から実装まで5ステップ（入門×N選、ECS初心者向け）
14. Unity AI Profiler Integration実践 ― AIが自動でGCスパイク・ボトルネックを特定する新ツールの使い方（Unity新機能・AI×パフォーマンス）
15. Claude Code v2.1 新機能でUnity開発を加速する ― /effortモード・PostCompact Hookの実践活用（Claude Code最新版×Unity、2026年3月公開機能）

## 済みトピック（重複確認用）

| スラッグ | タイトル | 完了日 |
|---------|---------|--------|
| 2026-04-13-unity-scriptableobject-5-patterns | ScriptableObjectで変わるゲームデータ設計5パターン【Unity】 | 2026-04-13 |
| 2026-03-26-unity-claude-code-auto-test-generation | Unity × Claude Code で自動テスト生成を実装する方法 | 2026-03-26 |
| 2026-03-28-univrm-lipsync-implementation | UniVRM 2.0 で口パク（リップシンク）を実装する方法【VRM 1.0対応】 | 2026-03-28 |
| 2026-03-28-zenn-github-actions-auto-deploy | Zenn × GitHub Actions で自動デプロイを設定する方法【textlint + PR プレビュー対応】 | 2026-03-28 |
| 2026-03-30-claude-code-launchd-autonomous-agent | OpenClawのAPI料金に疲れた人へ：Claude Code × macOS launchd で月額固定の自律AIエージェントを自作する | 2026-03-30 |
| 2026-03-31-why-humans-dislike-ai-design | なぜ人間はAIデザインを嫌うのか：バイアスと実質的傾向の2方向分析【Unity UI実装例付き】 | 2026-03-31 |
| 2026-04-01-claude-md-ascii-diagram-output | Claude Codeの出力が読めない問題をCLAUDE.mdのASCII図ルールで解決した | 2026-04-01 |
| 2026-04-02-claude-code-notion-mcp-root-page-automation | Claude Code × Notion MCP でルートページ整理を自動化する | 2026-04-02 |
| 2026-04-02-claude-code-gmail-calendar-mcp-ai-secretary | Claude Code × Gmail/Calendar MCP でAI秘書を実現する | 2026-04-02 |
| 2026-04-03-unity-architecture-ai-code-instruction | MonoBehaviourベタ書きを卒業したい人へ：AIに設計パターンを指示してUnityコードを整理する方法 | 2026-04-03 |
