---
title: "信頼性向上のためのtry/catch/finallyの活用 ― Unity C#で信頼性の高いゲームロジックを構築する"
emoji: "📑"
type: "tech"
topics: ["csharp","unity"]
published: true
---

# [](#unity-c%23%E3%81%A7%E3%81%AE%E3%82%A8%E3%83%A9%E3%83%BC%E3%83%8F%E3%83%B3%E3%83%89%E3%83%AA%E3%83%B3%E3%82%B0%E5%AE%8C%E5%85%A8%E3%82%AC%E3%82%A4%E3%83%89)Unity C#でのエラーハンドリング完全ガイド

Unityでゲーム開発を行う際、予期せぬエラーやバグが発生することは避けられません。これらの問題に対処し、ゲームの信頼性を高めるためには、適切なエラーハンドリングが不可欠です。本記事では、C#における例外処理の基本から実践的なテクニックまで、Unityプロジェクトで信頼性の高いゲームロジックを構築する方法について詳しく解説します。

## [](#try%2Fcatch%2Ffinally%E3%81%AE%E5%9F%BA%E6%9C%AC%E6%A7%8B%E9%80%A0)try/catch/finallyの基本構造

`try/catch/finally`は、例外処理のための基本的な構文です。この構造を適切に使用することで、エラー発生時の影響を最小限に抑え、ゲームの安定性を向上させることができます。

### [](#%E5%9F%BA%E6%9C%AC%E7%9A%84%E3%81%AA%E4%BD%BF%E7%94%A8%E4%BE%8B)基本的な使用例

BasicExceptionHandling.cs

```
using UnityEngine;

public class BasicExceptionHandling : MonoBehaviour
{
    void Start()
    {
        try
        {
            // エラーが発生する可能性のある処理
            string input = "abc";
            int result = int.Parse(input);
            Debug.Log($"変換結果: {result}");
        }
        catch (FormatException ex)
        {
            // 数値形式が不正な場合
            Debug.LogError($"数値への変換に失敗しました: {ex.Message}");
        }
        catch (OverflowException ex)
        {
            // 値が範囲外の場合
            Debug.LogError($"値が範囲外です: {ex.Message}");
        }
        catch (System.Exception ex)
        {
            // その他の予期せぬ例外
            Debug.LogError($"予期せぬエラーが発生しました: {ex.Message}");
            Debug.LogException(ex);
        }
        finally
        {
            // リソース解放など、必ず実行したい処理
            Debug.Log("処理を完了しました");
        }
    }
}
```

### [](#%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E8%A7%A3%E8%AA%AC)コードの解説

**tryブロック**

-   エラーが発生する可能性のある処理を記述
-   例外が発生すると、即座にcatchブロックに移行

**catchブロック**

-   特定の例外型をキャッチして適切に処理
-   具体的な例外から一般的な例外の順に記述
-   複数のcatchブロックで異なる例外に対応可能

**finallyブロック**

-   例外の有無にかかわらず必ず実行
-   リソース解放やクリーンアップ処理に使用
-   return文があっても実行される

!

例外処理は、予期せぬエラーに対処するための仕組みです。通常のプログラムフローの制御には使用せず、予測可能なエラーは条件分岐で対処しましょう。

## [](#%E4%BE%8B%E5%A4%96%E5%87%A6%E7%90%86%E3%81%AE%E3%83%99%E3%82%B9%E3%83%88%E3%83%97%E3%83%A9%E3%82%AF%E3%83%86%E3%82%A3%E3%82%B9)例外処理のベストプラクティス

### [](#1.-%E5%85%B7%E4%BD%93%E7%9A%84%E3%81%AA%E4%BE%8B%E5%A4%96%E3%82%92%E3%82%AD%E3%83%A3%E3%83%83%E3%83%81%E3%81%99%E3%82%8B)1\. 具体的な例外をキャッチする

SpecificExceptionHandling.cs

```
using UnityEngine;
using System;

public class SpecificExceptionHandling : MonoBehaviour
{
    // ❌ 悪い例：すべての例外を一括処理
    void BadExample()
    {
        try
        {
            LoadGameData();
        }
        catch (Exception ex)
        {
            Debug.LogError("エラーが発生しました");
        }
    }

    // ✅ 良い例：具体的な例外ごとに処理
    void GoodExample()
    {
        try
        {
            LoadGameData();
        }
        catch (System.IO.FileNotFoundException ex)
        {
            Debug.LogError($"セーブファイルが見つかりません: {ex.FileName}");
            CreateDefaultSaveData();
        }
        catch (UnauthorizedAccessException ex)
        {
            Debug.LogError($"ファイルへのアクセス権限がありません: {ex.Message}");
            ShowPermissionErrorDialog();
        }
        catch (Newtonsoft.Json.JsonException ex)
        {
            Debug.LogError($"セーブデータの形式が不正です: {ex.Message}");
            CreateDefaultSaveData();
        }
    }

    private void LoadGameData() { /* 実装 */ }
    private void CreateDefaultSaveData() { /* 実装 */ }
    private void ShowPermissionErrorDialog() { /* 実装 */ }
}
```

### [](#2.-%E4%BE%8B%E5%A4%96%E3%83%A1%E3%83%83%E3%82%BB%E3%83%BC%E3%82%B8%E3%82%92%E8%A9%B3%E7%B4%B0%E3%81%AB%E8%A8%98%E9%8C%B2%E3%81%99%E3%82%8B)2\. 例外メッセージを詳細に記録する

DetailedLogging.cs

```
using UnityEngine;
using System;

public class DetailedLogging : MonoBehaviour
{
    void LoadConfiguration(string configPath)
    {
        try
        {
            // 設定ファイル読み込み処理
            var config = System.IO.File.ReadAllText(configPath);
        }
        catch (Exception ex)
        {
            // 詳細なコンテキスト情報を含める
            Debug.LogError($"設定ファイルの読み込みに失敗しました\n" +
                          $"パス: {configPath}\n" +
                          $"例外型: {ex.GetType().Name}\n" +
                          $"メッセージ: {ex.Message}\n" +
                          $"スタックトレース:\n{ex.StackTrace}");
            
            // Unity固有のログ機能を使用
            Debug.LogException(ex, this);
        }
    }
}
```

### [](#3.-%E3%83%91%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%B3%E3%82%B9%E3%81%B8%E3%81%AE%E5%BD%B1%E9%9F%BF%E3%82%92%E8%80%83%E6%85%AE%E3%81%99%E3%82%8B)3\. パフォーマンスへの影響を考慮する

PerformanceConsideration.cs

```
using UnityEngine;

public class PerformanceConsideration : MonoBehaviour
{
    // ❌ 悪い例：頻繁に呼ばれるメソッドでの例外処理
    void Update()
    {
        try
        {
            // Updateループ内でのtry-catchは避ける
            ProcessPlayerInput();
        }
        catch (System.Exception ex)
        {
            Debug.LogError(ex);
        }
    }

    // ✅ 良い例：条件分岐でチェック
    void Update_Better()
    {
        // null チェックなど、予測可能なエラーは条件分岐で
        if (playerController != null && playerController.IsActive)
        {
            ProcessPlayerInput();
        }
    }

    // 例外処理は初期化など、1回だけ実行される処理で使用
    void Start()
    {
        try
        {
            InitializeGameSystems();
        }
        catch (System.Exception ex)
        {
            Debug.LogError($"ゲームシステムの初期化に失敗: {ex.Message}");
            ShowFatalErrorScreen();
        }
    }

    private PlayerController playerController;
    private void ProcessPlayerInput() { /* 実装 */ }
    private void InitializeGameSystems() { /* 実装 */ }
    private void ShowFatalErrorScreen() { /* 実装 */ }
}
```

### [](#4.-using%E6%96%87%E3%81%AB%E3%82%88%E3%82%8B%E3%83%AA%E3%82%BD%E3%83%BC%E3%82%B9%E7%AE%A1%E7%90%86)4\. using文によるリソース管理

ResourceManagement.cs

```
using UnityEngine;
using System.IO;

public class ResourceManagement : MonoBehaviour
{
    // ❌ 悪い例：手動でのリソース解放
    void BadExample()
    {
        StreamReader reader = null;
        try
        {
            reader = new StreamReader("data.txt");
            string content = reader.ReadToEnd();
        }
        catch (IOException ex)
        {
            Debug.LogError(ex.Message);
        }
        finally
        {
            if (reader != null)
            {
                reader.Dispose();
            }
        }
    }

    // ✅ 良い例：using文による自動リソース管理
    void GoodExample()
    {
        string path = Path.Combine(Application.persistentDataPath, "data.txt");
        
        try
        {
            using (StreamReader reader = new StreamReader(path))
            {
                string content = reader.ReadToEnd();
                ProcessData(content);
            } // usingブロック終了時に自動的にDisposeが呼ばれる
        }
        catch (FileNotFoundException)
        {
            Debug.LogWarning("データファイルが見つかりません。デフォルト値を使用します。");
            UseDefaultData();
        }
        catch (IOException ex)
        {
            Debug.LogError($"ファイル読み込みエラー: {ex.Message}");
        }
    }

    // C# 8.0以降：using宣言（よりシンプル）
    void ModernExample()
    {
        string path = Path.Combine(Application.persistentDataPath, "data.txt");
        
        try
        {
            using StreamReader reader = new StreamReader(path);
            string content = reader.ReadToEnd();
            ProcessData(content);
        } // メソッド終了時に自動的にDisposeが呼ばれる
        catch (IOException ex)
        {
            Debug.LogError($"ファイル読み込みエラー: {ex.Message}");
        }
    }

    private void ProcessData(string content) { /* 実装 */ }
    private void UseDefaultData() { /* 実装 */ }
}
```

## [](#%E5%AE%9F%E8%B7%B5%E7%9A%84%E3%81%AA%E5%AE%9F%E8%A3%85%E4%BE%8B)実践的な実装例

### [](#%E3%82%BB%E3%83%BC%E3%83%96%E3%83%87%E3%83%BC%E3%82%BF%E3%81%AE%E8%AA%AD%E3%81%BF%E8%BE%BC%E3%81%BF)セーブデータの読み込み

SaveDataLoader.cs

```
using UnityEngine;
using System;
using System.IO;
using Newtonsoft.Json;

public class SaveDataLoader : MonoBehaviour
{
    private string SaveFilePath => Path.Combine(
        Application.persistentDataPath, 
        "savedata.json"
    );

    public SaveData LoadSaveData()
    {
        // ファイルが存在しない場合は新規作成
        if (!File.Exists(SaveFilePath))
        {
            Debug.Log("セーブファイルが存在しません。新規作成します。");
            return CreateNewSaveData();
        }

        try
        {
            using StreamReader reader = new StreamReader(SaveFilePath);
            string json = reader.ReadToEnd();
            
            SaveData data = JsonConvert.DeserializeObject<SaveData>(json);
            
            if (data == null)
            {
                throw new InvalidOperationException("セーブデータがnullです");
            }

            Debug.Log("セーブデータの読み込みに成功しました");
            return data;
        }
        catch (FileNotFoundException ex)
        {
            Debug.LogWarning($"セーブファイルが見つかりません: {ex.FileName}");
            return CreateNewSaveData();
        }
        catch (JsonException ex)
        {
            Debug.LogError($"セーブデータの形式が不正です: {ex.Message}");
            BackupCorruptedSaveFile();
            return CreateNewSaveData();
        }
        catch (UnauthorizedAccessException ex)
        {
            Debug.LogError($"セーブファイルへのアクセスが拒否されました: {ex.Message}");
            throw; // 上位層で処理するため再スロー
        }
        catch (IOException ex)
        {
            Debug.LogError($"セーブファイルの読み込み中にエラー: {ex.Message}");
            return CreateNewSaveData();
        }
        catch (Exception ex)
        {
            Debug.LogError($"予期せぬエラーが発生しました: {ex.Message}");
            Debug.LogException(ex);
            return CreateNewSaveData();
        }
    }

    public bool SaveData(SaveData data)
    {
        if (data == null)
        {
            Debug.LogError("保存するデータがnullです");
            return false;
        }

        try
        {
            string json = JsonConvert.SerializeObject(data, Formatting.Indented);
            
            // 一時ファイルに書き込んでから、成功したらリネーム
            string tempPath = SaveFilePath + ".tmp";
            
            using (StreamWriter writer = new StreamWriter(tempPath))
            {
                writer.Write(json);
            }

            // バックアップを作成
            if (File.Exists(SaveFilePath))
            {
                string backupPath = SaveFilePath + ".backup";
                File.Copy(SaveFilePath, backupPath, overwrite: true);
            }

            // 一時ファイルを本ファイルに置き換え
            File.Move(tempPath, SaveFilePath, overwrite: true);
            
            Debug.Log("セーブデータの保存に成功しました");
            return true;
        }
        catch (UnauthorizedAccessException ex)
        {
            Debug.LogError($"保存権限がありません: {ex.Message}");
            return false;
        }
        catch (IOException ex)
        {
            Debug.LogError($"保存中にエラーが発生: {ex.Message}");
            return false;
        }
        catch (Exception ex)
        {
            Debug.LogError($"予期せぬエラー: {ex.Message}");
            Debug.LogException(ex);
            return false;
        }
    }

    private SaveData CreateNewSaveData()
    {
        return new SaveData
        {
            playerName = "NewPlayer",
            level = 1,
            gold = 0,
            lastPlayedDate = DateTime.Now
        };
    }

    private void BackupCorruptedSaveFile()
    {
        try
        {
            string backupPath = SaveFilePath + ".corrupted";
            File.Copy(SaveFilePath, backupPath, overwrite: true);
            Debug.Log($"破損したセーブファイルをバックアップしました: {backupPath}");
        }
        catch (Exception ex)
        {
            Debug.LogWarning($"破損ファイルのバックアップに失敗: {ex.Message}");
        }
    }
}

[Serializable]
public class SaveData
{
    public string playerName;
    public int level;
    public int gold;
    public DateTime lastPlayedDate;
}
```

### [](#%E3%83%8D%E3%83%83%E3%83%88%E3%83%AF%E3%83%BC%E3%82%AF%E9%80%9A%E4%BF%A1%E3%81%AE%E3%82%A8%E3%83%A9%E3%83%BC%E3%83%8F%E3%83%B3%E3%83%89%E3%83%AA%E3%83%B3%E3%82%B0)ネットワーク通信のエラーハンドリング

NetworkManager.cs

```
using UnityEngine;
using UnityEngine.Networking;
using System;
using System.Collections;
using System.Threading.Tasks;

public class NetworkManager : MonoBehaviour
{
    private const int MaxRetryCount = 3;
    private const float RetryDelay = 2f;

    public async Task<string> FetchDataFromServer(string url)
    {
        int retryCount = 0;

        while (retryCount < MaxRetryCount)
        {
            try
            {
                using UnityWebRequest request = UnityWebRequest.Get(url);
                
                var operation = request.SendWebRequest();
                
                // 非同期待機
                while (!operation.isDone)
                {
                    await Task.Yield();
                }

                // レスポンスコードのチェック
                if (request.result == UnityWebRequest.Result.Success)
                {
                    Debug.Log($"データ取得成功: {url}");
                    return request.downloadHandler.text;
                }
                else
                {
                    throw new NetworkException(
                        $"HTTP Error: {request.responseCode}",
                        request.result
                    );
                }
            }
            catch (NetworkException ex) when (ex.Result == UnityWebRequest.Result.ConnectionError)
            {
                retryCount++;
                Debug.LogWarning($"接続エラー（試行 {retryCount}/{MaxRetryCount}）: {ex.Message}");
                
                if (retryCount >= MaxRetryCount)
                {
                    Debug.LogError("最大リトライ回数に達しました");
                    throw;
                }

                await Task.Delay(TimeSpan.FromSeconds(RetryDelay));
            }
            catch (NetworkException ex) when (ex.Result == UnityWebRequest.Result.ProtocolError)
            {
                Debug.LogError($"サーバーエラー: {ex.Message}");
                throw; // プロトコルエラーはリトライしない
            }
            catch (OperationCanceledException)
            {
                Debug.Log("通信がキャンセルされました");
                throw;
            }
            catch (Exception ex)
            {
                Debug.LogError($"予期せぬエラー: {ex.Message}");
                Debug.LogException(ex);
                throw;
            }
        }

        throw new NetworkException("データ取得に失敗しました", UnityWebRequest.Result.ConnectionError);
    }

    // カスタム例外クラス
    public class NetworkException : Exception
    {
        public UnityWebRequest.Result Result { get; }

        public NetworkException(string message, UnityWebRequest.Result result) 
            : base(message)
        {
            Result = result;
        }
    }
}
```

### [](#%E3%83%AA%E3%82%BD%E3%83%BC%E3%82%B9%E3%83%AD%E3%83%BC%E3%83%89%E3%81%AE%E3%82%A8%E3%83%A9%E3%83%BC%E3%83%8F%E3%83%B3%E3%83%89%E3%83%AA%E3%83%B3%E3%82%B0)リソースロードのエラーハンドリング

ResourceLoader.cs

```
using UnityEngine;
using System;

public class ResourceLoader : MonoBehaviour
{
    public T LoadResource<T>(string path) where T : UnityEngine.Object
    {
        if (string.IsNullOrEmpty(path))
        {
            throw new ArgumentException("パスが空です", nameof(path));
        }

        try
        {
            T resource = Resources.Load<T>(path);

            if (resource == null)
            {
                throw new ResourceNotFoundException($"リソースが見つかりません: {path}");
            }

            Debug.Log($"リソース読み込み成功: {path}");
            return resource;
        }
        catch (ResourceNotFoundException)
        {
            // カスタム例外はそのまま再スロー
            throw;
        }
        catch (Exception ex)
        {
            Debug.LogError($"リソース読み込み中にエラー: {path}");
            Debug.LogException(ex);
            throw new ResourceLoadException($"リソースの読み込みに失敗: {path}", ex);
        }
    }

    public bool TryLoadResource<T>(string path, out T resource) where T : UnityEngine.Object
    {
        try
        {
            resource = LoadResource<T>(path);
            return true;
        }
        catch (Exception ex)
        {
            Debug.LogWarning($"リソースの読み込みに失敗: {path} - {ex.Message}");
            resource = null;
            return false;
        }
    }

    // カスタム例外クラス
    public class ResourceNotFoundException : Exception
    {
        public ResourceNotFoundException(string message) : base(message) { }
    }

    public class ResourceLoadException : Exception
    {
        public ResourceLoadException(string message, Exception innerException) 
            : base(message, innerException) { }
    }
}
```

## [](#%E3%82%AB%E3%82%B9%E3%82%BF%E3%83%A0%E4%BE%8B%E5%A4%96%E3%81%AE%E4%BD%9C%E6%88%90)カスタム例外の作成

CustomExceptions.cs

```
using System;

namespace GameExceptions
{
    // ゲーム固有の基底例外
    public class GameException : Exception
    {
        public GameException(string message) : base(message) { }
        public GameException(string message, Exception innerException) 
            : base(message, innerException) { }
    }

    // インベントリ関連の例外
    public class InventoryException : GameException
    {
        public InventoryException(string message) : base(message) { }
    }

    public class InventoryFullException : InventoryException
    {
        public int MaxCapacity { get; }

        public InventoryFullException(int maxCapacity) 
            : base($"インベントリが満杯です（最大: {maxCapacity}）")
        {
            MaxCapacity = maxCapacity;
        }
    }

    public class ItemNotFoundException : InventoryException
    {
        public string ItemId { get; }

        public ItemNotFoundException(string itemId) 
            : base($"アイテムが見つかりません: {itemId}")
        {
            ItemId = itemId;
        }
    }

    // 使用例
    public class InventorySystem
    {
        private const int MaxCapacity = 20;
        private int currentItemCount = 0;

        public void AddItem(string itemId)
        {
            if (currentItemCount >= MaxCapacity)
            {
                throw new InventoryFullException(MaxCapacity);
            }

            // アイテム追加処理
            currentItemCount++;
        }

        public void RemoveItem(string itemId)
        {
            // アイテムが存在しない場合
            throw new ItemNotFoundException(itemId);
        }
    }
}
```

## [](#%E3%82%A8%E3%83%A9%E3%83%BC%E3%83%8F%E3%83%B3%E3%83%89%E3%83%AA%E3%83%B3%E3%82%B0%E3%81%AE%E6%88%A6%E7%95%A5)エラーハンドリングの戦略

### [](#%E4%BE%8B%E5%A4%96%E5%87%A6%E7%90%86%E3%81%AE%E3%83%91%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%B3%E3%82%B9%E6%AF%94%E8%BC%83)例外処理のパフォーマンス比較

手法

パフォーマンス

使用場面

条件分岐

高速

予測可能なエラー、頻繁に呼ばれる処理

Try-Catch

低速

予測不可能なエラー、初期化処理

TryParse/TryGet系

高速

パース処理、辞書アクセス

null条件演算子

高速

nullチェック

### [](#%E4%BD%BF%E3%81%84%E5%88%86%E3%81%91%E3%81%AE%E6%8C%87%E9%87%9D)使い分けの指針

ErrorHandlingStrategy.cs

```
using UnityEngine;
using System.Collections.Generic;

public class ErrorHandlingStrategy : MonoBehaviour
{
    private Dictionary<string, int> itemCounts = new Dictionary<string, int>();

    // ✅ 条件分岐：予測可能なエラー
    public int GetItemCount(string itemId)
    {
        if (string.IsNullOrEmpty(itemId))
        {
            Debug.LogWarning("アイテムIDが空です");
            return 0;
        }

        if (itemCounts.ContainsKey(itemId))
        {
            return itemCounts[itemId];
        }

        return 0;
    }

    // ✅ TryGet：辞書アクセス
    public bool TryGetItemCount(string itemId, out int count)
    {
        return itemCounts.TryGetValue(itemId, out count);
    }

    // ✅ null条件演算子：nullチェック
    public void DamageEnemy(Enemy enemy, int damage)
    {
        enemy?.TakeDamage(damage);
    }

    // ✅ Try-Catch：予測不可能なエラー（外部リソース）
    public void LoadConfiguration()
    {
        try
        {
            string json = System.IO.File.ReadAllText("config.json");
            // JSONパース処理
        }
        catch (System.IO.IOException ex)
        {
            Debug.LogError($"設定ファイル読み込みエラー: {ex.Message}");
            UseDefaultConfiguration();
        }
    }

    private void UseDefaultConfiguration() { /* 実装 */ }
}

public class Enemy : MonoBehaviour
{
    public void TakeDamage(int damage) { /* 実装 */ }
}
```

## [](#%E3%81%BE%E3%81%A8%E3%82%81)まとめ

Unity C#でのエラーハンドリングは、ゲームの信頼性を高めるための重要な要素です。本記事で解説したテクニックを適切に活用することで、堅牢なゲームロジックを構築できます。

### [](#%E9%87%8D%E8%A6%81%E3%83%9D%E3%82%A4%E3%83%B3%E3%83%88)重要ポイント

1.  **具体的な例外をキャッチ** - System.Exceptionの一括処理は避ける
2.  **using文でリソース管理** - finallyブロックでの手動解放より安全
3.  **パフォーマンスを考慮** - Updateループでのtry-catchは避ける
4.  **詳細なログ記録** - Debug.LogExceptionを活用
5.  **カスタム例外の作成** - ゲーム固有のエラーを明確化
6.  **予測可能なエラーは条件分岐** - 例外処理は最後の手段
7.  **適切な例外の再スロー** - 上位層で処理が必要な場合

例外処理は強力なツールですが、適切に使用しないとパフォーマンス低下やコードの複雑化を招きます。通常のプログラムフローには条件分岐を使用し、真に例外的な状況にのみ例外処理を適用しましょう。

**ゲーム開発のご相談はこちら**  
Unity開発やAI統合に関するご相談を承っています  
[https://coconala.com/services/2610064](https://coconala.com/services/2610064)
