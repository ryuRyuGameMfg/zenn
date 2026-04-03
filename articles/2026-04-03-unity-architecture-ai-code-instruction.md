---
title: "MonoBehaviourベタ書きを卒業したい人へ：AIに設計パターンを指示してUnityコードを整理する方法"
emoji: "🏗️"
type: "tech"
topics: ["Unity", "CSharp", "AI", "設計パターン"]
published: false
---

## はじめに：MonoBehaviourが育ちすぎた問題

最初は数十行だったスクリプトが、気づいたら500行を超えていた。そういう経験はないだろうか。

`PlayerController.cs` に入力処理、アニメーション制御、HP管理、UI更新、サウンド再生まで全部入っている。動いているからいい、と思っていたが、新しい機能を追加するたびにどこに書けばいいか分からなくなり、バグの原因が追えなくなってきた。

そこでAIに丸投げしてみると、さらに混沌とした結果が返ってくる。GPTやClaudeは「既存コードに合わせて実装しました」と言いながら、500行のMonoBehaviourにさらに100行を追加してくる。

この記事は「設計パターンをちゃんと学ぼう」という話ではない。**AIに正確な指示を出すための最低限の語彙を持とう**という話だ。MVP、DI、Service Locator——この3つを「名前と概念だけ」知っていれば、AIが出力するコードの質は劇的に変わる。

---

## 1. なぜAI開発にもアーキテクチャが必要なのか

### ベタ書きをAIに渡すと何が起きるか

実際にやってみた失敗例を共有する。以下のような指示を出した。

> 「このPlayerController.csに敵の検知機能を追加してください」

返ってきたコードには `FindObjectsOfType<Enemy>()` がUpdateの中に書かれていた。毎フレーム全オブジェクトをスキャンする処理だ。コードは動く。しかし500msecのフリーズが発生するようになった。

なぜこうなるのか。AIはコンテキストを与えられると「既存スタイルに合わせて」コードを生成する。ベタ書きのMonoBehaviourを渡せば、ベタ書きで返ってくる。AIに責任はなく、指示の粒度が粗かっただけだ。

### 分離されたコードをAIに渡すと何が起きるか

同じ機能追加を、役割が分離されたコードに対して依頼すると結果が変わる。

> 「EnemyDetectionServiceを新しく作り、PlayerPresenterから呼び出してください。検知ロジックはMonoBehaviourに書かず、純粋なC#クラスとして実装してください」

この指示ならAIは `EnemyDetectionService.cs`（純粋クラス）と `PlayerPresenter.cs`（呼び出し側）を分けて生成してくれる。テストも書きやすく、後から差し替えも効く。

### 設計指示がAIへの入力になる時代

かつては「コードを書いてもらう」ことがAI活用の主軸だった。今は違う。「このアーキテクチャで実装してほしい」という設計指示が入力になっている。コードレビューではなく設計指示——その言語を持っているかどうかが、AIから得られる出力品質を決定する。

---

## 2. 最低限知るべき3つのパターン

### パターン1: MVP（Model-View-Presenter）

**概念：MonoBehaviourをViewに限定する**

MVPは「MonoBehaviourはUI表示と入力受付だけ担当させる」という考え方だ。ゲームのロジック（HP計算、スキルの発動判定など）はPresenterという純粋なC#クラスに移す。

MonoBehaviourをViewに限定することで、Unityのライフサイクルに依存しない部分が増え、AIがテスト可能なコードを生成しやすくなる。

```csharp
// PlayerView.cs - MonoBehaviour（Viewのみ担当）
using UnityEngine;
using UnityEngine.UI;

public class PlayerView : MonoBehaviour
{
    [SerializeField] private Slider hpSlider;
    [SerializeField] private Text hpText;

    private PlayerPresenter _presenter;

    private void Awake()
    {
        var model = new PlayerModel(maxHp: 100);
        _presenter = new PlayerPresenter(model, this);
    }

    private void Update()
    {
        // 入力の受付だけ。判定はPresenterへ
        if (Input.GetButtonDown("Fire1"))
        {
            _presenter.OnAttackInput();
        }
    }

    // PresenterからViewの更新を受け取る
    public void UpdateHpDisplay(int current, int max)
    {
        hpSlider.value = (float)current / max;
        hpText.text = $"{current} / {max}";
    }
}

// PlayerPresenter.cs - 純粋C#クラス（ロジック担当）
public class PlayerPresenter
{
    private readonly PlayerModel _model;
    private readonly PlayerView _view;

    public PlayerPresenter(PlayerModel model, PlayerView view)
    {
        _model = model;
        _view = view;
        _view.UpdateHpDisplay(_model.CurrentHp, _model.MaxHp);
    }

    public void OnAttackInput()
    {
        // ロジックはここで処理。MonoBehaviourに書かない
        _model.ConsumeHp(10);
        _view.UpdateHpDisplay(_model.CurrentHp, _model.MaxHp);
    }
}

// PlayerModel.cs - データのみ
public class PlayerModel
{
    public int MaxHp { get; }
    public int CurrentHp { get; private set; }

    public PlayerModel(int maxHp)
    {
        MaxHp = maxHp;
        CurrentHp = maxHp;
    }

    public void ConsumeHp(int amount) => CurrentHp = Mathf.Max(0, CurrentHp - amount);
}
```

**AIへの指示例（NG/OK比較）**

NG：「PlayerControllerにHP表示の更新を追加して」
→ MonoBehaviourに直接書かれる

OK：「MVP構成で実装してください。PlayerViewはMonoBehaviourとしてUI表示のみ担当、ロジックはPlayerPresenter（純粋C#クラス）に分離してください」

---

### パターン2: 依存性注入（DI）

**概念：依存するクラスをコンストラクタで受け取る**

依存性注入（Dependency Injection）は、クラスが必要とするオブジェクトを自分でnewせず、外から渡してもらう設計だ。

「自分でnewすると何が問題なのか？」——newすると実装に直接依存するため、差し替えが効かなくなる。AIに「テスト可能なコードにして」と指示しても、内部でnewしているコードはテストできない。

```csharp
// IPlayerService.cs - インターフェース（依存を抽象に向ける）
public interface IPlayerService
{
    void TakeDamage(int amount);
    int GetCurrentHp();
}

// PlayerService.cs - 実装クラス（純粋C#）
public class PlayerService : IPlayerService
{
    private int _hp;

    public PlayerService(int initialHp)
    {
        _hp = initialHp;
    }

    public void TakeDamage(int amount)
    {
        _hp = Mathf.Max(0, _hp - amount);
    }

    public int GetCurrentHp() => _hp;
}

// PlayerController.cs - コンストラクタでIPlayerServiceを受け取る
public class PlayerController
{
    private readonly IPlayerService _playerService;

    // 自分でnewせず、外から受け取る
    public PlayerController(IPlayerService playerService)
    {
        _playerService = playerService;
    }

    public void OnHit(int damage)
    {
        _playerService.TakeDamage(damage);
        UnityEngine.Debug.Log($"HP残量: {_playerService.GetCurrentHp()}");
    }
}

// MonoBehaviourの接続点（Bootstrapクラスで組み立てる）
public class GameBootstrap : MonoBehaviour
{
    private void Awake()
    {
        var playerService = new PlayerService(initialHp: 100);
        var playerController = new PlayerController(playerService);
        // 以降はplayerControllerを使って処理を呼ぶ
    }
}
```

**AIへの指示例（NG/OK比較）**

NG：「PlayerServiceをPlayerControllerの中で使えるようにして」
→ `new PlayerService()` がPlayerController内に書かれる

OK：「PlayerControllerはIPlayerServiceインターフェースに依存する設計にしてください。コンストラクタインジェクションで受け取り、PlayerServiceは外部（Bootstrapクラス）で生成して渡す構成にしてください」

---

### パターン3: Service Locator（簡易版）

**概念：グローバルなサービス取得窓口を作る**

VContainerやZenjectを使うほどではないが、シングルトンの乱立も避けたい——そのバランスポイントがService Locatorだ。サービスを一箇所に登録し、必要な側が取りに行く。

MonoBehaviourからGetComponentを多用するよりコード間の結合が下がり、AIが「どこに何があるか」を把握しやすくなる。

```csharp
// ServiceLocator.cs - 純粋C#クラス
using System;
using System.Collections.Generic;

public static class ServiceLocator
{
    private static readonly Dictionary<Type, object> _services = new();

    public static void Register<T>(T service)
    {
        _services[typeof(T)] = service;
    }

    public static T Get<T>()
    {
        if (_services.TryGetValue(typeof(T), out var service))
            return (T)service;

        throw new InvalidOperationException($"Service not registered: {typeof(T).Name}");
    }

    public static void Clear() => _services.Clear();
}

// 登録側（Bootstrapクラス）
public class GameBootstrap : MonoBehaviour
{
    private void Awake()
    {
        ServiceLocator.Register<IPlayerService>(new PlayerService(initialHp: 100));
        ServiceLocator.Register<IAudioService>(new AudioService());
    }

    private void OnDestroy()
    {
        ServiceLocator.Clear();
    }
}

// 利用側（MonoBehaviourから取得）
public class EnemyAI : MonoBehaviour
{
    private IPlayerService _playerService;

    private void Awake()
    {
        _playerService = ServiceLocator.Get<IPlayerService>();
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            _playerService.TakeDamage(20);
        }
    }
}
```

**AIへの指示例（NG/OK比較）**

NG：「EnemyAIからPlayerのHPを削ってください」
→ `FindObjectOfType<PlayerController>()` などで直接参照される

OK：「EnemyAIはServiceLocatorからIPlayerServiceを取得してTakeDamageを呼ぶ設計にしてください。EnemyAIはIPlayerServiceの実装クラスを直接参照しないようにしてください」

---

## 3. 実践：AIへの指示テンプレート

パターンを覚えたら、あとは指示の型を持つだけだ。以下は実際に使っているテンプレートだ。

**テンプレート1: MVPを指定する**
```
MonoBehaviourはViewとして扱い、UI表示と入力受付のみ担当させてください。
ゲームロジックは{クラス名}Presenter（純粋C#クラス）に実装してください。
PresenterはUnityのAPIを直接使用しないようにしてください。
```

**テンプレート2: DIを指定する**
```
{クラス名}は{インターフェース名}に依存する設計にしてください。
コンストラクタインジェクションで受け取り、実装クラスのnewはBootstrapクラスで行ってください。
{クラス名}内で直接newすることは避けてください。
```

**テンプレート3: Service Locatorを指定する**
```
{クラス名}はServiceLocator.Get<{インターフェース名}>()でサービスを取得してください。
Awakeで取得し、フィールドにキャッシュして使用してください。
FindObjectOfTypeやGetComponentで他のMonoBehaviourを取得する実装は避けてください。
```

**NG指示 vs OK指示の比較**

| NG指示 | OK指示 |
|--------|--------|
| 「PlayerにHPを追加して」 | 「PlayerModelにCurrentHpプロパティを追加し、PlayerPresenterがViewに通知する設計にして」 |
| 「サウンドを鳴らす処理を追加して」 | 「IAudioServiceをServiceLocatorから取得してPlaySEを呼ぶ。AudioServiceの実装は直接参照しないで」 |
| 「敵検知を追加して」 | 「EnemyDetectionService（純粋C#クラス）を新規作成し、MonoBehaviourからコンストラクタインジェクションで受け取る形にして」 |

---

## まとめ

この記事で紹介した3パターンは、すべてを理解している必要はない。

- **MVP**：MonoBehaviourをViewに限定する言葉を持つ
- **DI**：コンストラクタで受け取る設計を指定できる
- **Service Locator**：ServiceLocator経由で取得する構成を指定できる

この3つの語彙があるだけで、AIへの指示精度が変わる。完全に理解しなくていい。「チームの共通言語」として使えることが大切だ。

次のステップとして、より本格的なDIフレームワークを使いたい場合はVContainer（軽量）やZenject（多機能）を検討するといい。ただし、まずはこの記事の3パターンをAIへの指示で使い倒してから、その必要性を感じてからで十分だ。

---

*Unity 2022 LTS〜2023 LTS 動作確認済み。コードはプロジェクトに合わせて適宜調整してください。*
