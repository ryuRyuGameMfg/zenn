---
title: "Unity初心者必見！C#で効率UPする5つの小技"
emoji: "🎃"
type: "tech"
topics: ["csharp","unity","tips"]
published: true
---

Unityでゲーム開発を進めると、ちょっとしたスクリプトの書き方だけで**開発スピード**や保守性が大きく変わる瞬間があります。  
たとえば同じ結果を出すにも、数行のコードで済む便利なテクニックを知っているだけで、プロジェクトが見違えるように整理されるのです。

ここでは、UnityのC#スクリプトを扱ううえで知っておきたい“ちょっと便利な小技”をまとめました。最初は「何がそんなに便利なの？」とピンと来ないかもしれませんが、プロジェクトが大きくなるほど「ほんの小さな工夫」が活きてくるはず。ぜひ一つずつ試してみてください。

## [](#%E3%81%A4%E3%81%BE%E3%81%A5%E3%81%8D%E3%82%84%E3%81%99%E3%81%84%E7%90%86%E7%94%B1)つまづきやすい理由

C#自体はシンプルな言語ですが、Unity特有の**ライフサイクル**（`Start()`, `Update()`など）やエディター環境に慣れないうちは、どうコーディングして良いのか迷う場面が多いです。  
とくに以下のような問題で時間を取られるケースがよく見られます。

-   動的生成 → `Destroy` を頻繁に繰り返し、パフォーマンスが落ちる
-   毎フレーム `Find` 系メソッドを呼び出してしまう
-   C#の機能を知らないまま大規模化し、保守しづらいコードになる

こうした悩みを解消するヒントとして、次の章で紹介する「C#の小技」が役に立つはずです。

# [](#c%23%E5%B0%8F%E6%8A%80%E3%81%A7%E8%A7%A3%E6%B1%BA%E3%81%99%E3%82%8B%E6%96%B9%E6%B3%95)C#小技で解決する方法

## [](#1.-nameof\(\)%E3%81%A7%E6%96%87%E5%AD%97%E5%88%97%E4%BE%9D%E5%AD%98%E3%82%92%E6%B8%9B%E3%82%89%E3%81%99)1\. `nameof()`で文字列依存を減らす

Unityでログを出すときや、メソッド名やクラス名を文字列で書くと、リファクタリング（名称変更）時に気づかず不具合を招くことがあります。  
そんなときに便利なのが `nameof()` 演算子です。

```
Debug.Log($"Running {nameof(SomeMethod)}...");

void SomeMethod()
{
    // ...
}
```

万が一メソッド名を変更しても、`nameof`によって文字列が自動的に更新されるため、書き換え忘れのバグを防げます。  
C# 6.0以降で導入された機能なので、Unityが使うC#バージョンとの互換性をチェックしておくと安心です。公式マニュアルはこちら。  
[https://docs.unity3d.com/Manual/CSharpCompiler.html](https://docs.unity3d.com/Manual/CSharpCompiler.html)

また、C#のバージョン履歴や細かなアップデート内容はMicrosoft公式ドキュメントを確認すると分かりやすいでしょう。  
[https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-version-history](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-version-history)

## [](#2.-%E3%82%B7%E3%83%A7%E3%83%BC%E3%83%88%E3%83%8F%E3%83%B3%E3%83%89%E3%83%97%E3%83%AD%E3%83%91%E3%83%86%E3%82%A3%E3%81%A7%E3%82%B3%E3%83%BC%E3%83%89%E3%82%92%E3%81%99%E3%81%A3%E3%81%8D%E3%82%8A)2\. ショートハンドプロパティでコードをすっきり

C# 6.0以降では、自動プロパティの初期化や式形式プロパティなどの便利な記法を活用できます。

```
public class Player
{
    public string Name { get; set; } = "NoName";
    public int Score => 100; // 常に100を返す例
}
```

かつてのUnityバージョン（5系など）では使えない機能もありましたが、現行のUnityでは問題なくサポートされています。行数が減り、可読性も向上するため、ぜひ活用してみましょう。

### [](#3.-%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%82%84%E3%83%87%E3%83%AA%E3%82%B2%E3%83%BC%E3%83%88%E3%81%A7%E3%82%AA%E3%83%96%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E9%96%93%E9%80%9A%E4%BF%A1%E3%82%92%E7%B0%A1%E6%BD%94%E3%81%AB)3\. イベントやデリゲートでオブジェクト間通信を簡潔に

「ある処理が終わったら、他のクラスに通知したい」ときは**イベント**や**デリゲート**を使うと便利です。直接他クラスを参照せずに済むため、結合度が下がり保守しやすくなります。

```
public class ItemCollector : MonoBehaviour
{
    public static event Action<int> OnItemCollected;

    void CollectItem()
    {
        int points = 10;
        OnItemCollected?.Invoke(points);
    }
}
```

購読側では、以下のように受け取れます。

```
ItemCollector.OnItemCollected += (points) =>
{
    Debug.Log($"Points gained: {points}");
};
```

こうすることで、クラス間の依存を最小限に抑えながら柔軟な通信が実現できます。

## [](#4.-using-static%E3%81%A7%E5%AE%9A%E6%95%B0%E3%82%84%E3%83%A1%E3%82%BD%E3%83%83%E3%83%89%E3%82%92%E3%82%B9%E3%83%AA%E3%83%A0%E5%8C%96)4\. `using static`で定数やメソッドをスリム化

C# 6.0から導入された `using static SomeClass;` は、そのクラスのstaticメソッドや定数を**クラス名を書かずに**直接呼び出せる機能です。

csharp

```
using static UnityEngine.Mathf;

public class AngleChecker : MonoBehaviour
{
    void Update()
    {
        float angle = Atan2(transform.position.y, transform.position.x);
        // 通常なら Mathf.Atan2(...) と書くところを短縮できる
    }
}
```

頻繁に呼び出すメソッドがある場合、コードがかなりスッキリします。ただし、どのクラスのメソッドか分かりづらくなる可能性もあるため、使いどころは慎重に見極めましょう。

## [](#5.-linq%E3%81%A7%E3%82%B3%E3%83%AC%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%E6%93%8D%E4%BD%9C%E3%82%92%E4%B8%80%E8%A1%8C%E3%81%A7)5\. `LINQ`でコレクション操作を一行で

配列やリストを操作するとき、**LINQ**（Language Integrated Query）を使うと、フィルタリングやソートが非常に手軽に書けます。

csharp

```
var enemies = FindObjectsOfType<Enemy>();
var strongEnemies = enemies.Where(e => e.HP >= 100)
                          .OrderByDescending(e => e.HP);

foreach (var enemy in strongEnemies)
{
    // HPが高い敵から処理
}
```

ただし、LINQは実行コストがやや高めなので、毎フレーム呼び出すようなリアルタイム処理には不向きです。**コレクション操作をまとめて行いたい**ときに使うのがベターと言えます。より詳しい解説は以下のリンクも参考にしてみてください。  
[https://zenn.dev/ryuryu\_game/articles/5dfedf28aedb9f](https://zenn.dev/ryuryu_game/articles/5dfedf28aedb9f)

## [](#6.-%E6%8B%A1%E5%BC%B5%E3%83%A1%E3%82%BD%E3%83%83%E3%83%89%E3%81%A7%E7%8B%AC%E8%87%AA%E3%83%A1%E3%82%BD%E3%83%83%E3%83%89%E3%82%92%E8%BF%BD%E5%8A%A0)6\. 拡張メソッドで独自メソッドを追加

「Transformにもう少し便利な機能が欲しい…」という場合、**拡張メソッド**を使うと、既存のクラスに新メソッドを“後付け”できます。

```
public static class TransformExtensions
{
    public static void ResetLocal(this Transform tf)
    {
        tf.localPosition = Vector3.zero;
        tf.localRotation = Quaternion.identity;
        tf.localScale = Vector3.one;
    }
}
```

呼び出すときは、まるでTransformの標準APIのように使えます。

csharp

```
transform.ResetLocal();
```

濫用しすぎると「どの拡張クラスで定義していたか」が分かりにくくなるため、チーム開発では運用ルールを決めるとよいでしょう。

# [](#%E3%81%A9%E3%82%93%E3%81%AA%E5%95%8F%E9%A1%8C%E3%81%8C%E8%A7%A3%E6%B1%BA%E3%81%A7%E3%81%8D%E3%82%8B%E3%81%AE%E3%81%8B)どんな問題が解決できるのか

上記のような「C#小技」を導入すると、以下の問題が大幅に軽減されます。

-   **コードの重複や冗長表現** → ショートハンドプロパティや拡張メソッドで一気に削減
-   **オブジェクト間通信の複雑化** → イベント/デリゲートで依存を緩和
-   **長いstaticメソッド呼び出し** → `using static`でスッキリ
-   **大量のループ・条件分岐** → LINQでシンプルに書き分け

Unityでは「GameObject+コンポーネント」という構造でシーンを管理するため、スクリプトも自然と細かく分割されがちです。その際、C#の便利機能を活かせば**保守性**がぐんと上がります。

# [](#%E4%B8%80%E6%AD%A9%E9%80%B2%E3%82%93%E3%81%A0%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E7%AE%A1%E7%90%86%E3%81%B8)一歩進んだスクリプト管理へ

C#の小技を活用していくと、「もっと汎用的にまとめたい」「他のシーンでも使えるように再利用したい」といった要望が出てきます。そこから生まれるアイデアは、次のように発展しやすいでしょう。

-   抽象クラスやインタフェースを導入して、共通機能をまとめる
-   非同期処理（Async/Await）を使い、コルーチンより柔軟なタスク管理をする
-   IOCコンテナやサービスロケーターなど、設計パターンを適宜取り入れる

本記事で挙げた小技は、そうした**高度なコード設計への最初の一歩**です。慣れるほどに「ちょっとした工夫」が大規模化で効いてくるはず。

# [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

**C#の特徴を活かすだけで、Unity上でのスクリプトが劇的に書きやすくなる**のは驚きです。最初は「わざわざこんな書き方をする意味あるの？」と思うかもしれませんが、プロジェクト規模が大きくなるほどこうした差が出てきます。

小さなプロジェクトで試しながら、自分に合ったスタイルを見つけてみてください。UnityではシーンにGizmosを使ってデバッグ表示するなど、エディタ側の機能もいろいろ工夫できます。たとえば下記URLでは、Gizmosの活用例が紹介されています。  
[https://raspberly.hateblo.jp/entry/UnitySceneGizmos](https://raspberly.hateblo.jp/entry/UnitySceneGizmos)

また、C#の基礎をざっと見直したい方は、動画解説も参考になるでしょう。  
[https://www.youtube.com/watch?v=ONW2mg\_n6Xw](https://www.youtube.com/watch?v=ONW2mg_n6Xw)

「ちょっとの工夫」で大きく作業効率が変わるのがゲーム開発の面白いところ。ぜひ積極的に取り入れてみてください。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
