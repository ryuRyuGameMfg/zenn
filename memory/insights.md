# Insights - 学習・傾向・勝ちパターン

## 勝ちパターン
- 「入門×N選」型タイトルが最高ROI（avg 15スキ超、複数イテレーションで確認）
- コードサンプル付き「概念→実装→まとめ」3段構成が高スキ
- 重複記事のunpublishでavg_likes大幅改善（+19〜+46%）
- テーマキュー5件以上の維持が安定生産の前提条件
- スキ数・フォロワーをKPI代替指標として運用（PV非公開のため）

## 避けるべきパターン
- 重複記事の放置（Zennコンテンツペナルティ→検索流入汚染）
- auto-queueへの重複記事混入（順次再公開ループが発生）
- improveモードのスキップ（モード遷移の抜け漏れがKPI停滞の直接原因）
- git-Zenn状態の乖離放置（published:trueなのに非露出の幽霊記事が蓄積）
- metrics.json空のままリライト判断（根拠不在で誤った優先順位付け）

## トピック傾向
- Unity入門・C#設計パターン×N選が安定高スキ帯（競合少・検索需要あり）
- Claude Code×Unity連携（自律開発・AI活用ワークフロー）が2026年主力テーマ
- Unity新バージョン速報（6.4〜ECS標準化・CoreCLR）は競合少なく参入余地大

---
最終更新: 2026-05-07

## テーマキュー（未消費）

### #22 - Unity AI MCP Server入門 [DONE: 2026-05-08]
- 作成済み: `2026-05-08-unity-ai-mcp-server-claude-code-5steps.md`
- queue: 2026-06-20公開予定 (priority 69)

### #23 - Unity AI エディタ内AIエージェント入門 [HIGH]
- タイトル案: `Unity AI入門：エディタ内AIエージェントでゲーム開発を10倍速にする5つの使い方`
- 根拠: 2026/05 OpenBeta開始直後、日本語Zenn記事がほぼゼロのブルーオーシャン
- topics: unity, ai, game-development, csharp
- 参考: https://gamemakers.jp/article/2026_05_05_136667/

### #24 - Gemini 2.5 × Unity Vibe Coding入門 [HIGH]
- タイトル案: `Gemini 2.5 × Unity Vibe Coding入門：自然言語だけで3Dゲームを作る方法`
- 根拠: Google I/O 2026でGemini×ゲーム開発注目。Vibe Coding avg22スキ実績。Gemini特化は未開拓
- topics: unity, ai, game-development, vibe-coding
- 参考: https://medium.com/@slrender2008/i-built-a-unity-asset-using-gemini-ai-vibe-coding-heres-what-i-learned-0fe9c3bca909

### #25 - Unity CLI Loop × AIエージェント入門 [HIGH]
- タイトル案: `Unity CLI Loop入門：AIエージェントにUnityエディタを自動操縦させる実装ガイド`
- 根拠: Zennで盛り上がり初期、E2Eテスト自動化の実用性高し。uLoopMCPとの相乗効果
- topics: unity, claudecode, ai, game-development
- 参考: https://zenn.dev/unsoluble_sugar/articles/2a1f9e08ac9980

### #26 - Android XR × Unity 6入門 [MEDIUM]
- タイトル案: `Android XR × Unity 6入門：Samsung Galaxy XR向けアプリ開発を始める5ステップ`
- 根拠: Samsung Galaxy XR 2026ローンチ。Unity公式サポート発表済み。先行者利益あり
- topics: unity, xr, game-development, android
- 参考: https://unity3d.jp/news/android-xr-support/

### #27 - Unity Shader Graph入門 [HIGH]
- タイトル案: `Unity Shader Graph入門：コードゼロでPBRシェーダーを自作する5ステップ`
- 根拠: 入門×N選パターン。Shader Graph検索ボリューム大・初心者が躓くポイントを実装付きで解説。競合少ない日本語記事。
- topics: unity, csharp, game-development, shader
- 参考: https://docs.unity3d.com/Manual/shader-graph.html

### #28 - Unity Addressables入門 [HIGH]
- タイトル案: `Unity Addressables入門：Resourcesを卒業してアセット管理を5倍効率化する方法`
- 根拠: 入門×N選パターン。Resourcesからの移行ニーズが高く、Zennで実装付き記事が少ない。モバイルゲーム開発者に需要大。
- topics: unity, csharp, game-development
- 参考: https://docs.unity3d.com/Packages/com.unity.addressables@2.3/manual/index.html

### #29 - Claude Code × Unity テスト自動生成入門 [HIGH]
- タイトル案: `Claude Code × Unity：AIにPlayModeテストを自動生成させてバグを撲滅する実装ガイド`
- 根拠: claudecode×unity実装系。uLoopMCPとの相乗効果期待。テスト自動化はCI/CD文脈でエンジニア需要高。Zenn未開拓ニッチ。
- topics: unity, claudecode, csharp, game-development
- 参考: https://docs.unity3d.com/Manual/testing-editortestsrunner.html

### #30 - Unity Timeline入門 [HIGH]
- タイトル案: `Unity Timeline入門：アニメーション・カットシーン・演出を5ステップで実装する方法`
- 根拠: 入門×N選パターン。Timeline系の実装記事は少なく、ゲーム演出担当の初心者に刺さる。検索需要安定。
- topics: unity, csharp, game-development
- 参考: https://docs.unity3d.com/Packages/com.unity.timeline@1.8/manual/index.html

### #31 - Unity UI Toolkit入門 [HIGH]
- タイトル案: `Unity UI Toolkit入門：uGUIを卒業してランタイムUI開発を近代化する5ステップ`
- 根拠: 入門×N選パターン。Unity 6でUI Toolkit推奨方針。uGUI→UI Toolkit移行需要が急増中。実装コード付き解説が少ない。
- topics: unity, csharp, game-development
- 参考: https://docs.unity3d.com/Manual/UIElements.html
