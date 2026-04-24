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

## 2026-04-25 improve：非表示記事36本の正体特定（前回推定7本→実測36本に訂正）

### 分析手法
全 `articles/*.md` のうち `published: true` を抽出し、Zenn API (`/api/articles?username=ryuryu_game&count=200`) 返却スラッグと差集合を取得。各スラッグを curl でHTTPステータス取得し2分類。

### 実測結果（2026-04-25）
- `articles/published:true` = 50本
- Zenn API 返却 = 38本（うち我々の新規記事14本 + 2025年ハッシュスラッグ24本）
- 差分 = **36本が published:true なのに Zenn側に露出していない**

前回 analyze（4/24）で「非表示7本」と推定したのは、articles数の差分(49-42=7)のみ見ていたため。実際は profile articles_count 38 vs published:true 50 の差 = **12本が auto-queue 未消化**、更に API が2025年記事24本を含むため正味14本のみ「我々の新規記事として露出」= 50-14=**36本が非露出**という多層構造だった。

### 2分類（HTTPステータスベース）

| 分類 | 本数 | 意味 | 対応 |
|-----|-----|------|------|
| **404（Orphan flag）** | 10 | Zenn上に存在せず | auto-queue未消化。published:false化で即クリーンアップ可能 |
| **403（Zenn側非公開）** | 26 | Zenn上にスラッグ予約あるが公開停止状態 | Zenn UI側で非公開化されている。published:false化で git と一致させる |

### 404 (Orphan) 10本 - **2026-04-25 improve で published:false 化実行済み**
auto-queue が published:true フラグをセットしたが、Zennへのpushが発生しなかった or zenn-publish-daemon がスキップしたもの。Zennに露出せず、放置するとauto-queueが再度publishを試みる可能性があったためクリーンアップ。

1. ~~claude-code-subagent-vs-openclaw~~ (pub_at: 2026-04-11)
2. ~~openclaw-skills-7-automation-techniques~~ (pub_at: 2026-04-18)
3. ~~unity-ai-character-chatgpt-voicevox~~ (pub_at: 2026-04-04)
4. ~~unity-async-performance-optimization~~ (pub_at: 2026-04-05)
5. ~~unity-components-complete-reference~~ (pub_at: 2026-03-31)
6. ~~unity-csharp-fundamentals-complete-guide~~ (pub_at: 2026-03-30)
7. ~~unity-data-management-save-techniques~~ (pub_at: 2026-04-02)
8. ~~unity-design-patterns-practical-guide~~ (pub_at: 2026-04-01)
9. ~~unity-openclaw-ai-agent-editor-automation~~ (pub_at: 2026-04-24)
10. ~~unity-vr-development-roadmap-openxr~~ (pub_at: 2026-04-03)

### 403 (Zenn-unpublished) 26本 - **次rewrite サイクルで対応**
Zenn側で非公開化されている（=403）が git は published:true のままのため、Zenn-git 乖離状態。auto-queue が再publish試行しても Zenn が拒否（403維持）し続けるため、KPIには無害だが、git 状態を現実と一致させるため次rewriteで published:false 化推奨。

| # | slug | pub_at |
|---|------|--------|
| 1 | 2026-04-01-unity-official-mcp-complete-guide | NA |
| 2 | 2026-04-02-notion-mcp-root-page-automation | NA |
| 3 | 2026-04-02-uloopmcp-community-attention | NA |
| 4 | ai-first-game-development-workflow | 2026-03-25 |
| 5 | claude-code-security-5-layers-real-config | NA |
| 6 | claude-md-7-failure-patterns-2026 | NA |
| 7 | comfyui-game-assets-indie-dev-guide | NA |
| 8 | convai-ai-npc-unity-implementation | 2026-03-01 |
| 9 | gpu-resident-drawer-section1 | 2026-03-14 |
| 10 | llm-procedural-content-generation-game-survey | 2026-04-10 |
| 11 | llmunity-local-llamacpp-unity-integration | 2026-03-28 |
| 12 | mcp-unity-claude-cursor-editor-control | 2026-03-08 |
| 13 | meta-quest-unity-inference-engine-xr-ai | 2026-04-19 |
| 14 | nvidia-audio2face-3d-opensource-guide | 2026-03-22 |
| 15 | pcg-llm-integration-survey-2025 | 2026-04-03 |
| 16 | playwright-chrome-profile-automation | 2026-03-29 |
| 17 | shipping-games-with-ai-coding-agents | 2026-03-28 |
| 18 | stanford-generative-agents-ai-npc-design | 2026-03-20 |
| 19 | ubisoft-chord-pbr-material-generation-oss | NA |
| 20 | unity-ai-muse-complete-guide-6-2 | 2026-04-05 |
| 21 | unity-llm-mcp-architecture-migration | 2026-04-12 |
| 22 | unity-local-llm-complete-guide | 2026-03-29 |
| 23 | unity-ml-agents-release-23-summary | 2026-03-27 |
| 24 | unity-offline-ai-character-stt-llm-tts | 2026-03-07 |
| 25 | unity-sentis-whisper-voice-recognition-npc | 2026-03-13 |
| 26 | wfc-reinforcement-learning-mdp-optimization | 2026-04-17 |

### 検証根拠
- claude-code-skill-display-order（現公開中）: 200 OK
- claude-md-7-failure-patterns-2026（疑惑群）: 403 Forbidden
- definitely-not-exist-slug-9999（存在しない）: 404 Not Found

403≠404 の挙動差により「Zenn側にスラッグは存在するが非公開」を確定。単純なシャドウバンではなく過去にZenn UI上で unpublish された可能性が高い（我々の git では published:true が残存）。

### KPI効果試算
- 404 Orphan 10本 published:false 化（今回実行済み）:
  - API avg_likes: 変化なし（もともと0スキ扱い）
  - **auto-queue 再publish試行のコスト削減**（10本分の不要な schedule 登録を停止）
  - 累積の ghost publication 防止（前回 4/17-4/19 に3本が順次再公開された構造的欠陥と同種）
- 403 Zenn-unpublished 26本（次rewrite対応予定）:
  - git 状態と Zenn 状態の整合
  - auto-queue の「常時 publish 試行 → Zenn拒否」ループ停止

### Zenn-git状態チェック恒久化の推奨
`scripts/verify-zenn-sync.mjs`（仮）として、定期的に `articles/published:true` と Zenn API 返却スラッグを突き合わせ、403/404 を分類する検証スクリプトをdaemon化すべき。analyze モードのたびに実行し、乖離をゼロに保つ。

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
