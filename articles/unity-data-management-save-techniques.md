---
title: "Unityのデータ管理完全ガイド - JSON/PlayerPrefs/暗号化/LINQまで"
emoji: "🗄️"
type: "tech"
topics: ["unity", "csharp", "json", "gamedev", "security"]
published: true
published_at: 2026-04-02 18:00
---

## はじめに - ゲーム開発のデータ管理戦略

ゲーム開発において、データの保存・読み込み・操作は避けて通れない課題である。プレイヤーの進行状況、スコア、インベントリ、設定値――これらを適切に管理できるかどうかが、ゲームの品質とユーザー体験を左右する。

Unityでのデータ管理は、大きく分けて以下の4つの技術領域に整理できる。

| 領域 | 主な用途 | 代表的なAPI/手法 |
|------|----------|-----------------|
| 簡易保存 | 設定値・ハイスコア | PlayerPrefs |
| 構造化保存 | セーブデータ・インベントリ | JSON (JsonUtility / Newtonsoft.Json) |
| セキュリティ | 改ざん防止・データ保護 | AES暗号化 |
| データ操作 | フィルタリング・集計・検索 | LINQ |

本記事では、これら4つの技術を「いつ・何に・どう使うか」の観点で横断的に解説する。個別記事では扱いきれない**技術間の連携や使い分け**に重点を置いた構成である。

:::message
本記事のコード例はUnity 2021 LTS以降、C# 9.0以降を想定している。サンプルは要点を示す最小構成のため、本番コードでは適切なエラーハンドリングを追加すること。
:::

## PlayerPrefs - 手軽な設定保存とその限界

PlayerPrefsは、Unityが標準で提供するキーバリュー型の保存機構である。`int`、`float`、`string`の3型に対応し、1行で保存・読み込みが完結する手軽さが最大の特徴だ。

```csharp
// 保存
PlayerPrefs.SetInt("HighScore", 9800);
PlayerPrefs.SetFloat("BGMVolume", 0.75f);
PlayerPrefs.SetString("PlayerName", "Ryuya");
PlayerPrefs.Save();

// 読み込み（第2引数はキーが存在しない場合のデフォルト値）
int score = PlayerPrefs.GetInt("HighScore", 0);
float volume = PlayerPrefs.GetFloat("BGMVolume", 1.0f);
```

ローカルランキングのように、少数のスコアをインデックス付きキーで管理する程度であれば十分に実用的である。

しかし、PlayerPrefsには明確な制約がある。

- **保存先がプラットフォーム依存**（Windowsはレジストリ、macOSはplistファイル）
- **データは平文で保存される**ため、ユーザーが直接編集可能
- **複雑なデータ構造は扱えない**（リストやネストしたクラスは非対応）

:::message
PlayerPrefsは「ゲーム設定」「音量」「簡易スコア」など、改ざんされても致命的でない軽量データに限定して使うのが定石である。セーブデータ本体には次節のJSON保存を採用すべきだ。
:::

## JSON保存 - 自作クラスのシリアライズ/デシリアライズ

キャラクターのステータス、装備品、進行フラグなど、複数のフィールドを持つデータはJSON形式で管理するのが合理的である。Unityには標準の`JsonUtility`が搭載されており、`[System.Serializable]`属性を付与したクラスであればそのままJSON化できる。

```csharp
[System.Serializable]
public class SaveData
{
    public string playerName;
    public int level;
    public List<string> ownedItems;
}

// シリアライズ（オブジェクト → JSON文字列）
SaveData data = new SaveData { playerName = "Hero", level = 12 };
string json = JsonUtility.ToJson(data);

// デシリアライズ（JSON文字列 → オブジェクト）
SaveData loaded = JsonUtility.FromJson<SaveData>(json);
```

`JsonUtility`はシンプルだが、Dictionaryやポリモーフィズムには非対応という制約がある。より柔軟なシリアライズが必要な場合は、**Newtonsoft.Json（Json.NET）** を導入する。`record`型やnull制御、インデント出力など高度なオプションが利用可能だ。

```csharp
using Newtonsoft.Json;

// record型との組み合わせ（C# 9.0以降）
public record PlayerRecord(string Name, int Level, float Health);

var player = new PlayerRecord("Alice", 10, 100f);
string json = JsonConvert.SerializeObject(player, Formatting.Indented);
var restored = JsonConvert.DeserializeObject<PlayerRecord>(json);
```

JSON文字列はファイルへの書き出し（`File.WriteAllText`）はもちろん、前節のPlayerPrefsに`SetString`で格納することもできる。小規模なデータであればPlayerPrefs + JSONの組み合わせが最も手軽な永続化手段となる。

## 暗号化 - AESでセーブデータを保護する

JSONで保存したデータは人間が読めるテキストである。つまり、セーブファイルを直接開いてHPを99999に書き換える、といった改ざんが容易に行えてしまう。そこで有効なのが**AES（Advanced Encryption Standard）暗号化**だ。

C#の`System.Security.Cryptography`名前空間に標準実装されているため、外部ライブラリ不要で導入できる。

```csharp
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

public static class AESTool
{
    private static readonly byte[] key = Encoding.UTF8.GetBytes("1234567890ABCDEF1234567890ABCDEF"); // 32bytes
    private static readonly byte[] iv  = Encoding.UTF8.GetBytes("ABCDEF1234567890"); // 16bytes

    public static string Encrypt(string plainText)
    {
        using var aes = Aes.Create();
        aes.Key = key;
        aes.IV = iv;
        using var ms = new MemoryStream();
        using (var cs = new CryptoStream(ms, aes.CreateEncryptor(), CryptoStreamMode.Write))
        {
            byte[] bytes = Encoding.UTF8.GetBytes(plainText);
            cs.Write(bytes, 0, bytes.Length);
        }
        return Convert.ToBase64String(ms.ToArray());
    }

    public static string Decrypt(string cipherText)
    {
        using var aes = Aes.Create();
        aes.Key = key;
        aes.IV = iv;
        using var ms = new MemoryStream();
        using (var cs = new CryptoStream(ms, aes.CreateDecryptor(), CryptoStreamMode.Write))
        {
            byte[] bytes = Convert.FromBase64String(cipherText);
            cs.Write(bytes, 0, bytes.Length);
        }
        return Encoding.UTF8.GetString(ms.ToArray());
    }
}
```

JSON保存と組み合わせる場合の流れは単純である。

```csharp
// 保存: オブジェクト → JSON → 暗号化 → ファイル書き出し
string json = JsonUtility.ToJson(saveData);
string encrypted = AESTool.Encrypt(json);
File.WriteAllText(savePath, encrypted);

// 読込: ファイル読み込み → 復号 → JSON → オブジェクト
string encrypted = File.ReadAllText(savePath);
string json = AESTool.Decrypt(encrypted);
SaveData loaded = JsonUtility.FromJson<SaveData>(json);
```

:::message alert
キーとIVをソースコードにハードコードしている場合、逆コンパイルで取得されるリスクがある。IL2CPPビルドや難読化ツールとの併用を推奨する。完全な不正防止にはサーバー側での検証が不可欠である。
:::

## LINQ活用 - ゲームデータのフィルタリング・集計

保存と読み込みが整ったら、次はメモリ上のデータを効率的に**検索・抽出・変換**する技術が必要になる。C#のLINQ（Language Integrated Query）は、コレクション操作をSQL風のメソッドチェーンで記述できる強力な機能だ。

### フィルタリングとソート

```csharp
using System.Linq;

// HPが30以下の敵を抽出し、HP昇順で並べる
var weakEnemies = enemies
    .Where(e => e.hp <= 30)
    .OrderBy(e => e.hp)
    .ToList();
```

### グループ化と集計

```csharp
// アイテムをカテゴリ別にグループ化し、各カテゴリの所持数を集計
var summary = inventory
    .GroupBy(item => item.category)
    .Select(g => new { Category = g.Key, Count = g.Count() });
```

### インベントリ検索の実践例

アイテム管理クラスとLINQを組み合わせると、検索・フィルタが直感的に書ける。

```csharp
public class ItemManager : MonoBehaviour
{
    public List<Item> items = new List<Item>();

    // 特定IDのアイテムを検索
    public Item FindById(int id) => items.FirstOrDefault(i => i.itemID == id);

    // レア度でフィルタリング
    public List<Item> GetByRarity(string rarity) =>
        items.Where(i => i.rarity == rarity).ToList();

    // 所持アイテムの総価値を計算
    public int TotalValue() => items.Sum(i => i.price);
}
```

:::message
LINQはGC Allocを発生させるため、`Update()`内での毎フレーム実行は避けること。結果をキャッシュするか、イベント駆動で必要な時だけ実行するのがベストプラクティスである。
:::

## まとめ - 用途別の使い分け指針

本記事で解説した4つの技術を、用途別に整理すると以下のようになる。

| 用途 | 推奨技術 | 理由 |
|------|---------|------|
| 音量・言語などの設定 | PlayerPrefs | 1行で完結、改ざんされても影響が軽微 |
| セーブデータ全般 | JSON (JsonUtility) | 構造化データを柔軟に保存可能 |
| 複雑なデータ・record型 | JSON (Newtonsoft.Json) | Dictionary・null制御・高度な型に対応 |
| 改ざん防止が必要なデータ | JSON + AES暗号化 | 平文を見せない最低限の防御ライン |
| データの検索・集計・変換 | LINQ | 宣言的で可読性の高いコレクション操作 |

実際のプロジェクトでは、これらを**組み合わせて使う**のが一般的だ。たとえば「アイテムデータをJSON + AESで保存し、読み込み後にLINQでフィルタリングしてUIに表示する」というパイプラインは、多くのゲームで採用されている典型的な構成である。

まずはPlayerPrefsとJsonUtilityで小さく始め、プロジェクトの要件に応じて暗号化やLINQを段階的に導入していくのが、無理のない進め方だ。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
