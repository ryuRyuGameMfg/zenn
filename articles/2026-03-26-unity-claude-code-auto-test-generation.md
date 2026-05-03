---
title: "Unity × Claude Code で自動テスト生成を実装する方法"
emoji: "🧪"
type: "tech"
topics: ["unity", "claudecode", "csharp", "test", "ai"]
published: true
---

Unity プロジェクトでテストを書こうとするたびに、同じ壁にぶつかる。対象クラスのメソッドを一つひとつ確認して、境界値を洗い出して、AAA パターン（Arrange-Act-Assert）に沿ってコードを組む。作業自体は理解しているが、手が動くまでに時間がかかる。

実際に私が担当したゲームプロジェクトでは、`PlayerHealthController` のような基本クラスですら「後でテスト書こう」と後回しにしていた。そこで Claude Code をテスト生成に組み込んだところ、テストコードを書き始めるまでのハードルが大きく下がった。この記事では、その具体的な方法を紹介する。

## Claude Code でテストを生成する基本フロー

Claude Code は CLAUDE.md にルールを記述しておくことで、プロジェクト固有のコーディング規約をエージェントに事前共有できる。テスト生成においても、この仕組みを使って生成品質を安定させている。

### CLAUDE.md にテスト生成ルールを書く

プロジェクトルートの `CLAUDE.md` に以下のようなセクションを追加する。

```markdown
## テスト生成ルール

- Unity Test Framework (NUnit) を使用する
- テストクラスは `Tests/Editor/` または `Tests/Runtime/` に配置する
- テストメソッドは Arrange-Act-Assert パターンで記述する
- メソッド名は `[テスト対象メソッド名]_[条件]_[期待結果]` の形式にする
- `[UnityTest]` は非同期処理のみ使用し、同期処理は `[Test]` を使う
- モックが必要な場合は NSubstitute を使用する
```

このルールを書いておくことで、Claude Code がテストを生成するたびに命名規則や構成が統一される。チームメンバーが追加でテストを依頼しても、同じフォーマットで出力される。

### Claude Code へのプロンプトの渡し方

Claude Code のチャットまたはターミナルから、対象ファイルを指定して依頼する。重要なのは **対象クラスのファイルパスを明示すること**。ファイルパスを指定すると Claude Code がコードを読み込んだ上でテストを生成するため、クラスの実装に沿った具体的なテストが得られる。

```
@Assets/Scripts/Player/PlayerHealthController.cs のNUnitテストを生成してください。
CLAUDE.md のテスト生成ルールに従い、全パブリックメソッドを対象にしてください。
```

## 実装手順

### 前提環境

- Unity 2022.3 以降
- Unity Test Framework パッケージ導入済み（Package Manager から `com.unity.test-framework` を追加）
- NSubstitute 導入済み（モックを使う場合）

### 対象クラスの例

まず、テスト対象となるクラスを用意する。

```csharp
// Assets/Scripts/Player/PlayerHealthController.cs
using UnityEngine;

public class PlayerHealthController : MonoBehaviour
{
    private int _maxHealth;
    private int _currentHealth;

    public int CurrentHealth => _currentHealth;
    public bool IsAlive => _currentHealth > 0;

    public void Initialize(int maxHealth)
    {
        if (maxHealth <= 0)
            throw new System.ArgumentException("maxHealth must be greater than 0.");

        _maxHealth = maxHealth;
        _currentHealth = maxHealth;
    }

    public void TakeDamage(int damage)
    {
        if (damage < 0)
            throw new System.ArgumentException("damage must be 0 or greater.");

        _currentHealth = Mathf.Max(0, _currentHealth - damage);
    }

    public void Heal(int amount)
    {
        if (amount < 0)
            throw new System.ArgumentException("amount must be 0 or greater.");

        _currentHealth = Mathf.Min(_maxHealth, _currentHealth + amount);
    }
}
```

### 生成されたテストコードの例

上記クラスに対して Claude Code が生成したテストコードを以下に示す。私が手を加えた箇所はほぼなく、命名規則と AAA パターンが CLAUDE.md の指示通りに反映されていた。

```csharp
// Assets/Tests/Runtime/Player/PlayerHealthControllerTests.cs
using NUnit.Framework;
using UnityEngine;

public class PlayerHealthControllerTests
{
    private PlayerHealthController _controller;

    [SetUp]
    public void SetUp()
    {
        var go = new GameObject();
        _controller = go.AddComponent<PlayerHealthController>();
    }

    [TearDown]
    public void TearDown()
    {
        Object.DestroyImmediate(_controller.gameObject);
    }

    // Initialize
    [Test]
    public void Initialize_ValidMaxHealth_SetsCurrentHealthToMax()
    {
        // Arrange
        const int maxHealth = 100;

        // Act
        _controller.Initialize(maxHealth);

        // Assert
        Assert.AreEqual(maxHealth, _controller.CurrentHealth);
    }

    [Test]
    public void Initialize_ZeroOrNegativeMaxHealth_ThrowsArgumentException()
    {
        Assert.Throws<System.ArgumentException>(() => _controller.Initialize(0));
        Assert.Throws<System.ArgumentException>(() => _controller.Initialize(-1));
    }

    // TakeDamage
    [Test]
    public void TakeDamage_NormalDamage_ReducesCurrentHealth()
    {
        // Arrange
        _controller.Initialize(100);

        // Act
        _controller.TakeDamage(30);

        // Assert
        Assert.AreEqual(70, _controller.CurrentHealth);
    }

    [Test]
    public void TakeDamage_DamageExceedsHealth_SetsCurrentHealthToZero()
    {
        // Arrange
        _controller.Initialize(50);

        // Act
        _controller.TakeDamage(999);

        // Assert
        Assert.AreEqual(0, _controller.CurrentHealth);
        Assert.IsFalse(_controller.IsAlive);
    }

    [Test]
    public void TakeDamage_NegativeDamage_ThrowsArgumentException()
    {
        _controller.Initialize(100);
        Assert.Throws<System.ArgumentException>(() => _controller.TakeDamage(-1));
    }

    // Heal
    [Test]
    public void Heal_NormalAmount_IncreasesCurrentHealth()
    {
        // Arrange
        _controller.Initialize(100);
        _controller.TakeDamage(40);

        // Act
        _controller.Heal(20);

        // Assert
        Assert.AreEqual(80, _controller.CurrentHealth);
    }

    [Test]
    public void Heal_AmountExceedsMaxHealth_ClampsToMaxHealth()
    {
        // Arrange
        _controller.Initialize(100);
        _controller.TakeDamage(10);

        // Act
        _controller.Heal(999);

        // Assert
        Assert.AreEqual(100, _controller.CurrentHealth);
    }
}
```

### テストの実行確認

Unity エディタのメニューから `Window > General > Test Runner` を開き、`Run All` をクリックする。全テストがグリーンになれば正常に動作している。

## 実践的なプロンプトテンプレート集

実際に使っているプロンプトをそのまま紹介する。コピーして使えるように汎用的な形にしている。

### 境界値テスト生成プロンプト

```
@[対象ファイルパス] の [メソッド名] メソッドに対して境界値テストを生成してください。
- 引数の最小値・最大値・その前後の値をテストケースに含めること
- 無効な入力（負の値、null、空文字など）も必ずテストすること
- NUnit の [TestCase] 属性を使ってパラメータ化すること
```

### モックを使ったテスト生成

```
@[対象ファイルパス] のテストを生成してください。
- [インターフェース名] への依存をモック化すること
- NSubstitute を使用すること
- モックの呼び出し回数や引数の検証も含めること
```

### エッジケース洗い出しプロンプト

```
@[対象ファイルパス] を読んで、テストすべきエッジケースを列挙してください。
コードは書かず、まずケース一覧をMarkdownリストで出力してください。
確認後にテストコードを生成します。
```

エッジケースを先に列挙させる手順が特に効果的だった。一度にテストコードを生成させると見落としが起きやすいが、ケース確認を挟むことで抜け漏れをレビューできる。

## まとめ

Claude Code をテスト生成に導入してから、テストコードを書き始めるまでの時間が体感で 70% 以上短縮された。特に効果があったのは以下の点だ。

- CLAUDE.md にルールを書くことで、複数ファイルにわたって命名規則と構造が統一される
- エッジケースの洗い出しを Claude Code に任せることで、自分では気づかなかったケースが見つかる
- プロンプトテンプレートを用意しておくことで、チームメンバーでも再現性高く使える

注意点として、生成されたテストコードは必ず実行確認が必要だ。型名のタイポや存在しないメソッドへの参照など、コンパイルエラーが出ることがある。また、テストの内容がビジネスロジックとして正しいかどうかは人間がレビューする必要がある。

**生成は Claude Code に任せ、判断は人間がする**、この分担が自動テスト生成を実用レベルで使い続けるコツだと感じている。
