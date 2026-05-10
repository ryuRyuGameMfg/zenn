---
title: "LLMで動的ストーリーを実装する4つのナラティブ設計パターン【Unity/UE対応】"
emoji: "📖"
type: "tech"
topics: ["unity", "game-development", "ai", "llm", "csharp"]
published: true
published_at: 2026-03-08 18:00
---

## 結論から言うと

LLMを使えば、固定スクリプトなしでNPCがプレイヤーの発言に文脈適応した応答を返す「動的ナラティブ」をUnity/Unreal Engine上で実装できます。設計の核心は「目標定義（Section）」「分岐判断（Decision）」「動的変数注入（Trigger）」「LLM応答生成」という4つのパターンの組み合わせです。 **従来の分岐ツリー開発と比べ、コンテンツ管理コストを大幅に削減しながら没入感の高いナラティブが実現できます。**

## パターン0: 従来のナラティブシステムの限界

従来手法を代表するのは「ダイアログツリー（分岐ツリー）」です。開発者がすべての会話パターンを事前に定義し、プレイヤーは用意された選択肢から選ぶ形式です。

この方式が抱える主な問題は3つです。

- **スケールの壁**: 分岐が増えるほど管理コストが指数関数的に増大する
- **文脈の欠如**: プレイヤーが過去に何をしたかを反映した応答が作れない
- **創造性の制限**: 用意された選択肢の外には出られないため、没入感が損なわれる

有限状態機械（FSM）ベースのシステムも同様の問題を抱えています。状態数が増えると、遷移ルールの管理が破綻します。

:::message alert
分岐ツリーで「動的に見える」ナラティブを作ろうとすると、コンテンツ量が爆発します。AAA タイトルでも、実態は「固定台詞の組み合わせ」に過ぎないケースが多いです。
:::

## パターン1: Section・Decision・Trigger によるナラティブグラフ設計

LLMを使ったナラティブシステムの核心は、「構造化された目標」と「自由なAI生成」の両立です。開発者は会話の方向性（何を達成すべきか）を定義し、具体的なセリフ生成はLLMに委ねます。

Convaiが採用しているNarrative Graphは、以下の3要素で構成されます。

```mermaid
graph TD
    A[Section<br>シーン・目標定義] --> B[Decision<br>分岐判断点]
    B --> C[Trigger<br>イベント起動]
    C --> D[LLM Engine<br>文脈適応型応答生成]
    D --> E[プレイヤーへの応答]
    E --> B
```

動的変数の注入が特に強力な機能です。ゲーム状態をリアルタイムでナラティブに反映できます。

```text
Objective例:
"The time of day is {TimeOfDay}.
 Welcome the player and ask how their {TimeOfDay} is going."
```

`{TimeOfDay}` の部分にゲームエンジン側から "Morning" や "Night" を渡すことで、同じObjectiveから文脈の異なる会話が生まれます。

:::message
動的変数の記法ルール: 波括弧内にスペースを入れない。
`{CorrectFormat}` が正しく、`{Wrong Format}` はエラーになります。
:::

## パターン2: 従来型 vs LLM型ナラティブシステム比較

| 項目 | 従来型（分岐ツリー） | LLM型（Narrative Graph） |
|------|---------------------|--------------------------|
| セリフ生成 | 事前定義済み | リアルタイム生成 |
| 文脈反映 | 限定的 | 会話履歴を参照 |
| 開発コスト | 分岐数に比例して増大 | 目標定義のみ |
| 一貫性 | 高い（固定） | ガイドライン設計が必要 |
| 自由度 | 選択肢内のみ | 自然言語で自由に |
| エッジケース | 定義外は対応不可 | Knowledge Bankで補完 |

## パターン3: Unity × Convai での実装手順

### セットアップ手順

ConvaiのUnityプラグインをインポート後、以下の手順でNarrative Design Managerを設定します。

```text
ConvaiNPC Inspector
  → Add Components
  → Narrative Design Manager
  → Apply Changes
```

Section Triggerの設置により、プレイヤーが特定エリアに入った際にナラティブが自動起動します。

```text
GameObject（Collider必須）
  → Add Component: Narrative Design Trigger
  → Collider: Is Trigger を ON
  → ConvaiNPC フィールドにキャラクターを割り当て
  → Trigger ドロップダウンで発火条件を選択
```

### C# からの手動起動

Convai以外のアプローチとして、OpenAI APIを直接Unityから呼び出す実装例を示す。動的変数の注入パターンは先述のNarrative Graphと同じ考え方だ。

```csharp:LLMNarrativeController.cs
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;
using System.Text;

/// <summary>
/// UnityからLLM APIを呼び出してNPCのダイアログを動的生成するコントローラー
/// </summary>
public class LLMNarrativeController : MonoBehaviour
{
    [Header("API設定")]
    [SerializeField] private string apiEndpoint = "https://api.openai.com/v1/chat/completions";
    [SerializeField] private string apiKey; // Inspector で設定（本番はSecrets管理推奨）

    [Header("NPCキャラクター設定")]
    [SerializeField] private string characterName = "商人エルドン";
    [SerializeField, TextArea] private string characterPersonality =
        "あなたは冒険者に友好的な年老いた商人です。" +
        "地元の伝説をよく知っており、アドバイスを与えます。";

    [Header("動的変数")]
    [SerializeField] private string playerName = "勇者";
    [SerializeField] private string timeOfDay = "夕暮れ";

    // プレイヤーの入力を受け取ってNPCの応答を返す
    public void GetNPCResponse(string playerInput, System.Action<string> onResponse)
    {
        StartCoroutine(CallLLMAPI(playerInput, onResponse));
    }

    private IEnumerator CallLLMAPI(string playerInput, System.Action<string> onResponse)
    {
        // システムプロンプトに動的変数を注入
        string systemPrompt = $@"
{characterPersonality}

現在の状況:
- 時間帯: {timeOfDay}
- プレイヤー名: {playerName}
- キャラクター名: {characterName}

プレイヤーの発言に対して、キャラクターとして自然に応答してください。
日本語で2〜3文で返答してください。";

        // OpenAI API リクエストボディ
        string jsonBody = JsonUtility.ToJson(new ChatRequest
        {
            model = "gpt-4o-mini",
            messages = new[]
            {
                new Message { role = "system", content = systemPrompt },
                new Message { role = "user", content = playerInput }
            }
        });

        using var request = new UnityWebRequest(apiEndpoint, "POST");
        request.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(jsonBody));
        request.downloadHandler = new DownloadHandlerBuffer();
        request.SetRequestHeader("Content-Type", "application/json");
        request.SetRequestHeader("Authorization", $"Bearer {apiKey}");

        yield return request.SendWebRequest();

        if (request.result == UnityWebRequest.Result.Success)
        {
            var response = JsonUtility.FromJson<ChatResponse>(request.downloadHandler.text);
            onResponse?.Invoke(response.choices[0].message.content);
        }
        else
        {
            Debug.LogError($"LLM API呼び出し失敗: {request.error}");
            onResponse?.Invoke("（応答生成に失敗しました）");
        }
    }
}

// APIリクエスト/レスポンスのデータクラス
[System.Serializable]
public class ChatRequest
{
    public string model;
    public Message[] messages;
}

[System.Serializable]
public class Message
{
    public string role;
    public string content;
}

[System.Serializable]
public class ChatResponse
{
    public Choice[] choices;
}

[System.Serializable]
public class Choice
{
    public Message message;
}
```

### 動的変数の注入（Unreal Engine側の参考実装）

:::details Unreal Engine Blueprint側の設定例

Unreal EngineではBlueprintのMap型変数でテンプレートキーを管理します。

```text
Narrative Template Keys（Map型）:
  Key:   "TimeOfDay"    → Value: "Morning"
  Key:   "PlayerName"   → Value: "Taro"
  Key:   "QuestStatus"  → Value: "InProgress"
```

Blueprint内でゲーム状態が変わるたびに Value を更新することで、NPCの応答が自動的に変化します。Sectionに設定したObjectiveが `{TimeOfDay}` を参照していれば、同一キャラクターが朝・昼・夜で異なるセリフを話します。

:::

```mermaid
sequenceDiagram
    participant P as Player
    participant E as Game Engine
    participant N as NPC (Convai)
    participant L as LLM

    P->>E: エリアに進入
    E->>N: Trigger発火（TimeOfDay="Night"）
    N->>L: Objective + 動的変数を送信
    L->>N: 文脈に応じた応答を生成
    N->>P: 「夜遅いな、旅人よ。何か用か？」
    P->>N: 自然言語で返答
    L->>N: 会話履歴を参照して応答
    N->>P: 継続する動的な会話
```

## パターン4: AIナラティブツール比較と選定指針

ConvaiはUnity/Unreal向けの代表的なツールですが、他の選択肢も知っておくことが重要です。

| ツール | 特徴 | 強み | 価格帯 |
|--------|------|------|--------|
| Convai | リアルタイム音声 + 世界認識NPC | グラフ型ナラティブ、エンジン統合 | 無料〜$99/月 |
| Inworld AI | 感情・記憶・動機を持つキャラクター | 深いキャラクター設計、専用エンジン | 使用量課金 |
| LLMUnity | Unity内でLLMをローカル実行 | オフライン動作、コスト0 | 無料（OSS） |
| Eden AI | マルチLLMチャットボット | 複数LLMの切り替え | 従量制 |

:::message
**インディーゲーム開発者へのアドバイス**: 予算が限られているなら、まずLLMUnity（ローカル実行）で実験し、品質が必要になった段階でConvaiの無料プランに移行するのが現実的なルートです。
:::

## まとめ

LLMによるナラティブデザインは、「会話ツリーを書く作業」から「キャラクターの目標と世界観を設計する作業」へのパラダイムシフトをもたらします。

本記事で解説した核心的なポイントを整理します。

```mermaid
graph LR
    A[目標定義<br>Section] --> B[分岐設計<br>Decision]
    B --> C[動的変数<br>Trigger]
    C --> D[LLM生成<br>Response]
    D --> E[没入感の向上]
```

次のステップとして、まずConvaiの無料プランでNarrative Graphを体験してみることを推奨します。固定スクリプトでは実現できなかった「プレイヤーの行動に応じて変化するNPC」の手応えを、小さなプロトタイプで確認できます。

技術的なチャレンジはLLMの一貫性管理とコスト設計にありますが、Knowledge Bankとキャラクター設定の丁寧な作り込みで十分にコントロール可能な領域です。

**参考資料**

- [AI-Driven Narrative Design for Lifelike Characters in Unreal Engine & Unity（Convai公式）](https://convai.com/blog/ai-narrative-design-unreal-engine-and-unity-convai-guide)
- [LLM-Driven NPCs: Cross-Platform Dialogue System（arxiv）](https://arxiv.org/html/2504.13928v1)
- [Using LLMs for NPC Dialogue in Unity（Gerard Robert Kirwin）](https://gerardrobertkirwin.com/blog/2025/10/14/using-llms-for-npc-dialogue-in-unity)
- [Unscripted AI NPCs in Unreal Engine - Origins Demo（Inworld AI）](https://inworld.ai/blog/origins-unreal-engine-demo)

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064

この記事が参考になったら **いいね** をお願いします。
