---
title: "LLMUnityでAIキャラクターにローカルLLMを組み込んだ実装記録"
emoji: "🧠"
type: "tech"
topics: ["unity", "llm", "llmunity", "csharp", "ai"]
published: false
published_at: 2026-03-29 17:00
---

## はじめに

私は現在、VTuberやゲームNPC向けのAIキャラクターフレームワーク（ai-character-core）を開発しています。これまでOpenAI、Claude、Geminiといったクラウド型LLMに対応していましたが、ローカルLLM対応を追加する必要がありました。

**目的は明確でした。ai.jsonのproviderフィールドを"LLMUnity"に変更するだけで、既存のクラウドAPIと同じように動作するローカルLLMサービスを実現すること。**

選択肢を検討した結果、[LLM for Unity（LLMUnity）](https://github.com/undreamai/LLMUnity)を採用しました。理由は以下の通りです。

- llama.cppベースで推論速度が速い
- GGUF形式のモデルをそのまま使える
- Unity統合済みでInspectorから設定可能
- RAGシステム（LLMEmbedder）もセットで提供

結果として、IAIServiceインターフェースにLLMUnityServiceを追加し、ai.jsonの1行変更でプロバイダーを切り替え可能にすることができました。

## アーキテクチャの課題: MonoBehaviourとDIの衝突

最初に直面した問題は、LLMUnityとマルチプロバイダー設計の根本的な相性の悪さでした。

**既存のAIサービス実装:**
```csharp
// OpenAI/Claude/GeminiはPure C#クラス → newで生成可能
IAIService openai = new OpenAIService();
IAIService claude = new ClaudeService();
IAIService gemini = new GeminiService();
```

これらはMonoBehaviourに依存しないため、ファクトリーパターンでnew演算子を使って生成できます。

**LLMUnityの要求:**
```csharp
// LLMCharacterはMonoBehaviour → InspectorでLLMコンポーネントへの参照が必須
public class SomeMonoBehaviour : MonoBehaviour
{
    public LLMCharacter llmCharacter; // InspectorからD&D設定
}
```

LLMUnityは `LLMCharacter` というMonoBehaviourコンポーネントが必須で、そこから `Chat()` メソッドを呼び出す設計になっています。**MonoBehaviourはnewできません。**

この衝突をどう解決するか？答えは「後注入パターン」でした。

### 解決策: ファクトリー生成→後からInspector参照を注入

```csharp:AIServiceFactory.cs
public static class AIServiceFactory
{
    public static IAIService CreateService(AIServiceType serviceType, AIServiceConfig config = null)
    {
        return serviceType switch
        {
            AIServiceType.OpenAI => new OpenAIService(),
            AIServiceType.Claude => new ClaudeService(),
            AIServiceType.Gemini => new GeminiService(),
            AIServiceType.Ollama => new OllamaService(),
            AIServiceType.LLMUnity => new LLMUnityService(), // パラメータなしでnew
            _ => throw new NotSupportedException($"AI service type {serviceType} is not supported")
        };
    }
}
```

まずパラメータなしでnewします。その後、CharacterSystemが `SetLLMCharacter()` でInspectorの参照を後から注入します。

```csharp:CharacterSystem.cs（抜粋）
// ファクトリーで生成
_aiService = AIServiceFactory.CreateService(config.Provider);

// LLMUnityの場合のみ、Inspector参照を後注入
if (_aiService is LLMUnityService llmUnityService && llmCharacter != null)
{
    llmUnityService.SetLLMCharacter(llmCharacter);
}

await _aiService.InitializeAsync(config);
```

この設計により、LLMUnityServiceは他のサービスと同じファクトリー経由で生成でき、かつMonoBehaviour依存も満たせるようになりました。

## 実装: IAIServiceインターフェースへの統合

### 核心: コールバック→IAsyncEnumerable変換

LLMUnityの `Chat()` メソッドはコールバック方式です。

```csharp
llmCharacter.Chat(
    message,
    onPartialReply: (string partialText) => { /* 累積テキスト */ },
    onComplete: () => { /* 完了通知 */ }
);
```

一方、IAIServiceインターフェースはIAsyncEnumerable<AIResponse>によるストリーミングを要求します。

```csharp
IAsyncEnumerable<AIResponse> SendMessageStreamingAsync(
    AIRequest request,
    CancellationToken cancellationToken = default);
```

この変換を実現するために、ConcurrentQueueとTaskCompletionSourceを使いました。

```csharp:LLMUnityService.cs
#if LLM_UNITY

using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using LLMUnity;
using UnityEngine;

public class LLMUnityService : IAIService
{
    public string ServiceName => "LLMUnity";
    public bool IsInitialized { get; private set; }

    private LLMCharacter llmCharacter;
    private AIServiceConfig config;

    public LLMUnityService() { }

    public LLMUnityService(LLMCharacter llmCharacter)
    {
        this.llmCharacter = llmCharacter;
    }

    public void SetLLMCharacter(LLMCharacter character)
    {
        llmCharacter = character;
    }

    public async Task<bool> InitializeAsync(AIServiceConfig config)
    {
        try
        {
            this.config = config;
            if (llmCharacter == null)
            {
                Debug.LogError("[LLMUnityService] LLMCharacterが設定されていません。");
                return false;
            }
            // ai.jsonのシステムプロンプト・温度・最大トークン数を反映
            if (!string.IsNullOrEmpty(config?.SystemPrompt))
            {
                llmCharacter.prompt = config.SystemPrompt;
            }
            if (config != null)
            {
                llmCharacter.temperature = config.Temperature;
                llmCharacter.numPredict = config.MaxTokens;
            }
            IsInitialized = true;
            await Task.CompletedTask;
            return true;
        }
        catch (Exception ex)
        {
            Debug.LogError($"[LLMUnityService] 初期化失敗: {ex.Message}");
            return false;
        }
    }

    public async IAsyncEnumerable<AIResponse> SendMessageStreamingAsync(
        AIRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        if (!IsInitialized || llmCharacter == null)
        {
            yield return new AIResponse { ErrorMessage = "サービスが初期化されていません", IsComplete = true };
            yield break;
        }

        var chunkQueue = new System.Collections.Concurrent.ConcurrentQueue<string>();
        var completionSource = new TaskCompletionSource<string>();

        cancellationToken.Register(() => completionSource.TrySetCanceled());

        // 累積テキストから差分を抽出するロジック
        string previousText = "";
        _ = llmCharacter.Chat(
            request.Message,
            partialReply =>
            {
                if (!string.IsNullOrEmpty(partialReply) && partialReply.Length > previousText.Length)
                {
                    var delta = partialReply.Substring(previousText.Length);
                    chunkQueue.Enqueue(delta);
                    previousText = partialReply;
                }
            },
            () => completionSource.TrySetResult("")
        );

        // 非同期ストリームで差分を順次返す
        while (!completionSource.Task.IsCompleted)
        {
            if (cancellationToken.IsCancellationRequested) yield break;
            while (chunkQueue.TryDequeue(out var chunk))
            {
                yield return new AIResponse { Content = chunk, IsComplete = false };
            }
            await Task.Delay(10, cancellationToken).ContinueWith(_ => { });
        }

        while (chunkQueue.TryDequeue(out var remainingChunk))
        {
            yield return new AIResponse { Content = remainingChunk, IsComplete = false };
        }

        yield return new AIResponse { Content = "", IsComplete = true };
    }

    public void Dispose() { IsInitialized = false; }
}

#else

// LLMUnityパッケージがインストールされていない環境用のスタブ
public class LLMUnityService : IAIService
{
    public string ServiceName => "LLMUnity (Not Installed)";
    public bool IsInitialized => false;

    public Task<bool> InitializeAsync(AIServiceConfig config)
    {
        Debug.LogError("[LLMUnityService] LLMUnityパッケージがインストールされていません。");
        return Task.FromResult(false);
    }

    public async IAsyncEnumerable<AIResponse> SendMessageStreamingAsync(
        AIRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        yield return new AIResponse
        {
            ErrorMessage = "LLMUnityパッケージがインストールされていません",
            IsComplete = true
        };
        await Task.CompletedTask;
    }

    public void Dispose() { }
}

#endif
```

**ポイント:**
- `previousText` で累積テキストを保持し、差分だけを抽出
- `ConcurrentQueue` でスレッドセーフなチャンクキューを実現
- `TaskCompletionSource` で完了通知を待機
- `#if LLM_UNITY` でパッケージ未インストール環境でもコンパイル可能

この実装により、LLMUnityのコールバック方式をIAsyncEnumerable<AIResponse>に変換でき、既存のCharacterSystemのストリーミングパイプラインに統合できました。

## パッケージ依存の分離: 条件分岐コンパイル

LLMUnityパッケージがインストールされていない環境でもコンパイルが通るよう、`#if LLM_UNITY` による条件分岐を使用しています。

**Assembly Definition (.asmdef) で定義:**
```json
{
    "name": "AICharacter.Core",
    "versionDefines": [
        {
            "name": "com.undreamai.llmunity",
            "expression": "",
            "define": "LLM_UNITY"
        }
    ]
}
```

パッケージがインストールされていれば `LLM_UNITY` シンボルが定義され、本実装が有効になります。なければスタブ実装が使われ、エラーメッセージを返します。

## RAG（検索拡張生成）のローカル化

LLMUnityは推論だけでなく、Embeddingもローカル実行できます。LLMEmbedderコンポーネントを使い、OpenAI Embeddingと同じIEmbeddingServiceインターフェースに統合しました。

```csharp:LLMUnityEmbeddingService.cs
#if LLM_UNITY

using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using LLMUnity;
using UnityEngine;

public class LLMUnityEmbeddingService : IEmbeddingService
{
    public int EmbeddingDimension { get; private set; }
    private LLMEmbedder llmEmbedder;

    public void SetLLMEmbedder(LLMEmbedder embedder)
    {
        llmEmbedder = embedder;
        // 初期化時に次元数を0にリセット（実際の埋め込み実行時に自動補正）
        EmbeddingDimension = 0;
    }

    public async Task<float[]> GetEmbeddingAsync(string text, CancellationToken cancellationToken = default)
    {
        if (llmEmbedder == null)
        {
            Debug.LogError("[LLMUnityEmbeddingService] LLMEmbedderが設定されていません。");
            return new float[0];
        }

        List<float> embeddingList = await llmEmbedder.Embeddings(text);
        float[] result = embeddingList.ToArray();

        // 実際の次元数で自動補正（モデルによって異なるため）
        if (EmbeddingDimension != result.Length)
        {
            EmbeddingDimension = result.Length;
            Debug.Log($"[LLMUnityEmbeddingService] Embedding次元数を自動補正: {EmbeddingDimension}");
        }

        return result;
    }
}

#endif
```

**重要な実装ポイント:**
- Embedding次元数はモデル依存（例: all-MiniLM-L6-v2なら384次元）
- 初回実行時に実際の次元数を自動検出して補正
- OpenAI Embeddingと同じインターフェースで呼び出し可能

これにより、RAGシステムも完全にローカルで動作するようになりました。

## ai.jsonによるプロバイダー切り替え

実際のai.jsonファイルはこのような形です。

```json:ai.json
{
    "provider": "LLMUnity",
    "temperature": 0.7,
    "maxTokens": 500,
    "useStreaming": true,
    "systemPrompt": "あなたは冒険者ギルドの受付嬢リリアです。丁寧だが少しおっちょこちょいな性格で、冒険者に依頼を紹介する役割を担っています。"
}
```

**providerフィールドを変更するだけ:**
- `"OpenAI"` → OpenAI APIを使用
- `"Claude"` → Claude APIを使用
- `"Gemini"` → Gemini APIを使用
- `"LLMUnity"` → ローカルLLMを使用

APIキー設定、エンドポイント指定、認証ヘッダー等の変更は一切不要です。同じシステムプロンプト、温度、最大トークン数設定がそのまま適用されます。

## アーキテクチャ全体図

最終的なアーキテクチャは以下のようになりました。

```
入力層:
  YouTubeInputAdapter（YouTube配信コメント）
  ScriptInputAdapter（シナリオ台本）
  TextInputAdapter（テキスト入力）
  VoiceInputAdapter（音声入力 + Whisper文字起こし）
        ↓
CharacterSystem（コア制御）:
  1. 入力キュー管理
  2. AI推論（IAIService経由）← ここで OpenAI / Claude / Gemini / LLMUnity を切り替え
  3. 文分割パイプライン（句読点区切り）
  4. 音声合成（IVoiceService経由）
  5. 再生キュー管理
        ↓
サービス層:
  - AI推論:
      OpenAIService
      ClaudeService
      GeminiService
      OllamaService
      LLMUnityService ← 今回追加
  - 音声合成:
      VoicevoxService
      OpenAITTSService
  - RAG（検索拡張生成）:
      RAGService
        ↓
      Embedding:
        OpenAIEmbeddingService
        LLMUnityEmbeddingService ← 今回追加
        ↓
出力層:
  EmotionService → VRM BlendShape制御（喜怒哀楽表情）
  AnimationService → Animator制御（モーション再生）
  SubtitleService → TextMeshPro字幕表示
```

**この設計の利点:**
- 開発時はOpenAI APIで高速イテレーション
- 本番環境はローカルLLMでコスト削減・オフライン対応
- 1行の設定変更でプロバイダー切り替え可能
- 新しいLLMプロバイダーの追加が容易（IAIServiceを実装するだけ）

## 実際に動かしてわかったこと

### 初回起動が重い → Warmup()で対処

LLMUnityは初回推論時にモデルをメモリにロードするため、1回目の応答が遅くなります。`Warmup()` を使って事前ロードすることで解決しました。

```csharp
await llmCharacter.Warmup();
```

### GPUレイヤー数の調整が重要

InspectorのnumGPULayersを増やすとGPU推論が増えて高速化しますが、VRAMを大量に消費します。ターゲット環境のVRAM容量に応じて調整が必要でした。

| 環境 | 推奨numGPULayers |
|------|-----------------|
| RTX 4090（24GB VRAM） | 全層（例: 32層） |
| RTX 3060（12GB VRAM） | 半分（例: 16層） |
| M1 Mac（統合メモリ） | 全層（統合メモリのため柔軟） |

### 日本語性能はまだ発展途上

ローカルLLMの日本語性能は、クラウドAPIに比べるとまだ差があります。特に1-2Bの軽量モデルは会話の自然さに課題があります。

**比較的良好だったモデル:**
- Qwen2.5系（多言語最適化されている）
- Gemma3（Googleの多言語事前学習の恩恵）

**今後の期待:**
- 日本語特化ファインチューニングモデルの増加
- 量子化手法の改良（Q4でも品質維持）

### 完全オフラインAIキャラクターの実現

最終的に、以下の構成で完全オフライン動作するAIキャラクターを実現できました。

- VRMアバター（3Dモデル）
- VoiceVox（音声合成）
- LLMUnity（ローカルLLM推論）
- LLMEmbedder（ローカルEmbedding）

**インターネット接続なしで動作し、APIコストもゼロ。プライバシーも完全に保護されます。**

## まとめ

LLMUnityをマルチプロバイダー設計に統合した結果、以下が実現できました。

1. **ai.jsonの1行変更でクラウドAPI↔ローカルLLMを切り替え可能**
2. **MonoBehaviour依存は後注入パターンで解決**
3. **条件分岐コンパイルでパッケージ未インストール環境にも対応**
4. **RAGシステムも完全ローカル化**
5. **開発はクラウドAPI、本番はローカルLLMというワークフローが実現**

マルチプロバイダー設計にしておくと、新しいLLMサービスの追加が1クラスの実装で済むため、今後の拡張も容易です。

LLMUnityはllama.cppの高速推論エンジンをUnityから数行で呼び出せる優れたパッケージです。Unity Asset Storeで無料配布されており、商用利用も可能です。

興味がある方は[LLMUnity公式リポジトリ](https://github.com/undreamai/LLMUnity)からすぐに試すことができます。
