---
title: "Unity × ChatGPT × VoiceVox - AIキャラクターをゼロから実装する"
emoji: "🤖"
type: "tech"
topics: ["unity", "chatgpt", "voicevox", "ai", "gamedev"]
published: true
published_at: 2026-04-04 18:00
---

## はじめに - AIキャラクターの可能性

ゲームやアプリにおいて、キャラクターがユーザーの問いかけに対しリアルタイムで音声付きの応答を返す――。かつてSFの領域だったこの体験が、OpenAI API（ChatGPT）とVoiceVoxの組み合わせにより、個人開発者でも実現可能になった。

本記事では、Unity上で**テキスト生成 → 音声合成 → 3Dキャラクターとの同期**までを一気通貫で実装するパイプラインを解説する。NPCとの自然言語会話、バーチャル接客、VTuber配信など、応用先は多岐にわたる。

:::message
本記事は以下の個別トピックを1本にまとめた包括ガイドである。
- ChatGPT APIのストリーミング受信
- UnityWebRequestによるチャンク逐次処理
- VoiceVoxを使った音声合成
- Queue制御によるリアルタイム発話・アニメーション同期
:::

## アーキテクチャ - パイプライン全体像

AIキャラクターの発話システムは、大きく3つのレイヤーで構成される。

```
ユーザー入力（テキスト/音声）
    │
    ▼
┌──────────────────────────┐
│  OpenAI API (ChatGPT)    │  ← ストリーミングで逐次テキスト生成
│  stream=true             │
└──────────┬───────────────┘
           │ 句読点・記号で1文ずつ区切り
           ▼
┌──────────────────────────┐
│  VoiceVox Engine         │  ← テキストをWAV音声に変換
│  audio_query → synthesis │
└──────────┬───────────────┘
           │ AudioClip化
           ▼
┌──────────────────────────┐
│  Unity 3Dキャラクター     │  ← 音声再生・リップシンク・アニメーション
│  AudioSource + uLipSync  │
└──────────────────────────┘
```

データの流れは一方向であり、各レイヤーは疎結合に保つ。これにより、ChatGPTを別のLLMに差し替えたり、VoiceVoxの代わりにCOEIROINKを使うといった変更にも柔軟に対応できる。

## ChatGPT連携 - ストリーミングレスポンスの実装

### なぜストリーミングが必要か

通常のAPI呼び出しでは、ChatGPTの応答全文が生成完了するまで待つことになる。数百トークンの生成に数秒かかるため、ユーザーはその間「固まった」キャラクターを見続けることになり、体験が著しく損なわれる。

`stream=true`を指定すれば、生成途中のトークンがチャンク単位で逐次送信される。これにより、テキスト表示の即時開始と、句単位での音声合成パイプラインへの受け渡しが可能になる。

### UnityWebRequestによるチャンク受信

Unityでストリーミングを受信するには、`DownloadHandlerScript`を継承したカスタムハンドラを実装する。

```csharp
public class StreamDownloadHandler : DownloadHandlerScript
{
    public event Action<string> OnChunkReceived;

    protected override bool ReceiveData(byte[] data, int dataLength)
    {
        if (data == null || dataLength == 0) return true;

        string chunk = System.Text.Encoding.UTF8.GetString(data, 0, dataLength);

        // SSE形式をパースし、delta.contentを抽出
        foreach (string line in chunk.Split('\n'))
        {
            if (!line.StartsWith("data: ")) continue;
            string json = line.Substring(6);
            if (json == "[DONE]") break;

            // JSONからトークン文字列を取得
            var token = ParseDeltaContent(json);
            if (!string.IsNullOrEmpty(token))
            {
                OnChunkReceived?.Invoke(token);
            }
        }
        return true;
    }
}
```

:::message
`ReceiveData`はサーバーからチャンクが届くたびに呼び出される。SSE（Server-Sent Events）形式の各行を解析し、生成されたトークンだけを抽出する点がポイントである。
:::

### APIリクエストの送信

```csharp
public IEnumerator SendChatRequest(string userMessage)
{
    var requestBody = new
    {
        model = "gpt-4o-mini",
        stream = true,
        messages = new[]
        {
            new { role = "system", content = _systemPrompt },
            new { role = "user", content = userMessage }
        }
    };

    var request = new UnityWebRequest(_endpoint, "POST");
    byte[] body = Encoding.UTF8.GetBytes(JsonUtility.ToJson(requestBody));
    request.uploadHandler = new UploadHandlerRaw(body);
    request.downloadHandler = new StreamDownloadHandler();
    request.SetRequestHeader("Content-Type", "application/json");
    request.SetRequestHeader("Authorization", "Bearer " + _apiKey);

    yield return request.SendWebRequest();

    if (request.result != UnityWebRequest.Result.Success)
    {
        Debug.LogError($"API Error: {request.error}");
    }
}
```

受信した各トークンは文字列バッファに蓄積し、句読点（。、！、？）が出現した時点で1文として確定させ、次の音声合成ステージへ渡す。

## VoiceVox統合 - テキストから音声合成

VoiceVoxはローカルで動作するTTS（Text-to-Speech）エンジンであり、REST APIを通じて音声合成を行う。処理は2ステップで構成される。

1. **audio_query** - テキストから音声合成用のクエリ（アクセント・イントネーション情報）を生成
2. **synthesis** - クエリをもとにWAV形式の音声データを合成

```csharp
public IEnumerator SynthesizeVoice(string text, int speakerId, Action<AudioClip> onComplete)
{
    // Step 1: audio_query
    string queryUrl = $"http://localhost:50021/audio_query?text={UnityWebRequest.EscapeURL(text)}&speaker={speakerId}";
    using var queryReq = UnityWebRequest.Post(queryUrl, "");
    yield return queryReq.SendWebRequest();

    string queryJson = queryReq.downloadHandler.text;

    // Step 2: synthesis
    string synthUrl = $"http://localhost:50021/synthesis?speaker={speakerId}";
    using var synthReq = new UnityWebRequest(synthUrl, "POST");
    byte[] queryBytes = Encoding.UTF8.GetBytes(queryJson);
    synthReq.uploadHandler = new UploadHandlerRaw(queryBytes);
    synthReq.downloadHandler = new DownloadHandlerAudioClip(synthUrl, AudioType.WAV);
    synthReq.SetRequestHeader("Content-Type", "application/json");

    yield return synthReq.SendWebRequest();

    if (synthReq.result == UnityWebRequest.Result.Success)
    {
        AudioClip clip = DownloadHandlerAudioClip.GetContent(synthReq);
        onComplete?.Invoke(clip);
    }
}
```

VoiceVoxのspeakerIdを切り替えることで、キャラクターごとに異なる声質を割り当てることも容易である。

## 3Dキャラとの同期 - リップシンク・アニメーション連携

### Queueによる逐次再生制御

ChatGPTからは非同期でテキストが流れ続けるため、音声合成・再生を直列に制御しないと発話が重複する。ここで**Queue（先入れ先出し）**によるバッファリングが有効になる。

```csharp
public class CharacterPerformanceManager : MonoBehaviour
{
    private readonly Queue<PerformanceData> _queue = new();
    private bool _isPlaying;

    public void Enqueue(PerformanceData data)
    {
        _queue.Enqueue(data);
        if (!_isPlaying) StartCoroutine(ProcessQueue());
    }

    private IEnumerator ProcessQueue()
    {
        _isPlaying = true;

        while (_queue.Count > 0)
        {
            var data = _queue.Dequeue();

            // 1. 音声合成
            AudioClip clip = null;
            yield return SynthesizeVoice(data.Text, data.SpeakerId, c => clip = c);

            // 2. 字幕表示
            _subtitleText.text = data.Text;

            // 3. アニメーション切り替え
            _animator.SetTrigger(data.AnimationTrigger);

            // 4. 音声再生（リップシンクはuLipSyncが自動処理）
            _audioSource.clip = clip;
            _audioSource.Play();

            // 再生完了まで待機
            while (_audioSource.isPlaying) yield return null;
        }

        _isPlaying = false;
    }
}
```

### リップシンクの実装

リップシンクには**uLipSync**アセットが有効である。AudioSourceの音声波形をリアルタイム解析し、母音に対応するブレンドシェイプを自動で駆動する。VRMモデルを使用する場合は、以下の手順で設定する。

1. キャラクターのGameObjectに`uLipSync`コンポーネントを追加
2. `uLipSyncBlendShape`で各母音（あ・い・う・え・お）にブレンドシェイプを割り当て
3. AudioSourceを指定すれば、再生中の音声に連動して口が動く

追加で**表情やボディアニメーション**を制御したい場合は、ChatGPTのプロンプトに感情記号のルールを組み込むことで実現できる。

```plaintext
以下のルールに従い、各発言の冒頭に感情記号を付与してください:
[joy] - 喜び / [sad] - 悲しみ / [anger] - 怒り / [neutral] - 通常
例: [joy]今日はいい天気だね！
```

この記号をパースし、Animatorのトリガーやパラメータにマッピングすることで、発話内容に応じた表情変化を自動化できる。

:::message
プロンプトで感情記号を正しく出力させるには試行錯誤が必要である。うまくいかない場合は「出力形式が守られていない」とChatGPTにフィードバックし、プロンプト自体をリライトさせるテクニックが有効だ。
:::

## まとめ - AIキャラクターの今後

本記事では、Unity上でChatGPTとVoiceVoxを連携させ、AIキャラクターがリアルタイムに発話・動作するシステムの構築方法を解説した。

要点を振り返る:

- **ストリーミング受信**: `DownloadHandlerScript`を継承し、ChatGPTからのトークンを逐次取得する
- **句単位の分割**: 句読点で文を区切り、1文ずつ音声合成パイプラインへ送る
- **VoiceVox連携**: audio_query → synthesisの2ステップでテキストをWAV音声に変換する
- **Queue制御**: 先入れ先出しのキューで発話の重複を防ぎ、字幕・アニメーションと同期する
- **リップシンク**: uLipSyncで音声波形からブレンドシェイプを自動駆動する

この基盤を応用すれば、ゲーム内NPCとの自然言語会話、VTuber配信での自動応答、展示会でのバーチャル接客など、様々な体験を構築できる。今後はマルチモーダルAI（GPT-4oなど）の進化により、音声入力からの直接応答や、より豊かな感情表現が可能になることが期待される。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
