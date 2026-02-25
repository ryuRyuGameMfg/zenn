---
title: "Unity VR開発ロードマップ - OpenXRからMeta Quest実機デプロイまで"
emoji: "🥽"
type: "tech"
topics:
  - "unity"
  - "vr"
  - "openxr"
  - "metaquest"
  - "xr"
published: true
published_at: 2026-04-03 18:00
---

## はじめに - 2026年のVR開発状況

2026年現在、VR市場は急速に拡大している。総務省の情報通信白書によれば、日本のメタバース市場規模は2027年度に2兆円に達する見通しであり、VRChatやRobloxといったプラットフォームの普及に加え、Meta Quest 3の登場でスタンドアロンVRの敷居は大幅に下がった。

こうした状況のなか、Unityは開発者人口の多さ、Asset Storeの充実、比較的低いPCスペック要件から、VR開発の入口として最も選ばれるエンジンであり続けている。さらにOpenXRの標準化により、特定のヘッドセットに依存しないマルチプラットフォーム対応が容易になった。

本記事では、Unity + OpenXRの環境構築からハンドトラッキング・テレポート移動の実装、Meta Quest実機デプロイ、VRMアバター統合までを一気通貫で解説する。個別トピックの記事を読む前に、全体像を把握するためのロードマップとして活用してほしい。

:::message
本記事はUnity 6（6000.x）およびXR Interaction Toolkit 3.x系を前提としている。バージョンによりUIや手順が異なる場合がある。
:::

## 環境構築 - Unity + OpenXR + XR Interaction Toolkit

### Unity Hubとプロジェクト作成

まずUnity Hubをインストールし、Unity 6系のエディターを導入する。インストール時に**Android Build Support**（Meta Quest向けに必須）を含めておくこと。

プロジェクト作成時は「3D (URP)」テンプレートを選択する。URPはモバイルVR向けの描画パイプラインとして、パフォーマンスと品質のバランスに優れている。

### OpenXRの有効化

OpenXRはKhronos Groupが策定したオープンなVR/AR規格である。デバイス固有のSDKに依存せず、1つのコードベースで複数のヘッドセットに対応できる点が最大の利点だ。

```
導入手順:
Window > Package Manager > XR Plugin Management をインストール
  -> Edit > Project Settings > XR Plug-in Management
  -> OpenXR にチェックを入れる
  -> Meta Quest Feature Group を有効化（Android タブ）
```

### XR Interaction Toolkitの導入

XR Interaction Toolkit（XRI）は、VR向けのインタラクション機能をまとめたUnity公式パッケージである。掴み操作、UI操作、移動システムなどをコンポーネントベースで構築できる。

```csharp
// Package Managerからインストール後、以下の構成でシーンを構築する
// Hierarchy構成例:
// XR Origin (XR Rig)
//   ├── Camera Offset
//   │     ├── Main Camera
//   │     ├── Left Controller (XR Controller + XR Direct Interactor)
//   │     └── Right Controller (XR Controller + XR Ray Interactor)
//   └── Locomotion System
//         ├── Teleportation Provider
//         └── Snap Turn Provider
```

Package Managerから`com.unity.xr.interaction.toolkit`をインストールし、Samples内の**Starter Assets**をインポートすると、プリセットされたInput Actionやプレハブが利用可能になる。

:::message
Meta Quest 3向けに開発する場合は、`com.unity.xr.meta-openxr`パッケージを追加でインストールすることで、Meta固有の機能（パススルー、シーン理解など）にもアクセスできるようになる。
:::

## 基本実装 - ハンドトラッキング・テレポート移動

### ハンドトラッキングの実装

Meta Quest 3はコントローラーレスのハンドトラッキングに対応している。XRIの`XR Hand Tracking`を利用した基本的な設定手順は以下の通りである。

```csharp
// Hand Tracking用のInput Action設定
// Project Settings > OpenXR > Features で以下を有効化:
//   - Hand Tracking Subsystem
//   - Meta Hand Tracking Aim

// コード例: ピンチジェスチャーの検出
using UnityEngine;
using UnityEngine.XR.Hands;

public class PinchDetector : MonoBehaviour
{
    [SerializeField] private XRHandTrackingEvents handTrackingEvents;

    private void OnEnable()
    {
        handTrackingEvents.jointsUpdated.AddListener(OnJointsUpdated);
    }

    private void OnJointsUpdated(XRHandJointsUpdatedEventArgs args)
    {
        // 親指と人差し指の先端間の距離でピンチを判定
        if (args.hand.GetJoint(XRHandJointID.ThumbTip).TryGetPose(out var thumbPose) &&
            args.hand.GetJoint(XRHandJointID.IndexTip).TryGetPose(out var indexPose))
        {
            float distance = Vector3.Distance(thumbPose.position, indexPose.position);
            if (distance < 0.02f)
            {
                Debug.Log("Pinch detected!");
            }
        }
    }
}
```

### テレポート移動の実装

VR空間での移動方式はVR酔いを左右する重要な要素である。テレポート移動はVR酔いを最小限に抑える方式として広く採用されている。

```csharp
// テレポート移動の構成:
// 1. Locomotion System コンポーネントをXR Originに追加
// 2. Teleportation Provider を追加
// 3. 床面にTeleportation Area または Teleportation Anchor を配置
// 4. コントローラーのRay Interactorでテレポート先を指定

// カスタムテレポートフィルター例: 特定エリアのみ許可
using UnityEngine;
using UnityEngine.XR.Interaction.Toolkit;

public class TeleportFilter : MonoBehaviour
{
    [SerializeField] private TeleportationProvider teleportProvider;
    [SerializeField] private LayerMask allowedLayers;

    public bool ValidateTeleport(Vector3 targetPosition)
    {
        // NavMesh上かどうかを判定
        if (UnityEngine.AI.NavMesh.SamplePosition(
            targetPosition, out var hit, 1.0f, UnityEngine.AI.NavMesh.AllAreas))
        {
            return true;
        }
        return false;
    }
}
```

### 掴みインタラクション

XRIの`XR Grab Interactable`を使えば、VR空間内のオブジェクトを掴む操作を簡単に実装できる。対象のGameObjectにRigidbodyと`XR Grab Interactable`コンポーネントを追加するだけで基本的な掴み機能が動作する。

## Meta Quest実機デプロイ - ビルド設定と最適化

### ビルド環境の準備

Meta QuestはAndroidベースのスタンドアロンデバイスである。実機デプロイに必要な設定は以下の通りだ。

```
1. File > Build Settings > Platform を Android に Switch Platform
2. Player Settings で以下を設定:
   - Minimum API Level: Android 10.0 (API Level 29)
   - Scripting Backend: IL2CPP
   - Target Architecture: ARM64
3. XR Plug-in Management > Android タブ:
   - OpenXR にチェック
   - Meta Quest Feature Group を有効化
```

### 開発者モードとADB接続

実機にアプリをインストールするには、Meta Questの開発者モードを有効にする必要がある。

1. Meta公式サイトで開発者アカウントを登録する
2. スマートフォンのMeta Questアプリから**開発者モードをON**にする
3. USBケーブルでPCとMeta Questを接続する
4. ヘッドセット内に表示される「アクセスを許可しますか？」で許可を選択する
5. Unityの**Build and Run**でAPKが自動インストールされる

:::message
ビルドに失敗する場合は、ADB接続のアクセス権限許可ポップアップを見落としていないか確認すること。PC側とヘッドセット側の両方で許可が必要になる場合がある。
:::

### パフォーマンス最適化

Meta Questはモバイルチップ（Snapdragon XR2 Gen 2）で動作するため、PC VRと比較して描画性能に制約がある。以下の最適化が重要だ。

```csharp
// パフォーマンス最適化チェックリスト:
//
// [描画]
// - Draw Call: 100以下を目標
// - ポリゴン数: シーン全体で75万以下
// - テクスチャ: ASTC圧縮を使用
// - シェーダー: URP/Lit の代わりに URP/Simple Lit を検討
//
// [物理・ロジック]
// - Fixed Timestep: 1/72（72fps）に合わせる
// - GC Alloc: Update内でのnewを避ける
//
// [ツール]
// - Unity Profiler: CPU/GPUボトルネックを特定
// - Frame Debugger: Draw Callの内訳を確認
// - OVR Metrics Tool: Quest上のリアルタイムパフォーマンス監視

// Static Batchingの活用例
// 動かないオブジェクトはInspectorで Static フラグをONにする
// これにより複数オブジェクトのDraw Callが結合される
```

**Meta Quest Developer Hub**の利用も推奨する。ヘッドセット内の映像をPCにミラーリングしたり、アプリの管理やパフォーマンスモニタリングを行える開発者向けの公式ツールである。

## VRMアバター統合 - 自分のキャラをVR空間に

### VRMとは

VRMは、アバターやキャラクターモデルに特化した3Dモデル形式であり、形状・マテリアル・ブレンドシェイプ（表情）などの情報を1ファイルにまとめられる。VRChatやclusterなど多くのプラットフォームで採用されており、VRoidStudioで作成したアバターをそのまま利用できる互換性の高さが特徴だ。

### UniVRMによるインポート

UnityでVRMを扱うには**UniVRM**パッケージを導入する。

```csharp
// UniVRM導入手順:
// 1. GitHub Releasesから UniVRM の .unitypackage をダウンロード
//    https://github.com/vrm-c/UniVRM/releases
// 2. Assets > Import Package でインポート
// 3. .vrm ファイルを Assets フォルダにドラッグ&ドロップ

// ランタイムでVRMを読み込む例
using UniGLTF;
using UniVRM10;

public class VrmLoader : MonoBehaviour
{
    public async void LoadVrm(string path)
    {
        var vrm10Instance = await Vrm10.LoadPathAsync(
            path,
            canLoadVrm0X: true,
            controlRigGenerationOption: ControlRigGenerationOption.Generate
        );

        // VR空間に配置
        var go = vrm10Instance.gameObject;
        go.transform.position = Vector3.zero;
        go.transform.rotation = Quaternion.identity;
    }
}
```

### VRMモデルの最適化

VRMモデルをMeta Quest上で快適に動作させるには、以下の最適化が不可欠である。

| 最適化項目 | 手法 | 効果 |
|-----------|------|------|
| ポリゴン削減 | Blenderのデシメートモディファイア | レンダリング負荷軽減 |
| テクスチャ圧縮 | ASTC形式、解像度を1024x1024以下に | VRAM使用量削減 |
| ブレンドシェイプ整理 | 未使用の表情モーフを削除 | メモリ使用量削減 |
| メッシュ統合 | 分割されたメッシュを結合 | Draw Call削減 |
| マテリアル集約 | テクスチャアトラスで1マテリアルに | Draw Call削減 |

特にモバイルVRでは、アバター1体あたりのポリゴン数を**1万〜3万以下**に抑え、マテリアル数を**3以下**に集約することを目標にすると良い。

## まとめ - VR開発の次のステップ

本記事では、Unity + OpenXRによるVR開発の全体像を以下の流れで解説した。

1. **環境構築**: Unity Hub + OpenXR + XR Interaction Toolkitの導入
2. **基本実装**: ハンドトラッキングとテレポート移動
3. **実機デプロイ**: Meta Questのビルド設定とパフォーマンス最適化
4. **アバター統合**: UniVRMによるVRMモデルの読み込みと最適化

ここから先のステップとしては、以下の方向性が考えられる。

- **マルチプレイヤー**: Photon FusionやNetcode for GameObjectsによるVR空間の共有
- **パススルーMR**: Meta Quest 3のカラーパススルーを活用したMixed Reality体験
- **空間アンカー**: 現実空間にVRオブジェクトを固定するAR的な演出
- **AIキャラクター**: LLMと連携した対話可能なNPCの実装

VR開発はまだ情報が少なく、試行錯誤が必要な場面も多い。しかし、OpenXRの標準化とXR Interaction Toolkitの成熟により、かつてないほど開発の敷居は下がっている。本記事をロードマップとして、一つずつ実装を進めてほしい。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
