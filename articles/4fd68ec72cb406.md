---
title: "【純粋なロジック設計】Unity C#で実践する副作用のないプログラミング"
emoji: "✨"
type: "tech"
topics: ["csharp","unity"]
published: true
---

# [](#%E3%80%90%E7%B4%94%E7%B2%8B%E3%81%AA%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E8%A8%AD%E8%A8%88%E3%80%91unity-c%23%E3%81%A7%E5%AE%9F%E8%B7%B5%E3%81%99%E3%82%8B%E5%89%AF%E4%BD%9C%E7%94%A8%E3%81%AE%E3%81%AA%E3%81%84%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0)【純粋なロジック設計】Unity C#で実践する副作用のないプログラミング

Unityを使用したゲーム開発において、コードの品質とメンテナンス性はプロジェクトの成功に直結します。特に、副作用のない純粋なロジック設計は、バグの発生を抑え、チーム開発の効率を高めるために重要です。本記事では、Unity C#で副作用のないプログラミングを実践する方法について詳しく解説します。具体的なコード例や設計パターンを交え、あなたのプロジェクトに即活用できる知識を提供します。

## [](#%E7%B4%94%E7%B2%8B%E9%96%A2%E6%95%B0%E3%81%A8%E5%89%AF%E4%BD%9C%E7%94%A8%E3%81%AE%E9%87%8D%E8%A6%81%E6%80%A7)純粋関数と副作用の重要性

### [](#%E7%B4%94%E7%B2%8B%E9%96%A2%E6%95%B0%E3%81%A8%E3%81%AF%EF%BC%9F)純粋関数とは？

純粋関数とは、**同じ入力に対して常に同じ出力を返し、副作用がない関数**を指します。副作用とは、関数が外部の状態を変更したり、外部からの入力を操作したりすることを指します。純粋関数を使用することで、コードの予測可能性が向上し、テストが容易になります。

### [](#%E5%89%AF%E4%BD%9C%E7%94%A8%E3%81%8C%E3%82%82%E3%81%9F%E3%82%89%E3%81%99%E5%95%8F%E9%A1%8C%E7%82%B9)副作用がもたらす問題点

副作用が多いコードは以下のような問題を引き起こします：

-   **デバッグが困難**：状態の変化が予測しにくくなり、バグの原因追及が難しくなります。
-   **テストが複雑化**：外部依存が増えるため、単体テストが困難になります。
-   **再利用性の低下**：特定のコンテキストに依存するため、関数の再利用が難しくなります。

!

副作用の管理は、特に大規模なプロジェクトではコードの品質を維持するために不可欠です。純粋関数の導入は、これらの問題を解決する強力な手段となります。

## [](#unity%E3%81%AB%E3%81%8A%E3%81%91%E3%82%8B%E7%B4%94%E7%B2%8B%E3%81%AA%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E8%A8%AD%E8%A8%88%E3%81%AE%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88)Unityにおける純粋なロジック設計のメリット

### [](#%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E4%BA%88%E6%B8%AC%E5%8F%AF%E8%83%BD%E6%80%A7%E5%90%91%E4%B8%8A)コードの予測可能性向上

純粋関数を使用することで、関数の出力が入力に完全に依存するため、コードの挙動が予測しやすくなります。これにより、バグの発見と修正が迅速に行えるようになります。

### [](#%E3%83%86%E3%82%B9%E3%83%88%E3%81%AE%E5%AE%B9%E6%98%93%E3%81%95)テストの容易さ

副作用がないため、関数を単体でテストすることが容易です。モックの作成やデータの初期化が不要となり、テストの効率が大幅に向上します。

### [](#%E4%B8%A6%E8%A1%8C%E5%87%A6%E7%90%86%E3%81%AE%E5%AE%89%E5%85%A8%E6%80%A7)並行処理の安全性

副作用がないため、複数のスレッドから同時に関数を呼び出しても状態の競合が発生しません。これにより、マルチスレッド環境での開発が容易になります。

## [](#unity%E3%81%A7%E7%B4%94%E7%B2%8B%E9%96%A2%E6%95%B0%E3%82%92%E5%AE%9F%E8%A3%85%E3%81%99%E3%82%8B%E6%96%B9%E6%B3%95)Unityで純粋関数を実装する方法

### [](#%E5%9F%BA%E6%9C%AC%E7%9A%84%E3%81%AA%E7%B4%94%E7%B2%8B%E9%96%A2%E6%95%B0%E3%81%AE%E4%BE%8B)基本的な純粋関数の例

以下は、純粋関数の基本的な例です。この関数は、渡された数値を2倍にして返しますが、外部の状態を変更することはありません。

DoubleFunction.cs

```
public static class MathUtils
{
    public static int Double(int x)
    {
        return x * 2;
    }
}
```

### [](#%E5%89%AF%E4%BD%9C%E7%94%A8%E3%82%92%E6%8C%81%E3%81%A4%E9%96%A2%E6%95%B0%E3%81%A8%E3%81%AE%E6%AF%94%E8%BC%83)副作用を持つ関数との比較

副作用を持つ関数の例として、ゲームオブジェクトの位置を直接変更する関数を見てみましょう。

MoveObject.cs

```
public class ObjectMover : MonoBehaviour
{
    public void Move(Vector3 newPosition)
    {
        transform.position = newPosition;
    }
}
```

この関数は外部の状態（`transform.position`）を変更するため、副作用があります。これに対して純粋関数を使用する場合、状態の変更は関数外で行います。

### [](#%E7%8A%B6%E6%85%8B%E3%81%AE%E7%AE%A1%E7%90%86)状態の管理

状態を管理するために、**ステートマシンパターン**や**データドリブンアプローチ**を採用することで、副作用を最小限に抑えることが可能です。以下は、ステートマシンを使用してキャラクターの状態を管理する例です。

StateMachine.cs

```
public interface IState
{
    void Enter();
    void Execute();
    void Exit();
}

public class IdleState : IState
{
    public void Enter() { }
    public void Execute() { /* Idle logic */ }
    public void Exit() { }
}

public class StateMachine
{
    private IState currentState;

    public void ChangeState(IState newState)
    {
        currentState?.Exit();
        currentState = newState;
        currentState.Enter();
    }

    public void Update()
    {
        currentState?.Execute();
    }
}
```

## [](#%E9%96%A2%E6%95%B0%E5%9E%8B%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%AE%E5%B0%8E%E5%85%A5)関数型プログラミングの導入

### [](#%E9%AB%98%E9%9A%8E%E9%96%A2%E6%95%B0%E3%81%AE%E6%B4%BB%E7%94%A8)高階関数の活用

高階関数とは、他の関数を引数に取ったり、返り値として返したりする関数のことです。これにより、コードの再利用性が高まり、ロジックの分離が容易になります。

HigherOrderFunction.cs

```
public static class FunctionalUtils
{
    public static Func<T, TResult> Compose<T, TIntermediate, TResult>(
        Func<T, TIntermediate> first,
        Func<TIntermediate, TResult> second)
    {
        return x => second(first(x));
    }
}
```

### [](#%E3%83%AA%E3%83%B3%E3%82%B1%E3%83%BC%E3%82%B8%E3%81%AE%E6%B4%BB%E7%94%A8)リンケージの活用

リンケージ（関数の合成）は、複雑なロジックを単純な関数の組み合わせとして表現する手法です。これにより、コードの可読性と保守性が向上します。

## [](#%E5%89%AF%E4%BD%9C%E7%94%A8%E3%82%92%E7%AE%A1%E7%90%86%E3%81%99%E3%82%8B%E8%A8%AD%E8%A8%88%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3)副作用を管理する設計パターン

### [](#%E3%82%A4%E3%83%9F%E3%83%A5%E3%83%BC%E3%82%BF%E3%83%96%E3%83%AB%E3%83%87%E3%83%BC%E3%82%BF%E6%A7%8B%E9%80%A0)イミュータブルデータ構造

データ構造をイミュータブル（不変）にすることで、データの予期しない変更を防ぎます。以下は、イミュータブルなデータクラスの例です。

ImmutableData.cs

```
public class PlayerState
{
    public readonly int Health;
    public readonly Vector3 Position;

    public PlayerState(int health, Vector3 position)
    {
        Health = health;
        Position = position;
    }

    public PlayerState WithHealth(int newHealth)
    {
        return new PlayerState(newHealth, Position);
    }

    public PlayerState WithPosition(Vector3 newPosition)
    {
        return new PlayerState(Health, newPosition);
    }
}
```

### [](#di%EF%BC%88%E4%BE%9D%E5%AD%98%E6%80%A7%E6%B3%A8%E5%85%A5%EF%BC%89%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3)DI（依存性注入）パターン

依存性注入を用いることで、クラス間の依存関係を明確にし、副作用を最小限に抑えることができます。

DependencyInjection.cs

```
public interface ILogger
{
    void Log(string message);
}

public class ConsoleLogger : ILogger
{
    public void Log(string message)
    {
        Debug.Log(message);
    }
}

public class GameService
{
    private readonly ILogger logger;

    public GameService(ILogger logger)
    {
        this.logger = logger;
    }

    public void StartGame()
    {
        logger.Log("Game Started");
    }
}
```

## [](#%E3%83%86%E3%82%B9%E3%83%88%E3%81%AE%E5%AE%9F%E8%B7%B5)テストの実践

### [](#%E5%8D%98%E4%BD%93%E3%83%86%E3%82%B9%E3%83%88%E3%81%AE%E9%87%8D%E8%A6%81%E6%80%A7)単体テストの重要性

副作用のない純粋関数は、単体テストの効率を大幅に向上させます。以下は、先ほどの`MathUtils.Double`関数の単体テスト例です。

MathUtilsTests.cs

```
using NUnit.Framework;

public class MathUtilsTests
{
    [Test]
    public void Double_ReturnsCorrectValue()
    {
        int input = 5;
        int expected = 10;
        int result = MathUtils.Double(input);
        Assert.AreEqual(expected, result);
    }
}
```

### [](#%E3%83%86%E3%82%B9%E3%83%88%E9%A7%86%E5%8B%95%E9%96%8B%E7%99%BA%EF%BC%88tdd%EF%BC%89%E3%81%AE%E5%B0%8E%E5%85%A5)テスト駆動開発（TDD）の導入

テスト駆動開発を採用することで、コードの品質を高めつつ、設計時点で副作用を意識したアーキテクチャを構築できます。

## [](#%E5%89%AF%E4%BD%9C%E7%94%A8%E3%81%AE%E3%81%AA%E3%81%84%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%AE%E5%AE%9F%E8%B7%B5%E4%BE%8B)副作用のないプログラミングの実践例

### [](#%E3%82%B2%E3%83%BC%E3%83%A0%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E3%81%AE%E8%A8%AD%E8%A8%88)ゲームロジックの設計

以下は、ゲーム内のスコア管理を純粋関数で実装する例です。

ScoreManager.cs

```
public static class ScoreManager
{
    public static int AddScore(int currentScore, int points)
    {
        return currentScore + points;
    }

    public static int SubtractScore(int currentScore, int points)
    {
        return currentScore - points;
    }
}
```

### [](#%E3%83%87%E3%83%BC%E3%82%BF%E3%83%95%E3%83%AD%E3%83%BC%E3%81%AE%E6%9C%80%E9%81%A9%E5%8C%96)データフローの最適化

データフローを明確にすることで、副作用を管理しやすくなります。以下は、データフローを管理するための例です。

DataFlow.cs

```
public class GameController
{
    private int playerScore = 0;

    public void CollectItem(int points)
    {
        playerScore = ScoreManager.AddScore(playerScore, points);
        UpdateUI(playerScore);
    }

    private void UpdateUI(int score)
    {
        // UIの更新ロジック
    }
}
```

## [](#%E3%83%87%E3%82%B6%E3%82%A4%E3%83%B3%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%AE%E6%B4%BB%E7%94%A8)デザインパターンの活用

### [](#%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%A2%E3%83%BC%E3%82%AD%E3%83%86%E3%82%AF%E3%83%81%E3%83%A3%E3%81%AE%E6%8E%A1%E7%94%A8)クリーンアーキテクチャの採用

クリーンアーキテクチャを採用することで、依存関係を明確にし、副作用を最小限に抑えることができます。以下は、クリーンアーキテクチャの基本構造です。

レイヤー

説明

エンティティ

ビジネスロジックを担う。純粋関数が多く含まれる。

ユースケース

アプリケーションの具体的な動作を管理する。

インターフェース

ユーザーインターフェースやデータベースとのやり取りを管理する。

フレームワーク

外部のライブラリやフレームワークに依存する部分を管理する。

### [](#%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%AE%E5%B0%8E%E5%85%A5)リポジトリパターンの導入

データアクセスをリポジトリパターンで抽象化することで、副作用を管理しやすくなります。

RepositoryPattern.cs

```
public interface IPlayerRepository
{
    PlayerState GetPlayerState();
    void SavePlayerState(PlayerState state);
}

public class PlayerRepository : IPlayerRepository
{
    public PlayerState GetPlayerState()
    {
        // データ取得ロジック
    }

    public void SavePlayerState(PlayerState state)
    {
        // データ保存ロジック
    }
}
```

## [](#%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E3%83%AA%E3%83%95%E3%82%A1%E3%82%AF%E3%82%BF%E3%83%AA%E3%83%B3%E3%82%B0)コードのリファクタリング

### [](#%E4%B8%8D%E7%B4%94%E3%81%AA%E9%96%A2%E6%95%B0%E3%81%AE%E7%B4%94%E7%B2%8B%E5%8C%96)不純な関数の純粋化

既存の副作用を持つ関数を純粋関数にリファクタリングする方法を紹介します。例えば、以下の関数は副作用を持つため、純粋化が必要です。

OriginalFunction.cs

```
public class Enemy
{
    public int Health { get; private set; }

    public void TakeDamage(int damage)
    {
        Health -= damage;
        if (Health <= 0)
        {
            Die();
        }
    }

    private void Die()
    {
        // 死亡処理
    }
}
```

この関数を純粋関数にリファクタリングすると以下のようになります。

RefactoredFunction.cs

```
public static class EnemyUtils
{
    public static EnemyState TakeDamage(EnemyState state, int damage)
    {
        int newHealth = state.Health - damage;
        if (newHealth <= 0)
        {
            // 死亡処理を外部で行う
            return new EnemyState(newHealth, true);
        }
        return new EnemyState(newHealth, state.IsDead);
    }
}

public class EnemyState
{
    public int Health { get; }
    public bool IsDead { get; }

    public EnemyState(int health, bool isDead)
    {
        Health = health;
        IsDead = isDead;
    }
}
```

## [](#%E5%AE%9F%E8%B7%B5%E7%9A%84%E3%81%AA%E8%A8%AD%E8%A8%88%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3)実践的な設計パターン

### [](#mvc%EF%BC%88model-view-controller%EF%BC%89%E3%81%A8%E9%96%A2%E6%95%B0%E5%9E%8B%E3%82%A2%E3%83%97%E3%83%AD%E3%83%BC%E3%83%81%E3%81%AE%E8%9E%8D%E5%90%88)MVC（Model-View-Controller）と関数型アプローチの融合

MVCパターンと関数型アプローチを組み合わせることで、拡張性と保守性を高めることができます。

MVCExample.cs

```
public class PlayerModel
{
    public int Health { get; private set; }

    public void ApplyDamage(int damage)
    {
        Health = MathUtils.Double(damage); // 純粋関数を利用
    }
}

public class PlayerView
{
    public void UpdateHealthDisplay(int health)
    {
        // UI更新ロジック
    }
}

public class PlayerController
{
    private PlayerModel model;
    private PlayerView view;

    public PlayerController(PlayerModel m, PlayerView v)
    {
        model = m;
        view = v;
    }

    public void OnDamageReceived(int damage)
    {
        model.ApplyDamage(damage);
        view.UpdateHealthDisplay(model.Health);
    }
}
```

## [](#%E9%96%8B%E7%99%BA%E3%81%AE%E3%83%99%E3%82%B9%E3%83%88%E3%83%97%E3%83%A9%E3%82%AF%E3%83%86%E3%82%A3%E3%82%B9)開発のベストプラクティス

### [](#%E3%82%B3%E3%83%BC%E3%83%89%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%AE%E9%87%8D%E8%A6%81%E6%80%A7)コードレビューの重要性

コードレビューを通じて、副作用を持つコードが混入していないか確認することが重要です。チーム全体で純粋関数の重要性を共有し、ベストプラクティスを遵守しましょう。

### [](#%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%86%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3)ドキュメンテーション

純粋関数や副作用のない設計に関するドキュメンテーションを整備することで、新しいチームメンバーの理解を助け、プロジェクト全体の品質を向上させます。

## [](#%E5%89%AF%E4%BD%9C%E7%94%A8%E3%81%AE%E3%81%AA%E3%81%84%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%AE%E8%AA%B2%E9%A1%8C%E3%81%A8%E8%A7%A3%E6%B1%BA%E7%AD%96)副作用のないプログラミングの課題と解決策

### [](#%E5%AD%A6%E7%BF%92%E3%82%B3%E3%82%B9%E3%83%88)学習コスト

関数型プログラミングの概念に慣れるまでには時間がかかることがあります。しかし、以下の方法でスムーズに導入できます：

-   **チームでの勉強会**：定期的な勉強会を開催し、知識を共有する。
-   **小さなプロジェクトから始める**：小規模なプロジェクトで試行錯誤し、理解を深める。

### [](#%E3%83%91%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%B3%E3%82%B9)パフォーマンス

純粋関数の多用は、場合によってはパフォーマンスに影響を与えることがあります。しかし、適切な最適化を行うことで、この問題を軽減できます。

!

副作用のないプログラミングは、初期導入時には学習コストや設計の複雑化が伴いますが、長期的にはコードの品質と開発効率の向上に繋がります。継続的な学習と実践が成功の鍵となります。

## [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

純粋なロジック設計をUnity C#で実践することは、コードの品質向上とメンテナンス性の向上に直結します。副作用のないプログラミングを採用することで、バグの発生を抑え、テストの効率を高めることが可能です。関数型プログラミングの概念や設計パターンを活用し、プロジェクトの成功に繋げましょう。

:::details 純粋関数のメリット
純粋関数のメリット

純粋関数を導入することで、コードの可読性と再利用性が向上し、バグの発生を抑えることができます。特に、テストが容易になるため、品質保証が容易になります。
:::

!

副作用のないプログラミングは、初期導入時には若干の学習コストがかかりますが、長期的なプロジェクトの成功には不可欠な要素です。ぜひ、今回紹介した手法を実践してみてください。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
