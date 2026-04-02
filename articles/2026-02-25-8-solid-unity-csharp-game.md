---
title: "【8原則】SOLID実践で目指すUnity C#堅牢ゲームアーキテクチャ"
emoji: "🐙"
type: "tech"
topics: ["csharp","unity"]
published: true
---

## [](#%E3%80%908%E5%8E%9F%E5%89%87%E3%80%91solid%E5%AE%9F%E8%B7%B5%E3%81%A7%E7%9B%AE%E6%8C%87%E3%81%99unity-c%23%E5%A0%85%E7%89%A2%E3%82%B2%E3%83%BC%E3%83%A0%E3%82%A2%E3%83%BC%E3%82%AD%E3%83%86%E3%82%AF%E3%83%81%E3%83%A3)【8原則】SOLID実践で目指すUnity C#堅牢ゲームアーキテクチャ

Unityでのゲーム開発において、堅牢でメンテナンス性の高いアーキテクチャを構築することは非常に重要です。本記事では、SOLIDの原則を実践しながら、Unity C#での堅牢なゲームアーキテクチャを目指す方法について詳しく解説します。初心者から中級者まで、具体的なコード例や図解を交えつつ、実践的なアプローチを紹介します。

## [](#solid%E5%8E%9F%E5%89%87%E3%81%A8%E3%81%AF)SOLID原則とは

SOLIDは、オブジェクト指向設計の5つの基本原則を表す頭字語です。これらの原則を遵守することで、コードの可読性、再利用性、拡張性が向上し、バグの発生を減少させることができます。以下にSOLIDの各原則を簡潔に説明します。

### [](#%E5%8D%98%E4%B8%80%E8%B2%AC%E4%BB%BB%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88single-responsibility-principle%2C-srp%EF%BC%89)単一責任の原則（Single Responsibility Principle, SRP）

クラスは**単一の責任**を持つべきであり、その責任を完全にカプセル化する必要があります。

### [](#%E3%82%AA%E3%83%BC%E3%83%97%E3%83%B3%E3%83%BB%E3%82%AF%E3%83%AD%E3%83%BC%E3%82%BA%E3%83%89%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88open%2Fclosed-principle%2C-ocp%EF%BC%89)オープン・クローズドの原則（Open/Closed Principle, OCP）

ソフトウェアのエンティティは**拡張に対しては開かれており、修正に対しては閉じている**べきです。

### [](#%E3%83%AA%E3%82%B9%E3%82%B3%E3%83%95%E3%81%AE%E7%BD%AE%E6%8F%9B%E5%8E%9F%E5%89%87%EF%BC%88liskov-substitution-principle%2C-lsp%EF%BC%89)リスコフの置換原則（Liskov Substitution Principle, LSP）

サブタイプは**親タイプと置換可能**であるべきです。

### [](#%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%BC%E3%83%95%E3%82%A7%E3%83%BC%E3%82%B9%E5%88%86%E9%9B%A2%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88interface-segregation-principle%2C-isp%EF%BC%89)インターフェース分離の原則（Interface Segregation Principle, ISP）

クライアントは**使用しないメソッドへの依存を強制されるべきでない**です。

### [](#%E4%BE%9D%E5%AD%98%E6%80%A7%E9%80%86%E8%BB%A2%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88dependency-inversion-principle%2C-dip%EF%BC%89)依存性逆転の原則（Dependency Inversion Principle, DIP）

**抽象**に依存すべきであって、**具体的な実装**に依存してはならないです。

!

SOLID原則はもともと5つですが、本記事では拡張として**8原則**に基づいた包括的なアプローチを提案します。

## [](#unity%E3%81%AB%E3%81%8A%E3%81%91%E3%82%8Bsolid%E5%8E%9F%E5%89%87%E3%81%AE%E5%AE%9F%E8%B7%B5)UnityにおけるSOLID原則の実践

UnityでSOLID原則を実践することで、プロジェクトのスケーラビリティと保守性を大幅に向上させることが可能です。以下では、各原則を具体的にどのようにUnity C#で実装するかを説明します。

### [](#%E5%8D%98%E4%B8%80%E8%B2%AC%E4%BB%BB%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88srp%EF%BC%89%E3%81%AE%E5%AE%9F%E8%A3%85)単一責任の原則（SRP）の実装

単一責任の原則を遵守することで、各クラスが特定の機能に専念し、変更が容易になります。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B)具体例

PlayerMovement.cs

```
using UnityEngine;

public class PlayerMovement : MonoBehaviour
{
    public float speed = 5f;

    void Update()
    {
        float moveHorizontal = Input.GetAxis("Horizontal");
        float moveVertical = Input.GetAxis("Vertical");
        Vector3 movement = new Vector3(moveHorizontal, 0.0f, moveVertical);
        transform.Translate(movement * speed * Time.deltaTime);
    }
}
```

PlayerHealth.cs

```
using UnityEngine;

public class PlayerHealth : MonoBehaviour
{
    public int maxHealth = 100;
    private int currentHealth;

    void Start()
    {
        currentHealth = maxHealth;
    }

    public void TakeDamage(int amount)
    {
        currentHealth -= amount;
        if(currentHealth <= 0)
        {
            Die();
        }
    }

    void Die()
    {
        // プレイヤーの死亡処理
    }
}
```

上記の例では、`PlayerMovement`クラスがプレイヤーの移動に責任を持ち、`PlayerHealth`クラスがプレイヤーの健康管理に責任を持っています。これにより、各クラスの役割が明確になり、変更や拡張が容易になります。

### [](#%E3%82%AA%E3%83%BC%E3%83%97%E3%83%B3%E3%83%BB%E3%82%AF%E3%83%AD%E3%83%BC%E3%82%BA%E3%83%89%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88ocp%EF%BC%89%E3%81%AE%E5%AE%9F%E8%A3%85)オープン・クローズドの原則（OCP）の実装

オープン・クローズドの原則を守ることで、新しい機能の追加が既存のコードに影響を与えずに行えます。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B-1)具体例

IWeapon.cs

```
public interface IWeapon
{
    void Attack();
}
```

Sword.cs

```
public class Sword : IWeapon
{
    public void Attack()
    {
        Debug.Log("Swinging sword!");
    }
}
```

Bow.cs

```
public class Bow : IWeapon
{
    public void Attack()
    {
        Debug.Log("Shooting an arrow!");
    }
}
```

PlayerAttack.cs

```
using UnityEngine;

public class PlayerAttack : MonoBehaviour
{
    private IWeapon weapon;

    void Start()
    {
        weapon = new Sword(); // 依存性注入を利用することも可能
    }

    void Update()
    {
        if(Input.GetButtonDown("Fire1"))
        {
            weapon.Attack();
        }
    }

    public void SetWeapon(IWeapon newWeapon)
    {
        weapon = newWeapon;
    }
}
```

新しい武器を追加する場合、`IWeapon`インターフェースを実装した新しいクラスを作成するだけで、`PlayerAttack`クラスを変更する必要がありません。

### [](#%E3%83%AA%E3%82%B9%E3%82%B3%E3%83%95%E3%81%AE%E7%BD%AE%E6%8F%9B%E5%8E%9F%E5%89%87%EF%BC%88lsp%EF%BC%89%E3%81%AE%E5%AE%9F%E8%A3%85)リスコフの置換原則（LSP）の実装

リスコフの置換原則を遵守することで、サブクラスが親クラスと同等に振る舞い、予期しない動作を避けることができます。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B-2)具体例

Enemy.cs

```
public abstract class Enemy
{
    public abstract void Move();
}
```

FlyingEnemy.cs

```
public class FlyingEnemy : Enemy
{
    public override void Move()
    {
        Debug.Log("Flying enemy is moving.");
    }
}
```

GroundEnemy.cs

```
public class GroundEnemy : Enemy
{
    public override void Move()
    {
        Debug.Log("Ground enemy is moving.");
    }
}
```

`Enemy`クラスを継承した`FlyingEnemy`と`GroundEnemy`は、`Move`メソッドを適切に実装しており、親クラス`Enemy`の代わりに使用しても問題ありません。

### [](#%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%BC%E3%83%95%E3%82%A7%E3%83%BC%E3%82%B9%E5%88%86%E9%9B%A2%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88isp%EF%BC%89%E3%81%AE%E5%AE%9F%E8%A3%85)インターフェース分離の原則（ISP）の実装

インターフェース分離の原則を守ることで、クラスが不要なメソッドの実装を強制されることを防ぎます。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B-3)具体例

IMovable.cs

```
public interface IMovable
{
    void Move();
}
```

IAttackable.cs

```
public interface IAttackable
{
    void Attack();
}
```

Player.cs

```
public class Player : MonoBehaviour, IMovable, IAttackable
{
    public void Move()
    {
        // プレイヤーの移動処理
    }

    public void Attack()
    {
        // プレイヤーの攻撃処理
    }
}
```

Mine.cs

```
public class Mine : MonoBehaviour, IMovable
{
    public void Move()
    {
        // 地雷の移動処理
    }
}
```

地雷は攻撃機能を持たないため、`IAttackable`インターフェースを実装する必要がありません。これにより、クラスが不要なメソッドを実装することを避けられます。

### [](#%E4%BE%9D%E5%AD%98%E6%80%A7%E9%80%86%E8%BB%A2%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%88dip%EF%BC%89%E3%81%AE%E5%AE%9F%E8%A3%85)依存性逆転の原則（DIP）の実装

依存性逆転の原則を遵守することで、コードの柔軟性とテスト容易性が向上します。具体的には、高レベルモジュールが低レベルモジュールに依存せず、両者が抽象に依存します。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B-4)具体例

ILogger.cs

```
public interface ILogger
{
    void Log(string message);
}
```

ConsoleLogger.cs

```
public class ConsoleLogger : ILogger
{
    public void Log(string message)
    {
        Debug.Log(message);
    }
}
```

FileLogger.cs

```
public class FileLogger : ILogger
{
    public void Log(string message)
    {
        // ファイルにログを記録する処理
    }
}
```

GameManager.cs

```
using UnityEngine;

public class GameManager : MonoBehaviour
{
    private ILogger logger;

    void Start()
    {
        logger = new ConsoleLogger(); // 依存性注入を利用することも可能
        logger.Log("Game Started");
    }
}
```

`GameManager`は具体的なロガーに依存せず、`ILogger`という抽象に依存しています。これにより、ロギングの方法を簡単に変更することができます。

:::alert  
依存性逆転の原則を実践する際には、\*\*依存性注入（Dependency Injection）\*\*を用いるとより効果的です。  
:::

## [](#solid%E5%8E%9F%E5%89%87%E3%81%AE8%E3%81%A4%E7%9B%AE%E3%81%AE%E5%8E%9F%E5%89%87%EF%BC%9Adry%E3%81%A8yagni%E3%81%AE%E8%BF%BD%E5%8A%A0)SOLID原則の8つ目の原則：DRYとYAGNIの追加

SOLIDは本来5つの原則ですが、さらに開発効率と品質を高めるために\*\*DRY（Don't Repeat Yourself）**と**YAGNI（You Aren't Gonna Need It）\*\*の原則を追加で考慮します。

### [](#dry%EF%BC%88don't-repeat-yourself%EF%BC%89)DRY（Don't Repeat Yourself）

同じコードやロジックを繰り返さないようにすることで、バグの発生を防ぎ、コードのメンテナンス性を向上させます。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B-5)具体例

共通の機能を持つクラスやメソッドを抽象化し、再利用可能なコンポーネントとして実装します。

Singleton.cs

```
public class Singleton<T> : MonoBehaviour where T : MonoBehaviour
{
    private static T instance;

    public static T Instance
    {
        get
        {
            if(instance == null)
            {
                instance = FindObjectOfType<T>();
                if(instance == null)
                {
                    GameObject obj = new GameObject();
                    obj.name = typeof(T).Name;
                    instance = obj.AddComponent<T>();
                }
            }
            return instance;
        }
    }
}
```

GameManager.cs

```
public class GameManager : Singleton<GameManager>
{
    public int score;

    void Start()
    {
        score = 0;
    }
}
```

### [](#yagni%EF%BC%88you-aren't-gonna-need-it%EF%BC%89)YAGNI（You Aren't Gonna Need It）

必要になるまで機能を実装しないことで、過剰なコードを避け、開発の効率を高めます。

#### [](#%E5%85%B7%E4%BD%93%E4%BE%8B-6)具体例

機能追加の前に、本当に必要かどうかを検討し、不要な抽象化や機能実装を避けます。

```
// 不必要な機能を追加しない例
public class Enemy : MonoBehaviour
{
    public void Move()
    {
        // 移動処理
    }

    public void Attack()
    {
        // 攻撃処理
    }

    // 現在は攻撃機能が不要であれば、実装しない
}
```

## [](#%E3%83%86%E3%83%BC%E3%83%96%E3%83%AB%E3%81%A7%E8%A6%8B%E3%82%8Bsolid%E5%8E%9F%E5%89%87%E3%81%AE%E6%AF%94%E8%BC%83)テーブルで見るSOLID原則の比較

原則名

説明

メリット

単一責任の原則（SRP）

クラスは単一の責任を持つべき

高い可読性と保守性

オープン・クローズドの原則（OCP）

エンティティは拡張に対して開かれ、修正に対して閉じられている

柔軟な拡張と安定した既存機能

リスコフの置換原則（LSP）

サブクラスは親クラスと置換可能であるべき

安全なポリモーフィズムの実現

インターフェース分離の原則（ISP）

クライアントは使用しないメソッドに依存するべきでない

不要な依存の排除とインターフェースの明確化

依存性逆転の原則（DIP）

抽象に依存し、具体に依存しない

柔軟でテスト可能なコードの実現

DRY（Don't Repeat Yourself）

コードの重複を避ける

バグの減少とコードのメンテナンス性向上

YAGNI（You Aren't Gonna Need It）

必要になるまで機能を実装しない

開発効率の向上と過剰な機能の回避

## [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

SOLIDの原則をUnity C#で実践することで、堅牢で拡張性の高いゲームアーキテクチャを構築することが可能です。各原則を理解し、具体的なコード例とともに適用することで、開発効率とコード品質を大幅に向上させることができます。ぜひ本記事を参考に、あなたのUnityプロジェクトにSOLID原則を取り入れてみてください。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
