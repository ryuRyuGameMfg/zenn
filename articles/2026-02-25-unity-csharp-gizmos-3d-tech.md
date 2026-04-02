---
title: "【Unity C#】Gizmosで3D空間を徹底デバッグ!?隠れた不具合を見える化する技術"
emoji: "🕌"
type: "tech"
topics: ["csharp","unity","tips","デバッグ","gizmos"]
published: true
---

Unityでの3Dゲーム開発では、シーン上のオブジェクトの配置、移動経路、さらには物理挙動など、普段は見えにくい内部処理が隠れた不具合の原因となることがあります。本記事では、Gizmosを活用してこれらの情報を「見える化」し、効率的にデバッグするための手法を解説します。Gizmosの基本機能から、カメラとの距離に応じた描画調整、NPCのルート可視化、物理演算デバッグ、さらにはMeta Horizon向けの拡張機能まで、実践的なテクニックを幅広くご紹介します。

!

この記事では、Gizmosの基本的な使い方から応用テクニックまで、3D空間の隠れた不具合を見える化するための具体例と実装方法を解説します。

## [](#gizmos%E3%81%AE%E5%9F%BA%E6%9C%AC%E6%A9%9F%E8%83%BD%E3%81%A8%E6%B4%BB%E7%94%A8%E6%B3%95)Gizmosの基本機能と活用法

Gizmosは、エディタのシーンビュー上にデバッグ用の図形、アイコン、テキストなどを表示するための仕組みです。実際のゲームプレイには影響を与えないため、動作確認やオブジェクト配置のチェックに最適です。

-   シーン内に簡単な図形やアイコンを描画可能
-   シーン上に直接テキスト情報を表示できる
-   オブジェクトごとに描画の表示・非表示を制御可能

より詳しい設定方法は公式ドキュメントも参照してください。  
[https://docs.unity3d.com/ja/2019.4/Manual/GizmosMenu.html](https://docs.unity3d.com/ja/2019.4/Manual/GizmosMenu.html)

### [](#%E3%82%B7%E3%83%BC%E3%83%B3%E4%B8%8A%E3%81%AB%E6%8F%8F%E7%94%BB%E3%81%99%E3%82%8B%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%82%B3%E3%83%BC%E3%83%89)シーン上に描画するサンプルコード

Gizmosの描画は、`OnDrawGizmos`または`OnDrawGizmosSelected`メソッド内に記述します。たとえば、シーン上に赤い球体を表示する場合は以下のように実装します。

SampleGizmos.cs

```
using UnityEngine;

public class SampleGizmos : MonoBehaviour
{
    void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawSphere(transform.position, 0.5f);
    }
}
```

:::details テキスト表示のサンプル
テキスト表示のサンプル

SampleGizmosText.cs

```
using UnityEngine;

public class SampleGizmosText : MonoBehaviour
{
    void OnDrawGizmos()
    {
        GUIStyle style = new GUIStyle();
        style.normal.textColor = Color.white;
        UnityEditor.Handles.Label(transform.position + Vector3.up * 1.0f, "CheckPoint", style);
    }
}
```

このサンプルでは、`UnityEditor.Handles.Label`を利用して、シーン上に「CheckPoint」というテキストを表示しています。
:::

GizmosやHandlesを使った描画テクニックの詳細は、以下のリンクも参考にしてください。  
[https://raspberly.hateblo.jp/entry/UnitySceneGizmos](https://raspberly.hateblo.jp/entry/UnitySceneGizmos)

## [](#3d%E7%A9%BA%E9%96%93%E3%83%87%E3%83%90%E3%83%83%E3%82%B0%E3%81%AE%E5%BF%9C%E7%94%A8%E3%83%86%E3%82%AF%E3%83%8B%E3%83%83%E3%82%AF)3D空間デバッグの応用テクニック

### [](#%E3%82%AB%E3%83%A1%E3%83%A9%E8%B7%9D%E9%9B%A2%E3%81%AB%E5%BF%9C%E3%81%98%E3%81%9F%E6%8F%8F%E7%94%BB%E3%81%AE%E6%9C%80%E9%81%A9%E5%8C%96)カメラ距離に応じた描画の最適化

広大な3D空間では、カメラから離れた位置にあるGizmosが見えにくくなることがあります。そこで、カメラとの距離に応じて描画方法を動的に変えるテクニックが有効です。具体的には：

-   `Vector3.Distance`でカメラとの距離を算出
-   一定距離以上のオブジェクトは、アイコンやテキストを縮小または非表示にする
-   距離に合わせたスケール調整で、常に適切なサイズで表示

### [](#npc%E3%81%AE%E7%A7%BB%E5%8B%95%E7%B5%8C%E8%B7%AF%E3%82%84%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%A9%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%E7%AF%84%E5%9B%B2%E3%81%AE%E8%A6%96%E8%A6%9A%E5%8C%96)NPCの移動経路やインタラクション範囲の視覚化

3D空間におけるNPCの巡回ルートや、ユーザーがインタラクション可能な範囲を可視化することは、デバッグだけでなくシステム設計の観点からも重要です。Gizmosを用いることで、以下の効果が期待できます。

1.  NPCのルートをラインや矢印で明示
2.  ルート編集を直感的に行える（クリックやドラッグで調整）
3.  インタラクション可能領域を円や立体図形で表現

シーンビュー上で直接移動経路を編集する方法については、こちらも参考になります。  
[https://ryo620.org/post/unity-editor-extending-03](https://ryo620.org/post/unity-editor-extending-03)

## [](#%E7%89%A9%E7%90%86%E6%BC%94%E7%AE%97%E3%81%AE%E7%8A%B6%E6%85%8B%E3%82%92%E8%A6%8B%E3%81%88%E3%82%8B%E5%8C%96%E3%81%99%E3%82%8B)物理演算の状態を見える化する

3D空間内では、ユーザーの動きに合わせた物理演算の正確な動作確認が求められます。UnityのPhysics Debug Visualization機能を使うと、以下の点がチェックできます。

-   衝突判定が正常に行われているか
-   トリガーの範囲が意図した通りか
-   静的・動的コライダーの重なり状況

これらの詳細な設定方法は、公式ドキュメントを確認してください。  
[https://docs.unity3d.com/ja/2022.3/Manual/PhysicsDebugVisualization.html](https://docs.unity3d.com/ja/2022.3/Manual/PhysicsDebugVisualization.html)

## [](#meta-horizon%E5%90%91%E3%81%91debuggizmos%E3%81%AE%E5%AE%9F%E8%B7%B5)Meta Horizon向けDebugGizmosの実践

Meta HorizonプラットフォームでのVR体験を構築する場合、DebugGizmosを活用すると、手の衝突判定やインタラクションの可視化が容易になり、問題発生時の原因究明がスムーズになります。具体的な実装例は以下のリンクで紹介されています。  
[https://developers.meta.com/horizon/documentation/unity/unity-isdk-debug-gizmos/?locale=ja\_JP](https://developers.meta.com/horizon/documentation/unity/unity-isdk-debug-gizmos/?locale=ja_JP)

!

Meta Horizon向けの機能は、専用のSDKなど事前準備が必要な場合があるため、注意して利用してください。

## [](#%E5%AE%9F%E8%B7%B5%EF%BC%81gizmos%E3%82%92%E5%88%A9%E7%94%A8%E3%81%97%E3%81%9F%E7%B5%8C%E8%B7%AF%E5%8F%AF%E8%A6%96%E5%8C%96%E3%81%AE%E4%BE%8B)実践！Gizmosを利用した経路可視化の例

:::details 経路表示のサンプルコード
経路表示のサンプルコード

PathDebug.cs

```
using UnityEngine;

public class PathDebug : MonoBehaviour
{
    public Transform[] points;

    void OnDrawGizmos()
    {
        if (points == null || points.Length == 0) return;

        Gizmos.color = Color.yellow;

        for (int i = 0; i < points.Length - 1; i++)
        {
            Gizmos.DrawLine(points[i].position, points[i + 1].position);
        }
    }
}
```

このコードは、指定したポイント間を黄色いラインで結び、NPCなどの移動経路を視覚化します。
:::

### [](#%E6%88%90%E5%8A%9F%E3%81%99%E3%82%8B%E3%81%9F%E3%82%81%E3%81%AE%E3%82%AD%E3%83%BC%E3%83%9D%E3%82%A4%E3%83%B3%E3%83%88)成功するためのキーポイント

-   **最小限の描画**に留め、情報過多を避ける
-   エディタ拡張と連携し、シーン上での直接編集を可能にする
-   レイヤー管理により、必要な情報のみを選別して表示する

プロジェクト全体でGizmosの表示を制御する仕組みを導入すれば、さらに効率的なデバッグが実現します。

## [](#%E7%B7%8F%E6%8B%AC%EF%BC%9A%E9%9A%A0%E3%82%8C%E3%81%9F%E4%B8%8D%E5%85%B7%E5%90%88%E3%82%92%E8%A6%8B%E3%81%88%E3%82%8B%E5%8C%96%E3%81%97%E3%81%A6%E9%96%8B%E7%99%BA%E5%8A%B9%E7%8E%87%E3%82%92%E5%90%91%E4%B8%8A)総括：隠れた不具合を見える化して開発効率を向上

3D空間の開発において、膨大なオブジェクトや複雑な移動経路、物理挙動のチェックは非常に重要です。Gizmosを巧みに使いこなすことで、これらの隠れた不具合を見える化し、迅速なデバッグ作業と高品質なシステム構築が可能となります。

1.  基本的な図形やテキスト描画から始める
2.  NPCのルートやコライダーの状態を明確に視覚化する
3.  公式ドキュメントや実例を元に、独自のデバッグツールを整備する

これらの手法を積極的に取り入れて、3D空間のデバッグ効率を劇的に向上させましょう。

-   参考記事

[https://raspberly.hateblo.jp/entry/UnitySceneGizmos](https://raspberly.hateblo.jp/entry/UnitySceneGizmos)  
[https://ryo620.org/post/unity-editor-extending-03](https://ryo620.org/post/unity-editor-extending-03)

-   公式リファレンス

[https://docs.unity3d.com/ja/2022.3/Manual/PhysicsDebugVisualization.html](https://docs.unity3d.com/ja/2022.3/Manual/PhysicsDebugVisualization.html)  
[https://docs.unity3d.com/ja/2019.4/Manual/GizmosMenu.html](https://docs.unity3d.com/ja/2019.4/Manual/GizmosMenu.html)  
[https://developers.meta.com/horizon/documentation/unity/unity-isdk-debug-gizmos/?locale=ja\_JP](https://developers.meta.com/horizon/documentation/unity/unity-isdk-debug-gizmos/?locale=ja_JP)

!

この記事を参考に、ぜひGizmosを活用して3D空間内の隠れた不具合を見える化し、デバッグ作業を効率化してください。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
