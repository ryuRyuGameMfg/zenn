---
title: "【7ルール】Unity C#による柔軟なロジック分離テクニック"
emoji: "👋"
type: "tech"
topics: ["csharp","unity","コード"]
published: true
---

# [](#unity-c%23%E3%81%AB%E3%82%88%E3%82%8B%E6%9F%94%E8%BB%9F%E3%81%AA%E3%83%AD%E3%82%B8%E3%83%83%E3%82%AF%E5%88%86%E9%9B%A2%E3%83%86%E3%82%AF%E3%83%8B%E3%83%83%E3%82%AF7%E9%81%B8)Unity C#による柔軟なロジック分離テクニック7選

Unityでのゲーム開発において、コードの可読性や保守性を高めるためには、ロジックの分離が不可欠です。適切にロジックを分離することで、開発効率の向上やバグの減少、チーム開発時の協働作業がスムーズになります。

本記事では、Unity C#における柔軟なロジック分離テクニックを7つのルールに分けて解説します。各ルールには具体的な実装例や注意点も含まれているため、初心者から中級者まで幅広く活用できます。

## [](#%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB%E3%83%88%E3%83%B3%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%AE%E9%81%A9%E5%88%87%E3%81%AA%E4%BD%BF%E7%94%A8)シングルトンパターンの適切な使用

### [](#%E3%82%B7%E3%83%B3%E3%82%B0%E3%83%AB%E3%83%88%E3%83%B3%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%A8%E3%81%AF)シングルトンパターンとは

シングルトンパターンは、クラスのインスタンスを1つだけ作成し、グローバルにアクセス可能にするデザインパターンです。Unityでは、ゲーム全体で共有するデータや管理者クラスに適用されることが多いです。

### [](#%E5%AE%9F%E8%A3%85%E4%BE%8B)実装例

Singleton.cs

```
using UnityEngine;

public class Singleton<T> : MonoBehaviour where T : MonoBehaviour
{
    private static T instance;
    private static readonly object lockObject = new object();

    public static T Instance
    {
        get
        {
            if (instance == null)
            {
                lock (lockObject)
                {
                    if (instance == null)
                    {
                        instance = FindObjectOfType<T>();
                        
                        if (instance == null)
                        {
                            GameObject singletonObject = new GameObject(typeof(T).Name);
                            instance = singletonObject.AddComponent<T>();
                        }
                    }
                }
            }
            return instance;
        }
    }

    protected virtual void Awake()
    {
        if (instance == null)
        {
            instance = this as T;
            DontDestroyOnLoad(gameObject);
        }
        else if (instance != this)
        {
            Debug.LogWarning($"Duplicate {typeof(T).Name} instance detected. Destroying duplicate.");
            Destroy(gameObject);
        }
    }

    protected virtual void OnDestroy()
    {
        if (instance == this)
        {
            instance = null;
        }
    }
}
```

### [](#%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95)使用方法

GameManager.cs

```
public class GameManager : Singleton<GameManager>
{
    private int score;

    public int Score => score;

    public void AddScore(int value)
    {
        if (value < 0)
        {
            Debug.LogWarning("Negative score values are not allowed.");
            return;
        }
        
        score += value;
        Debug.Log($"スコア: {score}");
    }

    public void ResetScore()
    {
        score = 0;
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88)メリット・デメリット

**メリット**

-   汎用的にインスタンスを管理できる
-   グローバルアクセスが容易
-   DontDestroyOnLoadで複数シーン間でデータを維持

**デメリット**

-   過度な使用は依存関係を増やし、テストが困難に
-   グローバル状態による予期せぬ副作用
-   マルチスレッド環境での注意が必要

!

シングルトンパターンは適切な場面で使用することが重要です。ゲームマネージャーやサウンドマネージャーなど、確実に1つしか存在しないべきオブジェクトに限定しましょう。過度な利用はコードの柔軟性を損ないます。

## [](#%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%81%AE%E6%B4%BB%E7%94%A8)イベントシステムの活用

### [](#%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%81%A8%E3%81%AF)イベントシステムとは

イベントシステムを活用することで、オブジェクト間の通信を疎結合に保つことができます。これにより、コンポーネント間の依存関係を減らし、コードの再利用性が向上します。

### [](#%E5%AE%9F%E8%A3%85%E4%BE%8B-1)実装例

EventManager.cs

```
using System;
using System.Collections.Generic;
using UnityEngine;

public class EventManager : Singleton<EventManager>
{
    private Dictionary<Type, Delegate> eventDictionary = new Dictionary<Type, Delegate>();

    public void Subscribe<T>(Action<T> listener) where T : struct
    {
        Type eventType = typeof(T);
        
        if (eventDictionary.TryGetValue(eventType, out Delegate existingDelegate))
        {
            eventDictionary[eventType] = Delegate.Combine(existingDelegate, listener);
        }
        else
        {
            eventDictionary[eventType] = listener;
        }
    }

    public void Unsubscribe<T>(Action<T> listener) where T : struct
    {
        Type eventType = typeof(T);
        
        if (eventDictionary.TryGetValue(eventType, out Delegate existingDelegate))
        {
            Delegate newDelegate = Delegate.Remove(existingDelegate, listener);
            
            if (newDelegate == null)
            {
                eventDictionary.Remove(eventType);
            }
            else
            {
                eventDictionary[eventType] = newDelegate;
            }
        }
    }

    public void Publish<T>(T eventData) where T : struct
    {
        Type eventType = typeof(T);
        
        if (eventDictionary.TryGetValue(eventType, out Delegate eventDelegate))
        {
            (eventDelegate as Action<T>)?.Invoke(eventData);
        }
    }

    protected override void OnDestroy()
    {
        base.OnDestroy();
        eventDictionary.Clear();
    }
}
```

### [](#%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%83%87%E3%83%BC%E3%82%BF%E3%81%AE%E5%AE%9A%E7%BE%A9%E3%81%A8%E4%BD%BF%E7%94%A8)イベントデータの定義と使用

GameEvents.cs

```
public struct GameStartEvent
{
    public float startTime;
    public int level;
}

public struct ScoreChangedEvent
{
    public int oldScore;
    public int newScore;
    public int delta;
}

public struct PlayerDeathEvent
{
    public Vector3 position;
    public string causeOfDeath;
}
```

Player.cs

```
using UnityEngine;

public class Player : MonoBehaviour
{
    private void OnEnable()
    {
        EventManager.Instance.Subscribe<GameStartEvent>(OnGameStart);
        EventManager.Instance.Subscribe<ScoreChangedEvent>(OnScoreChanged);
    }

    private void OnDisable()
    {
        if (EventManager.Instance != null)
        {
            EventManager.Instance.Unsubscribe<GameStartEvent>(OnGameStart);
            EventManager.Instance.Unsubscribe<ScoreChangedEvent>(OnScoreChanged);
        }
    }

    private void OnGameStart(GameStartEvent eventData)
    {
        Debug.Log($"ゲームが開始されました！ レベル: {eventData.level}");
    }

    private void OnScoreChanged(ScoreChangedEvent eventData)
    {
        Debug.Log($"スコアが変更: {eventData.oldScore} → {eventData.newScore}");
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88-1)メリット・デメリット

**メリット**

-   コンポーネント間の結びつきを緩められる
-   イベント駆動型の柔軟な設計が可能
-   新しいリスナーの追加が容易

**デメリット**

-   イベントフローの追跡が難しい
-   デバッグ時に実行順序が不明瞭
-   メモリリークのリスク（登録解除忘れ）

!

イベントの登録と解除を確実に行うことで、メモリリークや予期せぬ動作を防げます。OnEnableとOnDisableのペアで管理し、OnDisableではEventManagerのnullチェックを行いましょう。

## [](#%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%BC%E3%83%95%E3%82%A7%E3%83%BC%E3%82%B9%E3%81%AB%E3%82%88%E3%82%8B%E4%BE%9D%E5%AD%98%E6%80%A7%E3%81%AE%E6%B3%A8%E5%85%A5)インターフェースによる依存性の注入

### [](#%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%BC%E3%83%95%E3%82%A7%E3%83%BC%E3%82%B9%E3%81%A8%E3%81%AF)インターフェースとは

インターフェースを使用することで、具体的な実装に依存せずに機能を利用できるようになります。これにより、コンポーネント間の独立性が高まり、テストや拡張が容易になります。

### [](#%E5%AE%9F%E8%A3%85%E4%BE%8B-2)実装例

IDamageable.cs

```
public interface IDamageable
{
    int CurrentHealth { get; }
    int MaxHealth { get; }
    bool IsDead { get; }
    
    void TakeDamage(int amount);
    void Heal(int amount);
}
```

Enemy.cs

```
using UnityEngine;

public class Enemy : MonoBehaviour, IDamageable
{
    [SerializeField] private int maxHealth = 100;
    private int currentHealth;

    public int CurrentHealth => currentHealth;
    public int MaxHealth => maxHealth;
    public bool IsDead => currentHealth <= 0;

    private void Start()
    {
        currentHealth = maxHealth;
    }

    public void TakeDamage(int amount)
    {
        if (IsDead) return;
        
        currentHealth = Mathf.Max(0, currentHealth - amount);
        Debug.Log($"ダメージを受けた。現在の体力: {currentHealth}/{maxHealth}");
        
        if (IsDead)
        {
            Die();
        }
    }

    public void Heal(int amount)
    {
        if (IsDead) return;
        
        currentHealth = Mathf.Min(maxHealth, currentHealth + amount);
        Debug.Log($"回復した。現在の体力: {currentHealth}/{maxHealth}");
    }

    private void Die()
    {
        Debug.Log("敵が倒れた！");
        // 死亡エフェクトやアニメーションをトリガー
        Destroy(gameObject, 1f);
    }
}
```

PlayerAttack.cs

```
using UnityEngine;

public class PlayerAttack : MonoBehaviour
{
    [SerializeField] private int attackDamage = 25;
    [SerializeField] private float attackRange = 2f;
    [SerializeField] private LayerMask damageableLayer;

    public void Attack()
    {
        Collider[] hits = Physics.OverlapSphere(transform.position, attackRange, damageableLayer);
        
        foreach (Collider hit in hits)
        {
            // インターフェースを実装しているコンポーネントを取得
            if (hit.TryGetComponent<IDamageable>(out IDamageable damageable))
            {
                damageable.TakeDamage(attackDamage);
                Debug.Log($"{hit.gameObject.name}に{attackDamage}ダメージを与えた");
            }
        }
    }

    private void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(transform.position, attackRange);
    }
}
```

### [](#%E4%BE%9D%E5%AD%98%E6%80%A7%E6%B3%A8%E5%85%A5%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3)依存性注入パターン

WeaponSystem.cs

```
using UnityEngine;

public class WeaponSystem : MonoBehaviour
{
    private IDamageable target;

    // コンストラクタ注入（MonoBehaviourでは使用不可）
    // プロパティ注入
    public void SetTarget(IDamageable damageable)
    {
        target = damageable;
    }

    // メソッド注入
    public void Attack(IDamageable damageable, int damage)
    {
        damageable?.TakeDamage(damage);
    }

    // 現在のターゲットへの攻撃
    public void AttackCurrentTarget(int damage)
    {
        if (target == null)
        {
            Debug.LogWarning("攻撃対象が設定されていません");
            return;
        }
        
        target.TakeDamage(damage);
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88-2)メリット・デメリット

**メリット**

-   コンポーネントの交換や拡張が容易
-   テスト時にモックを使用しやすい
-   異なる実装を持つオブジェクトを統一的に扱える

**デメリット**

-   インターフェースの設計が不適切だと複雑化
-   小規模プロジェクトでは過剰設計になる可能性
-   Unityエディタでのインスペクタ表示に制限

!

インターフェースを適切に設計しないと、逆にコードが複雑になります。共通の振る舞いを持つオブジェクトグループに対してのみ使用し、適切な抽象化を心がけましょう。

## [](#scriptableobject%E3%82%92%E5%88%A9%E7%94%A8%E3%81%97%E3%81%9F%E3%83%87%E3%83%BC%E3%82%BF%E7%AE%A1%E7%90%86)ScriptableObjectを利用したデータ管理

### [](#scriptableobject%E3%81%A8%E3%81%AF)ScriptableObjectとは

ScriptableObjectは、Unityにおけるデータ管理のための軽量なオブジェクトです。データをアセットとして保存できるため、データ駆動型の開発が可能になります。

### [](#%E5%AE%9F%E8%A3%85%E4%BE%8B-3)実装例

WeaponData.cs

```
using UnityEngine;

[CreateAssetMenu(fileName = "New Weapon", menuName = "Game/Weapon Data")]
public class WeaponData : ScriptableObject
{
    [Header("基本情報")]
    public string weaponName;
    [TextArea(3, 5)]
    public string description;
    
    [Header("性能")]
    public int damage;
    public float range;
    public float attackSpeed;
    
    [Header("ビジュアル")]
    public Sprite icon;
    public GameObject prefab;
    
    [Header("サウンド")]
    public AudioClip attackSound;
    
    // 計算プロパティ
    public float DPS => damage * attackSpeed;
    
    // バリデーション
    private void OnValidate()
    {
        damage = Mathf.Max(0, damage);
        range = Mathf.Max(0f, range);
        attackSpeed = Mathf.Max(0.1f, attackSpeed);
    }
}
```

### [](#scriptableobject%E3%81%AE%E5%88%A9%E7%94%A8%E6%96%B9%E6%B3%95)ScriptableObjectの利用方法

Weapon.cs

```
using UnityEngine;

public class Weapon : MonoBehaviour
{
    [SerializeField] private WeaponData weaponData;
    private float nextAttackTime;

    private void Start()
    {
        if (weaponData == null)
        {
            Debug.LogError("WeaponDataが設定されていません");
            enabled = false;
        }
    }

    public bool CanAttack()
    {
        return Time.time >= nextAttackTime;
    }

    public void Attack()
    {
        if (!CanAttack()) return;
        
        Debug.Log($"{weaponData.weaponName}で攻撃！ ダメージ: {weaponData.damage}");
        
        // 攻撃処理
        PerformAttack();
        
        // 次の攻撃までの時間を設定
        nextAttackTime = Time.time + (1f / weaponData.attackSpeed);
    }

    private void PerformAttack()
    {
        // 攻撃範囲内の敵を検索
        Collider[] hits = Physics.OverlapSphere(
            transform.position, 
            weaponData.range
        );
        
        foreach (Collider hit in hits)
        {
            if (hit.TryGetComponent<IDamageable>(out IDamageable damageable))
            {
                damageable.TakeDamage(weaponData.damage);
            }
        }
        
        // サウンド再生
        if (weaponData.attackSound != null)
        {
            AudioSource.PlayClipAtPoint(
                weaponData.attackSound, 
                transform.position
            );
        }
    }

    // エディタでの可視化
    private void OnDrawGizmosSelected()
    {
        if (weaponData == null) return;
        
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(transform.position, weaponData.range);
    }
}
```

### [](#%E8%A4%87%E6%95%B0%E3%83%87%E3%83%BC%E3%82%BF%E3%81%AE%E7%AE%A1%E7%90%86%E4%BE%8B)複数データの管理例

WeaponDatabase.cs

```
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[CreateAssetMenu(fileName = "Weapon Database", menuName = "Game/Weapon Database")]
public class WeaponDatabase : ScriptableObject
{
    [SerializeField] private List<WeaponData> weapons = new List<WeaponData>();

    public IReadOnlyList<WeaponData> Weapons => weapons;

    public WeaponData GetWeaponByName(string name)
    {
        return weapons.FirstOrDefault(w => w.weaponName == name);
    }

    public List<WeaponData> GetWeaponsByDamageRange(int minDamage, int maxDamage)
    {
        return weapons
            .Where(w => w.damage >= minDamage && w.damage <= maxDamage)
            .ToList();
    }

    // エディタ用のバリデーション
    private void OnValidate()
    {
        // 重複チェック
        var duplicates = weapons
            .GroupBy(w => w.weaponName)
            .Where(g => g.Count() > 1)
            .Select(g => g.Key);
        
        if (duplicates.Any())
        {
            Debug.LogWarning($"重複する武器名: {string.Join(", ", duplicates)}");
        }
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88-3)メリット・デメリット

**メリット**

-   データの再利用性が高い
-   プランナーやデザイナーとの協働が容易
-   ランタイム時のメモリ効率が良い（インスタンス間で共有）
-   バージョン管理が容易

**デメリット**

-   実行時のデータ変更が全インスタンスに影響
-   参照の管理が複雑になる場合がある
-   エディタでの可視化に工夫が必要

!

ScriptableObjectのデータは全インスタンスで共有されます。実行時に変更する必要がある場合は、データのコピーを作成するか、別途インスタンスデータを持つ設計にしましょう。

## [](#mvp%2Fmvvm%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%AE%E5%B0%8E%E5%85%A5)MVP/MVVMパターンの導入

### [](#mvp%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%A8%E3%81%AF)MVPパターンとは

MVP（Model-View-Presenter）パターンは、UIロジックとビジネスロジックを分離するための設計パターンです。ViewはPresenterを通じてModelと通信し、各コンポーネントの責任範囲が明確になります。

### [](#%E5%AE%9F%E8%A3%85%E4%BE%8B-4)実装例

IPlayerView.cs

```
public interface IPlayerView
{
    void UpdateHealthDisplay(int currentHealth, int maxHealth);
    void UpdateScoreDisplay(int score);
    void ShowGameOverScreen();
}
```

PlayerModel.cs

```
using System;

public class PlayerModel
{
    private int health;
    private int maxHealth;
    private int score;

    public int Health 
    { 
        get => health;
        set
        {
            health = value;
            OnHealthChanged?.Invoke(health, maxHealth);
        }
    }

    public int MaxHealth
    {
        get => maxHealth;
        set => maxHealth = value;
    }

    public int Score
    {
        get => score;
        set
        {
            score = value;
            OnScoreChanged?.Invoke(score);
        }
    }

    public bool IsDead => health <= 0;

    public event Action<int, int> OnHealthChanged;
    public event Action<int> OnScoreChanged;
    public event Action OnDeath;

    public PlayerModel(int initialHealth, int initialMaxHealth)
    {
        maxHealth = initialMaxHealth;
        health = initialHealth;
        score = 0;
    }

    public void TakeDamage(int amount)
    {
        Health = Math.Max(0, Health - amount);
        
        if (IsDead)
        {
            OnDeath?.Invoke();
        }
    }

    public void Heal(int amount)
    {
        if (IsDead) return;
        Health = Math.Min(maxHealth, Health + amount);
    }

    public void AddScore(int points)
    {
        Score += points;
    }
}
```

PlayerPresenter.cs

```
using UnityEngine;

public class PlayerPresenter
{
    private readonly IPlayerView view;
    private readonly PlayerModel model;

    public PlayerPresenter(IPlayerView view, PlayerModel model)
    {
        this.view = view;
        this.model = model;

        // Modelのイベントを購読
        model.OnHealthChanged += OnModelHealthChanged;
        model.OnScoreChanged += OnModelScoreChanged;
        model.OnDeath += OnModelDeath;

        // 初期表示を更新
        UpdateView();
    }

    private void OnModelHealthChanged(int currentHealth, int maxHealth)
    {
        view.UpdateHealthDisplay(currentHealth, maxHealth);
    }

    private void OnModelScoreChanged(int score)
    {
        view.UpdateScoreDisplay(score);
    }

    private void OnModelDeath()
    {
        view.ShowGameOverScreen();
    }

    public void TakeDamage(int amount)
    {
        model.TakeDamage(amount);
    }

    public void Heal(int amount)
    {
        model.Heal(amount);
    }

    public void AddScore(int points)
    {
        model.AddScore(points);
    }

    private void UpdateView()
    {
        view.UpdateHealthDisplay(model.Health, model.MaxHealth);
        view.UpdateScoreDisplay(model.Score);
    }

    public void Dispose()
    {
        model.OnHealthChanged -= OnModelHealthChanged;
        model.OnScoreChanged -= OnModelScoreChanged;
        model.OnDeath -= OnModelDeath;
    }
}
```

PlayerUIView.cs

```
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class PlayerUIView : MonoBehaviour, IPlayerView
{
    [Header("UI Elements")]
    [SerializeField] private Slider healthBar;
    [SerializeField] private TextMeshProUGUI healthText;
    [SerializeField] private TextMeshProUGUI scoreText;
    [SerializeField] private GameObject gameOverPanel;

    private PlayerPresenter presenter;

    private void Start()
    {
        // Modelを作成
        PlayerModel model = new PlayerModel(initialHealth: 100, initialMaxHealth: 100);
        
        // Presenterを作成（自身をViewとして渡す）
        presenter = new PlayerPresenter(this, model);
    }

    public void UpdateHealthDisplay(int currentHealth, int maxHealth)
    {
        if (healthBar != null)
        {
            healthBar.maxValue = maxHealth;
            healthBar.value = currentHealth;
        }

        if (healthText != null)
        {
            healthText.text = $"{currentHealth} / {maxHealth}";
        }
    }

    public void UpdateScoreDisplay(int score)
    {
        if (scoreText != null)
        {
            scoreText.text = $"Score: {score}";
        }
    }

    public void ShowGameOverScreen()
    {
        if (gameOverPanel != null)
        {
            gameOverPanel.SetActive(true);
        }
    }

    private void OnDestroy()
    {
        presenter?.Dispose();
    }

    // デバッグ用のテストメソッド（Inspector経由で呼び出し可能）
    public void TestTakeDamage()
    {
        presenter?.TakeDamage(20);
    }

    public void TestAddScore()
    {
        presenter?.AddScore(100);
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88-4)メリット・デメリット

**メリット**

-   UIとロジックの完全な分離で再利用性向上
-   単体テストが容易（ViewをモックUIに置き換え可能）
-   責任範囲が明確で保守性が高い

**デメリット**

-   小規模プロジェクトでは過剰設計
-   初期設定のボイラープレートコードが多い
-   クラス数が増加し、ファイル管理が煩雑

!

MVP/MVVMパターンは中規模以上のプロジェクトや、UI/ビジネスロジックが複雑な場合に効果を発揮します。小規模な画面では、シンプルな設計で十分な場合もあります。

## [](#%E3%83%AC%E3%82%A4%E3%83%A4%E3%83%BC%E3%83%89%E3%82%A2%E3%83%BC%E3%82%AD%E3%83%86%E3%82%AF%E3%83%81%E3%83%A3%E3%81%AE%E6%8E%A1%E7%94%A8)レイヤードアーキテクチャの採用

### [](#%E3%83%AC%E3%82%A4%E3%83%A4%E3%83%BC%E3%83%89%E3%82%A2%E3%83%BC%E3%82%AD%E3%83%86%E3%82%AF%E3%83%81%E3%83%A3%E3%81%A8%E3%81%AF)レイヤードアーキテクチャとは

レイヤードアーキテクチャは、アプリケーションを複数の層（レイヤー）に分割し、それぞれの層が特定の責任を持つ設計手法です。一般的には、プレゼンテーション層、ビジネスロジック層、データアクセス層などに分かれます。

### [](#%E3%83%AC%E3%82%A4%E3%83%A4%E3%83%BC%E6%A7%8B%E6%88%90)レイヤー構成

レイヤー

役割

使用例

プレゼンテーション層

UIの表示と入力受付

UIView, InputController

アプリケーション層

ゲームフロー制御

GameManager, StateManager

ドメイン層

ゲームルールとビジネスロジック

InventorySystem, CombatSystem

インフラ層

データ永続化と外部連携

SaveDataManager, APIClient

### [](#%E5%AE%9F%E8%A3%85%E4%BE%8B-5)実装例

Layers/Domain/IInventoryService.cs

```
// ドメイン層 - インターフェース定義
using System.Collections.Generic;

namespace GameDomain
{
    public interface IInventoryService
    {
        IReadOnlyList<ItemData> GetAllItems();
        bool AddItem(ItemData item);
        bool RemoveItem(string itemId);
        ItemData GetItem(string itemId);
    }
}
```

Layers/Domain/InventoryService.cs

```
// ドメイン層 - ビジネスロジック実装
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace GameDomain
{
    public class InventoryService : IInventoryService
    {
        private readonly List<ItemData> items = new List<ItemData>();
        private readonly int maxCapacity;

        public InventoryService(int capacity = 20)
        {
            maxCapacity = capacity;
        }

        public IReadOnlyList<ItemData> GetAllItems()
        {
            return items.AsReadOnly();
        }

        public bool AddItem(ItemData item)
        {
            if (items.Count >= maxCapacity)
            {
                Debug.LogWarning("インベントリが満杯です");
                return false;
            }

            items.Add(item);
            Debug.Log($"アイテム追加: {item.itemName}");
            return true;
        }

        public bool RemoveItem(string itemId)
        {
            ItemData item = items.FirstOrDefault(i => i.itemId == itemId);
            if (item != null)
            {
                items.Remove(item);
                Debug.Log($"アイテム削除: {item.itemName}");
                return true;
            }
            return false;
        }

        public ItemData GetItem(string itemId)
        {
            return items.FirstOrDefault(i => i.itemId == itemId);
        }
    }
}
```

Layers/Infrastructure/ISaveDataRepository.cs

```
// インフラ層 - データ永続化インターフェース
namespace GameInfrastructure
{
    public interface ISaveDataRepository
    {
        void Save<T>(string key, T data);
        T Load<T>(string key);
        bool Exists(string key);
        void Delete(string key);
    }
}
```

Layers/Infrastructure/JsonSaveDataRepository.cs

```
// インフラ層 - JSON実装
using System.IO;
using UnityEngine;

namespace GameInfrastructure
{
    public class JsonSaveDataRepository : ISaveDataRepository
    {
        private readonly string saveDirectory;

        public JsonSaveDataRepository()
        {
            saveDirectory = Application.persistentDataPath;
        }

        public void Save<T>(string key, T data)
        {
            string path = GetFilePath(key);
            string json = JsonUtility.ToJson(data, true);
            File.WriteAllText(path, json);
            Debug.Log($"データ保存: {path}");
        }

        public T Load<T>(string key)
        {
            string path = GetFilePath(key);
            if (!File.Exists(path))
            {
                Debug.LogWarning($"ファイルが存在しません: {path}");
                return default;
            }

            string json = File.ReadAllText(path);
            return JsonUtility.FromJson<T>(json);
        }

        public bool Exists(string key)
        {
            return File.Exists(GetFilePath(key));
        }

        public void Delete(string key)
        {
            string path = GetFilePath(key);
            if (File.Exists(path))
            {
                File.Delete(path);
                Debug.Log($"データ削除: {path}");
            }
        }

        private string GetFilePath(string key)
        {
            return Path.Combine(saveDirectory, $"{key}.json");
        }
    }
}
```

Layers/Application/GameController.cs

```
// アプリケーション層 - 各層の連携
using UnityEngine;
using GameDomain;
using GameInfrastructure;

namespace GameApplication
{
    public class GameController : MonoBehaviour
    {
        private IInventoryService inventoryService;
        private ISaveDataRepository saveRepository;

        private void Awake()
        {
            // 依存性の注入
            inventoryService = new InventoryService(capacity: 20);
            saveRepository = new JsonSaveDataRepository();
        }

        private void Start()
        {
            LoadGameData();
        }

        public void AddItemToInventory(ItemData item)
        {
            if (inventoryService.AddItem(item))
            {
                SaveGameData();
            }
        }

        private void SaveGameData()
        {
            var saveData = new GameSaveData
            {
                items = inventoryService.GetAllItems() as List<ItemData>
            };
            
            saveRepository.Save("game_data", saveData);
        }

        private void LoadGameData()
        {
            if (saveRepository.Exists("game_data"))
            {
                var saveData = saveRepository.Load<GameSaveData>("game_data");
                // データをInventoryServiceに復元
            }
        }
    }

    [System.Serializable]
    public class GameSaveData
    {
        public List<ItemData> items;
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88-5)メリット・デメリット

**メリット**

-   各レイヤーの責任範囲が明確
-   テストが容易（レイヤーごとに独立してテスト可能）
-   実装の差し替えが容易（インターフェース経由）

**デメリット**

-   レイヤー間の通信オーバーヘッド
-   小規模プロジェクトでは過剰
-   初期構築のコストが高い

!

レイヤードアーキテクチャは、依存関係が一方向（上位レイヤーから下位レイヤーへ）になるよう設計します。下位レイヤーは上位レイヤーを知らないため、再利用性が高まります。

## [](#%E5%8D%98%E4%B8%80%E8%B2%AC%E4%BB%BB%E5%8E%9F%E5%89%87%E3%81%AE%E5%BE%B9%E5%BA%95)単一責任原則の徹底

### [](#%E5%8D%98%E4%B8%80%E8%B2%AC%E4%BB%BB%E5%8E%9F%E5%89%87%E3%81%A8%E3%81%AF)単一責任原則とは

単一責任原則（Single Responsibility Principle, SRP）は、クラスやモジュールが一つの責任のみを持つべきであるという原則です。「変更する理由は一つだけであるべき」と言い換えることもできます。

### [](#%E6%82%AA%E3%81%84%E4%BE%8B%EF%BC%9A%E8%B2%AC%E4%BB%BB%E3%81%8C%E6%B7%B7%E5%9C%A8)悪い例：責任が混在

PlayerController\_Bad.cs

```
// ❌ 移動、攻撃、UI更新が混在
using UnityEngine;
using TMPro;

public class PlayerController_Bad : MonoBehaviour
{
    public float moveSpeed = 5f;
    public int health = 100;
    public int maxHealth = 100;
    public int damage = 25;
    public float attackRange = 2f;
    public TextMeshProUGUI healthText;
    
    private Rigidbody rb;

    private void Start()
    {
        rb = GetComponent<Rigidbody>();
        UpdateHealthUI();
    }

    private void Update()
    {
        // 移動処理
        float moveX = Input.GetAxis("Horizontal");
        float moveZ = Input.GetAxis("Vertical");
        Vector3 movement = new Vector3(moveX, 0, moveZ) * moveSpeed * Time.deltaTime;
        rb.MovePosition(transform.position + movement);

        // 攻撃処理
        if (Input.GetKeyDown(KeyCode.Space))
        {
            Attack();
        }

        // UI更新
        UpdateHealthUI();
    }

    private void Attack()
    {
        Collider[] hits = Physics.OverlapSphere(transform.position, attackRange);
        foreach (Collider hit in hits)
        {
            Enemy enemy = hit.GetComponent<Enemy>();
            if (enemy != null)
            {
                enemy.TakeDamage(damage);
            }
        }
    }

    public void TakeDamage(int amount)
    {
        health -= amount;
        UpdateHealthUI();
        if (health <= 0)
        {
            Die();
        }
    }

    private void UpdateHealthUI()
    {
        healthText.text = $"HP: {health}/{maxHealth}";
    }

    private void Die()
    {
        Debug.Log("プレイヤーが死亡");
        gameObject.SetActive(false);
    }
}
```

### [](#%E8%89%AF%E3%81%84%E4%BE%8B%EF%BC%9A%E8%B2%AC%E4%BB%BB%E3%82%92%E5%88%86%E9%9B%A2)良い例：責任を分離

PlayerMovement.cs

```
// ✅ 移動のみを担当
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class PlayerMovement : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private float rotationSpeed = 10f;
    
    private Rigidbody rb;
    private Vector3 moveDirection;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    private void Update()
    {
        ReadInput();
    }

    private void FixedUpdate()
    {
        Move();
        Rotate();
    }

    private void ReadInput()
    {
        float moveX = Input.GetAxis("Horizontal");
        float moveZ = Input.GetAxis("Vertical");
        moveDirection = new Vector3(moveX, 0, moveZ).normalized;
    }

    private void Move()
    {
        if (moveDirection.magnitude < 0.1f) return;

        Vector3 movement = moveDirection * moveSpeed * Time.fixedDeltaTime;
        rb.MovePosition(rb.position + movement);
    }

    private void Rotate()
    {
        if (moveDirection.magnitude < 0.1f) return;

        Quaternion targetRotation = Quaternion.LookRotation(moveDirection);
        transform.rotation = Quaternion.Slerp(
            transform.rotation, 
            targetRotation, 
            rotationSpeed * Time.fixedDeltaTime
        );
    }

    public void SetMoveSpeed(float speed)
    {
        moveSpeed = Mathf.Max(0f, speed);
    }
}
```

PlayerHealth.cs

```
// ✅ 体力管理のみを担当
using System;
using UnityEngine;

public class PlayerHealth : MonoBehaviour
{
    [SerializeField] private int maxHealth = 100;
    private int currentHealth;

    public int CurrentHealth => currentHealth;
    public int MaxHealth => maxHealth;
    public bool IsDead => currentHealth <= 0;
    public float HealthPercentage => (float)currentHealth / maxHealth;

    public event Action<int, int> OnHealthChanged;
    public event Action OnDeath;

    private void Start()
    {
        currentHealth = maxHealth;
    }

    public void TakeDamage(int amount)
    {
        if (IsDead) return;

        int previousHealth = currentHealth;
        currentHealth = Mathf.Max(0, currentHealth - amount);

        OnHealthChanged?.Invoke(currentHealth, maxHealth);
        Debug.Log($"ダメージ: {amount}, 残りHP: {currentHealth}/{maxHealth}");

        if (IsDead && previousHealth > 0)
        {
            OnDeath?.Invoke();
        }
    }

    public void Heal(int amount)
    {
        if (IsDead) return;

        currentHealth = Mathf.Min(maxHealth, currentHealth + amount);
        OnHealthChanged?.Invoke(currentHealth, maxHealth);
        Debug.Log($"回復: {amount}, 現在HP: {currentHealth}/{maxHealth}");
    }

    public void SetMaxHealth(int newMaxHealth)
    {
        maxHealth = Mathf.Max(1, newMaxHealth);
        currentHealth = Mathf.Min(currentHealth, maxHealth);
        OnHealthChanged?.Invoke(currentHealth, maxHealth);
    }
}
```

PlayerCombat.cs

```
// ✅ 戦闘のみを担当
using UnityEngine;

public class PlayerCombat : MonoBehaviour
{
    [SerializeField] private int attackDamage = 25;
    [SerializeField] private float attackRange = 2f;
    [SerializeField] private float attackCooldown = 0.5f;
    [SerializeField] private LayerMask enemyLayer;
    
    private float lastAttackTime;

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space) && CanAttack())
        {
            Attack();
        }
    }

    private bool CanAttack()
    {
        return Time.time >= lastAttackTime + attackCooldown;
    }

    private void Attack()
    {
        lastAttackTime = Time.time;
        
        Collider[] hits = Physics.OverlapSphere(
            transform.position, 
            attackRange, 
            enemyLayer
        );

        foreach (Collider hit in hits)
        {
            if (hit.TryGetComponent<IDamageable>(out IDamageable damageable))
            {
                damageable.TakeDamage(attackDamage);
                Debug.Log($"{hit.name}に{attackDamage}ダメージ");
            }
        }
    }

    private void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(transform.position, attackRange);
    }
}
```

PlayerHealthUI.cs

```
// ✅ UI表示のみを担当
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class PlayerHealthUI : MonoBehaviour
{
    [SerializeField] private PlayerHealth playerHealth;
    [SerializeField] private Slider healthBar;
    [SerializeField] private TextMeshProUGUI healthText;
    [SerializeField] private Image fillImage;
    [SerializeField] private Gradient healthGradient;

    private void OnEnable()
    {
        if (playerHealth != null)
        {
            playerHealth.OnHealthChanged += UpdateHealthDisplay;
        }
    }

    private void OnDisable()
    {
        if (playerHealth != null)
        {
            playerHealth.OnHealthChanged -= UpdateHealthDisplay;
        }
    }

    private void Start()
    {
        if (playerHealth != null)
        {
            UpdateHealthDisplay(playerHealth.CurrentHealth, playerHealth.MaxHealth);
        }
    }

    private void UpdateHealthDisplay(int currentHealth, int maxHealth)
    {
        if (healthBar != null)
        {
            healthBar.maxValue = maxHealth;
            healthBar.value = currentHealth;
        }

        if (healthText != null)
        {
            healthText.text = $"{currentHealth} / {maxHealth}";
        }

        if (fillImage != null && healthGradient != null)
        {
            float healthPercentage = (float)currentHealth / maxHealth;
            fillImage.color = healthGradient.Evaluate(healthPercentage);
        }
    }
}
```

### [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%E3%83%BB%E3%83%87%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88-6)メリット・デメリット

**メリット**

-   クラスがシンプルで理解しやすい
-   変更の影響範囲が限定される
-   単体テストが容易
-   再利用性が高い

**デメリット**

-   クラス数が増加し、ファイル管理が煩雑
-   コンポーネント間の連携が必要
-   過度な分割は逆効果

!

単一責任原則を守るために、クラスが細分化しすぎないようバランスを取ることが重要です。「この機能が変更される理由」を考え、理由が複数ある場合は分割を検討しましょう。

## [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

Unity C#における柔軟なロジック分離は、プロジェクトの成長とともにコードの保守性や拡張性を高めるために不可欠です。本記事で紹介した7つのテクニックを適用することで、効率的な開発と高品質なゲーム制作が実現できます。

### [](#7%E3%81%A4%E3%81%AE%E3%83%86%E3%82%AF%E3%83%8B%E3%83%83%E3%82%AF%E6%8C%AF%E3%82%8A%E8%BF%94%E3%82%8A)7つのテクニック振り返り

1.  **シングルトンパターン** - グローバル管理が必要なマネージャークラスに適用
2.  **イベントシステム** - コンポーネント間の疎結合な通信を実現
3.  **インターフェース** - 依存性注入でテスト性と拡張性を向上
4.  **ScriptableObject** - データ駆動型開発でデザイナーとの協働を促進
5.  **MVP/MVVMパターン** - UIとロジックの明確な分離
6.  **レイヤードアーキテクチャ** - 責任範囲を階層化して整理
7.  **単一責任原則** - クラスの役割を明確化

### [](#%E9%81%A9%E7%94%A8%E3%81%AE%E6%8C%87%E9%87%9D)適用の指針

-   **小規模プロジェクト**: シングルトン、イベント、単一責任原則から開始
-   **中規模プロジェクト**: インターフェース、ScriptableObjectを追加
-   **大規模プロジェクト**: MVP/MVVM、レイヤードアーキテクチャを導入

これらのテクニックは万能ではありません。プロジェクトの規模、チーム構成、開発期間に応じて適切に選択・組み合わせることが成功の鍵です。

* * *

**ゲーム開発のご相談はこちら**  
Unity開発やAI統合に関するご相談を承っています  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
