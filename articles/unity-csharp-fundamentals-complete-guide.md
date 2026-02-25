---
title: "Unity C#基礎を1記事で総復習 - ライフサイクルからラムダ式まで"
emoji: "📘"
type: "tech"
topics: ["unity", "csharp", "gamedev", "beginners", "dotnet"]
published: true
published_at: 2026-03-30 18:00
---

## はじめに

Unity開発でC#を書いていると、ライフサイクルの実行順序、クラス設計の原則、モダンC#の構文など、押さえるべき基礎は意外と幅広い。本記事では **ライフサイクル / クラス設計 / モダン構文** の3本柱で一気に総復習する。各トピックに実用的なコード例を添えた。

:::message
対象読者: Unity入門を終え、コードの「なぜそう書くのか」を体系的に整理したい方。
:::

## ライフサイクル -- Awake / Start / Update の使い分け

Unityのスクリプトは `MonoBehaviour` を継承しており、エンジンが決められた順序でメソッドを呼び出す。この実行順序を**ライフサイクル**と呼ぶ。最も重要な3つを押さえておこう。

| メソッド | タイミング | 主な用途 |
|---------|-----------|---------|
| `Awake` | オブジェクト生成直後（1回） | 自身の参照・シングルトン初期化 |
| `Start` | 初回アクティブ化直後（1回） | 他オブジェクトとの相互参照 |
| `Update` | 毎フレーム | 入力処理・移動・アニメーション制御 |

ポイントは **Awake は他コンポーネントより先に走る** 点である。自身のフィールド初期化は `Awake`、他オブジェクトへの参照取得は `Start` と役割を分けると、初期化順序のバグを防げる。

```csharp
public class PlayerController : MonoBehaviour
{
    Rigidbody rb;
    GameManager gm;

    void Awake()
    {
        // 自身のコンポーネント取得は Awake で
        rb = GetComponent<Rigidbody>();
    }

    void Start()
    {
        // 他オブジェクトへの参照は Start で
        gm = FindObjectOfType<GameManager>();
    }

    void Update()
    {
        float h = Input.GetAxis("Horizontal");
        rb.AddForce(Vector3.right * h * 10f);
    }
}
```

:::message alert
`Start` は1回しか呼ばれない。オブジェクトを `SetActive(false)` → `SetActive(true)` で再利用する場合、再初期化が必要なら `OnEnable` を使うこと。
:::

カメラ追従は `LateUpdate`、Rigidbody操作は `FixedUpdate` に書くのが定石である。

## クラス設計の基本 -- 継承・インターフェイス・ポリモーフィズム

共通処理をコピペで量産するのではなく、**継承**と**インターフェイス**で設計する。

### 継承とポリモーフィズム

親クラスに共通ロジックを持たせ、子クラスで振る舞いを上書き（`override`）するのがポリモーフィズムの基本形である。

```csharp
public abstract class EnemyBase : MonoBehaviour
{
    public int hp;

    // 子クラスに攻撃の実装を強制する
    public abstract void Attack();

    public void TakeDamage(int damage)
    {
        hp -= damage;
        if (hp <= 0) Destroy(gameObject);
    }
}

public class Slime : EnemyBase
{
    public override void Attack()
    {
        Debug.Log("スライムの体当たり!");
    }
}

public class Dragon : EnemyBase
{
    public override void Attack()
    {
        Debug.Log("ドラゴンのブレス!");
    }
}
```

`EnemyBase` 型の変数でどの敵でも扱えるため、管理が統一的に書ける。

### インターフェイス -- 「何ができるか」の契約

継承が「何であるか（is-a）」を表すのに対し、インターフェイスは「何ができるか」を表す契約である。C#は単一継承だが、インターフェイスは複数実装できる。

```csharp
public interface IDamageable
{
    void TakeDamage(int amount);
}

public interface IInteractable
{
    void Interact();
}

// プレイヤーは「ダメージを受けられる」かつ「インタラクトできる」
public class Player : MonoBehaviour, IDamageable, IInteractable
{
    public void TakeDamage(int amount) { /* HP減少処理 */ }
    public void Interact() { /* 調べる処理 */ }
}
```

命名規則として `I` + 形容詞（`IDamageable`, `IMovable`）を使うと、「このオブジェクトは何ができるか」がコードだけで伝わる。

## モダンC#構文 -- switch式・Null-conditional・ラムダ式・デリゲート

Unity 2021 LTS以降はC# 9相当が使える。冗長なコードを削減する4つの構文を紹介する。

### switch式（C# 8.0〜）

switch式なら値を直接返せるため、条件分岐がコンパクトになる。

```csharp
string rank = score switch
{
    >= 90 => "S",
    >= 70 => "A",
    >= 50 => "B",
    _     => "C"
};
```

タプルパターンと組み合わせれば、複数条件の同時判定も一箇所にまとめられる。

```csharp
string action = (hp, state) switch
{
    (<= 0, _)       => "戦闘不能",
    (_, "Guard")     => "防御中",
    (>= 50, "Rage") => "猛攻撃",
    _                => "通常攻撃"
};
```

### Null-conditional演算子（?.）

`?.` を使うと、対象が null の場合は何も実行せずスキップしてくれる。

```csharp
// 従来の冗長な書き方
if (player != null) player.Move();

// Null-conditional でワンライナー
player?.Move();

// 連鎖アクセスにも対応
int? score = manager?.currentPlayer?.Score;

// Null合体演算子 (??) と組み合わせてデフォルト値を設定
string name = player?.Name ?? "Unknown";
```

:::message alert
UnityEngine.Object は `==` 演算子をオーバーロードしており、Destroy済みオブジェクトを `null` と判定する独自仕様がある。`?.` はC#標準の null判定を使うため、Destroy済みオブジェクトに対しては意図通りに動作しない場合がある。MonoBehaviour参照には従来の `if (obj != null)` との使い分けが必要である。
:::

### デリゲートとイベント

デリゲートは「メソッドを変数に格納し、後から呼び出す仕組み」である。UIボタンの `onClick` やカスタムイベントの根幹を支えている。

```csharp
public class EventManager : MonoBehaviour
{
    // Action<T> は .NET標準のデリゲート型
    public static event System.Action<int> OnScoreChanged;

    public static void AddScore(int point)
    {
        OnScoreChanged?.Invoke(point);
    }
}

// 別スクリプトで購読
public class ScoreUI : MonoBehaviour
{
    void OnEnable()  => EventManager.OnScoreChanged += UpdateText;
    void OnDisable() => EventManager.OnScoreChanged -= UpdateText;

    void UpdateText(int score) => GetComponent<Text>().text = $"Score: {score}";
}
```

`+=` で登録、`-=` で解除というパターンを覚えておけば、スクリプト間の疎結合な通信が実現できる。

### ラムダ式

ラムダ式は「名前のない短い関数」をその場で書ける構文である。デリゲートやLINQと組み合わせて使う場面が多い。

```csharp
// ボタンイベントにラムダ式で登録
button.onClick.AddListener(() => Debug.Log("Clicked!"));

// リストから条件に合う要素を抽出
var aliveEnemies = enemies.Where(e => e.hp > 0).ToList();
```

1〜3行で収まる処理はラムダ式、それ以上はメソッドとして切り出す、という使い分けが可読性を保つコツである。

## まとめ -- 次のステップへ

本記事で扱ったトピックを振り返る。

| カテゴリ | キーワード | 一言ポイント |
|---------|----------|------------|
| ライフサイクル | Awake / Start / Update | 自身初期化 → 相互参照 → 毎フレーム処理 |
| クラス設計 | 継承 / インターフェイス | is-a は継承、can-do はインターフェイス |
| モダン構文 | switch式 / ?. / デリゲート / ラムダ | 冗長なコードを削減し意図を明確に |

これらはどれも「知っているかどうか」でコードの品質が変わる基礎知識である。次のステップとしては以下のテーマが有効だろう。

- **非同期処理**: `async/await` と UniTask
- **設計パターン**: Singleton、Observer、State
- **ScriptableObject**: データ駆動設計

基礎を固めたうえで設計パターンに踏み込むと、チーム開発でも通用するコードが書けるようになる。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
