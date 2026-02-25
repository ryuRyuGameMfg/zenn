---
title: "初心者でも作れる！“使い捨てUnityイベント”で開発効率を爆上げする方法"
emoji: "🎉"
type: "tech"
topics: ["csharp","unity","効率化","イベント駆動"]
published: true
---

Unityでゲームを作っていると、イベントまわりのコードが膨れ上がりがちです。複数のオブジェクト間で「何かが起きたら通知してほしい」という仕組みは便利ですが、管理が難しくなると**メモリリーク**や**コードの混沌化**につながることも…。そこで注目したいのが「使い捨てイベント」というアイデアです。本記事では、初心者でも分かりやすい実装方法からメリット・注意点までを解説し、開発効率を一気に高める秘訣を紹介します。

## [](#%E4%BD%BF%E3%81%84%E6%8D%A8%E3%81%A6%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%81%A8%E3%81%AF%E4%BD%95%E3%81%8B)使い捨てイベントとは何か

### [](#%E4%B8%80%E5%BA%A6%E3%81%8D%E3%82%8A%E3%83%BB%E7%9F%AD%E6%9C%9F%E5%88%A9%E7%94%A8%E3%81%AE%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%82%92%E5%AE%89%E5%85%A8%E3%81%AB%E6%89%B1%E3%81%86)一度きり・短期利用のイベントを安全に扱う

「使い捨てイベント」とは、**ある一定期間だけ有効になり、その後不要になったら速やかに破棄**できる設計のことを指します。Unityのイベントを通常の`AddListener`/`RemoveListener`で管理していると、以下のような悩みが出てくることがあります。

-   イベント登録はしたけれど、どこで解除すればいいか分からない
-   シーン切り替え時にリスナーが残っていて、思わぬ挙動が起きる
-   使わなくなったイベントを放置した結果、メモリリークを引き起こす

こうした問題を“使い捨て”という概念でまとめると、あるタイミングで確実に破棄できる仕組みが生まれ、コード全体がすっきりするわけです。

## [](#%E3%83%A1%E3%83%AA%E3%83%83%E3%83%88%EF%BC%9A%E3%83%A1%E3%83%A2%E3%83%AA%E3%83%AA%E3%83%BC%E3%82%AF%E3%82%92%E9%98%B2%E3%81%90)メリット：メモリリークを防ぐ

### [](#disposable%E5%AE%9F%E8%A3%85%E3%81%AE%E5%BF%9C%E7%94%A8)Disposable実装の応用

C#には`IDisposable`というインターフェースがあり、`Dispose()`メソッドを呼び出すことでリソースを安全に破棄する仕組みがあります。以下のリンクでも、このDisposable実装を使ったイベントのメモリリーク防止方法が紹介されています。  
[https://shikaku-sh.hatenablog.com/entry/c-sharp-prevent-memory-leak-by-disposable](https://shikaku-sh.hatenablog.com/entry/c-sharp-prevent-memory-leak-by-disposable)

記事では、`Subscribe`と`Dispose`を組み合わせた例が解説されており、**イベント購読をスマートに終了する**ことで、不要なリスナーを残さないようにするテクニックが示されています。

## [](#%E5%85%B7%E4%BD%93%E4%BE%8B%EF%BC%9A%E4%BD%BF%E3%81%84%E6%8D%A8%E3%81%A6%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%81%AE%E5%9F%BA%E6%9C%AC%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3)具体例：使い捨てイベントの基本パターン

### [](#%E3%82%B3%E3%83%BC%E3%83%89%E4%BE%8B%EF%BC%88%E7%B0%A1%E6%98%93%E3%82%A4%E3%83%A1%E3%83%BC%E3%82%B8%EF%BC%89)コード例（簡易イメージ）

以下は「イベント購読時に`IDisposable`なオブジェクトを返し、`Dispose()`を呼ぶとイベント解除される」という仕組みを想定したサンプルです。

```
using System;
using UnityEngine;
using UnityEngine.Events;

public class DisposableEvent
{
    private UnityEvent _internalEvent = new UnityEvent();

    public IDisposable Subscribe(Action action)
    {
        UnityAction unityAction = () => action();
        _internalEvent.AddListener(unityAction);

        // 返却用のDisposableを作って管理する
        return new EventHandle(() =>
        {
            _internalEvent.RemoveListener(unityAction);
        });
    }

    public void Invoke()
    {
        _internalEvent.Invoke();
    }

    private class EventHandle : IDisposable
    {
        private Action _onDispose;
        public EventHandle(Action onDispose)
        {
            _onDispose = onDispose;
        }
        public void Dispose()
        {
            _onDispose?.Invoke();
            _onDispose = null;
        }
    }
}
```

1.  `DisposableEvent`は内部で`UnityEvent`を持ち、`Subscribe`メソッドでラムダ式を登録
2.  `Subscribe`は`IDisposable`な`EventHandle`オブジェクトを返し、`Dispose()`を呼ぶとリスナーを削除

こうして、購読と解除を**使い捨て**の形で一対一に結びつけられます。

# [](#%E4%BD%BF%E3%81%84%E6%8D%A8%E3%81%A6%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%C3%97%E3%82%B3%E3%83%AB%E3%83%BC%E3%83%81%E3%83%B3%E3%81%A7%E3%81%95%E3%82%89%E3%81%AB%E5%8A%B9%E7%8E%87up)使い捨てイベント×コルーチンでさらに効率UP

## [](#%E3%82%B3%E3%83%AB%E3%83%BC%E3%83%81%E3%83%B3%E3%81%AE%E3%82%BF%E3%82%A4%E3%83%9F%E3%83%B3%E3%82%B0%E5%88%B6%E5%BE%A1%E3%82%82%E5%AE%89%E5%85%A8%E3%81%AB)コルーチンのタイミング制御も安全に

Unity特有の**コルーチン**を使う場面でも、使い捨てイベントと相性が良いです。例えばコルーチンで一定時間後にイベント発火し、その後自動で`Dispose()`するなどの運用が可能。

より詳しいコルーチンの活用法は下記リンク先でも解説されています。  
[https://zenn.dev/ryuryu\_game/articles/b65109c90933cc](https://zenn.dev/ryuryu_game/articles/b65109c90933cc)

敵の湧き処理やアニメーション演出、UIフェードなど、**短期で使い終わる処理**に対して使い捨てイベントで購読し、処理が終われば安全に破棄すると、イベントリスナーが無駄に残らない環境を作れます。

## [](#%E5%AE%9F%E8%A3%85%E4%BE%8B%EF%BC%88%E3%82%B3%E3%83%AB%E3%83%BC%E3%83%81%E3%83%B3%E3%81%A7%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%82%92%E7%A0%B4%E6%A3%84%E3%81%99%E3%82%8B%EF%BC%89)実装例（コルーチンでイベントを破棄する）

```
public class EventConsumer : MonoBehaviour
{
    [SerializeField] private DisposableEvent someEvent;
    private IDisposable subscription;

    private void Start()
    {
        // イベントを購読
        subscription = someEvent.Subscribe(() => Debug.Log("Event Fired!"));
        // 5秒後にDisposeするコルーチン開始
        StartCoroutine(AutoDisposeEvent(5.0f));
    }

    private IEnumerator AutoDisposeEvent(float delay)
    {
        yield return new WaitForSeconds(delay);
        subscription.Dispose(); // 使い捨てイベントを解除
        Debug.Log("Event disposed.");
    }
}
```

これなら5秒経過したら自動でリスナーを削除し、余計なイベント発火が発生しないようにできます。**タイミングをコルーチンで管理できる**ため、シーン切り替えやステージ終了などにも柔軟に対応可能です。

# [](#observer%E3%83%91%E3%82%BF%E3%83%BC%E3%83%B3%E3%81%A8%E3%81%AE%E7%B5%84%E3%81%BF%E5%90%88%E3%82%8F%E3%81%9B)Observerパターンとの組み合わせ

## [](#unirx%E3%82%84idisposable%E3%81%A7%E3%83%A9%E3%82%AF%E3%81%AB%E5%AE%9F%E8%A3%85)UniRxやIDisposableでラクに実装

使い捨てイベントは、**Observerパターン**と親和性が高いです。たとえばUniRxなどを使えば、イベント購読のたびに`IDisposable`が得られ、破棄タイミングを明確にできる仕組みがあります。  
[https://qiita.com/Cova8bitdot/items/632782ad5264baf6a366](https://qiita.com/Cova8bitdot/items/632782ad5264baf6a366)

\*\*「ラムダ式でサクッと書ける」\*\*ところもメリットで、UniRxの`Subscribe()`と同じ感覚で、自分だけのDisposableイベントを作ることも可能です。

# [](#%E5%AE%9F%E8%A3%85%E6%89%8B%E9%A0%86%E3%81%BE%E3%81%A8%E3%82%81)実装手順まとめ

## [](#1.-disposable%E3%81%AA%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E3%82%AF%E3%83%A9%E3%82%B9%E3%81%AE%E4%BD%9C%E6%88%90)1\. Disposableなイベントクラスの作成

-   `UnityEvent`や`EventHandler`などを内部で保持
-   `Subscribe(Action<T>)` メソッドを用意して、`IDisposable`実装オブジェクトを返す
-   `Dispose()`が呼ばれたらリスナーを削除する仕組みを内包

## [](#2.-%E4%BD%BF%E3%81%84%E3%81%9F%E3%81%84%E5%A0%B4%E6%89%80%E3%81%A7%E8%B3%BC%E8%AA%AD%E3%81%99%E3%82%8B)2\. 使いたい場所で購読する

-   シーン開始時やオブジェクト生成時に`Subscribe`
-   返却される`IDisposable`をフィールドなどで保持

## [](#3.-%E9%81%A9%E5%88%87%E3%81%AA%E3%82%BF%E3%82%A4%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%A7dispose\(\)%E3%82%92%E5%91%BC%E3%81%B6)3\. 適切なタイミングで`Dispose()`を呼ぶ

-   シーン切り替え前にまとめて解除
-   あるいはコルーチンなどで一定時間後に解除
-   イベントが不要になったら確実に破棄してメモリリーク防止

# [](#%E6%B3%A8%E6%84%8F%E7%82%B9%E3%81%A8%E9%81%8B%E7%94%A8%E3%81%AE%E3%82%B3%E3%83%84)注意点と運用のコツ

注意点

内容

対策

適切な`Dispose`呼び出しが必須

使い捨てイベントでも、`Dispose()`を忘れると残り続ける

**実装ルール**をチーム内で徹底。シーン切り替え時やDestroy時に必ず解除

構造が複雑になりすぎないように

Disposableイベントを過剰にネストすると読みづらい

メソッド分割やクラス分割で**可読性を維持**

コルーチンとの連動で予期せぬタイミングがあるかも

WaitForSecondsやシーンロードタイミングとの調整が必要

**時間制御**を設計時に明確化し、テストを十分に行う

UniRxなど外部ライブラリとの競合

既にUniRxを使っているなら二重管理に注意

同じObserverパターンを意識しつつ、**一元管理**できる仕組みに

# [](#%E3%81%BE%E3%81%A8%E3%82%81%EF%BC%9A%E5%88%9D%E5%BF%83%E8%80%85%E3%81%A7%E3%82%82%E6%8C%91%E3%82%81%E3%82%8B%E2%80%9C%E4%BD%BF%E3%81%84%E6%8D%A8%E3%81%A6%E2%80%9D%E3%81%A7%E5%AE%89%E5%85%A8%E3%83%BB%E7%B0%A1%E5%8D%98%E3%81%AA%E3%82%A4%E3%83%99%E3%83%B3%E3%83%88%E7%AE%A1%E7%90%86)まとめ：初心者でも挑める“使い捨て”で安全・簡単なイベント管理

Unityのイベントを使い捨て方式で運用すれば、**メモリリークを防ぎつつ**、余計なリスナーが生き残るトラブルも回避できます。初心者でも理解しやすい形で`IDisposable`を導入してみると、イベント管理が見違えるほどシンプルになるはずです。

-   まずは自作の`DisposableEvent`クラスを用意する
-   `Subscribe`と`Dispose`の仕組みを理解し、必ず解除するルールを作る
-   コルーチンやObserverパターンと組み合わせれば、シーン管理やアニメ演出がさらにラクに

さらに詳しいサンプルや応用を知りたい方は、下記リンクも参考にしてください。

[https://shikaku-sh.hatenablog.com/entry/c-sharp-prevent-memory-leak-by-disposable](https://shikaku-sh.hatenablog.com/entry/c-sharp-prevent-memory-leak-by-disposable)  
[https://qiita.com/Cova8bitdot/items/632782ad5264baf6a366](https://qiita.com/Cova8bitdot/items/632782ad5264baf6a366)

**最後に**、使い捨てイベントは初心者でも「ちょっと試してみよう」と導入しやすいのが魅力です。コードの可読性と堅牢性を同時に上げたいなら、ぜひ「Disposableなイベント」を取り入れてみてください。短期で役目を終える処理を安全に破棄し、開発効率を爆上げしていきましょう。

╭━━━━━━━━━━━━━━━━━━╮  
　まずは、チェック！無料相談も受付中！  
╰━ｖ━━━━━━━━━━━━━━━━╯  
▼ AIキャラクターで接客・配信を自動化 ▼  
[https://coconala.com/services/3327092](https://coconala.com/services/3327092)

ゲーム開発のご相談：  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
