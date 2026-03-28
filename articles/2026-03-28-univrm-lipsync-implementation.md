---
title: "UniVRM 2.0 で口パク（リップシンク）を実装する方法【VRM 1.0対応】"
emoji: "🎤"
type: "tech"
topics: ["Unity", "UniVRM", "VRM", "リップシンク", "uLipSync"]
published: true
---

VRM キャラクターに口パクを付けようとすると、すぐに気づく。検索して出てくる情報の大半が VRM 0.x 時代のものであり、コードをそのままコピーしても動かない。`VRMBlendShapeProxy` を使っているチュートリアルは VRM 0.x 用で、UniVRM 2.0（VRM 1.0）では API が根本から変わっている。

この記事では VRM 1.0 対応のリップシンクを、シンプルな振幅ベースの実装から uLipSync を使った本格実装まで順番に解説する。

## VRM 0.x と VRM 1.0 の API 差異

まずここを押さえないと何も始まらない。**VRM 0.x と VRM 1.0 ではブレンドシェイプ操作の API が全く異なる。**

| 項目 | VRM 0.x | VRM 1.0 (UniVRM 2.0) |
|------|---------|----------------------|
| コンポーネント | VRMBlendShapeProxy | Vrm10Instance.Runtime.Expression |
| 設定メソッド | proxy.SetValues(Dictionary) | expression.SetWeight(key, float) |
| 口パク Enum | BlendShapePreset.A/I/U/E/O | ExpressionKey.Aa/Ih/Ou/Ee/Oh |
| uLipSync連携 | uLipSyncBlendShape | uLipSyncExpressionVRM |

以降のコードはすべて VRM 1.0（UniVRM 2.0）を前提とする。プロジェクトの Scripting Define Symbols に `USE_VRM10` が設定されているか事前に確認しておく。

## 方法1: Unity 標準マイク + 振幅ベースの簡易リップシンク

最速で動かしたい場合はこれ。外部パッケージ不要で、5分あれば口が動き始める。

仕組みは単純で、マイク入力の音量（振幅）を「あ」の口の開き具合にそのままマッピングするだけ。母音の区別はないが、話しているかどうかをビジュアルに伝えるだけなら十分機能する。

```csharp
using UnityEngine;
using UniVRM10;

public class SimpleLipSync : MonoBehaviour
{
    [SerializeField] private Vrm10Instance _vrmInstance;
    private AudioSource _audioSource;
    private const int SAMPLE_COUNT = 256;
    private float[] _samples = new float[SAMPLE_COUNT];

    void Start()
    {
        _audioSource = GetComponent<AudioSource>();
        // デフォルトマイクを開始（10秒ループ、44100Hz）
        var clip = Microphone.Start(null, true, 10, 44100);
        // マイクの準備完了を待つ
        while (Microphone.GetPosition(null) <= 0) { }
        _audioSource.clip = clip;
        _audioSource.loop = true;
        _audioSource.mute = true; // スピーカーへの出力を無音化
        _audioSource.Play();
    }

    void Update()
    {
        _audioSource.GetOutputData(_samples, 0);
        float volume = 0f;
        foreach (var s in _samples) volume += Mathf.Abs(s);
        volume /= SAMPLE_COUNT;

        // 音量を「あ」の口の開き具合にマッピング
        float weight = Mathf.Clamp01(volume * 20f);
        _vrmInstance.Runtime.Expression.SetWeight(ExpressionKey.Aa, weight);
    }

    void OnDestroy()
    {
        Microphone.End(null);
    }
}
```

`_audioSource.mute = true` にしている理由は、マイク音声がスピーカーからハウリングするのを防ぐため。`GetOutputData` はミュート状態でもサンプルを取れるので問題ない。

乗数の `20f` は環境によって調整が必要。静かな室内なら `10f`、騒がしい環境なら `5f` 程度から試す。

## 方法2: uLipSync を使った高品質リップシンク

「あいうえお」を正確に区別したい場合は uLipSync を使う。MFCC（メル周波数ケプストラム係数）解析で母音5種を推定するため、精度が格段に上がる。

### インストール

Package Manager の「Add package from git URL」に以下を入力:

```
https://github.com/hecomi/uLipSync.git#upm
```

### ランタイム初期化コード

Inspector から手動でコンポーネントを積む方法もあるが、VRM はランタイムロードが一般的なのでコードで完結させる。

```csharp
using UnityEngine;
using UniVRM10;
using uLipSync;

public class ULipSyncInitializer : MonoBehaviour
{
    [SerializeField] private GameObject _vrmObject;
    [SerializeField] private Profile _lipSyncProfile;

    void Start()
    {
        // 1. ExpressionVRM コンポーネント追加
        var expressionVrm = _vrmObject.AddComponent<uLipSyncExpressionVRM>();

        // 2. 音素 → Expression マッピング
        expressionVrm.AddBlendShape("A", ExpressionPreset.aa.ToString());
        expressionVrm.AddBlendShape("I", ExpressionPreset.ih.ToString());
        expressionVrm.AddBlendShape("U", ExpressionPreset.ou.ToString());
        expressionVrm.AddBlendShape("E", ExpressionPreset.ee.ToString());
        expressionVrm.AddBlendShape("O", ExpressionPreset.oh.ToString());

        // 3. uLipSync 本体追加とプロファイル設定
        var lipSync = _vrmObject.AddComponent<uLipSync.uLipSync>();
        lipSync.profile = _lipSyncProfile;
        lipSync.outputSoundGain = 0f; // マイク音声を出力しない

        // 4. コールバック登録
        lipSync.onLipSyncUpdate.AddListener(expressionVrm.OnLipSyncUpdate);

        // 5. AudioSource と マイク入力コンポーネント
        _vrmObject.AddComponent<AudioSource>();
        _vrmObject.AddComponent<uLipSyncMicrophone>();
    }
}
```

`Profile` は uLipSync が提供するキャリブレーション済みの音声プロファイル。**プロファイルなしでは母音推定が機能しない**ため、必ず事前にキャリブレーション（"あいうえお" を録音して各母音のMFCCを学習させる手順）を済ませておく。デモ用のプロファイルアセットがパッケージに同梱されているので、動作確認はそれで十分。

`outputSoundGain = 0f` にしているのは方法1と同じ理由。マイク音声をそのまま出力するとハウリングするため。

## よくあるハマりポイント

実装していて詰まるのは大体このどれか。

**`uLipSyncBlendShape` と `uLipSyncExpressionVRM` の混同**
VRM 0.x 向けのチュートリアルは `uLipSyncBlendShape` を使う。VRM 1.0 では `uLipSyncExpressionVRM` が正解。コンポーネント名が似ているため、古い記事を参考にすると誤って 0.x 用を積んでしまう。

**`USE_VRM10` Scripting Define が未設定**
Project Settings → Player → Scripting Define Symbols に `USE_VRM10` を追加しないと、VRM 1.0 用のクラスがコンパイル対象にならない。`Vrm10Instance` が見つからないビルドエラーが出たらまずここを確認。

**BlendShape の競合**
複数のシステムが同一の Expression を同時に書き換えると値が競合する。AnimationClip でフェイシャルを動かしながらリップシンクを重ねたい場合は、Animator の Avatar Mask か Additive レイヤーで制御範囲を分離する。`ImmediatelySetValue` は現在非推奨で、`SetWeight` で統一されている。

**`Vrm10Instance` が null になる**
VRM のロード完了前に `Start()` や `Awake()` でアクセスすると null になる。ランタイムロードには `await Vrm10.LoadPathAsync()` のような非同期 API を使い、完了後に初期化処理を走らせる設計にする。

## まとめ

- **5分で動かす**: 標準 Microphone API + 振幅ベース。`SimpleLipSync` を積むだけ
- **母音を区別する**: uLipSync + `uLipSyncExpressionVRM` でプロ品質の口パク
- **VRM 1.0 の鉄則**: ブレンドシェイプ操作は必ず `Vrm10Instance.Runtime.Expression.SetWeight()` を使う

VRM 0.x の情報に惑わされず、UniVRM 2.0 のドキュメントと本記事のコードを組み合わせれば、詰まるポイントはほぼなくなるはず。
