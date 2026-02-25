---
title: "Unityで使えるデザインパターン実践 - Factory/Observer/Stateを現場で活かす"
emoji: "🏗"
type: "tech"
topics: ["unity", "csharp", "designpattern", "gamedev", "architecture"]
published: true
published_at: 2026-04-01 18:00
---

## はじめに - なぜデザインパターンが必要か

Unityでゲームを開発していると、プロジェクトの規模拡大に伴い「コードが読めない」「修正が連鎖する」「新機能の追加が怖い」という壁にぶつかる。これはコードの設計が場当たり的になっている兆候である。

デザインパターンは、こうした問題に対する再利用可能な設計の型だ。GoF（Gang of Four）が体系化した23のパターンのうち、Unity開発で特に実用性が高いのが**Factory**、**Observer**、**State**の3つである。

:::message
デザインパターンは万能薬ではない。プロジェクトの規模や要件に応じて「使うべき場面」を見極めることが最も重要である。小規模プロトタイプに無理にパターンを適用すると、かえってコードが冗長になる。
:::

本記事では、この3パターンに加え、Unityならではのデータ管理手法であるScriptableObjectとの組み合わせまでを実践的なコード付きで解説する。

## Factory Pattern - 敵やアイテムの動的生成

### 課題: Instantiateの散在

敵やアイテムの生成処理が各スクリプトに散らばっていると、Prefabの差し替えやパラメータ変更のたびに複数ファイルを修正する羽目になる。生成ロジックの一元管理がFactoryパターンの役割である。

### 実装例

```csharp
// 敵の種別を列挙体で定義
public enum EnemyType { Goblin, Dragon, Slime }

public class EnemyFactory : MonoBehaviour
{
    [SerializeField] private GameObject goblinPrefab;
    [SerializeField] private GameObject dragonPrefab;
    [SerializeField] private GameObject slimePrefab;

    public Enemy Create(EnemyType type, Vector3 position)
    {
        GameObject prefab = type switch
        {
            EnemyType.Goblin => goblinPrefab,
            EnemyType.Dragon => dragonPrefab,
            EnemyType.Slime  => slimePrefab,
            _ => throw new System.ArgumentException($"Unknown type: {type}")
        };

        GameObject obj = Instantiate(prefab, position, Quaternion.identity);
        Enemy enemy = obj.GetComponent<Enemy>();
        enemy.Initialize(type);
        return enemy;
    }
}
```

呼び出し側は `factory.Create(EnemyType.Dragon, spawnPoint)` と書くだけで済む。Prefabの追加時もFactoryクラスだけを修正すればよく、呼び出し側のコードは一切変わらない。

### 使いどころ

- 敵のウェーブスポーン処理
- アイテムドロップのランダム生成
- ステージ上のオブジェクト動的配置

## Observer Pattern - イベント駆動のゲームシステム

### 課題: Update()での監視地獄

「プレイヤーのHPが変化したらUIを更新したい」「敵を倒したらスコアを加算したい」。これらをUpdate()内のif文で毎フレーム監視するのは非効率であり、オブジェクト間の結合度も高くなる。

Observerパターンは、C#のevent/delegateを利用して**発行者（Subject）と購読者（Observer）を疎結合にする**設計である。

### 実装例

```csharp
using System;
using UnityEngine;

public class PlayerHealth : MonoBehaviour
{
    public event Action<int, int> OnHealthChanged; // current, max
    public event Action OnDeath;

    private int currentHP;
    private int maxHP = 100;

    public void TakeDamage(int amount)
    {
        currentHP = Mathf.Max(0, currentHP - amount);
        OnHealthChanged?.Invoke(currentHP, maxHP);

        if (currentHP <= 0)
            OnDeath?.Invoke();
    }
}
```

```csharp
public class HealthBarUI : MonoBehaviour
{
    [SerializeField] private PlayerHealth player;
    [SerializeField] private UnityEngine.UI.Slider slider;

    private void OnEnable()
    {
        player.OnHealthChanged += UpdateBar;
    }

    private void OnDisable()
    {
        player.OnHealthChanged -= UpdateBar;
    }

    private void UpdateBar(int current, int max)
    {
        slider.value = (float)current / max;
    }
}
```

:::message alert
イベントの購読（+=）と解除（-=）は必ずペアで記述すること。OnEnableで登録しOnDisableで解除するのが定石である。解除を忘れるとメモリリークやNullReferenceExceptionの原因になる。
:::

### 使いどころ

- HP/MP変動のUI反映
- スコア加算、実績解除の通知
- サウンド再生のトリガー
- ゲームオーバー判定と画面遷移

## State Pattern - NPCやプレイヤーの状態管理

### 課題: if/switchの肥大化

キャラクターの行動パターンが増えると、Update()内の条件分岐が膨れ上がる。Idle/Walk/Attack/Dieといった状態ごとの処理が混在し、新しい状態を追加するたびにバグのリスクが増大する。

Stateパターンは、各状態を独立したクラスに分離し、状態遷移のルールを明確化する設計である。

### 実装例

```csharp
// ステートの共通インターフェース
public interface IState
{
    void Enter();
    void Update();
    void Exit();
}

// 待機状態
public class IdleState : IState
{
    private readonly NPCController npc;
    public IdleState(NPCController npc) => this.npc = npc;

    public void Enter() => npc.Animator.Play("Idle");
    public void Update()
    {
        if (npc.DetectPlayer())
            npc.ChangeState(npc.ChaseState);
    }
    public void Exit() { }
}

// 追跡状態
public class ChaseState : IState
{
    private readonly NPCController npc;
    public ChaseState(NPCController npc) => this.npc = npc;

    public void Enter() => npc.Animator.Play("Run");
    public void Update()
    {
        npc.MoveToward(npc.PlayerPosition);
        if (npc.IsInAttackRange())
            npc.ChangeState(npc.AttackState);
    }
    public void Exit() { }
}
```

```csharp
public class NPCController : MonoBehaviour
{
    public Animator Animator { get; private set; }
    public IState IdleState { get; private set; }
    public IState ChaseState { get; private set; }
    public IState AttackState { get; private set; }

    private IState currentState;

    private void Start()
    {
        Animator = GetComponent<Animator>();
        IdleState = new IdleState(this);
        ChaseState = new ChaseState(this);
        // AttackStateも同様に初期化
        ChangeState(IdleState);
    }

    private void Update() => currentState?.Update();

    public void ChangeState(IState newState)
    {
        currentState?.Exit();
        currentState = newState;
        currentState.Enter();
    }

    public bool DetectPlayer() { /* 距離判定 */ return false; }
    public bool IsInAttackRange() { /* 範囲判定 */ return false; }
    public Vector3 PlayerPosition => Vector3.zero; // 実装は省略
    public void MoveToward(Vector3 target) { /* 移動処理 */ }
}
```

各状態が独立クラスになることで、新しい状態（Patrol、Fleeなど）の追加が既存コードに影響を与えずに行える。

## ScriptableObject活用 - データとロジックの分離

### Factoryパターンとの組み合わせ

前述のFactoryパターンでは、敵の種別ごとにPrefab参照をハードコードしていた。ScriptableObjectを併用すれば、敵のパラメータをデータアセットとして外部化し、コードを一切変更せずにバランス調整が可能になる。

```csharp
[CreateAssetMenu(menuName = "Game/EnemyData")]
public class EnemyData : ScriptableObject
{
    public string enemyName;
    public int maxHP;
    public int attackPower;
    public float moveSpeed;
    public GameObject prefab;
}
```

```csharp
public class DataDrivenEnemyFactory : MonoBehaviour
{
    [SerializeField] private EnemyData[] enemyDatabase;

    public Enemy Create(string name, Vector3 position)
    {
        EnemyData data = System.Array.Find(enemyDatabase, d => d.enemyName == name);
        if (data == null) return null;

        GameObject obj = Instantiate(data.prefab, position, Quaternion.identity);
        Enemy enemy = obj.GetComponent<Enemy>();
        enemy.Initialize(data);
        return enemy;
    }
}
```

:::message
ScriptableObjectはシーンに依存しない独立アセットである。プログラマーがロジックを書き、デザイナーがInspectorでデータを調整するという役割分担が自然に実現できる。バランス調整のたびにコードを変更する必要がなくなるのが最大の利点だ。
:::

### 活用が効果的な場面

| 用途 | 具体例 |
|------|--------|
| キャラクターステータス | HP、攻撃力、移動速度などの数値テーブル |
| アイテムマスタ | アイテム名、レアリティ、アイコン参照 |
| ウェーブ定義 | 出現敵の種類・数・間隔をアセットで管理 |
| ダイアログデータ | NPCの会話テキストと分岐条件 |

## まとめ - パターンの選び方

3つのパターンとScriptableObjectは、それぞれ異なる課題を解決する。以下の判断基準で選択するとよい。

| パターン | 解決する課題 | 導入の目安 |
|---------|-------------|-----------|
| Factory | 生成処理の散在・重複 | オブジェクト種類が3つ以上 |
| Observer | オブジェクト間の密結合 | 状態変化の通知先が2つ以上 |
| State | 条件分岐の肥大化 | 状態が3つ以上かつ遷移ルールが複雑 |
| ScriptableObject | コードとデータの密結合 | パラメータ調整が頻繁に発生 |

重要なのは、パターンの存在を知った上で**必要になったタイミングで導入する**ことである。最初から全てを適用しようとすると過剰設計になる。まずは小さな機能でパターンを試し、効果を実感してからプロジェクト全体へ展開するのが現実的な進め方である。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
