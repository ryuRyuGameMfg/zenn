---
title: "GPU Resident Drawer システム要件とプラットフォーム対応"
emoji: "🖥"
type: "tech"
topics: ["unity", "gpu", "rendering", "urp", "hdrp"]
published: true
published_at: 2026-03-04 18:00
---

## はじめに

GPU Resident Drawerは、Unityの描画コマンド生成をGPU上で実行するレンダリング最適化技術です。本記事では、必須要件・プラットフォーム対応・GameObject互換性の3点を解説します。

## 必須システム要件

GPU Resident Drawerを動作させるには、以下の要件を全て満たす必要があります。

| 要件カテゴリ | 詳細 | 重要度 |
|------------|------|--------|
| レンダリングパイプライン | URP または HDRP | ★★★ |
| レンダリングパス | Forward+ (URPのみ) | ★★★ |
| グラフィックスAPI | コンピュートシェーダー対応API | ★★★ |
| 除外API | OpenGL ES, VisionOS | ★★★ |
| SRP Batcher | 有効化必須 | ★★★ |

Built-in Render Pipelineでは動作しません。URPの場合はForward+レンダリングパスが必要です。対応グラフィックスAPIはDirectX 11/12、Vulkan、Metalで、**OpenGL ES・WebGL・VisionOSは非対応**です。SRP Batcherの有効化も必須です。

:::message alert
WebGLは完全に非対応（コンピュートシェーダー要件）。AndroidはVulkanのみ対応（OpenGL ES不可）。
:::

## プラットフォーム対応状況

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

デスクトップ（Windows/macOS/Linux）とコンソール（PS4/5、Xbox、Switch）は完全対応です。モバイルはAndroid（Vulkanのみ）とiOS（Metal）が条件付き対応、WebGLは非対応です。

## GameObject互換性要件

GPU Resident Drawerを使用するGameObjectには、特定の条件と制約があります。この要件を満たさないオブジェクトは、GPU Resident Drawerの恩恵を受けられません。

### 必須コンポーネントと設定

GPU Resident Drawerで描画されるGameObjectは、以下の条件を満たす必要があります。

| 要件 | 詳細 | 必須度 |
|------|------|--------|
| Mesh Renderer | 必須コンポーネント | ★★★ |
| Light Probes | Use Proxy Volume以外 | ★★★ |
| Global Illumination | 静的のみ(Contribute GIチェック) | ★★★ |
| シェーダー | DOTS Instancing対応 | ★★★ |
| マテリアル数 | 最大128個まで | ★★☆ |

### Mesh Rendererの要件

GameObjectには**Mesh Rendererコンポーネント**が必須です。Skinned Mesh RendererやParticle Systemなどの他のレンダラーは、現時点でGPU Resident Drawerに対応していません。

### Light Probesの設定

Light Probesを使用する場合、**Use Proxy Volume以外の設定**を選択する必要があります。推奨される設定は以下の通りです:

- Off: ライトプローブを使用しない
- Blend Probes: 周囲のプローブをブレンド(推奨)
- Custom Provided: カスタムプローブデータを使用

### Global Illuminationの制約

GPU Resident Drawerは、**静的なGlobal Illuminationのみ**サポートします。

設定方法:
1. GameObjectを選択
2. Inspectorウィンドウ右上の「Static」チェックボックスをオン
3. Mesh Renderer設定で「Contribute GI」をオンに設定
4. 「Receive Global Illumination」を「Lightmaps」に設定

**リアルタイムGIは使用できません**。EnlightenリアルタイムライトマップなどのリアルタイムGI機能を使用している場合、そのオブジェクトはGPU Resident Drawerで描画されません。

### シェーダーの互換性

使用するシェーダーは、**DOTS Instancing**に対応している必要があります。

対応シェーダー:
- URP標準シェーダー(Lit, Unlit等)
- HDRP標準シェーダー
- Shader Graphで作成したDOTS Instancing対応シェーダー

カスタムシェーダーを使用する場合、`#pragma multi_compile _ DOTS_INSTANCING_ON`ディレクティブを追加し、DOTSインスタンシングバッファからデータを読み取る実装が必要です。

### マテリアル数の制限

1つのGameObjectに設定できるマテリアルは、**最大128個まで**です。この制限を超えるオブジェクトは、GPU Resident Drawerで描画されません。

実際のゲーム開発では、ほとんどの場合この制限に抵触することはありませんが、複雑なモデルや大量のサブメッシュを持つオブジェクトを扱う際は注意が必要です。

### 禁止事項と制約

GPU Resident Drawerを使用する場合、以下のAPIやコンポーネントは使用できません。

:::message alert
**使用禁止API・機能**

- MaterialPropertyBlock API
- OnRenderObject() コールバック
- OnBecameVisible() / OnBecameInvisible() コールバック
- Text Meshコンポーネント
- カメラ間レンダリング中の位置変更
:::

**MaterialPropertyBlock**の代替はマテリアルインスタンス化またはShader Graphのカスタムプロパティです。**レンダリングコールバック**（`OnRenderObject()`等）の代替はカリングイベントまたはEntities Graphics連携です。**Text Mesh**はTextMesh ProまたはUI Toolkitに置き換えてください。カメラ間でのGameObject位置変更も不可です。

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

## まとめ

GPU Resident Drawerは強力な最適化技術ですが、システム要件とGameObject互換性の両面で厳密な条件を満たす必要があります。

**キーポイント**:
- コンピュートシェーダー対応APIが必須(WebGLは非対応)
- URP Forward+またはHDRPが必要
- Mesh Renderer + DOTS Instancing対応シェーダーが必須
- MaterialPropertyBlock等の一部APIは使用不可

プロジェクトでGPU Resident Drawerを導入する際は、まずターゲットプラットフォームの対応状況を確認し、既存のGameObjectが互換性要件を満たしているかチェックすることが重要です。

## 参考リンク

- [GPU Resident Drawer - Unity公式](https://docs.unity3d.com/Manual/urp/gpu-resident-drawer.html)
- [Make objects compatible - Unity公式](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/make-object-compatible-gpu-rendering.html)

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064