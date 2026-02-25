---
title: "DAY4 ハンズオン | 銃を撃て！Raycastで射撃システム"
free: false
---

# Unityで事前準備

# アセットのインポート

まずは、銃、エフェクト、サウンドのアセット(ゲーム素材)を`Unityアセットストア`からダウンロードしてきましょう。

## Unityアセットストアとは

Unityのアセットストアは、ゲーム開発に役立つさまざまな素材やツールを購入・ダウンロードできる公式マーケットプレイスです。ここでは、3Dモデル、テクスチャ、スクリプト、音楽、エフェクト、プラグインなど、ゲーム制作に必要なリソースを幅広く提供しています。

## Unityアセットストアを開く

Unityアセットは以下のURLからアクセスできます。ここでは、アセットをダウンロードする手順を紹介していますので、それを参考にして「Gun（銃）」アセットと「エフェクト」アセットをダウンロードしてみましょう。どちらも無料で利用可能です。

https://assetstore.unity.com/

![](https://storage.googleapis.com/zenn-user-upload/6f23056630d8-20241201.gif)

::: message
Unityアセットストアでアセットをダウンロードするには、ログインが必要です。
:::

## Gunアセットのインポート

https://assetstore.unity.com/
※アセットストアで「FPS weapon」と検索してください（例: Free FPS Weapon - MCX など）

![](https://storage.googleapis.com/zenn-user-upload/ed6b25eaf624-20241201.gif)

### マテリアルがピンク色に表示される場合の修正方法

マテリアルがピンク色に表示されてしまうときは、以下の設定で修正できます。

![](https://storage.googleapis.com/zenn-user-upload/12157dcc91a1-20241201.gif)

::: message
このプロジェクトはレンダーパイプラインとしてURP（Universal Render Pipeline）を使用しています。そのため、URPに非対応のマテリアルはピンク色になってしまいます。この問題を解決するには、マテリアルを手動でURP対応に変更する必要があります。
:::

## レンダーパイプラインとは？

レンダーパイプラインは、ゲームや3Dアプリケーションで「画面に何をどのように描くか」を決める仕組みのことです。
Unityでは、複数のレンダーパイプラインを使い分けることができ、作りたいゲームやアプリに合った描画方法を選べます。

## **レンダーパイプラインの種類**

| **種類**                     | **特徴**                                                                                       | **向いている用途**                     |
|-----------------------------|-------------------------------------------------------------------------------------------|--------------------------------------|
| **Built-in Render Pipeline** | Unityの初期から使われている標準的なレンダーパイプライン。簡単に使えるが、細かいカスタマイズは難しい。 | シンプルな2D/3Dゲームやプロトタイプ作成。|
| **Universal Render Pipeline (URP)** | 軽量で高速な描画ができる次世代型。モバイルや中小規模のゲームに最適化されている。                   | モバイルゲームや、幅広いデバイス向けの開発。|
| **High Definition Render Pipeline (HDRP)** | 高品質でリアルなグラフィックを描画可能。ただし処理が重いので、高性能なデバイス専用。                  | リアルな映像表現が必要なPC/コンソールゲーム。|

:::details 詳しい解説
1. Built-in Render Pipeline

	•	簡単に使える： Unityに標準で用意されており、特別な設定は不要。
	•	拡張性が低い： カスタマイズの幅が狭く、高度な描画には向いていない。

2. Universal Render Pipeline (URP)

	•	軽量で高速： モバイルや低スペックなPCでもスムーズに動作。
	•	広い対応範囲： モバイルからコンソールまで幅広いデバイスをサポート。
	•	カスタマイズ可能： シェーダーグラフを使って簡単に見た目を変更できる。

3. High Definition Render Pipeline (HDRP)

	•	高品質なグラフィック： リアルな影や反射、物理ベースのレンダリングが可能。
	•	処理が重い： 高性能なデバイスでないと動作が遅くなる。
	•	リッチな表現： 映像作品や高品質ゲームに最適。
:::

## エフェクトのインポート

https://assetstore.unity.com/
※アセットストアで「particle pack」と検索してください（例: Free Quick Effects Vol. 1 など）

## レイアウトを変更して作業効率アップ

Unityエディタのレイアウトを事前に`2by3`に設定しましょう。このレイアウトでは、シーンビューとゲームビューを同時に表示できるため、作業効率が向上します。

![](https://storage.googleapis.com/zenn-user-upload/93c7843fb109-20241201.gif)

## ゲームビューの解像度を設定

ゲームビューの比率を`1920×1080`の解像度に変更しましょう。開発するデバイスやターゲット環境に合わせた設定を行うことで、本番に近い環境で開発を進めることができます。

![](https://storage.googleapis.com/zenn-user-upload/c8699b97c3c3-20241201.gif)

# Unityでつくる

## プレイヤーに銃を持たせる

**1.	インポートした銃のアセットからプレハブを選び、PLAYERオブジェクトの子オブジェクトであるCameraの子オブジェクトとして配置します。**

**2.	ゲームビューを確認しながら、FPS視点で銃が見えるように、Transformコンポーネントを使って位置、回転、大きさを調整してください。配置はお好みで設定しましょう。**

![](https://storage.googleapis.com/zenn-user-upload/cbe5497f044c-20241201.gif)

## Gunスクリプトの作成

**Gunスクリプトを新規で作成して、以下のコードを記述してください。**

```csharp:Gun
using UnityEngine;
using UnityEngine.InputSystem;

public class Gun : MonoBehaviour
{
    // エフェクト
    public GameObject muzzleFlash; // 射撃エフェクト(マズルフラッシュ)のプレハブ
    [SerializeField] GameObject hitEffect; // 弾痕エフェクトのプレハブ

    // サウンド
    [SerializeField] AudioSource audioSource;
    [SerializeField] AudioClip gunSound;

    // 射撃設定
    public Transform bulletSpawnPoint; // 弾の発射点
    public float rate = 0.2f; // 射撃間隔(レート)

    private bool isShooting = false; // 射撃操作中かどうか
    private float nextFire = 0.0f; // 次の射撃までの時間
    public int currentAmmo = 30; // 現在の弾の残量

    // 射撃操作(右クリック)
    public void Shoot(InputAction.CallbackContext context)
    {
        if (context.performed)
        {
            isShooting = true;
        }
        else if (context.canceled)
        {
            isShooting = false;
        }
    }

    private void Update()
    {
        if (isShooting && Time.time > nextFire) 
        {
            // 射撃間隔を設定
            nextFire = Time.time + rate;

            // 弾がなくなったら射撃しない
            if (currentAmmo <= 0) return;  

            // 弾を発射
            GameObject ef = Instantiate(muzzleFlash, bulletSpawnPoint.position, bulletSpawnPoint.rotation);
            ef.transform.SetParent(transform);

            // マズルからRayを飛ばす
            RaycastHit hit;
            if (Physics.Raycast(bulletSpawnPoint.position, bulletSpawnPoint.forward, out hit))
            {
                // ヒット処理
                Instantiate(hitEffect, hit.point, Quaternion.LookRotation(hit.normal));
            }

            // 弾の残量を減らす
            currentAmmo--;
        }
    }

    //Eキーをクリック
    public void Reload(InputAction.CallbackContext context)
    {
        if (context.performed)
        {
            // 残弾を増やす
            currentAmmo = 30;
        }
    }
}
```
## Gunスクリプトのアタッチ・変数の設定

**1.	Gunスクリプトをアタッチ**
•	Gunスクリプトを、PLAYERが持つ銃のオブジェクトにアタッチします。

**2.	Gunスクリプトの変数を設定**
•	銃オブジェクトを選択し、インスペクターからGunスクリプトの変数を設定します。
•	rate: 発射間隔を指定します。例えば、0.2と設定すると、0.2秒に1回弾が発射されます。
•	currentAmmo: マガジン内の弾数を指定します。

**3.	MuzzleFlashの設定**
•	MuzzleFlashには、インポートしたアセット内のプレハブを選択して割り当てます。

![](https://storage.googleapis.com/zenn-user-upload/31ee42ef73d5-20241201.gif)

**4.	BulletSpawnPointの設定**
•	弾の発射位置を正確に設定するため、銃口の位置に空のゲームオブジェクトを作成します。
•	この空のオブジェクトをBulletSpawnPointとしてGunスクリプトに割り当てます。

![](https://storage.googleapis.com/zenn-user-upload/6a1f819bd6cc-20241201.gif)

## PlayerInputに設定

**PLAYERオブジェクトを選択し、インスペクターでPlayerInputコンポーネントのEvents設定を開きます。**
•	Attackアクションに射撃処理のShoot関数を紐付けます。
•	Interactアクションにリロード処理のReload関数を紐付けます。

これにより、InputSystemとスクリプトの紐付けが完了します。

![](https://storage.googleapis.com/zenn-user-upload/11dfa2564fcf-20241201.gif)

# Unityで動かす

マウスをクリックした際に、マズルフラッシュが表示されれば設定は成功です。

![](https://storage.googleapis.com/zenn-user-upload/1c472e44f47e-20241201.gif)

# Unityを理解する

UnityでFPS視点の射撃システムをプログラムする方法を解説します。射撃操作のスクリプト作成、入力設定、エフェクトの設定など、段階的に説明していきます。

# 射撃システムに必要なことをまとめる

射撃システムを構築するために必要な基本機能を以下にまとめました。
**1.射撃：右クリックで射撃を実行。
2.	リロード：Eキーで弾薬を補充。
3.	エフェクト：射撃時にマズルフラッシュなどのエフェクトを再生。
4.	サウンド：射撃音やリロード音を再生。**

これらの機能はGunスクリプトで実装します。

# Gunスクリプトの記述

以下に、射撃システムを段階的に実装していきます。

# 射撃操作

射撃のロジックは以下です。
1.射撃操作(右クリック)がされる
2.射撃エフェクト(マズルフラッシュ)・射撃サウンド(射撃音)を再生します。
3.ターゲットにヒットした時のみ、ヒット処理と弾痕エフェクトを再生します。

## 入力値を取得

InputAction.CallbackContextを使用して射撃操作を取得します。
**performedで射撃を開始し、canceledで射撃を停止するように制御します**。

```diff csharp:Gun
using UnityEngine;
+ using UnityEngine.InputSystem;

public class Gun : MonoBehaviour
{
+   private bool isShooting = false; // 初期値はfalse

+   // 射撃操作(右クリック)
+   public void Shoot(InputAction.CallbackContext context)
+   {
+       if (context.performed) // 右クリックが押された時
+       {
+           isShooting = true;
+       }
+       else if (context.canceled) // 右クリックが離された時
+       {
+           isShooting = false;
+       }
+   }

+   void Update()
+   {
+      // 射撃処理
+   }
}
```

## 射撃の条件設定

**射撃操作が行われた際に、間隔（レート）を考慮してRayを飛ばします**。これにより、1秒間に多数の弾が発射されるのを防ぎます。

また、**残弾数が0の場合は射撃を行わないよう、残弾数の条件を追加します**。

```diff csharp:Gun
using UnityEngine;
using UnityEngine.InputSystem;

public class Gun : MonoBehaviour
{
+   // 射撃設定
+   public float rate; // 射撃間隔(レート)
    
+   private bool isShooting = false; // 射撃操作中かどうか
+   private float nextFire = 0.0f; // 次の射撃までの時間

    (省略)

    void Update()
    {
+       // 射撃操作中かつ前回の射撃から射撃間隔(レート)以上の時間が経ったら、Rayを飛ばす
+       if (isShooting && Time.time > nextFire) 
+       {
+           // 射撃間隔を設定
+           nextFire = Time.time + rate;

+           // 弾がなくなったら射撃しない
+           if (currentAmmo <= 0) return;

+           // 射撃処理
+
+           // 弾の残量を減らす
+           currentAmmo--;
+       }
    }
}
```

### if文の省略記法

**if 文の中で実行する処理が1行のみの場合は、ブロック {} を省略して簡潔に記述できます。**

```csharp:通常の記述
if (条件式)
{
    // 処理
}
```

```csharp:省略した記述
if (条件式) // 処理;
```

### アーリーリターンの活用

if 文を使う際に、条件を満たした時点でreturnを利用して**以降のコードをスキップする**ことで、コードを簡潔にするテクニックを**アーリーリターン**と呼びます。

### 実際のコードで理解する
次の2つのコードは同じ処理を実行しますが、後者（アーリーリターンを使用した例）はコードがスッキリしています。

```csharp:returnを使用しない場合
// A : returnを使用しない場合
if (currentAmmo > 0)
{
    // 射撃処理
}
else
{
    // 弾切れ処理
}
```

```csharp:returnを使用した場合
// B : returnを使用した場合
if (currentAmmo <= 0)
{
    // 弾切れ処理
    return;
}
// 射撃処理
```

### メリット
•	コードの見通しが良くなる: 余計なelseブロックを省略できるため、可読性が向上。
•	処理の流れが明確: 特定条件を満たさない場合に早めに終了するため、無駄なネストが減る。

## Rayによるヒット判定

### Rayの基本的な使い方

**射撃時にRayを飛ばしてターゲットとのヒット判定を行います**。ヒットした際には、ターゲットのスクリプトにアクセスして、ダメージ処理やエフェクトを実行します。

以下のコードでは、弾の発射点（bulletSpawnPoint）からRayを飛ばし、ヒットした場合にヒット処理を行います。

```csharp
public Transform bulletSpawnPoint; // 弾の発射点

// 射撃
if (Physics.Raycast(bulletSpawnPoint.position, bulletSpawnPoint.forward, out hit))
{
    // ヒット処理
}
```

## コード記述の注意点

::: message
射撃エフェクト（マズルフラッシュ）や射撃音は、ターゲットへのヒットに関係なく発生させます。
:::

つまり、発射間隔や弾の残量を超える射撃を防ぐことを考慮したコード記述が必要です。

```diff csharp:Gun
 // 射撃操作中かつ前回の射撃から射撃間隔(レート)以上の時間が経ったら、Rayを飛ばす
if (isShooting && Time.time > nextFire) 
{
    // 射撃間隔を設定
    nextFire = Time.time + rate;

    // 弾がなくなったら射撃しない
    if (currentAmmo <= 0) return;

+   // 射撃エフェクト(マズルフラッシュ)の生成

    if (Ray判定)
    {
+       // ヒット処理
    }

    // 弾の残量を減らす
    currentAmmo--;
}
```

## 実際のコードで理解する

```diff csharp:Gun
using UnityEngine;
using UnityEngine.InputSystem;

public class Gun : MonoBehaviour
{
    // 射撃設定
+   public Transform bulletSpawnPoint; // 弾の発射点
    public float rate; // 射撃間隔(レート)

    private bool isShooting = false; // 射撃操作中かどうか
    private float nextFire = 0.0f; // 次の射撃までの時間
    public int currentAmmo = 30; // 現在の弾の残量

    // 射撃操作(右クリック)
    public void Shoot(InputAction.CallbackContext context)
    {
        if (context.performed)
        {
            isShooting = true;
        }
        else if (context.canceled)
        {
            isShooting = false;
        }
    }

    private void Update()
    {
        // 射撃操作中かつ前回の射撃から射撃間隔(レート)以上の時間が経ったら、Rayを飛ばす
        if (isShooting && Time.time > nextFire) 
        {
            // 射撃間隔を設定
            nextFire = Time.time + rate;

            // 弾がなくなったら射撃しない
            if (currentAmmo <= 0) return;  

+           // マズルからRayを飛ばす
+           RaycastHit hit;
+           if (Physics.Raycast(bulletSpawnPoint.position, bulletSpawnPoint.forward, out hit))
+           {
+               // ヒット処理
+           }

            // 弾の残量を減らす
            currentAmmo--;
        }
    }
}
```

## マズルフラッシュの生成

射撃時のエフェクトを再生することで、視覚的な演出を加えます。
また、ターゲットにヒットした場合、弾痕エフェクトも生成します。

下記では、Unityの`Instantiate`関数を利用して、マズルフラッシュを生成しています。その後、transform.SetParent(トランスフォーム)を利用して、Gunがアタッチされているオブジェクトの子オブジェクトにするようにしています。これは、エフェクトが生成された後に、銃の位置が移動しても、エフェクトが銃口に追従するようにするためです。

```csharp:Gun
GameObject ef = Instantiate(muzzleFlash, bulletSpawnPoint.position, bulletSpawnPoint.rotation);
ef.transform.SetParent(transform);
```

```diff csharp:Gun
using UnityEngine;
using UnityEngine.InputSystem;

public class Gun : MonoBehaviour
{
+   // エフェクト
+   public GameObject muzzleFlash; // 射撃エフェクト(マズルフラッシュ)のプレハブ
+   public GameObject hitEffect; // 弾痕エフェクトのプレハブ

    // 射撃設定
    public Transform bulletSpawnPoint; // 弾の発射点
    public float rate; // 射撃間隔(レート)

    private bool isShooting = false; // 射撃操作中かどうか
    private float nextFire = 0.0f; // 次の射撃までの時間
    public int currentAmmo = 30; // 現在の弾の残量

    // 射撃操作(右クリック)
    public void Shoot(InputAction.CallbackContext context)
    {
        if (context.performed)
        {
            isShooting = true;
        }
        else if (context.canceled)
        {
            isShooting = false;
        }
    }

    private void Update()
    {
        if (isShooting && Time.time > nextFire) 
        {
            // 射撃間隔を設定
            nextFire = Time.time + rate;

            // 弾がなくなったら射撃しない
            if (currentAmmo <= 0) return;  

+           // 弾を発射
+           GameObject ef = Instantiate(muzzleFlash, bulletSpawnPoint.position, bulletSpawnPoint.rotation);
+           ef.transform.SetParent(transform);

            // マズルからRayを飛ばす
            RaycastHit hit;
            if (Physics.Raycast(bulletSpawnPoint.position, bulletSpawnPoint.forward, out hit))
            {
                // ヒット処理
            }

            // 弾の残量を減らす
            currentAmmo--;
        }
    }
}
```

# リロード操作

リロード操作（Eキー）で弾薬を補充する処理を追加します。弾薬の補充時にリロード音を再生します。

>リロードは、入力がされた際に一度だけ実行されれば良いため、Inputsystemのメソッドに直接記述します。

```csharp:Gunn
public void Reload(InputAction.CallbackContext context)
{
    if (context.performed)
    {
        currentAmmo = 30; // 最大弾薬数にリセット
    }
}
```

# 完成したコード
```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class Gun : MonoBehaviour
{
    // エフェクト
    public GameObject muzzleFlash; // 射撃エフェクト(マズルフラッシュ)のプレハブ
    [SerializeField] GameObject hitEffect; // 弾痕エフェクトのプレハブ

    // サウンド
    [SerializeField] AudioSource audioSource;
    [SerializeField] AudioClip gunSound;

    // 射撃設定
    public Transform bulletSpawnPoint; // 弾の発射点
    public float rate; // 射撃間隔(レート)

    private bool isShooting = false; // 射撃操作中かどうか
    private float nextFire = 0.0f; // 次の射撃までの時間
    public int currentAmmo = 30; // 現在の弾の残量

    // 射撃操作(右クリック)
    public void Shoot(InputAction.CallbackContext context)
    {
        if (context.performed)
        {
            isShooting = true;
        }
        else if (context.canceled)
        {
            isShooting = false;
        }
    }

    private void Update()
    {
        if (isShooting && Time.time > nextFire)
        {
            // 射撃間隔を設定
            nextFire = Time.time + rate;

            // 弾がなくなったら射撃しない
            if (currentAmmo <= 0) return;

            // 銃声を再生
            audioSource.PlayOneShot(gunSound);

            // 弾を発射
            GameObject ef = Instantiate(muzzleFlash, bulletSpawnPoint.position, bulletSpawnPoint.rotation);
            ef.transform.SetParent(transform);

            // マズルからRayを飛ばす
            RaycastHit hit;
            if (Physics.Raycast(bulletSpawnPoint.position, bulletSpawnPoint.forward, out hit))
            {
                // ヒット処理
                Instantiate(hitEffect, hit.point, Quaternion.LookRotation(hit.normal));
            }

            // 弾の残量を減らす
            currentAmmo--;
        }
    }

    //Eキーをクリック
    public void Reload(InputAction.CallbackContext context)
    {
        if (context.performed)
        {
            // 残弾を増やす
            currentAmmo = 30;
        }
    }
}
```