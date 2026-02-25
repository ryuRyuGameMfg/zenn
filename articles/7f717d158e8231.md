---
title: "【Unity×Cursor】AI開発時代におけるプログラム設計の新常識！脱Monobehaviour!?"
emoji: "👋"
type: "idea"
topics: ["ai","csharp","unity","設計","cursor"]
published: true
---

# [](#monobehaviour%E3%81%AF%E2%80%9Cview%E3%82%AF%E3%83%A9%E3%82%B9%E2%80%9D%EF%BC%9F)MonoBehaviourは“Viewクラス”？

Unityでの開発において、**MonoBehaviourは視覚的かつ物理的なオブジェクトと深く結び付いている**ため、他言語でいうところの「Viewクラス」のような役割を果たします。GameObjectにアタッチしてシーン上に配置し、Inspectorで設定を調整する――このフローは、見た目の制御や座標管理が主体の場面では非常に便利です。**しかし近年はAIのコード生成や自動リファクタリングを活かした開発が増え、MonoBehaviourに過度に依存すると、AIに書かせにくい要素が多くなる**のが現実です。

# [](#monobehaviour%E3%81%ABai%E3%81%8C%E9%96%A2%E4%B8%8E%E3%81%97%E3%81%A5%E3%82%89%E3%81%84%E7%90%86%E7%94%B1%EF%BC%81)MonoBehaviourにAIが関与しづらい理由！

-   MonoBehaviour内のコードを頻繁に更新するたび、**Inspectorでの再設定**が必要になる
-   AIが補完しづらく、開発者の手戻り作業が増える
-   **Unityの階層構造やInspectorをAIが把握するのは難しい**

!

結果的に、MonoBehaviour依存の箇所はAIが関与しにくいコードになりやすい

## [](#%E3%83%87%E3%83%BC%E3%82%BF%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E3%82%92%E5%88%86%E9%9B%A2%E3%81%97%E3%81%A6ai%E3%82%92%E3%83%95%E3%83%AB%E6%B4%BB%E7%94%A8)データロジックを分離してAIをフル活用

そこで「MonoBehaviourをViewクラスとみなし、データロジックを別に切り出す」アーキテクチャを採用することで、独立したロジック部分はAIにまるごと書かせることが容易になります。以下では、MonoBehaviour依存が強い場合に起こりがちな問題点から、どう脱却してAIと連携しやすい設計を実現するか、その手法を見ていきましょう。

## [](#monobehaviour%E3%81%B8%E3%81%AE%E9%81%8E%E5%89%B0%E3%81%AA%E4%BE%9D%E5%AD%98%E3%81%AB%E3%82%88%E3%82%8B%E8%AA%B2%E9%A1%8C)MonoBehaviourへの過剰な依存による課題

-   純粋C#のテストやツール連携がしづらい
-   Inspector上での座標管理やイベントロジックが混在し、データ層が可読性を失いやすい
-   AIが生成・更新する場合、MonoBehaviour特有のライフサイクル（Awake, Start, Updateなど）をいちいち理解させる必要がある
-   Inspector再設定が伴う変更はAIが自動的に行えないため、ヒューマンの手間が増える

一方で、MonoBehaviourには**視覚調整**や**ライフサイクル管理**などの恩恵もあるため、まったく使わないわけにはいきません。要は、Unityで表示や物理演算に必要な部分だけMonoBehaviourに任せ、**バックグラウンドのデータロジックは極力MonoBehaviour外で扱おう**という考え方です。

# [](#%E3%83%97%E3%83%AD%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E3%81%AB%E3%81%8A%E3%81%91%E3%82%8Bmonobehaviour%E4%BE%9D%E5%AD%98%E5%BA%A6%E3%81%AE%E8%A9%95%E4%BE%A1)プロジェクトにおけるMonoBehaviour依存度の評価

**まずはMonoBehaviourに依存しすぎているかどうかをチェックしてみましょう！**

No.

チェック項目

1

多数のスクリプトがMonoBehaviourクラスに直接依存している

2

MonoBehaviourライフサイクル（Awake, Start, Update等）を多用

3

データ管理やロジックがMonoBehaviour内部に集約されている

4

ユニットテストやAIコード生成で苦労している

5

他システムやプラグインとの連携時、MonoBehaviour依存が足かせになっている

6

シリアライズ/永続化までもMonoBehaviourが担っていて設計が複雑化

7

コルーチンやイベントハンドリングに過度依存し、他言語/AIツールが扱いづらい

8

プロジェクト全体がMonoBehaviour主体の設計になっており、別アーキテクチャへの移行が難しい

9

MonoBehaviourを継承したクラスが膨大で、クラス階層が煩雑

10

インスタンス生成・破棄が煩雑になり、メモリ管理やイベント解放などで不具合が起きやすい

チェック項目が多く当てはまるほど、AIによるコード補完や自動リファクタリングを活かしづらい環境であると言えます。

# [](#monobehaviour%E5%A4%96%E3%81%B8%E3%81%AE%E3%83%87%E3%83%BC%E3%82%BF%E7%AE%A1%E7%90%86%E3%81%8A%E3%82%88%E3%81%B3%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E3%81%AE%E5%88%86%E9%9B%A2%E6%96%B9%E6%B3%95)MonoBehaviour外へのデータ管理およびロジックの分離方法

**「MonoBehaviourはViewクラス」** と捉え、画面表示やオブジェクト操作に限定し、データロジックは別管理することが重要です。以下、段階的にどう独立させていくかを解説します。

## [](#step1%3A-%E3%83%A6%E3%83%BC%E3%83%86%E3%82%A3%E3%83%AA%E3%83%86%E3%82%A3%E5%8C%96)Step1: ユーティリティ化

### [](#%E3%83%A6%E3%83%BC%E3%83%86%E3%82%A3%E3%83%AA%E3%83%86%E3%82%A3%E3%82%AF%E3%83%A9%E3%82%B9)ユーティリティクラス

Unityのシーン状況と無関係な数値演算や文字列処理、アルゴリズムなどを、純粋C#のユーティリティクラスとしてまとめます。MonoBehaviourに依存しないため、**CursorやChatGPTなどのAIツール**が自動生成・修正しやすく、テストも行いやすいです。

```
public static class MathUtility
{
    public static float CalculateDistance(Vector3 a, Vector3 b)
    {
        return Vector3.Distance(a, b);
    }

    public static int Factorial(int n)
    {
        if (n <= 1) return 1;
        else return n * Factorial(n - 1);
    }
}
```

## [](#step2%3A-scriptableobject%E3%81%A7%E3%83%87%E3%83%BC%E3%82%BF%E5%88%86%E9%9B%A2)Step2: ScriptableObjectでデータ分離

### [](#scriptableobject)ScriptableObject

パラメータや設定値をInspectorで扱いつつ、MonoBehaviourに依存しない形式で保持する仕組みがScriptableObjectです。AIがデータ部分をまるごと書き換えたい場合も、ScriptableObjectとして切り出しておくと、**再ビルドやシーン変更の手間が最小化**されます。

```
[CreateAssetMenu(fileName = "GameSettings", menuName = "Settings/GameSettings")]
public class GameSettings : ScriptableObject
{
    public float playerSpeed;
    public int maxHealth;
}
```

[https://zenn.dev/ryuryu\_game/articles/fb4dacb67cd3b9](https://zenn.dev/ryuryu_game/articles/fb4dacb67cd3b9)

## [](#step3%3A-factory%E3%82%84repository%E3%81%A7%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E3%82%92%E9%9B%86%E4%B8%AD)Step3: FactoryやRepositoryでロジックを集中

### [](#%E3%82%B8%E3%82%A7%E3%83%8D%E3%83%AA%E3%83%83%E3%82%AF%E3%81%AAfactory%EF%BC%8Frepository)ジェネリックなFactory／Repository

AIが書いたコードをシステムに組み込む際、**汎用インターフェース**に沿って設計されていると、追加や改変が容易になります。たとえばFactoryはオブジェクト生成、Repositoryはデータアクセスを一括で管理し、MonoBehaviourの登場を最小限に留められます。

```
public interface IRepository<T>
{
    void Add(T item);
    T Get(int id);
    IEnumerable<T> GetAll();
}

public class PlayerRepository : IRepository<Player>
{
    private List<Player> players = new List<Player>();

    public void Add(Player player) => players.Add(player);
    public Player Get(int id) => players.FirstOrDefault(p => p.Id == id);
    public IEnumerable<Player> GetAll() => players;
}
```

## [](#step4%3A-%E3%83%90%E3%83%83%E3%82%AF%E3%82%B0%E3%83%A9%E3%82%A6%E3%83%B3%E3%83%89%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E3%82%92%E7%8B%AC%E7%AB%8B)Step4: バックグラウンドロジックを独立

### [](#%E8%83%8C%E6%99%AF%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%81%AE%E5%88%87%E3%82%8A%E9%9B%A2%E3%81%97)背景システムの切り離し

アイテムの管理やレベルアップ計算など、直接シーン表示に関係ない処理は、MonoBehaviourではなく**Plain Old C# Objects (POCO)**で設計しましょう。こうすることで**AIが生成・編集しやすいロジック領域**が広がります。

```
public class Inventory
{
    private List<Item> items = new List<Item>();

    public void AddItem(Item item) => items.Add(item);
    public void RemoveItem(Item item) => items.Remove(item);
    public IEnumerable<Item> GetAllItems() => items;
}
```

# [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

### [](#monobehaviour%E3%81%AFview%E3%82%AF%E3%83%A9%E3%82%B9%E3%80%81ai%E3%81%AE%E3%81%9F%E3%82%81%E3%81%AB%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E3%81%AF%E7%8B%AC%E7%AB%8B)MonoBehaviourはViewクラス、AIのためにロジックは独立

最終的なゴールは、**MonoBehaviourを主にView（可視化）担当とみなし、データやロジックは別クラスへ切り離す**ことです。AIが生成・編集するコードは基本的にバックグラウンドロジック側になり、MonoBehaviour上のInspector再設定などの人間でしか扱えない部分を減らすことで、チーム全体の効率が上がります。AI時代には、こうした**Cursorなどの支援ツール**で自動リファクタリングやコード生成を行う機会が増えるでしょう。そのためにも**MonoBehaviour依存を低減したアーキテクチャ**が、有力な選択肢となります。

さあ、あなたもMonoBehaviour依存から一歩脱却して、**AIが書きやすいUnityプロジェクト**を目指してみませんか。見た目はMonoBehaviour、裏ではFactory＆Repository――そんな構造が、あなたの開発に新しい風を吹き込みます。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
