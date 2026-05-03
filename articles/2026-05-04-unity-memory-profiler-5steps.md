---
title: "Unityのメモリリークを5ステップで解決する方法：Memory Profiler入門ガイド"
emoji: "🔍"
type: "tech"
topics: ["unity", "csharp", "gamedev", "performance", "debug"]
published: false
---

## はじめに

「スマホゲームをリリースしたら、数分プレイするとFPSが急落する」——そういった経験をしたUnity開発者は少なくないはずです。原因を探ろうとProfilerを開いても、GC.Allocのスパイクが見つかるだけで、どこで何がアロケートされているか特定できない。

**Memory Profilerを使えば、この問題を体系的に追跡できます。** 勘や目視でコードを見回す必要がなくなり、ボトルネックを数値で特定できるようになります。

この記事では、Memory Profilerを導入してから実際にリークを修正・確認するまでの5ステップを紹介します。

---

## Step 1: Memory Profilerのインストールと起動

Unity公式のMemory Profilerは、Package Managerから追加できます。

**インストール手順:**

1. メニューバーから `Window > Package Manager` を開く
2. 左上のドロップダウンを `Unity Registry` に切り替える
3. 検索欄に `Memory Profiler` と入力
4. `Memory Profiler` を選択して `Install` をクリック

インストール後は `Window > Analysis > Memory Profiler` でウィンドウを起動できます。

:::message
Unity 2022 LTS以降では、Memory Profilerパッケージのバージョンが `1.0.0` 以上推奨です。古いバージョンではスナップショットの比較機能が制限される場合があります。
:::

エディタ上でも、Android/iOS実機でも動作します。実機デバッグ時はEditorと同じWi-Fiネットワーク上でUnity Profilingを有効にした状態でビルドしてください。

---

## Step 2: スナップショットを撮って基準値を確認

Memory Profilerの核心は「スナップショット」です。任意のタイミングでメモリの全体像を記録し、どのオブジェクトが何バイト占有しているかを可視化できます。

**スナップショットの取り方:**

1. Memory Profilerウィンドウ左上の `Capture New Snapshot` をクリック
2. ゲームが一時停止し、スナップショットが保存される
3. 左のパネルにサムネイルとタイムスタンプが表示される

確認すべき主要指標は以下の2つです。

| 指標 | 意味 |
|------|------|
| Managed Heap | C#オブジェクトが占有するヒープメモリ。GC管理下 |
| Native Memory | TextureやAudioClipなどUnityエンジン側のメモリ |

ゲーム起動直後にスナップショットを撮り、これを「ベースライン」として保存しておきます。この値と比較することで、プレイ時間に比例してメモリが増えているかどうかを判断できます。

---

## Step 3: GC Allocationのホットスポットを特定

Managed Heapが異常に増大している場合、C#コード内で不要なアロケーションが発生しているケースが大半です。

よくある原因のひとつが、**Update()内でのオブジェクトのnew**です。

```csharp
// 悪い例（毎フレームGCアロケーション発生）
void Update()
{
    // StringBuilderを毎回newするとGCスパイクの原因に
    var sb = new System.Text.StringBuilder();
    sb.Append("Score: ");
    sb.Append(_score);
    _scoreText.text = sb.ToString();
}
```

このコードは毎フレーム `StringBuilder` を生成・破棄するため、GCが頻繁に走りFPSスパイクを引き起こします。

修正するには、インスタンスをキャッシュして使い回します。

```csharp
// 良い例（アロケーションをフィールドに移動してキャッシュ）
private readonly System.Text.StringBuilder _sb = new System.Text.StringBuilder(32);

void Update()
{
    _sb.Clear();
    _sb.Append("Score: ");
    _sb.Append(_score);
    _scoreText.text = _sb.ToString();
}
```

フィールドとして一度だけ生成し、`Clear()` で中身をリセットして使い回すことでアロケーションを排除できます。

:::message
Memory Profilerの `All Of Memory > Managed Objects` ビューを開くと、型ごとのインスタンス数とサイズが一覧表示されます。件数が異常に多い型があれば、そこがホットスポットです。
:::

---

## Step 4: Nativeメモリのリークを確認

Managed Heapと並んで問題になるのが、Nativeメモリの増加です。TextureやAudioClipはC#オブジェクトではなくUnityのネイティブ側で管理されるため、GCでは回収されません。

主な原因は `Resources.Load` で読み込んだアセットの解放忘れです。シーン遷移後も参照が残っていると、Nativeメモリは増え続けます。

`Resources.UnloadUnusedAssets()` を呼び出すことで、参照が切れたアセットを解放できます。

```csharp
using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneLoader : MonoBehaviour
{
    public IEnumerator LoadSceneWithCleanup(string sceneName)
    {
        // シーンをアンロード
        yield return SceneManager.UnloadSceneAsync(SceneManager.GetActiveScene());

        // 未使用アセットを解放してNativeメモリを回収
        yield return Resources.UnloadUnusedAssets();

        // GCを明示的に実行（ローディング画面中などの許容タイミングで）
        System.GC.Collect();

        // 次のシーンをロード
        yield return SceneManager.LoadSceneAsync(sceneName);
    }
}
```

:::message alert
`Resources.UnloadUnusedAssets()` と `System.GC.Collect()` はどちらも重い処理です。ゲームプレイ中に呼ぶとフレームドロップの原因になります。必ずローディング画面など、プレイヤーが処理負荷を感じにくいタイミングで実行してください。
:::

Memory Profilerの `Native Objects` ビューでは、Texture2DやAudioClipの個数を型別に確認できます。シーン遷移前後でこの数が減っていない場合は解放漏れを疑ってください。

---

## Step 5: 差分スナップショットで改善を確認

修正を加えたら、改善できているかをスナップショットの比較で定量的に確認します。

**比較手順:**

1. 修正前のスナップショット（Step 2で取得したもの）を左側に表示
2. 修正後のスナップショットを新たに取得して右側に表示
3. ウィンドウ上部の `Compare Snapshots` を選択

Diffビューでは、増加・減少したオブジェクトが色分けで表示されます。

確認すべき項目:

- `Managed Heap Used` が修正後に減少しているか
- 問題のあった型（例: `StringBuilder`）のインスタンス数が減っているか
- シーン遷移後に `Native Objects` の数が適切に減少しているか

**数値で改善を確認することが、メモリ最適化において最も重要なステップです。** 「直ったはず」という感覚ではなく、スナップショットの数字で確認する習慣をつけることで、修正の抜け漏れを防げます。

---

## まとめ

Memory Profilerを使った5ステップのメモリリーク解決フローをまとめます。

- **Step 1**: Package ManagerからMemory Profilerをインストールして起動する
- **Step 2**: ゲーム起動直後にスナップショットを撮りベースラインを記録する
- **Step 3**: Managed Objectsビューでアロケーションのホットスポットを特定し、フィールドキャッシュで修正する
- **Step 4**: Native Objectsビューでアセットの解放漏れを確認し、`Resources.UnloadUnusedAssets()` を適切なタイミングで呼ぶ
- **Step 5**: 修正前後のスナップショットを比較して改善を数値で検証する

Memory Profilerを使う前は「なんとなく重い」で終わっていた問題が、数値ベースで追跡できるようになります。最初はスナップショットを撮るだけでも十分です。まず基準値を記録することから始めてみてください。
