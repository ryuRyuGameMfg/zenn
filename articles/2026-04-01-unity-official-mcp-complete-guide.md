---
title: "Unity公式が本気で作ったAI連携：Claude/Cursorと直結する新時代の開発フロー"
emoji: "🤖"
type: "tech"
topics: ["unity", "ai", "mcp", "claude", "cursor"]
published: true
---

## はじめに：Unity公式が「AI連携」に本気を出した背景

Unity 6.0（6000.0以降）で、Unity Technologiesが本格的なAI連携機能を公式実装しました。その名も**Unity MCP（Model Context Protocol）**です。

従来のUnity開発では、AI支援ツール（Claude Code、Cursor、Windsurf等）を使う場合でも「コードを生成 → コピペ → Unityエディタで確認」という手動プロセスが必要でした。Unity MCPはこのギャップを埋め、**AIクライアントがUnityエディタと直接通信**する新しい開発フローを実現します。

**本記事の目的：**
Unity公式ドキュメントを日本語で詳細解説し、セットアップ手順から実装例まで網羅します。また、コミュニティ版（CoplayDev/unity-mcp、IvanMurzak/Unity-MCP）との違いも明示します。

---

## Unity公式MCPとは：従来の開発フローとの決定的な違い

### Model Context Protocolの概要

**MCP（Model Context Protocol）** は、LLMベースのAIエージェントと外部システムを接続するためのオープンスタンダードです。Unity MCPはこのプロトコルを実装し、AIクライアントがUnityエディタを直接操作できるようにします。

公式ドキュメントの定義：
> "Enable AI agents to interact directly with the Unity Editor through the Model Context Protocol"

### 従来のワークフロー vs Unity MCP

**従来**：
```
AIクライアント → コード生成 → 開発者がコピペ → Unityエディタで手動確認
```

**Unity MCP**：
```
AIクライアント ↔ MCP Protocol ↔ Unityエディタ（直接操作）
```

Unity MCPでは、AIが以下を自動実行します：
- シーン管理（オブジェクト配置、階層操作）
- アセット操作（プレハブ作成、マテリアル設定）
- スクリプト編集（C#コード生成、既存スクリプト修正）
- コンソール監視（エラー検出、警告の要約）

### なぜ今、Unity公式がMCPを実装したのか

2025年後半から2026年にかけて、AI支援開発ツールが急速に普及しました。特に以下の背景があります：

1. **Claude Code / Cursor の爆発的普及**：開発者の30〜50%が日常的にAI支援ツールを使用
2. **コミュニティ版MCPの先行成功**：CoplayDev/unity-mcp が4,200スター超、IvanMurzak/Unity-MCPも人気
3. **Unity AI Assistant パッケージの強化**：com.unity.ai.assistant 2.0で正式サポート

Unity Technologiesは「AI時代の開発フロー」を公式サポートする戦略に転換しました。

---

## Unity公式MCP、その実力を解剖する

### アーキテクチャ：4層構成で動作する

Unity MCPは以下の4層で構成されています：

```
┌─────────────────────────────┐
│ AIクライアント層            │ ← Claude Code, Cursor, Windsurf
│ (LLMベースのエージェント)   │
└─────────────┬───────────────┘
              │ MCP Protocol
┌─────────────▼───────────────┐
│ リレーバイナリ層            │ ← ~/.unity/relay/ に自動配置
│ (MCP サーバープロセス)      │
└─────────────┬───────────────┘
              │ IPC（名前付きパイプ/Unixソケット）
┌─────────────▼───────────────┐
│ Unityエディタ内部            │
│ MCPブリッジ                 │ ← com.unity.ai.assistant
└─────────────────────────────┘
```

**各層の役割：**

| 層 | 役割 | 実装 |
|---|---|---|
| **AIクライアント層** | ユーザー指示の解釈、MCPツール呼び出し | Claude Code等のAIクライアント |
| **リレーバイナリ層** | MCPプロトコルの実装、クライアント↔エディタの橋渡し | ~/.unity/relay/ の実行ファイル |
| **IPC層** | プロセス間通信（名前付きパイプ/Unixソケット） | OS依存 |
| **MCPブリッジ** | エディタ内部API呼び出し、動的ツール登録 | com.unity.ai.assistant |

### セキュリティモデル：2つの接続方式

Unity MCPは2つの接続モードを提供します：

**1. AIゲートウェイ接続（自動承認）**
- Unity公式のAIゲートウェイ経由で接続
- ユーザー操作不要、自動承認
- エンタープライズ向け（将来的に有料化の可能性）

**2. 直接接続（ユーザー承認必須）**
- AIクライアントが直接MCPリレーに接続
- プロジェクト設定で初回承認が必要
- 承認したクライアントは記憶される
- 個人開発者向け、無料

### 複数クライアント同時接続に対応

Unity MCPは**同一Unityインスタンスに複数のAIクライアントを同時接続**できます。例えば：
- Claude Codeでスクリプト編集
- Cursorでシーン構成
- Windsurfでテスト実行

を並行して実行可能です（ただし、競合リスクは開発者が管理する必要があります）。

### 動的ツール登録システム

Unity MCPの強力な機能の1つは、**エディタ起動時にツールを動的に登録**することです。

- 属性ベース登録
- インターフェース実装
- ランタイムAPI呼び出し

これにより、カスタムツールを追加して独自のAI操作を定義できます（詳細は今後の記事で解説予定）。

---

## セットアップ手順：macOS/Windows/Linux 共通フロー

### 前提条件

Unity MCPを使用するには以下が必要です：

| 項目 | 要件 |
|---|---|
| **Unityバージョン** | Unity 6（6000.0以降） |
| **必須パッケージ** | com.unity.ai.assistant（バージョン2.0以降） |
| **対応AIクライアント** | Claude Code、Cursor、Windsurf、Claude Desktop |

### Step 1：Unity AI Assistantパッケージのインストール

1. Unity 6 プロジェクトを開く
2. Window → Package Manager を開く
3. 検索バーで `com.unity.ai.assistant` を検索
4. バージョン2.0以降をインストール

### Step 2：リレーバイナリの確認

リレーバイナリは`~/.unity/relay/`に自動インストールされます。

**プラットフォーム別のパス：**

| OS | パス |
|---|---|
| **macOS（Apple Silicon）** | `~/.unity/relay/relay_mac_arm64.app/Contents/MacOS/relay_mac_arm64` |
| **macOS（Intel）** | `~/.unity/relay/relay_mac_x64.app/Contents/MacOS/relay_mac_x64` |
| **Windows** | `%USERPROFILE%\.unity\relay\relay_win.exe` |
| **Linux** | `~/.unity/relay/relay_linux` |

**確認コマンド（macOS/Linux）：**
```bash
ls -la ~/.unity/relay/
```

**確認コマンド（Windows）：**
```powershell
dir %USERPROFILE%\.unity\relay\
```

### Step 3：AIクライアントの設定

**Claude Codeの場合：**

1. Claude Codeを起動
2. MCP設定ファイルを開く（`~/.claude/claude_desktop_config.json`）
3. 以下を追加：

```json
{
  "mcpServers": {
    "unity": {
      "command": "/Users/<username>/.unity/relay/relay_mac_arm64.app/Contents/MacOS/relay_mac_arm64",
      "args": []
    }
  }
}
```

**Cursorの場合：**

1. Cursor設定を開く（Settings → Extensions → MCP）
2. Unity MCPサーバーを追加
3. パスを指定：`~/.unity/relay/relay_mac_arm64.app/Contents/MacOS/relay_mac_arm64`（macOS例）

### Step 4：接続承認

1. Unityエディタで任意のプロジェクトを開く
2. AIクライアントから「Read the Unity console messages」等の指示を出す
3. Unity側で初回承認ダイアログが表示される
4. 「Allow」をクリック

**接続確認方法：**
- Unity: Edit → Project Settings → AI Assistant → **Connected Clients**
- AIクライアント: Unity MCPツール一覧が表示される

### Step 5：接続テスト

Claude Codeで以下のプロンプトを試してください：

```
Read the Unity console messages and summarize any warnings or errors.
```

Unity MCPの`Unity_ReadConsole`ツールが実行され、コンソール内容が要約されます。

---

## Unity公式MCPの組み込みツール

Unity MCPは以下のカテゴリのツールを提供します（具体的なツール一覧は公式ドキュメントに記載なし。今後のアップデートで詳細公開予定）。

### 推定されるツールカテゴリ

| カテゴリ | 想定されるツール |
|---|---|
| **シーン管理** | GameObjectの作成/削除、階層操作、Transform変更 |
| **アセット操作** | プレハブ作成、マテリアル設定、テクスチャ適用 |
| **スクリプト編集** | C#スクリプト生成、既存コード修正、リファクタリング |
| **コンソールアクセス** | ログ読み取り、エラー検出、警告要約 |
| **ビルド操作** | ビルド設定変更、プラットフォーム切り替え |

**ドキュメント引用：**
> "manage assets, control scenes, edit scripts, and automate tasks within Unity"

---

## 「公式」と「コミュニティ版」の決定的な違い

Unity MCPには**公式版**と**コミュニティ版**が存在します。以下、主要な2つのコミュニティ版との比較です。

### CoplayDev/unity-mcp（コミュニティ版1）

- **開発元**：CoplayDev（旧justinpbarnett）
- **GitHubスター**：4,200+（2026年3月時点）
- **最新バージョン**：v8.2.1（2025年12月8日）
- **特徴**：Python ベースのMCPサーバー、Unity Bridgeとの通信

**公式版との違い：**
- 公式版はC#ネイティブ実装、CoplayDev版はPython実装
- 公式版はUnity 6専用、CoplayDev版はUnity 2022.3以降対応
- 公式版は自動インストール、CoplayDev版は手動セットアップ

### IvanMurzak/Unity-MCP（コミュニティ版2）

- **開発元**：IvanMurzak
- **最新バージョン**：v0.51.4（2026年3月9日）
- **特徴**：「Any C# method may be turned into a tool by a single line」

**独自機能：**
- C#メソッドを1行で MCPツール化できる
- CLI for Unity Engine を統合
- トークン効率最適化

**公式版との違い：**
- IvanMurzak版は開発者が自由にツールを拡張可能
- 公式版は標準ツールセットのみ（カスタムツールは属性/API必須）

### 比較表

| 項目 | Unity公式MCP | CoplayDev/unity-mcp | IvanMurzak/Unity-MCP |
|---|---|---|---|
| **開発元** | Unity Technologies | CoplayDev | IvanMurzak |
| **実装言語** | C# | Python | C# |
| **Unity対応バージョン** | Unity 6.0以降 | Unity 2022.3以降 | Unity 2022.3以降 |
| **インストール** | 自動 | 手動 | 手動 |
| **カスタムツール** | 属性/API経由 | Bridge拡張 | 1行で登録可 |
| **ライセンス** | Unity公式 | Apache 2.0 | MIT |
| **サポート** | 公式サポート | コミュニティ | コミュニティ |

### どれを選ぶべきか？

**Unity公式MCPを選ぶ理由：**
- Unity 6を使用している
- 公式サポートが必要
- 標準ツールセットで十分

**CoplayDev/unity-mcpを選ぶ理由：**
- Unity 2022.3/2023.3を使用している
- Pythonエコシステムと統合したい
- 4,200+のコミュニティ実績を重視

**IvanMurzak/Unity-MCPを選ぶ理由：**
- C#で柔軟にツールをカスタマイズしたい
- トークン効率を最適化したい
- CLI統合を重視

---

## Unity公式MCPが切り開く未来

### AI駆動開発の標準化

Unity公式MCPの登場により、「AI支援開発」から「**AI駆動開発**」への転換が加速します。

従来の開発：
```
開発者 → AIに質問 → AIが提案 → 開発者が実装
```

AI駆動開発：
```
開発者 → AIに指示 → AI が実装・テスト・デバッグまで自動実行
```

### Unity AI Assistant 2.0との統合

Unity公式MCPは、Unity AI Assistant 2.0の中核機能として位置づけられています。将来的には以下の機能が期待されます：

- **自動テスト生成**：シーンを解析してPlayModeテストを自動生成
- **パフォーマンス最適化**：Profilerデータを解析して最適化案を提示
- **アセット検索**：自然言語でアセットストアを検索・インポート

### コミュニティエコシステムとの共存

Unity公式がMCPを実装したことで、コミュニティ版との「競争」ではなく「共存」のエコシステムが生まれます。

- 公式版：標準機能・安定性重視
- コミュニティ版：実験的機能・柔軟性重視

開発者は用途に応じて使い分けができるようになります。

---

## まとめ：Unity公式MCPで変わる開発体験

**本記事のポイント：**

1. **Unity公式MCPとは**：Claude Code/CursorとUnityエディタを直接接続するAI連携機能
2. **アーキテクチャ**：4層構成（AIクライアント→リレーバイナリ→IPC→エディタ）
3. **セットアップ**：Unity 6 + com.unity.ai.assistant 2.0で自動インストール
4. **公式 vs コミュニティ版**：公式は標準化・安定性、コミュニティ版は柔軟性・実験性

**Unity開発者への提言：**

- Unity 6を使用しているなら、公式MCPを試す価値は十分にある
- コミュニティ版も並行して使い、用途に応じて使い分ける
- AI駆動開発の時代に向けて、MCPプロトコルの理解を深める

Unity公式がAI連携に本気を出した今、開発フローの変革が始まっています。次の記事では、コミュニティで注目される「uLoopMCP」の実力を検証します。

---

## 参考文献

**Unity公式ドキュメント：**
- [Unity MCP Overview](https://docs.unity3d.com/Packages/com.unity.ai.assistant@2.0/manual/unity-mcp-overview.html)
- [Unity MCP Get Started](https://docs.unity3d.com/Packages/com.unity.ai.assistant@2.0/manual/unity-mcp-get-started.html)

**コミュニティ版MCP：**
- [CoplayDev/unity-mcp（GitHub）](https://github.com/CoplayDev/unity-mcp)
- [IvanMurzak/Unity-MCP（GitHub）](https://github.com/IvanMurzak/Unity-MCP)
- [Comparing Coplay and Unity MCP](https://coplay.dev/blog/comparing-coplay-and-unity-mcp)

**Model Context Protocol（MCP）：**
- [MCP公式仕様](https://modelcontextprotocol.io/)
