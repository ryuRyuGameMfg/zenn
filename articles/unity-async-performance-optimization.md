---
title: "Unity非同期処理とパフォーマンス最適化 - コルーチン/async/DOTS/ObjectPool"
emoji: "⚡"
type: "tech"
topics: ["unity", "csharp", "performance", "async", "gamedev"]
published: true
published_at: 2026-04-05 18:00
---

## はじめに - フレームレートを守る設計思想

Unityでゲームを開発する際、最も重要な制約の一つが「フレームレート」である。60FPSを維持するためには、1フレームあたり約16.6msの処理時間しか許されない。この時間を超えた瞬間、プレイヤーはカクつきを体感し、ゲーム体験は損なわれる。

本記事では、Unityにおけるパフォーマンス最適化の主要テクニックを横断的に解説する。コルーチン、async/await、ObjectPool、TaskQueue、DOTSの5つの手法を「いつ、何に使うか」という判断基準とともに整理した。個々のテクニックを深掘りするのではなく、全体像を俯瞰して最適な選択ができるようになることを目指す。

:::message
本記事は各テクニックの入門的な位置づけである。実務で導入する際は、各手法の詳細記事やUnity公式ドキュメントも併せて参照してほしい。
:::

## コルーチン vs async/await - 使い分けの判断基準

Unityにおける非同期処理の代表格が、コルーチンとasync/awaitである。どちらも「待つ」処理を書けるが、設計思想と得意領域が異なる。

### コルーチン - Unityネイティブの時間制御

コルーチンは`IEnumerator`を返すメソッドで、`yield return`を用いて処理を一時停止・再開できる。Unityのライフサイクルに統合されており、フレーム単位の制御が直感的に書ける。

```csharp
private IEnumerator SpawnEnemies(float interval, int count)
{
    for (int i = 0; i < count; i++)
    {
        Instantiate(enemyPrefab, GetSpawnPosition(), Quaternion.identity);
        yield return new WaitForSeconds(interval);
    }
}
```

`WaitForSeconds`、`WaitUntil`、`WaitForFixedUpdate`など、Unity固有の待機命令が充実しており、演出やスポーン制御に向いている。

### async/await - C#標準の非同期パターン

`Task`ベースの非同期処理は、C#の言語機能として標準サポートされている。例外処理の`try-catch`が使える点、`CancellationToken`によるキャンセル制御が容易な点が大きな利点である。

```csharp
private async Task LoadAssetsAsync(CancellationToken token)
{
    try
    {
        Task<Texture2D> texTask = LoadTextureAsync("hero.png");
        Task<AudioClip> audioTask = LoadAudioAsync("bgm.wav");
        await Task.WhenAll(texTask, audioTask);
        Debug.Log("全アセット読み込み完了");
    }
    catch (OperationCanceledException)
    {
        Debug.Log("読み込みがキャンセルされた");
    }
}
```

`Task.WhenAll`による並列待機、`Task.Delay`によるミリ秒単位の待機など、コルーチンでは煩雑になる処理をシンプルに書ける。

### 判断基準

| 観点 | コルーチン | async/await |
|------|-----------|-------------|
| フレーム同期の制御 | 得意（WaitForEndOfFrame等） | 不向き |
| 例外ハンドリング | try-catch不可 | try-catch可能 |
| キャンセル処理 | StopCoroutineで停止 | CancellationTokenで制御 |
| 並列実行 | 複数StartCoroutine | Task.WhenAllで一括管理 |
| 学習コスト | 低い | やや高い |
| 推奨用途 | 演出・タイミング制御 | I/O・通信・重い計算 |

:::message
実務では「フレーム同期が必要ならコルーチン、それ以外はasync/await」という判断が基本線になる。UniTaskライブラリを導入すると、コルーチンの使い勝手とasync/awaitの堅牢性を両立できるため、中〜大規模プロジェクトでは検討する価値がある。
:::

## ObjectPool - GCを抑える弾・エフェクト管理

弾幕シューティングのように大量のオブジェクトを生成・破棄するゲームでは、`Instantiate`と`Destroy`の繰り返しがGC（ガベージコレクション）スパイクの主因となる。ObjectPoolは「事前に生成して使い回す」ことで、この問題を根本的に解決する。

### 基本実装

```csharp
public class BulletPool : MonoBehaviour
{
    [SerializeField] private GameObject bulletPrefab;
    [SerializeField] private int initialSize = 50;
    private Queue<GameObject> pool;

    private void Awake()
    {
        pool = new Queue<GameObject>();
        for (int i = 0; i < initialSize; i++)
        {
            var bullet = Instantiate(bulletPrefab);
            bullet.SetActive(false);
            pool.Enqueue(bullet);
        }
    }

    public GameObject Get()
    {
        if (pool.Count > 0)
        {
            var bullet = pool.Dequeue();
            bullet.SetActive(true);
            return bullet;
        }
        // プール枯渇時は新規生成
        return Instantiate(bulletPrefab);
    }

    public void Return(GameObject bullet)
    {
        bullet.SetActive(false);
        pool.Enqueue(bullet);
    }
}
```

### イベント駆動による自動返却

上記の基本実装では、外部から明示的に`Return`を呼ぶ必要がある。イベント駆動型にすれば、弾が自律的にプールへ返却される。

```csharp
public class Bullet : MonoBehaviour
{
    public event Action<Bullet> OnExpired;
    [SerializeField] private float lifetime = 2f;

    private void OnEnable() => Invoke(nameof(Expire), lifetime);
    private void OnDisable() => CancelInvoke();

    private void Expire() => OnExpired?.Invoke(this);
}
```

プール管理側で`OnExpired`を購読し、`SetActive(false)`で回収する設計にすると、弾の種類が増えてもプール管理コードの変更が不要になる。

### 最適化のポイント

- **初期プールサイズ**: ステージごとの最大同時弾数をProfilerで計測し、その値の1.2倍程度を確保する
- **動的拡張**: プール枯渇時の新規生成はログ出力して、初期サイズの見直し材料にする
- **再初期化**: `OnEnable`で位置・速度・状態を必ずリセットする。前回の残留データがバグの温床になる

## Task Queue - 重い処理を分散実行する

経路探索、地形生成、AI計算など、1フレームに収まらない重い処理を一度に実行するとフレーム落ちが発生する。TaskQueueは、これらの処理をキューに入れて1フレームに1件ずつ（または時間予算内で）実行することで、フレームレートを維持する仕組みである。

```csharp
public class FrameBudgetTaskQueue : MonoBehaviour
{
    private Queue<Action> tasks = new Queue<Action>();
    private const float FRAME_BUDGET_MS = 4f; // 1フレームあたりの処理予算

    public void Enqueue(Action task) => tasks.Enqueue(task);

    private void Update()
    {
        float startTime = Time.realtimeSinceStartup * 1000f;
        while (tasks.Count > 0)
        {
            if ((Time.realtimeSinceStartup * 1000f - startTime) > FRAME_BUDGET_MS)
                break; // 時間予算を超えたら次フレームへ持ち越し
            tasks.Dequeue().Invoke();
        }
    }
}
```

このパターンのポイントは「時間予算（フレームバジェット）」の概念である。16.6msのうち描画やPhysicsが消費する分を差し引いた残り時間を、自前のタスク実行に割り当てる。上記の例では4msを予算としているが、この値はProfilerの実測値に基づいて調整する必要がある。

:::message
優先度付きキュー（`SortedDictionary<int, Queue<Action>>`）にすれば、プレイヤー近傍のAI計算を優先的に処理するといった制御も可能になる。スレッドセーフにする場合は`lock`による排他制御を追加する。
:::

## DOTS概要 - 大量オブジェクト処理の切り札

数千〜数万のオブジェクトを同時に処理する必要がある場合、従来のMonoBehaviourベースの設計では限界がある。Unity DOTSは、データ指向設計によってこの壁を突破するための技術スタックである。

### 3つの柱

1. **ECS（Entity Component System）**: データとロジックを分離し、メモリ上に連続配置することでキャッシュ効率を最大化する
2. **Job System**: マルチスレッドによる並列処理を安全に実装できる仕組みを提供する
3. **Burst Compiler**: C#コードをSIMD命令を含むネイティブコードに変換し、計算速度を数十倍に高速化する

### 実装例 - 並列処理ジョブ

```csharp
[BurstCompile]
public struct MoveJob : IJobParallelFor
{
    public NativeArray<float3> positions;
    [ReadOnly] public NativeArray<float3> velocities;
    public float deltaTime;

    public void Execute(int index)
    {
        positions[index] += velocities[index] * deltaTime;
    }
}
```

このジョブは全エンティティの位置更新を並列実行する。Burst Compilerによって最適化されたネイティブコードが生成され、通常のC#コードと比較して10〜50倍の速度向上が見込める。

### DOTS導入の判断基準

DOTSは強力だが、学習コストが高く、既存のアセットやプラグインとの互換性に制約がある。以下の条件を満たす場合に導入を検討すべきである。

- 同種のオブジェクトが1000体以上同時に存在する
- MonoBehaviourベースで既にProfilerが赤い（フレーム落ちが常態化）
- チームにDOTSの経験者がいる、または学習に投資できる期間がある

## まとめ - パフォーマンスチューニングの優先順位

パフォーマンス最適化は「効果が大きく、導入コストが低いもの」から着手するのが鉄則である。以下に推奨する優先順位を示す。

| 優先度 | テクニック | 効果 | 導入コスト | 対象シーン |
|--------|-----------|------|-----------|-----------|
| 1 | ObjectPool | GCスパイク排除 | 低 | 弾・エフェクト・敵の頻繁な生成破棄 |
| 2 | コルーチン | フレーム分散 | 低 | 演出・スポーン・タイミング制御 |
| 3 | TaskQueue | 重い処理の分散 | 中 | AI・経路探索・地形生成 |
| 4 | async/await | I/O効率化 | 中 | アセット読み込み・通信・ファイルI/O |
| 5 | DOTS | 大量オブジェクト並列処理 | 高 | 数千体以上の同種オブジェクト処理 |

まずはProfilerで実測し、ボトルネックを特定してから最適な手法を選択する。「推測するな、計測せよ」はゲーム開発においても不変の原則である。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
