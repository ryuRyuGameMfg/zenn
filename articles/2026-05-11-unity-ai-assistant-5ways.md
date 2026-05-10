---
title: "Unity AI入門：エディタ内AIアシスタントでゲーム開発を効率化する5つの使い方"
emoji: "🤖"
type: "tech"
topics: ["unity", "ai", "gamedev", "csharp"]
published: false
---

2026年5月4日、Unity AIがOpen Betaになった。

インストールしてすぐ使えるエディタ内チャット、テキストからスプライト・サウンド・アニメーションを生成するGenerators、MLモデルをランタイム推論するSentis――この3つが1つのパッケージ群として整備された状態で公開されている。日本語の記事がまだほとんどない段階なので、実際に動かして確認した内容を整理する。

**Unity AIは「外部ツールに接続する」方式ではなく、エディタに直接組み込まれたAI層**だ。外部ツールとの連携（Claude Code + MCP Server）については別の記事で扱っているため、ここではエディタ内の組み込み機能に絞る。

https://docs.unity3d.com/6000.3/Documentation/Manual/unity-ai.html

## Unity AIとは何か（3つのコンポーネント）

Unity AIは以下の3パッケージで構成されている。

```mermaid
graph TD
    A[Unity AI] --> B[Assistant<br/>com.unity.ai.assistant]
    A --> C[Generators<br/>com.unity.ai.generators]
    A --> D[Sentis<br/>com.unity.ai.inference]

    B --> B1[/ask: プロジェクト参照クエリ]
    B --> B2[/run: シーン操作 ユーザー承認制]
    B --> B3[/code: C#スクリプト生成]

    C --> C1[スプライト / テクスチャ / マテリアル]
    C --> C2[サウンド / アニメーション / キューブマップ]

    D --> D1[ONNXモデル → .sentisフォーマット]
    D --> D2[ランタイムML推論]
```

3つのパッケージは独立しており、必要なものだけ導入できる。Assistantだけ使いたい場合は `com.unity.ai.assistant` を入れればいい。

| パッケージ | 役割 | インストール名 |
|-----------|------|--------------|
| Assistant | エディタ内チャットエージェント | com.unity.ai.assistant |
| Generators | テキストからアセット生成 | com.unity.ai.generators |
| Sentis | ランタイムML推論 | com.unity.ai.inference |

Assistantのインストール手順は3ステップで終わる。

1. `Window > Package Manager` を開く
2. `+` → `Add package by name` で `com.unity.ai.assistant` を入力
3. `Window > AI > Assistant` でウィンドウを開き、Unityアカウントでログイン

:::message
Unity 6（6000.x系）が動作環境の前提。Unity 2022.x / 2023.x では動作しない可能性がある。Package Managerで見つからない場合はUnityバージョンを確認すること。
:::

## 使い方1: /runコマンドでシーンを自動構築する

Assistantには3つのモードがある。`/ask`（読み取り専用クエリ）、`/run`（シーン操作）、`/code`（スクリプト生成）だ。

最も実用的なのが `/run` だ。シーン操作をAssistantに委任できるが、実行前に必ずユーザーへの承認ステップが入る設計になっている。意図しない変更が走らない安全機構だ。

公式ドキュメントに掲載されている `/run` のプロンプト例を引用する。

```
/run Generate three wide angle spotlights that illuminate the attached character.
A 'Key light' should be bright and pointing straight at the character from about 3m away.
Group them under a new GameObject called 'StudioLighting'.
```

このプロンプトで実行されること：

- `StudioLighting` という名前の空GameObjectを作成
- その下にSpotLightを3つ生成
- Key Lightを正面3m、残り2つをサイドアングルで配置
- 各LightのIntensityとAngleを指示通りに設定

同等の操作をInspectorで手動でやると、GameObject作成・Light追加・Transform調整・親子関係設定と15クリック以上かかる。それが1つのプロンプトで完結する。

:::message
`/run` はシーン内のGameObjectへの操作が対象。プレハブの新規作成やAssetの生成は `/run` の対象外。これらは後述のGeneratorsか `/code` で対応する。
:::

## 使い方2: /codeでC#スクリプトを生成する

`/code` モードはC#スクリプトの生成に特化している。生成されたコードはそのままProjectビューに保存でき、任意のGameObjectへのアタッチまで誘導される。

公式ドキュメントの例：

```
/code Write a script using the new input system that slowly rotates a GameObject
about the y axis based on left and right arrow keys.
```

このプロンプトから生成されるコードの典型的な出力がこれだ。

```csharp:RotateObject.cs
using UnityEngine;
using UnityEngine.InputSystem;

public class RotateObject : MonoBehaviour
{
    [SerializeField] private float rotationSpeed = 45f;

    private InputAction rotateAction;

    private void OnEnable()
    {
        rotateAction = new InputAction(type: InputActionType.Value, binding: "<Keyboard>/leftArrow,<Keyboard>/rightArrow");
        rotateAction.Enable();
    }

    private void OnDisable()
    {
        rotateAction?.Disable();
    }

    private void Update()
    {
        float input = rotateAction.ReadValue<float>();
        transform.Rotate(Vector3.up, input * rotationSpeed * Time.deltaTime);
    }
}
```

新しいInput System（com.unity.inputsystem）を前提としたコードが生成される点が重要で、旧来の `Input.GetKey()` ではなく `InputAction` ベースで書き出される。プロジェクトが旧Input System使用の場合は明示的に「Legacy Input Systemで」と指定する必要がある。

:::message alert
`/code` で生成されたスクリプトは自動的にコンパイル・テストされない。生成後は必ずPlayモードで動作確認すること。特に物理演算・アニメーション・シーン遷移を含むコードは、AIが想定する構成とプロジェクトの既存構成が食い違う場合がある。
:::

https://docs.unity3d.com/Packages/com.unity.ai.assistant@2.4/manual/index.html

## 使い方3: テキストからアセットを量産する（Generators）

`com.unity.ai.generators` パッケージがテキストからアセットを生成する。対応フォーマットは以下の通りだ。

| アセット種別 | 生成内容 |
|------------|---------|
| スプライト | 2Dキャラクター・アイコン・UI素材 |
| テクスチャ | タイル・背景・エフェクト素材 |
| マテリアル | PBRマテリアルのパラメータ設定付き |
| サウンド | SE・BGMのサウンドクリップ |
| アニメーション | キャラクター動作のクリップ |
| キューブマップ | スカイボックス・リフレクションマップ |

プロトタイプ段階で「仮素材を今すぐ用意したい」場面での実用度が高い。「Fire explosion effect, top-down view, transparent background」のようなプロンプトを入力すると、数秒でスプライトが生成されProjectビューに追加される。

生成品質は商用レベルには届かないが、**グレーボックスプロトタイプや内部テスト用途であれば十分機能する**。外部の画像生成サービスに移動せずにエディタ内で完結できることが最大のメリットだ。

## 使い方4: FigmaデザインをそのままUnity UIに変換する

AssistantにはUI Agent機能が含まれており、FigmaのデザインURLを渡すとUXML・USSへの変換を試みる。

```
/run Convert this Figma design to Unity UI Toolkit:
https://www.figma.com/design/[your-file-id]/[your-design-name]
```

出力されるファイル構成：

```
Assets/
└── UI/
    ├── MainMenu.uxml     # UI構造
    └── MainMenu.uss      # スタイルシート
```

UXMLはUI Toolkitのドキュメント構造で、USSはCSSベースのスタイル定義だ。FigmaのオートレイアウトはFlexboxに近い構造を持つため、変換精度は比較的高い。ただし、Figmaのコンポーネント変数やインタラクティブ要素（プロトタイプ遷移）は自動変換の対象外なので、手動で接続する必要がある。

:::message
UI Toolkitを使用しているプロジェクトに限定される機能だ。uGUI（Canvas/Image/TextMeshPro構成）を使っているプロジェクトでは利用できない。新規プロジェクトでUI Toolkitを選択している場合にのみ有効な手段だ。
:::

## 使い方5: SentisでオフラインML推論を実装する

`com.unity.ai.inference`（Sentis）は、ONNXフォーマットのMLモデルをUnityのランタイム上で動作させるパッケージだ。外部APIへの通信が不要なため、**オフライン環境やモバイル・コンソール向けのAI機能実装**に適している。

使い方の基本パターンはこうだ。

1. ONNXモデル（`.onnx`）をProjectビューにドラッグ&ドロップ
2. Unityが `.sentis` フォーマットに自動変換
3. C#スクリプトからモデルをロードして推論を実行

```csharp:SentisInference.cs
using Unity.Sentis;
using UnityEngine;

public class SentisInference : MonoBehaviour
{
    [SerializeField] private ModelAsset modelAsset;

    private Worker worker;

    private void Start()
    {
        var model = ModelLoader.Load(modelAsset);
        worker = new Worker(model, BackendType.GPUCompute);
    }

    private void RunInference(Texture2D inputTexture)
    {
        // テクスチャをTensorに変換
        using var inputTensor = TextureConverter.ToTensor(inputTexture);

        // 推論実行
        worker.Schedule(inputTensor);

        // 結果を取得
        using var output = worker.PeekOutput() as Tensor<float>;
        var result = output.DownloadToArray();

        Debug.Log($"推論結果: {result[0]}");
    }

    private void OnDestroy()
    {
        worker?.Dispose();
    }
}
```

`BackendType.GPUCompute` を指定するとGPUで推論が走る。モバイル向けにはCPUバックエンド（`BackendType.CPU`）に切り替える。Sentisが対応するユースケースは、敵AIの行動判定・アニメーション補間・画像分類など、推論をゲームロジックに組み込みたい場面が中心だ。

:::details 対応バックエンドの一覧

| BackendType | 対象 | 特徴 |
|-------------|------|------|
| GPUCompute | PC / Console | 最高速。ComputeShader使用 |
| GPUCommandBuffer | WebGL / 一部モバイル | GPU対応だがCompute不可環境向け |
| CPU | 全プラットフォーム | 低速だが互換性が高い |

:::

## 料金と注意点

Unity AIは現在Open Betaとして提供されており、以下の制約がある。

| 項目 | 内容 |
|------|------|
| 試用期間 | 14日間の無料トライアル（1,000クレジット付き） |
| 有料プラン | $10 / 1,000クレジット（トライアル終了後） |
| Playモード | 現時点で非対応（エディタ操作のみ） |
| 対応エンジン | Unity 6（6000.x）以降 |

クレジット消費はAssistantのチャットリクエスト単位で発生する。`/ask` の参照クエリと `/run` の操作クエリでクレジット消費量が異なる可能性があるが、現時点で公式からの詳細な仕様公開はない。

:::message alert
現時点でPlayモードへのアクセスは非対応だ。ゲームロジックの実行中にAssistantがシーンを操作することはできない。エディタを停止した状態での操作に限られる。
:::

また、Assistantはプロジェクトの構造を読み取って補完するが、**複雑なゲームシステム（ステートマシン・依存関係の深いコンポーネント設計）の設計判断はまだ人間が行う必要がある**。生成されたコードのレビューと、プロジェクト固有のアーキテクチャへの適合は省略できない。

## まとめ

Unity AI Open Betaの3コンポーネントを整理した。

- **Assistant（/run, /code）**: シーン操作とスクリプト生成をチャットで実行。プロトタイプ速度が上がる
- **Generators**: テキストからスプライト・サウンドなどを即席生成。仮素材調達に有効
- **Sentis**: ONNXモデルをエディタ内で動かす。外部API不要のオフラインML推論

外部ツールとの接続（Claude Code + MCP Server）を使ったUnity操作については、別記事で詳しく解説している。内蔵AIとMCP Server連携は用途が重なる部分もあるが、設計思想が異なるため、プロジェクトの要件に合わせて使い分けることになる。
