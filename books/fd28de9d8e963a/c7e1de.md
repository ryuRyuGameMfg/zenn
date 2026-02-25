---
title: "DAY2 ハンズオン | 初めてのスクリプトをUnityで動かす"
free: false
---

# Unityでつくる

## C#スクリプトのファイルを作成

1. プロジェクトビューの`+`をクリック
2. `Scripting` / `MonoBehaviour Script`をクリック
3. 任意のプログラム名`Test`を命名
4. プログラムを`ダブルクリック`または、右クリックから`Open`を選択して、エディタで開くことができます。

![](https://storage.googleapis.com/zenn-user-upload/854dd48a6ab6-20241128.gif)

::: message alert
同じ名前のプログラムが存在する場合、エラーが発生します。既存のプログラムを削除し、新たに作成し直すことをお勧めします。
:::

::: message
エディタとは、コードを編集するためのアプリケーションです。Unityには一般的に推奨されるエディタが同梱されていますが、インストールされていない場合は別途インストールが必要です。

下記の参考リンクから適切なエディタを選び、インストールしてください。なお、テキストエディタでもプログラムの記述は可能ですが、効率が低下するため専用のエディタを使用することをお勧めします。
:::

:::details エディタのインストール方法
定番エディタ「[VsCode](https://zenn.dev/tmb/articles/1444e0a85543e5)」

https://zenn.dev/tmb/articles/1444e0a85543e5
  
最新AIエディタ「[Cursor](https://zenn.dev/wappaboy/articles/cursor-unity)」

https://zenn.dev/wappaboy/articles/cursor-unity

::: message
本記事はCursorを利用しております。
:::

## C#スクリプトの記述

FPSゲームに必要な基本クラスとして、**`PlayerController`** クラスを作成・記述し、`PLAYER`にアタッチして、`Debug.Log`を確認してみましょう。

::: message
本講座では、`Scripts`フォルダを作成し、その中に`C#スクリプト`のデータを管理します。
:::

![](https://storage.googleapis.com/zenn-user-upload/6ac98f0d16e3-20241201.gif)

:::details アタッチについて
**Unityで「アタッチ」とは、スクリプトやコンポーネントを特定のゲームオブジェクトに追加して、そのオブジェクトの動作や機能を制御することを指します**。アタッチを行うことで、オブジェクトに独自の振る舞いを設定したり、機能を拡張したりできます。

### アタッチの方法
1.	ゲームオブジェクトを選択
シーンビューまたはヒエラルキーウィンドウで、スクリプトを追加したいゲームオブジェクトを選択します。
2.	スクリプトをドラッグ＆ドロップ
プロジェクトビューで作成済みのスクリプトを選択し、ゲームオブジェクトにドラッグ＆ドロップします。
3.	インスペクタウィンドウから追加
•	ゲームオブジェクトを選択した状態でインスペクタウィンドウを開きます。
•	「Add Component」ボタンをクリックします。
•	スクリプト名を検索し、該当のスクリプトを選択して追加します。

::: message
**スクリプトをアタッチする目的**
スクリプトをゲームオブジェクトにアタッチすることで、そのオブジェクトに特定の動作（例: プレイヤーの移動や敵の攻撃パターン）を実装できます。
:::

```diff csharp:PlayerController
using UnityEngine;

public class PlayerController : MonoBehaviour
{
    // 移動速度
    public float moveSpeed = 5f;

    // 初期設定
    void Start()
    {
        Debug.Log("PlayerControllerが開始されました");
    }

    // 毎フレームごとの更新
    void Update()
    {
        MovePlayer();
    }

    // プレイヤーの移動処理
    void MovePlayer()
    {
        Debug.Log("速度" + moveSpeed + "で移動中");
    }
}
```
::: details C#スクリプト解説
> 1行目 : `using UnityEngine;`  
> Unityエンジンの機能を使うための宣言です。

> 3行目 : `public class PlayerController : MonoBehaviour`  
> MonoBehaviourクラスを継承したPlayerControllerクラスを定義します。

> 5行目 : `public float moveSpeed = 5f;`  
> プレイヤーの移動速度を設定する変数です。

> 8行目 : `void Start()`  
> Unityの開始時に一度だけ呼ばれる初期設定用のメソッドです。

> 10行目 : `Debug.Log("PlayerControllerが開始されました");`  
> 初期設定が行われたことをデバッグログに表示します。

> 13行目 : `void Update()`  
> 毎フレーム呼ばれる更新処理用のメソッドです。

> 15行目 : `MovePlayer();`  
> プレイヤーの移動処理を行うメソッドを呼び出します。

> 18行目 : `void MovePlayer()`  
> プレイヤーの移動処理を行うメソッドを定義します。

> 20行目 : `Debug.Log("速度 + moveSpeed + で移動中");`  
> 現在の移動処理と移動速度をデバッグログに表示します。
---
>上記のプログラムを実行すると、
>ゲーム開始時に1回以下のログが表示されます。
>`PlayerControllerが開始されました`
>また、ゲーム開始後、毎フレーム以下のログが表示され続けます。
>`速度5で移動中`
:::

# Unityで動かす

**1.再生ボタンをクリック**

**2.コンソールビューでログが流れることを確認**

![](https://storage.googleapis.com/zenn-user-upload/2ba518ca1efb-20241201.gif)
