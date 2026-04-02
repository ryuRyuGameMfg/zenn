---
title: "【軽量データ】structで軽量データを ― Unity C#でパフォーマンス重視のゲーム設計"
emoji: "📌"
type: "tech"
topics: ["csharp","unity"]
published: true
---

Unityでのゲーム開発において、パフォーマンスの最適化は非常に重要です。特に、大量のデータを扱う際には、データ構造の選択がパフォーマンスに大きく影響します。本記事では、C#の`struct`を使用して軽量データを管理する方法と、その利点について詳しく解説します。

## [](#struct%E3%81%A8%E3%81%AF%E4%BD%95%E3%81%8B%EF%BC%9F)structとは何か？

C#における`struct`は、値型のデータ構造であり、クラスとは異なる特性を持ちます。以下に、`struct`の基本的な特徴をまとめます。

-   **値型**であり、スタックメモリに格納されるため、メモリの割り当てが高速。
-   **イミュータブル**（不変性）を推奨されるため、データの変更が容易に追跡できる。
-   **デフォルトではパラメーターレスコンストラクタ**が提供され、初期化が簡単。

!

**注意点**  
`struct`は主に小規模なデータ構造に適しており、過度に大きな`struct`は逆にパフォーマンスを低下させる可能性があります。

## [](#struct%E3%82%92%E4%BD%BF%E7%94%A8%E3%81%99%E3%82%8B%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88)structを使用するメリット

`struct`を使用することで得られる主なメリットは以下の通りです。

-   **メモリ効率の向上**: 値型であるため、ヒープメモリの使用を避け、ガベージコレクションの負荷を軽減します。
-   **高速なアクセス**: スタックに格納されるため、データへのアクセスが迅速です。
-   **データの不変性**: イミュータブルなデータ構造を作成しやすく、バグの発生を抑制できます。

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%81%AE%E8%A9%B3%E7%B4%B0)メリットの詳細

メリット

説明

メモリ効率の向上

ヒープではなくスタックに格納されるため、メモリ使用量が減少します。

高速なアクセス

スタックへのデータアクセスはヒープよりも高速です。

データの不変性

イミュータブルな設計が推奨され、データの整合性が保たれます。

キャッシュ効率の改善

データが連続して配置されるため、キャッシュヒット率が向上します。

## [](#struct%E3%81%A8class%E3%81%AE%E9%81%95%E3%81%84)structとclassの違い

`struct`と`class`は似たようなデータ構造ですが、いくつかの重要な違いがあります。

### [](#%E4%B8%BB%E3%81%AA%E9%81%95%E3%81%84)主な違い

-   **メモリ割り当て**: `struct`は値型でスタックに格納され、`class`は参照型でヒープに格納されます。
-   **コピー時の挙動**: `struct`はコピー時に全てのデータが複製されますが、`class`は参照がコピーされます。
-   **継承**: `struct`は継承をサポートしておらず、`class`は可能です。

:::details 詳細な違い
詳細な違い

```
// structの例
public struct Vector3
{
    public float x;
    public float y;
    public float z;
}

// classの例
public class Player
{
    public string Name;
    public int Score;
}
```
:::

## [](#unity%E3%81%A7%E3%81%AEstruct%E3%81%AE%E4%BD%BF%E7%94%A8%E4%BE%8B)Unityでのstructの使用例

Unityでは、`struct`を使用してデータを管理することで、パフォーマンスを向上させることができます。以下に具体的な使用例を示します。

### [](#%E3%82%B2%E3%83%BC%E3%83%A0%E3%82%AA%E3%83%96%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E3%81%AE%E3%83%87%E3%83%BC%E3%82%BF%E7%AE%A1%E7%90%86)ゲームオブジェクトのデータ管理

PlayerData.cs

```
public struct PlayerData
{
    public int id;
    public string name;
    public Vector3 position;

    public PlayerData(int id, string name, Vector3 position)
    {
        this.id = id;
        this.name = name;
        this.position = position;
    }
}
```

この例では、プレイヤーのID、名前、位置を管理するために`struct`を使用しています。値型であるため、データのコピーが高速に行えます。

### [](#%E3%83%91%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%B3%E3%82%B9%E3%81%AE%E5%90%91%E4%B8%8A)パフォーマンスの向上

`struct`を使用することで、以下のようなパフォーマンス向上が期待できます。

-   **ガベージコレクションの負荷軽減**: 多数のオブジェクトを生成・破棄する際に、ヒープメモリの使用を最小限に抑えます。
-   **キャッシュ効率の改善**: 連続したメモリ配置により、データのキャッシュヒット率が向上します。

!

**警告**  
`struct`は大きすぎるデータ構造には適していません。一般的には16バイト以下の小規模なデータに使用することが推奨されます。

## [](#struct%E4%BD%BF%E7%94%A8%E6%99%82%E3%81%AE%E6%B3%A8%E6%84%8F%E7%82%B9)struct使用時の注意点

`struct`の利点を最大限に活かすためには、いくつかの注意点があります。

-   **不変性の維持**: `struct`はイミュータブルに設計することで、安全に使用できます。
-   **メモリのサイズ管理**: `struct`が大きくなりすぎないように注意し、必要に応じて分割します。
-   **適切な使用場面の選択**: データが頻繁に変更される場合や、巨大なデータ構造には`class`を使用する方が適切です。

## [](#%E5%AE%9F%E8%A3%85%E4%BE%8B%EF%BC%9Astruct%E3%82%92%E4%BD%BF%E7%94%A8%E3%81%97%E3%81%9F%E3%83%91%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%B3%E3%82%B9%E3%83%81%E3%83%A5uning)実装例：Structを使用したパフォーマンスチュuning

以下は、`struct`を使用してゲーム内のアイテムデータを管理し、パフォーマンスを向上させる実装例です。

ItemData.cs

```
public struct ItemData
{
    public int itemId;
    public string itemName;
    public float weight;

    public ItemData(int id, string name, float weight)
    {
        this.itemId = id;
        this.itemName = name;
        this.weight = weight;
    }
}
```

Inventory.cs

```
using System.Collections.Generic;
using UnityEngine;

public class Inventory : MonoBehaviour
{
    public List<ItemData> items = new List<ItemData>();

    void Start()
    {
        // アイテムの追加
        items.Add(new ItemData(1, "Sword", 5.0f));
        items.Add(new ItemData(2, "Shield", 7.5f));
    }

    void Update()
    {
        // アイテムの処理
        foreach (var item in items)
        {
            // アイテムの処理ロジック
        }
    }
}
```

この実装では、アイテムデータを`struct`で管理することで、メモリの使用量を抑え、処理速度を向上させています。

## [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

`struct`を適切に使用することで、Unityにおけるゲーム開発のパフォーマンスを大幅に向上させることが可能です。メモリ効率の向上や高速なデータアクセスを実現するために、`struct`と`class`の特性を理解し、適切な場面で使い分けることが重要です。今回紹介した実装例や参考資料を活用し、効率的なゲーム設計を目指しましょう。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
