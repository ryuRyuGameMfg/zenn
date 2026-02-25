---
title: "UnityにおけるMonoBehaviourとPureC#の違い｜AI開発時代の必須知識"
emoji: "👻"
type: "tech"
topics:
  - "ai"
  - "csharp"
  - "unity"
  - "monobehaviour"
published: true
published_at: "2026-01-08 20:04"
---


## はじめに

Unity開発を始めたとき、チュートリアルで見るコードの先頭には必ず`: MonoBehaviour`って書いてありますよね。

私も最初は「これがUnityのお決まりなんだな」と思って、**すべてのスクリプトにMonoBehaviourを付けていました**。でも、それって実は適切じゃないんです。

MonoBehaviourとPure C#（MonoBehaviourを継承しないクラス）を適切に使い分けることで、コードがグッと読みやすく、テストもしやすくなります。一緒に違いを見ていきましょう！

## 何が違うの？

まず、両者の違いを表で見てみましょう。細かいことは後で説明するので、「こんな感じなんだな」と眺めてください。

| 項目 | MonoBehaviour | Pure C# |
|------|--------------|---------|
| **GameObjectへのアタッチ** | 必須 | できない |
| **Unityライフサイクル** | 使える（Start、Updateなど） | 使えない |
| **Inspector表示** | 表示される | 表示されない |
| **Coroutine** | 使える | 使えない |
| **インスタンス化** | Unityが自動管理 | newで作る |
| **メモリ効率** | ちょっと重い | 軽量 |
| **単体テスト** | 難しい | 簡単 |

:::message
MonoBehaviourは、コンポーネントとして、アタッチできるのが利点です。
:::

## MonoBehaviourって何？

MonoBehaviourは、**Unityのゲームオブジェクトにアタッチできるスクリプトの基底クラス**です。

```csharp:PlayerController.cs
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    void Start()
    {
        // ゲーム開始時に1回だけ実行
    }

    void Update()
    {
        // 毎フレーム実行
    }
}
```

### MonoBehaviourができること

MonoBehaviourを継承すると、こんな便利な機能が使えるようになります:

- **Start、Update**などのライフサイクル関数が使える
- **GameObjectにドラッグ&ドロップ**でアタッチできる
- **Inspectorで値を調整**できる（デバッグが楽！）
- **Coroutine**で時間差処理ができる

:::message
**要するに**: MonoBehaviourは「ゲームの世界（GameObjectたち）と直接やり取りする」クラスなんです
:::

## Pure C#って何？

Pure C#は、**MonoBehaviourを継承しない、普通のC#クラス**です。

```csharp:PlayerData.cs
public class PlayerData
{
    public string playerName;
    public int level;
    public int hp;

    public PlayerData(string name, int level, int hp)
    {
        this.playerName = name;
        this.level = level;
        this.hp = hp;
    }

    public void TakeDamage(int damage)
    {
        hp -= damage;
    }
}
```

### Pure C#ができること

Pure C#は地味に見えますが、実は重要な役割があります:

- **Unityに依存しない**ロジックが書ける（テストが楽！）
- **new演算子**で好きなタイミングで作れる
- **軽量**でメモリに優しい
- **単体テスト**がサクサク書ける

:::message
**要するに**: Pure C#は「データや計算を管理する、縁の下の力持ち」なんです
:::

## どう使い分ければいいの？

ここが一番悩むポイントですよね。私も最初は「全部MonoBehaviourでいいじゃん」って思ってました。

でも、**判断基準はシンプル**なんです。

:::message alert
**たった1つの質問**: 「これ、GameObjectにアタッチする必要ある？」
:::

**MonoBehaviourを使うのはこんな時:**
- キャラクターを動かしたい（transform使う）
- カメラをついてこさせたい
- UIボタンを押したい
- アニメーションを再生したい
- 何かにぶつかったことを検知したい

**Pure C#を使うのはこんな時:**
- プレイヤーのステータスを管理したい（HP、レベルとか）
- スコアを計算したい
- セーブデータを作りたい
- ユーティリティ関数を作りたい
- 敵のパラメータを保存したい

## 実装例で理解する

言葉だけだとピンと来ないかもしれないので、実際のコードで見てみましょう。

### やりがちな失敗例

```csharp:BadExample.cs
public class Player : MonoBehaviour
{
    public string playerName;
    public int level;
    public int hp;
    public int attackPower;

    void Update()
    {
        // 移動処理とデータ管理が混在
        if (Input.GetKey(KeyCode.W))
        {
            transform.position += Vector3.forward * Time.deltaTime;
        }
    }

    public void TakeDamage(int damage)
    {
        hp -= damage;
    }
}
```

:::message alert
**何が問題？**: HP管理も移動処理も全部1つのクラスに詰め込んでいる。これだと「HPの計算だけテストしたい」ができません
:::

### 改善版：役割をキレイに分けてみる

```csharp:PlayerData.cs
// Pure C#: データクラス
public class PlayerData
{
    public string playerName;
    public int level;
    public int hp;
    public int maxHp;

    public PlayerData(string name, int level)
    {
        playerName = name;
        this.level = level;
        maxHp = level * 100;
        hp = maxHp;
    }

    public void TakeDamage(int damage)
    {
        hp = Mathf.Max(0, hp - damage);
    }

    public bool IsDead() => hp <= 0;
}
```

```csharp:PlayerController.cs
// MonoBehaviour: GameObject操作
public class PlayerController : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    private PlayerData playerData;

    void Start()
    {
        // Pure C#クラスをインスタンス化
        playerData = new PlayerData("Hero", 1);
    }

    void Update()
    {
        // 移動処理のみを担当
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");

        Vector3 movement = new Vector3(horizontal, 0, vertical);
        transform.position += movement * moveSpeed * Time.deltaTime;
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.CompareTag("Enemy"))
        {
            playerData.TakeDamage(10);

            if (playerData.IsDead())
            {
                Debug.Log("Game Over");
            }
        }
    }
}
```

:::message
**こうすると何がいいの？**:
- PlayerDataはUnity関係なくテストできる！
- PlayerControllerは「動かす」ことだけに集中できる
- 「データはこっち、動きはあっち」と役割がハッキリする
:::

### さらに進んだ設計

:::details より本格的な実装例（クリックで展開）

```csharp:GameManager.cs
// Pure C#: ゲームロジック
public class GameLogic
{
    public int CalculateScore(int level, int enemiesDefeated)
    {
        return level * 100 + enemiesDefeated * 50;
    }

    public int CalculateExpGain(int enemyLevel)
    {
        return enemyLevel * 10;
    }
}

// MonoBehaviour: シーン管理
public class GameManager : MonoBehaviour
{
    private GameLogic gameLogic;
    private PlayerData playerData;

    void Start()
    {
        gameLogic = new GameLogic();
        playerData = new PlayerData("Hero", 1);
    }

    public void OnEnemyDefeated(int enemyLevel)
    {
        int exp = gameLogic.CalculateExpGain(enemyLevel);
        // 経験値処理...
    }
}
```

この設計により、GameLogicは**Unity非依存**でテスト可能になります。
:::

## まとめ

MonoBehaviourとPure C#の使い分けは、Unity開発における最重要スキルの一つです。

**判断基準:**
- **GameObjectと紐付く** → MonoBehaviour
- **データ・ロジック** → Pure C#

この原則を守ることで、テストしやすく、保守性の高いコードが書けるようになります。

:::message
**次のステップ**:
- ScriptableObjectによるデータ管理
- DIコンテナを使った依存性の注入
- MVCパターン・MVPパターンの適用
:::

## 参考リンク

- [Unity公式 - MonoBehaviour](https://docs.unity3d.com/ja/current/ScriptReference/MonoBehaviour.html)
- [Unity公式 - Scripting API](https://docs.unity3d.com/ja/current/ScriptReference/index.html)
- [Microsoft C# ドキュメント](https://learn.microsoft.com/ja-jp/dotnet/csharp/)
