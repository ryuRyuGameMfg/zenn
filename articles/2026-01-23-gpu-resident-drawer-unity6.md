---
title: "Unity 6 GPU Resident Drawerで実現する高速レンダリング"
emoji: "⚡"
type: "tech"
topics: ["Unity", "パフォーマンス", "GPU", "Unity6", "レンダリング"]
published: true
---

## はじめに

:::message
**GPU Resident Drawerのポイント**

- Unity 6の新しいレンダリングシステム
- 大規模シーンでドローコール99.7%削減の実績
- CPU処理時間を大幅削減
:::

Unity 6で導入されたGPU Resident Drawerは、大規模シーンのレンダリングパフォーマンスを劇的に向上させる新機能です。従来のCPUベースのドローコール処理をGPU主導に切り替えることで、35,000オブジェクトを含むシーンでドローコール99.7%削減という驚異的な結果を実現しています。

本記事では、GPU Resident Drawerの仕組みから実装手順、実測ベンチマーク、トラブルシューティングまで詳しく解説します。

### GPU Resident Drawerとは

GPU Resident DrawerはUnityの内部レンダリングシステムで、BatchRendererGroup APIを自動的に使用してGameObjectをGPUインスタンシングで描画します。この技術により、ドローコールを削減しCPU処理時間を解放できるため、環境要素などの多数のオブジェクトを含む大規模で複雑なシーンに最適です。

### BatchRendererGroupとは

BatchRendererGroupは、インスタンス化されたドローコールを介して大量のオブジェクトを効率的にレンダリングできる技術です。このシステムは、インスタンシング情報(batchID、meshID、materialID)を含むドローコマンドを処理し、開発者がBatchRendererGroup APIの技術的詳細を直接管理する必要を排除します。Unityがレンダリングを自動的に処理します。

### 本記事で学べること

本記事では、以下の内容を網羅的に解説します:

- ✅ システム要件とプラットフォーム対応状況
- ✅ URP/HDRP別の実装手順
- ✅ 実測パフォーマンスベンチマーク(35,000オブジェクトでの検証)
- ✅ GPU Occlusion Cullingとの連携
- ✅ トラブルシューティングとベストプラクティス

### 対象読者

- Unity中級者以上(Unity基本操作を理解している)
- パフォーマンス最適化に関心がある開発者
- 大規模シーンを扱うプロジェクト担当者

## システム要件とプラットフォーム対応

GPU Resident Drawerは、Unityの最新レンダリング最適化技術ですが、利用には厳密なシステム要件を満たす必要があります。本セクションでは、必須要件、プラットフォーム対応状況、GameObject互換性の3つの観点から詳しく解説します。

### 必須システム要件

GPU Resident Drawerを動作させるには、以下の要件を全て満たす必要があります。

| 要件カテゴリ | 詳細 | 重要度 |
|------------|------|--------|
| レンダリングパイプライン | URP または HDRP | ★★★ |
| レンダリングパス | Forward+ (URPのみ) | ★★★ |
| グラフィックスAPI | コンピュートシェーダー対応API | ★★★ |
| 除外API | OpenGL ES, VisionOS | ★★★ |
| SRP Batcher | 有効化必須 | ★★★ |

#### レンダリングパイプラインの選択

GPU Resident Drawerは、Built-in Render Pipelineでは動作しません。必ずUniversal Render Pipeline (URP)またはHigh Definition Render Pipeline (HDRP)を使用してください。

**URPを使用する場合**、レンダリングパスをForward+に設定する必要があります。これは、Unity 2022.2以降で導入された新しいレンダリングパスで、多数のライトを効率的に処理できる特性がGPU Resident Drawerと相性が良いためです。

#### グラフィックスAPIの制約

最も重要な要件の1つが、**コンピュートシェーダー対応のグラフィックスAPI**です。GPU Resident Drawerは、描画コマンドの生成をGPU上で実行するため、コンピュートシェーダーが必須となります。

対応API:
- DirectX 11 / 12 (Windows)
- Vulkan (Windows, Linux, Android)
- Metal (macOS, iOS)

非対応API:
- OpenGL ES (モバイルデバイスの一部)
- WebGL (コンピュートシェーダー非対応)
- VisionOS (現時点で非対応)

#### SRP Batcherの有効化

Scriptable Render Pipeline (SRP) Batcherは、GPU Resident Drawerと組み合わせることで最大のパフォーマンスを発揮します。Project SettingsのGraphicsセクションで、SRP Batcherが有効になっていることを確認してください。

:::message alert
**重要な制限事項**

- WebGLは完全に非対応です(コンピュートシェーダー要件のため)
- AndroidデバイスでOpenGL ESを使用している場合は非対応(Vulkanのみ)
- VisionOSは現時点で非対応
:::

### プラットフォーム対応状況

GPU Resident Drawerの対応状況は、プラットフォームごとに異なります。以下の表で詳細な対応状況を確認してください。

| プラットフォーム | 対応状況 | 対応グラフィックスAPI | 備考 |
|---------------|---------|---------------------|------|
| Windows | ✓ 完全対応 | DirectX 11/12, Vulkan | 最も安定した動作環境 |
| macOS | ✓ 完全対応 | Metal | Apple Silicon / Intel両対応 |
| Linux | ✓ 完全対応 | Vulkan | Vulkanドライバー必須 |
| PlayStation 4/5 | ✓ 完全対応 | プラットフォーム固有API | コンピュートシェーダー対応 |
| Xbox One/Series | ✓ 完全対応 | DirectX | コンピュートシェーダー対応 |
| Nintendo Switch | ✓ 完全対応 | NVN | コンピュートシェーダー対応 |
| Android | △ 条件付き対応 | Vulkanのみ | OpenGL ESデバイスは非対応 |
| iOS | △ 条件付き対応 | Metal | VisionOSを除く |
| WebGL | ✗ 非対応 | - | コンピュートシェーダー非対応のため |

#### デスクトップ環境(Windows/macOS/Linux)

デスクトップ環境は、GPU Resident Drawerが最も安定して動作するプラットフォームです。

**Windows**: DirectX 11以降またはVulkanをサポートする全てのGPUで動作します。NVIDIA、AMD、Intelの主要GPUは全て対応しています。

**macOS**: Metal APIを使用するため、macOS 10.13以降であれば問題なく動作します。Apple SiliconとIntel Mac両方で利用可能です。

**Linux**: Vulkan対応GPUドライバーが必要です。主要なLinuxディストリビューション(Ubuntu、Fedora等)で動作確認されています。

#### コンソール環境(PlayStation/Xbox/Switch)

主要なゲームコンソールは全てコンピュートシェーダーをサポートしているため、GPU Resident Drawerを問題なく使用できます。

各プラットフォームの専用APIを通じて最適化された描画が可能で、特に大規模なオープンワールドゲームや多数のオブジェクトを扱うゲームで効果を発揮します。

#### モバイル環境(Android/iOS)

モバイル環境では、いくつかの制約があります。

**Android**: Vulkan APIをサポートするデバイスのみ対応します。Android 7.0 (Nougat)以降の多くのミッドレンジ〜ハイエンドデバイスはVulkanに対応していますが、古いデバイスやエントリーレベルのデバイスはOpenGL ESのみのサポートとなり、GPU Resident Drawerは使用できません。

**iOS**: Metal APIをサポートする全てのiOSデバイスで動作します。ただし、VisionOSは現時点で非対応となっています。

#### WebGL

WebGLはコンピュートシェーダーをサポートしていないため、GPU Resident Drawerは利用できません。ブラウザベースのゲームを開発する場合は、従来の描画方式を使用する必要があります。

### GameObject互換性要件

GPU Resident Drawerを使用するGameObjectには、特定の条件と制約があります。この要件を満たさないオブジェクトは、GPU Resident Drawerの恩恵を受けられません。

#### 必須コンポーネントと設定

GPU Resident Drawerで描画されるGameObjectは、以下の条件を満たす必要があります。

| 要件 | 詳細 | 必須度 |
|------|------|--------|
| Mesh Renderer | 必須コンポーネント | ★★★ |
| Light Probes | Use Proxy Volume以外 | ★★★ |
| Global Illumination | 静的のみ(Contribute GIチェック) | ★★★ |
| シェーダー | DOTS Instancing対応 | ★★★ |
| マテリアル数 | 最大128個まで | ★★☆ |

#### Mesh Rendererの要件

GameObjectには**Mesh Rendererコンポーネント**が必須です。Skinned Mesh RendererやParticle Systemなどの他のレンダラーは、現時点でGPU Resident Drawerに対応していません。

#### Light Probesの設定

Light Probesを使用する場合、**Use Proxy Volume以外の設定**を選択する必要があります。推奨される設定は以下の通りです:

- Off: ライトプローブを使用しない
- Blend Probes: 周囲のプローブをブレンド(推奨)
- Custom Provided: カスタムプローブデータを使用

#### Global Illuminationの制約

GPU Resident Drawerは、**静的なGlobal Illuminationのみ**サポートします。

設定方法:
1. GameObjectを選択
2. Inspectorウィンドウ右上の「Static」チェックボックスをオン
3. Mesh Renderer設定で「Contribute GI」をオンに設定
4. 「Receive Global Illumination」を「Lightmaps」に設定

**リアルタイムGIは使用できません**。EnlightenリアルタイムライトマップなどのリアルタイムGI機能を使用している場合、そのオブジェクトはGPU Resident Drawerで描画されません。

#### シェーダーの互換性

使用するシェーダーは、**DOTS Instancing**に対応している必要があります。

対応シェーダー:
- URP標準シェーダー(Lit, Unlit等)
- HDRP標準シェーダー
- Shader Graphで作成したDOTS Instancing対応シェーダー

カスタムシェーダーを使用する場合、`#pragma multi_compile _ DOTS_INSTANCING_ON`ディレクティブを追加し、DOTSインスタンシングバッファからデータを読み取る実装が必要です。

#### マテリアル数の制限

1つのGameObjectに設定できるマテリアルは、**最大128個まで**です。この制限を超えるオブジェクトは、GPU Resident Drawerで描画されません。

実際のゲーム開発では、ほとんどの場合この制限に抵触することはありませんが、複雑なモデルや大量のサブメッシュを持つオブジェクトを扱う際は注意が必要です。

#### 禁止事項と制約

GPU Resident Drawerを使用する場合、以下のAPIやコンポーネントは使用できません。

:::message alert
**使用禁止API・機能**

- MaterialPropertyBlock API
- OnRenderObject() コールバック
- OnBecameVisible() / OnBecameInvisible() コールバック
- Text Meshコンポーネント
- カメラ間レンダリング中の位置変更
:::

#### MaterialPropertyBlock APIの代替案

MaterialPropertyBlockは、オブジェクトごとにマテリアルプロパティを変更するための便利なAPIですが、GPU Resident Drawerでは使用できません。

代替方法:
1. **マテリアルインスタンス化**: 個別のマテリアルを生成して使用
2. **Shader Graphのカスタムプロパティ**: Mesh情報やカスタムバッファからデータを取得
3. **Compute Shaderとの連携**: カスタムバッファを使用した動的プロパティ変更

#### コールバック制限

`OnRenderObject()`、`OnBecameVisible()`、`OnBecameInvisible()`などのレンダリング関連コールバックは使用できません。これらは従来のCPUベースの描画フローに依存しているためです。

代替方法:
1. **カリングイベント**: カスタムカリングコールバックを使用
2. **Visibility変更検知**: 別の方法でオブジェクトの可視状態を追跡
3. **ECS統合**: Entities Graphics パッケージとの連携

#### Text Meshコンポーネント

レガシーのText Meshコンポーネントは非対応です。テキスト表示が必要な場合は、以下の代替手段を使用してください:

- TextMesh Pro (TMP)
- UI Toolkit
- Canvas UI

#### カメラ間レンダリングの制約

複数のカメラでレンダリングする際、カメラ間でGameObjectの位置を変更することはできません。これは、GPU Resident Drawerがフレームの開始時にオブジェクトの位置情報をGPUバッファに転送するためです。

この制約により、一部の特殊なレンダリング技法(ポータルレンダリングなど)は使用できない場合があります。

:::details GameObject互換性の詳細チェックリスト

**必須条件**
- [ ] Mesh Rendererコンポーネント使用
- [ ] Light ProbesでUse Proxy Volume未使用
- [ ] 静的Global Illumination設定(Contribute GI有効)
- [ ] DOTS Instancing対応シェーダー使用
- [ ] マテリアル数128個以下

**禁止事項**
- [ ] MaterialPropertyBlock未使用
- [ ] OnRenderObject()等のコールバック未使用
- [ ] Text Meshコンポーネント未使用
- [ ] カメラ間での位置変更なし
- [ ] Realtime GI無効化

**推奨設定**
- [ ] SRP Batcher有効化
- [ ] Static Batching無効化(GPU Resident Drawerと競合)
- [ ] Occlusion Culling有効化(パフォーマンス向上)
:::

#### まとめ

GPU Resident Drawerは強力な最適化技術ですが、システム要件とGameObject互換性の両面で厳密な条件を満たす必要があります。

**キーポイント**:
- コンピュートシェーダー対応APIが必須(WebGLは非対応)
- URP Forward+またはHDRPが必要
- Mesh Renderer + DOTS Instancing対応シェーダーが必須
- MaterialPropertyBlock等の一部APIは使用不可

プロジェクトでGPU Resident Drawerを導入する際は、まずターゲットプラットフォームの対応状況を確認し、既存のGameObjectが互換性要件を満たしているかチェックすることが重要です。

https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html

https://docs.unity3d.com/6000.0/Documentation/Manual/urp/make-object-compatible-gpu-rendering.html

## 実装手順 - URP/HDRP設定ガイド

GPU Resident DrawerをUnity 6で有効化する手順を、ステップバイステップで解説します。URP(Universal Render Pipeline)とHDRP(High Definition Render Pipeline)それぞれの設定方法を説明します。

### URP環境での設定手順(5ステップ)

Unity 6のURPでGPU Resident Drawerを有効化するには、以下の設定が必要です。

#### ステップ1: BatchRendererGroup Variants設定

Project Settings > Graphics > Shader Strippingを開き、BatchRendererGroup Variantsを設定します。

```text:設定パス
Edit > Project Settings > Graphics
└─ Shader Stripping
   └─ BatchRendererGroup Variants: Keep All
```

![BatchRendererGroup設定](https://theknightsofu.com/wp-content/uploads/2025/04/BRG-Keep-all.png)
*出典: [The Knights of U - Boost performance of your game in Unity 6 with GPU Resident Drawer](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)*

:::message
**なぜ"Keep All"が必要か**

BatchRendererGroup(BRG)は、GPU Resident Drawerの基盤技術です。シェーダーバリアントを保持することで、ランタイムでのシェーダー再コンパイルを回避し、安定したパフォーマンスを実現します。

Unity公式ドキュメント:
https://docs.unity3d.com/Manual/batch-renderer-group.html
:::

#### ステップ2: Universal Renderer設定(Rendering Path)

URP AssetにアタッチされているUniversal Rendererで、Rendering Pathを"Forward+"に設定します。

```text:設定パス
Project > Settings > (URP Asset)
└─ Renderer List > Universal Renderer Data
   └─ Rendering > Rendering Path: Forward+
```

![Universal Renderer設定](https://theknightsofu.com/wp-content/uploads/2025/04/BRG-Forward.png)
*出典: [The Knights of U](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)*

:::message
**Forward+が必須な理由**

GPU Resident DrawerはForward+レンダリングパスと統合設計されています。従来のForwardレンダリングでは、GPU Resident Drawerの最適化効果が得られません。

Forward+の技術詳細:
https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@17.0/manual/rendering/forward-plus-rendering-path.html
:::

#### ステップ3: URP Asset設定(SRP Batcher & GPU Resident Drawer)

URP Asset本体で、以下2つの設定を行います。

```text:設定パス
Project > Settings > (URP Asset)
├─ Advanced
│  └─ SRP Batcher: 有効化(チェックON)
└─ Rendering
   └─ GPU Resident Drawer: Instanced Drawing
```

![URP Asset設定](https://theknightsofu.com/wp-content/uploads/2025/04/BRG-3-4.png)
*出典: [The Knights of U](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)*

:::message
**SRP BatcherとGPU Resident Drawerの関係**

両者は競合せず、**共存して動作**します。

- SRP Batcher: SetPassCall削減(マテリアルプロパティの効率的な送信)
- GPU Resident Drawer: ドローコール処理のGPU移譲

Unity公式ドキュメント:
https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html
:::

#### ステップ4(推奨): Static Batching無効化

Project Settings > Player > Other Settingsで、Static Batchingを無効化します。

```text:設定パス
Edit > Project Settings > Player
└─ Other Settings
   └─ Static Batching: 無効化(チェックOFF)
```

:::details なぜStatic Batchingを無効化すべきか

Static Batchingは、静的オブジェクトのメッシュを事前結合してドローコールを削減する古い最適化手法です。GPU Resident Drawerと併用すると、以下の問題が発生する可能性があります:

1. メモリ使用量の増加(メッシュデータの重複)
2. GPU Resident Drawerの最適化が無効化される
3. ビルドサイズの肥大化

GPU Resident Drawerを有効化する場合、Static Batchingは不要です。

Unity公式ドキュメント:
https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html
:::

#### ステップ5(推奨): Lightmap最適化設定

Window > Rendering > Lightingで、以下の設定を行います。

```text:設定パス
Window > Rendering > Lighting
└─ Lightmap Settings
   ├─ Fixed Lightmap Size: 有効化(チェックON)
   └─ Use Mipmap Limits: 無効化(チェックOFF)
```

:::details Lightmap設定の最適化理由

GPU Resident Drawerは、ライトマップデータの効率的な処理を行います。以下の設定により、最適化効果を最大化できます:

- **Fixed Lightmap Size**: ライトマップサイズを固定化し、GPU Resident Drawerのメモリ管理を最適化
- **Use Mipmap Limits無効化**: Mipmap制限を無効化し、GPU Resident Drawerの自動最適化を優先

詳細は公式ドキュメント参照:
https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html
:::

### HDRP環境での設定手順

HDRP(High Definition Render Pipeline)でのGPU Resident Drawer設定は、URPよりもシンプルです。

#### HDRP Asset設定

HDRP Assetで、GPU Resident Drawerを有効化します。

```text:設定パス
Project > Settings > (HDRP Asset)
└─ Rendering
   └─ GPU Resident Drawer: 有効化(チェックON)
```

:::message
**URPとHDRPの設定の違い**

HDRPでは、以下の設定が**不要**です:

- BatchRendererGroup Variants(自動最適化)
- Rendering Path設定(HDRPは独自のレンダリングパス)
- Static Batching無効化(HDRPは非対応)

HDRPは、GPU Resident Drawerとの統合がより深く、設定項目が少なくなっています。

HDRP公式ドキュメント:
https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/gpu-resident-drawer.html
:::

#### HDRP Frame Settings

HDRP Quality SettingsまたはCamera個別のFrame Settingsで、GPU Resident Drawerを有効化します。

```text:設定パス(Quality Settings)
Edit > Project Settings > HDRP
└─ Frame Settings (Quality)
   └─ Rendering
      └─ GPU Resident Drawer: 有効化(チェックON)
```

```text:設定パス(Camera個別)
Hierarchy > Main Camera > Inspector
└─ Frame Settings Override
   └─ Rendering
      └─ GPU Resident Drawer: 有効化(チェックON)
```

### 特定GameObjectをGPU Resident Drawerから除外する方法

一部のGameObjectをGPU Resident Drawerの処理から除外したい場合、"Disallow GPU Driven Rendering"コンポーネントを使用します。

#### 除外コンポーネントの追加手順

```text:手順
1. Hierarchy上で除外したいGameObjectを選択
2. Inspector > Add Component
3. "Disallow GPU Driven Rendering"を追加
4. (オプション)"Apply to Children Recursively"にチェック
   → 子オブジェクトにも適用される
```

![Disallow GPU Driven Rendering](https://theknightsofu.com/wp-content/uploads/2025/04/Disallow-BRG.png)
*出典: [The Knights of U](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)*

:::details どんな場合に除外が必要か

以下のような場合、GPU Resident Drawerから除外することを検討してください:

1. **動的なメッシュ変更**
   - Mesh.SetVertices()などでリアルタイムにメッシュを変更する
2. **カスタムシェーダーの非互換性**
   - BatchRendererGroup非対応のシェーダーを使用
3. **パフォーマンステスト**
   - GPU Resident Drawer有効/無効の比較検証

Unity公式ドキュメント:
https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html
:::

### GPU Resident Drawer有効化の確認方法

設定が正しく適用されているか、Frame Debuggerで確認します。

#### Frame Debuggerでの確認手順

```text:確認手順
1. Window > Analysis > Frame Debugger
2. "Enable"をクリックしてデバッグモードに入る
3. Rendering階層を展開
4. "Hybrid Batch Group"が表示されていれば有効化成功
```

:::message
**確認ポイント**

Frame Debuggerで以下を確認してください:

- **Hybrid Batch Groupの表示**
  - GPU Resident Drawerが動作している証拠
- **ドローコール数の削減**
  - 従来の個別DrawCallが統合されている

Frame Debugger公式ドキュメント:
https://docs.unity3d.com/Manual/frame-debugger.html
:::

### 設定チェックリスト

GPU Resident Drawerを有効化するために必要な設定をまとめます。

:::message
**URP設定チェックリスト**

必須設定:
- [ ] BatchRendererGroup Variants: Keep All
- [ ] SRP Batcher: 有効化
- [ ] GPU Resident Drawer: Instanced Drawing
- [ ] Rendering Path: Forward+

推奨設定:
- [ ] Static Batching: 無効化
- [ ] Fixed Lightmap Size: 有効化
- [ ] Use Mipmap Limits: 無効化

確認:
- [ ] Frame Debuggerで"Hybrid Batch Group"を確認
:::

:::message
**HDRP設定チェックリスト**

必須設定:
- [ ] HDRP Asset > GPU Resident Drawer: 有効化
- [ ] Frame Settings > GPU Resident Drawer: 有効化

確認:
- [ ] Frame Debuggerで"Hybrid Batch Group"を確認
:::

### トラブルシューティング

GPU Resident Drawerの設定で問題が発生した場合の対処方法を紹介します。

#### 問題1: Frame Debuggerで"Hybrid Batch Group"が表示されない

**原因**:
- Unity 6.0未満のバージョンを使用している
- URPバージョンが17.0未満

**対処法**:
```bash
# Unity Hubでバージョン確認
Unity Version: 6.0.0以上
URP Version: 17.0.0以上
```

#### 問題2: パフォーマンスが向上しない

**原因**:
- Static Batchingが有効になっている
- Rendering PathがForwardのまま

**対処法**:
1. Player Settings > Static Batchingを無効化
2. Universal Renderer > Rendering Path: Forward+に変更

#### 問題3: 一部のオブジェクトが正しく描画されない

**原因**:
- カスタムシェーダーがBatchRendererGroup非対応
- 動的メッシュ変更との競合

**対処法**:
該当GameObjectに"Disallow GPU Driven Rendering"コンポーネントを追加

:::details より詳細なトラブルシューティング

Unity公式ドキュメントのトラブルシューティングセクションを参照してください:

- URP: https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html
- HDRP: https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/gpu-resident-drawer.html

Unity Discussionsでのコミュニティサポート:
https://discussions.unity.com/
:::

## パフォーマンスベンチマーク

実際のシーンでGPU Resident Drawerがどれほどの効果を発揮するか、実測データで検証します。

### 実測環境

The Knights of Uの検証では、以下の環境でテストを実施しました:

- **オブジェクト数**: 35,000+の植物オブジェクト
- **解像度**: 1920×1080
- **目的**: 大規模自然環境シーンでの性能評価

この環境は、現代のオープンワールドゲームやアーキテクチャビジュアライゼーションで頻繁に遭遇する、大量の静的オブジェクトを含むシーンを想定しています。

### パフォーマンス比較結果

GPU Resident Drawerの有効/無効での比較結果は驚異的でした:

| 指標 | GPU Resident Drawer無効時 | 有効時 | 改善率 |
|------|-------------------------|--------|--------|
| **Draw Calls** | 43,500 | 128 | **99.7%削減** |
| **Batches** | 43,483 | 128 | **99.7%削減** |
| **Triangles** | 500万+ | 大幅削減 | - |
| **Memory** | 0.82GB | 0.92GB | +100MB |
| **GPU Frame Time** | 高負荷 | 16ms(アイドル残) | 大幅改善 |
| **Frame Rate** | <60 FPS | 60 FPS達成 | ✓ |

![GPU Resident Drawer無効時のパフォーマンス](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Disabled-Times-1024x268.png)
*GPU Resident Drawer無効時: GPU Frame Timeが高負荷*

![GPU Resident Drawer有効時のパフォーマンス](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Enabled-Times-1024x284.png)
*GPU Resident Drawer有効時: GPU Frame Time 16ms、アイドル時間が残る余裕*

![GPU Resident Drawer無効時のレンダリング統計](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Disabled-Rendering-1024x467.png)
*GPU Resident Drawer無効時: ドローコール43,500件、500万三角形*

![GPU Resident Drawer有効時のレンダリング統計](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Enabled-Rendering-1024x491.png)
*GPU Resident Drawer有効時: ドローコール128件(99.7%削減)*

![GPU Resident Drawer無効時のメモリ使用量](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Disabled-Memory-1024x433.png)
*GPU Resident Drawer無効時: メモリ使用量0.82GB*

![GPU Resident Drawer有効時のメモリ使用量](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Enabled-Memory-1024x432.png)
*GPU Resident Drawer有効時: メモリ使用量0.92GB(+100MB)*

*出典: [The Knights of U - Boost Performance of Your Game in Unity 6 with GPU Resident Drawer](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)*

#### 注目すべきポイント

**ドローコールの劇的削減**

43,500件のドローコールが128件まで削減されたことは、**99.7%の削減率**を意味します。これは従来のバッチング技術では達成不可能なレベルです。CPUオーバーヘッドが大幅に削減され、CPU-boundなシーンでは特に効果的です。

**Frame Rateの安定化**

無効時は60FPSを下回っていたフレームレートが、有効時には安定して60FPSを達成しました。GPU Frame Timeも余裕が生まれ、他の処理(ポストプロセス、物理演算など)に余力を残せます。

**メモリトレードオフ**

一方で、メモリ使用量は約100MB増加しています。これはGPU上にメッシュデータを常駐させるための代償です。メモリに余裕のある環境では問題ありませんが、モバイルやVRデバイスでは注意が必要です。

### トレードオフ分析

GPU Resident Drawerは万能ではなく、いくつかのトレードオフがあります。採用前に以下の点を理解しておく必要があります:

:::details メリットとデメリットの詳細

**メリット**

- ✅ **CPU処理時間最大50%削減**: ドローコール処理のCPUオーバーヘッドが大幅削減
- ✅ **ドローコール大幅削減**: 数万件→数百件レベルの劇的削減
- ✅ **大規模シーン対応**: 従来は処理困難だった大規模シーンが実用可能に
- ✅ **インスタンシング効率最大化**: 同一メッシュ・マテリアルの大量配置に最適

**デメリット**

- ⚠ **メモリ使用量約100MB増加**: GPUメモリにメッシュデータを常駐
- ⚠ **ビルド時間延長**: BRGデータの事前処理が必要
- ⚠ **GPU負荷増加**: 特にモバイル・VRでは注意が必要
- ⚠ **オーバードロー増加**: 非タイル型GPU(Desktopなど)では非効率な場合あり
- ⚠ **互換性制限**: 一部のエフェクト・シェーダーと併用不可

:::

Unity公式ドキュメントでも、以下のような警告が記載されています:

:::message
GPU Resident Drawerは、GPU-boundなアプリケーション(特にモバイルやVR)では逆効果になる可能性があります。プロファイラーで計測しながら、プロジェクトに適しているか判断してください。
:::

### 効果的なユースケース

GPU Resident Drawerが最も効果を発揮するシーン特性を整理します:

| シーン特性 | 効果 | 理由 |
|----------|------|------|
| **大規模シーン**(多数オブジェクト) | ★★★ | ドローコール削減の効果が最大化 |
| **同一メッシュ・マテリアル多用** | ★★★ | インスタンシング効率が最大化 |
| **高遮蔽率シーン** | ★★★ | GPU Occlusion Cullingと相乗効果 |
| **CPU-boundアプリ** | ★★★ | CPU処理時間削減が直接フレームレート改善につながる |
| **GPU-boundアプリ** | ★☆☆ | GPU負荷増加リスク、慎重な検証が必要 |
| **メモリ制約の厳しい環境**(モバイル/VR) | ★☆☆ | メモリ増加が問題になる可能性 |

#### 推奨シナリオ

以下のようなプロジェクトでは、GPU Resident Drawerの効果が特に顕著です:

1. **オープンワールドゲーム**: 植生、建物、小物など大量の静的オブジェクト
2. **アーキテクチャビジュアライゼーション**: 家具、装飾品などの重複配置
3. **ストラテジーゲーム**: ユニット、建物などの大量インスタンス
4. **シミュレーションゲーム**: 都市、交通など多数の静的・動的オブジェクト

#### 非推奨シナリオ

逆に、以下のような状況では慎重な検証が必要です:

1. **モバイルゲーム**(特にローエンド): メモリ制約・GPU性能の問題
2. **VRアプリケーション**: 高フレームレート要求・GPU負荷の懸念
3. **高度なシェーダーエフェクト多用**: 互換性制限の可能性
4. **既にCPU負荷が低いシーン**: 改善効果が限定的

### まとめ

実測ベンチマークから、GPU Resident Drawerは**大規模シーンにおいて劇的なパフォーマンス改善**をもたらすことが証明されました。特にドローコール99.7%削減という数値は、従来のバッチング技術の限界を超えています。

ただし、メモリ増加やGPU負荷増加というトレードオフも存在します。**プロジェクトの特性・ターゲットプラットフォームに応じて、プロファイラーで計測しながら導入判断を行う**ことが重要です。

次のセクションでは、GPU Occlusion Cullingとの連携について解説します。

## GPU Occlusion Cullingとの連携

GPU Resident Drawerと組み合わせることで、さらなるパフォーマンス向上が期待できるGPU Occlusion Cullingについて解説します。

### GPU Occlusion Cullingとは

GPU Occlusion Cullingは、前フレームの深度バッファを使用して、他のオブジェクトに遮蔽されているジオメトリインスタンスをGPUベースでカリングする技術です。従来のCPUベースのOcclusion Cullingと異なり、GPU上で効率的に処理されるため、CPU負荷を軽減しつつ、より高速な遮蔽判定が可能になります。

**GPU Occlusion Cullingの仕組み**:

1. **前フレーム深度テクスチャの活用**: 直前のフレームでレンダリングされた深度情報を基に、次フレームで遮蔽されているオブジェクトを判定します。この保守的なアプローチにより、いずれかのフレームで非遮蔽と判定されたオブジェクトはレンダリングされるため、視覚的な欠落を防ぎます。

2. **バウンディングスフィア近似**: 各オブジェクトのバウンディングボックスを球体で近似することで、効率的な遮蔽判定を実現します。この簡略化により、複雑な形状のオブジェクトでも高速に処理できます。

3. **マルチレベル深度バッファ**: ダウンサンプルされた深度バッファを複数レベルで保持し、異なるスケールでの遮蔽判定を効率化します。これにより、大小さまざまなオブジェクトに対して最適な判定が行えます。

https://docs.unity3d.com/6000.0/Documentation/Manual/urp/gpu-culling.html

### 有効化手順(URP)

GPU Occlusion CullingはGPU Resident Drawerの追加機能として動作するため、GPU Resident Drawerが有効化されていることが前提条件となります。

**設定ステップ**:

1. **Graphics設定の変更**
   - Project Settings > Graphics
   - Compatibility Mode: 無効化
   - これにより、Unity 6の最新レンダリング機能が利用可能になります

2. **GPU Resident Drawerの有効化**
   - Project Settings > Graphics
   - GPU Resident Drawer: チェックを入れる
   - GPU Occlusion Cullingの前提条件です

3. **Universal RendererでGPU Occlusionを有効化**
   - URP Asset > Renderer
   - GPU Occlusion: チェックを入れる

![GPU Occlusion Culling設定](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Occlusion-culling.png)
*出典: [The Knights of U](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)*

:::message
**Compatibility Modeについて**

Compatibility Modeは、Unity 5時代のレンダリングパイプラインとの互換性を保つためのオプションです。これを無効化することで、Unity 6の新機能であるGPU Resident DrawerやGPU Occlusion Cullingが利用可能になります。既存プロジェクトでは、無効化後にレンダリング結果を十分に確認してください。
:::

### デバッグ・可視化

Rendering Debuggerを使用すると、GPU Occlusion Cullingのカリング状況を視覚的に確認できます。

**Rendering Debuggerの起動**:

1. Window > Analysis > Rendering Debugger
2. Rendering > Rendering Debug
3. Map Overlays > GPU Occlusion Debug: 有効化

![Rendering Debugger設定](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Debugger.png)

デバッグモードでは、シーンビューでオブジェクトがカラーコード表示され、カリング状況が一目で分かります:

![Rendering Debuggerシーンビュー](https://theknightsofu.com/wp-content/uploads/2025/04/GPU-Debugger-Scene-View-1024x576.png)
*カラーコード表示でカリング状況を確認*

**カラーコードの意味**:
- 緑: レンダリング対象(カメラから見える)
- 赤: 遮蔽によりカリングされた
- 青: フラスタムカリングされた

この可視化により、意図しないカリングや、期待通りの最適化が行われているかを確認できます。

### 効果的なシーン特性

GPU Occlusion Cullingは、すべてのシーンで同等の効果を発揮するわけではありません。以下の特性を持つシーンで特に効果的です:

**最適なシーン条件**:

1. **インスタンシング向きのアセット構成**
   - 複数のオブジェクトが同じメッシュを使用している
   - GPU Resident Drawerとの相乗効果が高い

2. **高い遮蔽率の環境**
   - 密集した都市シーン
   - 屋内環境(壁や家具による遮蔽が多い)
   - ダンジョンや迷路のような閉鎖空間

3. **小さなバウンディング半径のオブジェクト多数**
   - 画面空間でのバウンディング半径が小さいオブジェクト
   - 詳細な小物やデコレーションが多いシーン

:::message
**GPU Occlusion Cullingの相乗効果**

GPU Resident DrawerとGPU Occlusion Cullingを併用すると:

- **GPU Resident Drawer**: ドローコール削減とインスタンシング最適化
- **GPU Occlusion Culling**: 遮蔽オブジェクトのレンダリング回避

により、CPUとGPUの両方で大幅なパフォーマンス向上が期待できます。特に、オープンワールドゲームや大規模シミュレーションでは、両機能の組み合わせが不可欠です。
:::

## まとめ - ベストプラクティス

GPU Resident DrawerはUnity 6で導入された強力なパフォーマンス最適化機能です。本記事のポイントを振り返ります。

### ベストプラクティスチェックリスト

GPU Resident Drawerを効果的に活用するためのチェックリストです。

#### 環境設定

**レンダリングパイプライン**:
- Forward+レンダリングパス使用
- SRP Batcher有効化
- Static Batching無効化
- GPU Occlusion Culling併用
- Depth Priming Mode活用

**推奨設定の根拠**:

Unity公式ドキュメントおよびThe Knights of Uの記事によれば、Forward+レンダリングパスはGPU Resident Drawerと最も相性が良く、SRP Batcherとの併用により最大限のパフォーマンス向上が期待できます。一方、Static Batchingは内部的にメッシュを結合するため、GPU Resident Drawerのインスタンシング機能と競合し、むしろパフォーマンスを低下させる可能性があります。

#### シーン設計

**オブジェクト構成**:
- 同一メッシュ・マテリアルのオブジェクト集約
- マテリアル数128個以下に制限
- MaterialPropertyBlock未使用
- DOTS Instancing対応シェーダー使用

**避けるべき構成**:
- GPU-bound環境での使用
- リアルタイムGI多用シーン
- MaterialPropertyBlockの多用
- 128個以上のマテリアル使用

MaterialPropertyBlockはマテリアルのプロパティを動的に変更する便利な機能ですが、GPU Resident Drawerのバッチング効率を著しく低下させます。動的なプロパティ変更が必要な場合は、DOTS Instancingのメタデータ機能を活用することで、パフォーマンスを維持しながら実現できます。

#### プラットフォーム対応

**サポート対象**:
- Windows (DirectX 11/12, Vulkan)
- macOS/iOS (Metal)
- Android (Vulkan)
- PlayStation/Xbox

**非サポート**:
- WebGL (全面非対応)
- Android OpenGL ES (Unity 6で除外)
- コンピュートシェーダー非対応GPU

プラットフォームごとのサポート状況は、Unity公式ドキュメントで明記されています。特にWebGLは完全に非対応のため、マルチプラットフォーム展開する場合は注意が必要です。

### 既知の問題と制限事項

:::message alert
**導入前に確認すべき問題点**

以下の問題が報告されています。本番環境への導入前に、必ずターゲットプラットフォームでの検証を実施してください。
:::

#### エディタ安定性の問題

Unity Discussionsの報告によれば、Unity 6 Previewで有効化時にエディタが不安定化する事例が複数報告されています。特に以下のような症状が確認されています:

- エディタの予期しないクラッシュ
- プレビュー画面の表示崩れ
- 保存処理中のフリーズ

これらの問題は、Unity 6の正式版リリース後も一部の環境で発生する可能性があるため、段階的な導入とこまめなバックアップが推奨されます。

#### パフォーマンス特性

一部のテストケースでは、CPU/GPU両方の使用率が上昇し、FPSが低下するケースが報告されています。これは以下のような状況で発生しやすい傾向があります:

**CPU使用率上昇**:
- 大量の小さなオブジェクトが散在
- 頻繁なカリング判定が必要
- フレームごとの可視性変化が激しい

**GPU使用率上昇**:
- すでにGPU-boundな環境
- 複雑なシェーダー処理
- 高解像度テクスチャ多用

#### ECSとの併用

Entities(ECS)との併用時にメッシュレンダリング問題が発生するケースが報告されています。Unity公式ドキュメントでは、ECSとGPU Resident Drawerの統合は段階的に進められており、完全な互換性が保証されるまで注意が必要です。

### 次のステップ

GPU Resident Drawerを実際のプロジェクトに導入する際の推奨ステップです。

#### 1. 小規模テストシーンでの検証

まずは既存プロジェクトとは別に、小規模なテストシーンを作成します:

**テストシーン構成例**:
- 100〜1000個の同一メッシュオブジェクト
- 5〜10種類のマテリアル
- Forward+レンダリングパス
- GPU Resident Drawer有効化

このテストシーンで、有効/無効時のパフォーマンスを比較測定します。

#### 2. パフォーマンス計測

Unity Profilerを使用して、以下の指標を計測します:

**必須計測項目**:
- CPU使用率 (メインスレッド/レンダースレッド)
- GPU使用率
- FPS (最小/平均/最大)
- ドローコール数
- セットパスコール数
- バッチ数

特に、CPU Profilerの「Rendering」カテゴリで、レンダリングコストの内訳を詳細に確認することが重要です。

#### 3. ターゲットプラットフォーム実機テスト

エディタ上での検証だけでなく、必ず実機でのテストを実施します:

**実機テストチェックリスト**:
- ターゲット解像度での動作確認
- 低スペック/高スペックデバイス両方でのテスト
- 長時間動作時の安定性確認
- メモリ使用量の監視
- 発熱状況の確認 (モバイル)

#### 4. 本番シーンへの適用

テストで問題がなければ、段階的に本番シーンへ適用します:

**段階的導入フロー**:
1. 静的な背景オブジェクトのみ有効化
2. 動的オブジェクトを徐々に追加
3. 全シーンで有効化
4. パフォーマンスの継続監視

各段階で問題が発生した場合は、前の段階に戻り、原因を特定してから次に進みます。

### まとめ

GPU Resident Drawerは、適切に使用すれば大幅なパフォーマンス向上が期待できる強力な機能です。ただし、以下の点に注意が必要です:

**成功のポイント**:
- 推奨構成の遵守 (Forward+, SRP Batcher, 同一メッシュ集約)
- 十分な事前検証 (テストシーン、実機テスト)
- 段階的な導入 (リスク最小化)
- 継続的な監視 (パフォーマンス計測)

**避けるべき落とし穴**:
- 非対応プラットフォームでの使用
- GPU-bound環境での盲目的な適用
- MaterialPropertyBlockの多用
- ECSとの無計画な併用

Unity 6の新機能として、今後さらなる改善が期待されます。公式ドキュメントやコミュニティの最新情報を常にチェックし、最適な使い方を模索していくことが重要です。

## 参考資料

本記事の執筆にあたり、以下の情報源を参考にしました。

### Unity公式ドキュメント

**GPU Resident Drawer基本**:
- [Enable the GPU Resident Drawer in URP](https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html)
- [GPU Resident Drawer performance considerations](https://docs.unity3d.com/6000.4/Documentation/Manual/urp/gpu-resident-drawer-performance.html)
- [Make a GameObject compatible with the GPU Resident Drawer in URP](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/make-object-compatible-gpu-rendering.html)

**関連機能**:
- [Enable GPU occlusion culling in URP](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/gpu-culling.html)
- [Use the GPU Resident Drawer (HDRP)](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/gpu-resident-drawer.html)
- [BatchRendererGroup API in URP](https://docs.unity3d.com/6000.3/Documentation/Manual/batch-renderer-group.html)

**インスタンシング**:
- [DOTS Instancing shaders in URP](https://docs.unity3d.com/Manual/dots-instancing-shaders.html)
- [Introduction to GPU instancing](https://docs.unity3d.com/Manual/GPUInstancing.html)

### コミュニティ記事

- [Boost performance of your game in Unity 6 with GPU Resident Drawer - The Knights of U](https://theknightsofu.com/boost-performance-of-your-game-in-unity-6-with-gpu-resident-drawer/)
- [Improve CPU Performance In Unity 6 (GPU Resident Drawer Tutorial) – SpeedTutor](https://www.speed-tutor.com/blogs/news/improve-cpu-performance-in-unity-6-gpu-resident-drawer-tutorial)

### Unity Discussions

**互換性・問題報告**:
- [Unity 6 GPU Resident Drawer GPU Occlusion Culling compatibility with Android](https://discussions.unity.com/t/unity-6-gpu-resident-drawer-gpu-occlusion-cullling-compatibility-with-android/1539448)
- [Enabling GPU Resident Drawer = Completely unstable editor](https://discussions.unity.com/t/enabling-gpu-resident-drawer-completely-unstable-editor/1512943)