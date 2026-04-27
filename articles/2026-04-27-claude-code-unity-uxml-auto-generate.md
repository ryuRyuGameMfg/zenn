---
title: "Claude CodeでUnity UI Toolkit自動生成｜UXML/USS実践ガイド"
emoji: "🤖"
type: "tech"
topics: ["unity", "claudecode", "uitoolkit", "gamedev", "ai"]
published: false
---

## はじめに

Unity UIのコーディング、全部手書きしてた？

uGUI時代、私はそうだった。InspectorでButtonを配置し、TextをドラッグしてRectTransformを整え、C#では `GameObject.Find("Panel")` でコンポーネントを手探りしていた。命名ミスで実行時にnullが返るたびに何分も無駄にした経験は一度や二度ではない。

Claude CodeとUnity UI Toolkitの組み合わせはその流れを変えた。UXMLの構造はAIが出力し、USSのデザイントークンはプロジェクト全体で共有され、C#は型安全なバインディングで完結する。「全自動」ではないが、 **手書き量は体感で大幅に削減できた** (体感)。

本記事では、実際のプロジェクト（ai-character-core）で使ったコードをそのまま公開しながら、Claude Code × UI Toolkitのワークフローと落とし穴を解説する。

---

## Unity UI Toolkitとは

### uGUI vs UI Toolkit

Unityには現在2つのUIシステムが存在する。

| 項目 | uGUI | UI Toolkit |
|------|------|-----------|
| 構造定義 | Inspector / Hierarchy | UXML（XMLベース） |
| スタイリング | Component設定 | USS（CSSライク） |
| C#バインディング | GetComponent / Find | Q\<T\>()で型安全 |
| バッチング（1,000要素） | 45ドローコール | 5ドローコール（参考値） |
| CPUフレーム時間 | 12.5ms | 4.2ms（参考値） |
| メモリ使用量 | 125MB | 48MB（参考値） |
| 将来性 | バグ修正のみ | Unity公式推奨 |

パフォーマンス参考値の出典: [Angry Shark Studio - Unity UI Toolkit vs uGUI 2025 Guide](https://www.angry-shark-studio.com/blog/unity-ui-toolkit-vs-ugui-2025-guide/)

### Web技術との対応関係

UI Toolkitの設計はWeb技術から明快にマッピングできる。

| Web | UI Toolkit | 役割 |
|-----|-----------|------|
| HTML | UXML | 構造定義 |
| CSS | USS | スタイリング |
| JS | C# | インタラクション |

### Unity 6での位置づけ

[Unity 6公式ドキュメント](https://docs.unity3d.com/6000.3/Documentation/Manual/ui-systems/introduction-ui-toolkit.html) によれば、UI ToolkitはUnity 6から本格的に推奨される標準UIシステムとなった。一方、[uGUIは移行ガイド](https://docs.unity3d.com/Manual/UIE-Transitioning-From-UGUI.html) が整備されており、新機能追加なしのメンテナンスモードに移行している。

:::message
UI ToolkitはUnityの未来のUIスタンダードだ。新規プロジェクトでuGUIを選ぶ理由はほぼない。Unity公式の開発チームが継続的に機能強化を続けており、[2025年6月時点のAI対応状況](https://discussions.unity.com/t/unity-ai-coding-tools-current-state-june-2025/1664497) でもその姿勢が確認できる。
:::

---

## Claude CodeでUXMLを自動生成する実践

### 通知パネルの生成例

ai-character-coreプロジェクトで使用しているNotification.uxmlは以下のようにClaude Codeに依頼して生成した。

依頼文（要約）:
> 「Unity UI Toolkit用の通知パネルUXMLを作って。overlay/panel/header/message/ボタンの階層構造で、CSSクラスでスタイルを当てる形式。デフォルトは非表示。」

生成されたコードをそのまま採用した（命名のみプロジェクト規約に合わせて微調整）。

```xml:Notification.uxml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:VisualElement name="overlay" class="notification-overlay">
        <ui:VisualElement name="panel" class="notification-panel">
            <ui:VisualElement name="header" class="notification-header">
                <ui:Label name="icon" class="notification-icon" />
                <ui:Label name="title" class="notification-title" />
            </ui:VisualElement>
            <ui:Label name="message" class="notification-message" />
            <ui:Button name="btn-ok" class="btn-primary" text="OK" />
        </ui:VisualElement>
    </ui:VisualElement>
</ui:UXML>
```

`display: none` でデフォルト非表示にし、C#からプログラム的に表示する設計だ。overlay要素でモーダル的な制御が可能になる。

### 字幕表示用UXML

シンプルな字幕コンポーネントも同様にAIに生成させた。

```xml:Subtitle.uxml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:VisualElement name="container" class="subtitle-container">
        <ui:Label name="subtitle-text" class="subtitle-text" />
    </ui:VisualElement>
</ui:UXML>
```

構造がシンプルなほどAIの出力精度は高く、**ほぼ修正なしで採用できた** (体感)。

### Common.uss — デザイントークンシステム

プロジェクト全体のスタイルは `Common.uss` に集約している。カラー・フォントサイズ・角丸・コントロール高さをCSSカスタムプロパティ（`:root`）で定義し、全パネルから参照する設計だ。これもClaude Codeとの対話で設計した。

:::details Common.uss（全文）

```css:Common.uss
:root {
    /* アクセントカラー */
    --color-accent: #4f46e5;
    --color-accent-hover: #4338ca;
    --color-accent-soft: #eef2ff;

    /* ニュートラル */
    --color-bg-primary: #ffffff;
    --color-bg-secondary: #f8fafc;
    --color-border: #e2e8f0;

    /* テキスト */
    --color-text-primary: #0f172a;
    --color-text-secondary: #1e293b;
    --color-text-muted: #64748b;
    --color-text-inverse: #ffffff;

    /* ステータス */
    --color-success: #22c55e;
    --color-warning: #f59e0b;
    --color-danger: #ef4444;

    /* フォントサイズ */
    --font-size-xs: 16px;
    --font-size-sm: 18px;
    --font-size-base: 22px;
    --font-size-lg: 24px;

    /* 角丸 */
    --radius-sm: 9px;
    --radius-md: 14px;
    --radius-lg: 18px;
    --radius-full: 9999px;

    /* コントロール高さ */
    --control-height-md: 54px;
    --control-height-lg: 56px;
}
```

:::

1つのCommon.ussを持つことで、カラースキームの変更が全パネルに即時反映される。**AI駆動の開発でもデザインの一貫性を保てる** のはこのトークンシステムのおかげだ (体感)。

---

## C#でのUIバインディングパターン

### Q\<T\>() で型安全にバインドする

CharacterSettingsView.csでのバインディングパターンを示す。`GameObject.Find()` や `GetComponent<T>()` の連鎖は不要で、UIDocument経由でルートを取得後、`Q<T>()` で要素を直接参照する。

```csharp:CharacterSettingsView.cs
using UnityEngine;
using UnityEngine.UIElements;

namespace Core.Character.UI
{
    public class CharacterSettingsView : MonoBehaviour
    {
        // 省略: _config, _tabs, _contents, _activeTab フィールド宣言

        private void OnEnable()  // UIDocument初期化後に確実に呼ばれる
        {
            var root = GetComponent<UIDocument>().rootVisualElement;
            
            // Q<T>()で型安全にバインド
            var tempField = root.Q<FloatField>("field-ai-temperature");
            tempField.RegisterCallback<ChangeEvent<float>>(evt => {
                _config.aiTemperature = evt.newValue;
                ScheduleSave();
            });
        }

        private void SwitchTab(int index)
        {
            // CSSクラストグルでタブ切り替え
            _tabs[_activeTab].RemoveFromClassList("tab-button--active");
            _contents[_activeTab].style.display = DisplayStyle.None;
            
            _activeTab = index;
            _tabs[_activeTab].AddToClassList("tab-button--active");
            _contents[_activeTab].style.display = DisplayStyle.Flex;
        }
    }
}
```

:::message
**公式推奨は `OnEnable()` でのバインディング:** Unity公式ドキュメントはUIDocumentを使ったバインディングを `OnEnable()` で行うパターンを一貫して推奨している。`OnEnable()` はUIDocumentの初期化後に呼ばれるため、`rootVisualElement` が確実に利用可能な状態になっている。
:::

### CSSクラストグルによるタブ切り替え

`SwitchTab()` のパターンは注目に値する。`style.display` の直接操作とCSSクラスの追加/削除を組み合わせることで、UIのビジュアル状態をC#で完全に制御できる。**クラストグル方式はuGUIのGameObject.SetActive()より細かい制御が可能だ** (体感)。

---

## 落とし穴と対処法

### バグ#1: ビルド後フォント消失

エディタ上では問題ないのに、ビルドすると文字が見えなくなるケースがある。

**原因:** UXMLのTextField/LabelにtextSettingsフィールドが残っていると、ビルド時のアセット解決に失敗する。具体的には `{fileID: 0}` 以外の値が混入することで発生する。

**解決策:** 全TextField/LabelのtextSettings参照をInspectorでクリアし、UXML内に対応する記述が残っていないか確認する。

:::message alert
**ビルド前に必ず確認:** エディタでは表示されているのにビルド後に消えるUIバグは再現性が低く、見つけにくい。Claude Codeにレビューさせる際も「textSettings参照の有無を確認して」と明示的に指示するのが確実だ。
:::

### バグ#2: 背景色変更でカメラ位置リセット

背景色を変更した際にカメラ位置がリセットされ、字幕などの配置が崩れる問題がある。

**回避策:** 背景色変更とカメラ操作を別のフレームまたは別のメソッドに分離する。Claude Codeにコード生成させる際は「背景色変更とカメラ操作を同時に行わないコードにして」と制約を明示する。

### USSの制約: gap プロパティが未対応

WebのCSSにある `gap` プロパティはUI Toolkitのゲームランタイムでは動作しない（エディタUIでは一部対応）。**要素間のスペースは `margin-bottom` や `margin-right` で代替する** 必要がある。

---

## まとめ

Claude Code × Unity UI Toolkitで何が変わったか。

| 工程 | uGUI時代 | 現在 |
|------|---------|------|
| UI構造定義 | Inspector手動配置 | UXML生成（AI） |
| スタイリング | Component個別設定 | USS一元管理 |
| C#バインディング | Find() / GetComponent() | Q\<T\>()型安全 |
| デザイン変更 | 全コンポーネント手動更新 | トークン変数1箇所変更 |

「手書きゼロ」は正直ではない。UXMLの細部調整、USSのプロパティ対応確認、バグ対処はまだ人間の目が必要だ。それでも **AIが構造の骨格を作り、人間が精度を上げるワークフロー** (体感) は確実に開発サイクルを短縮した。

uGUI時代の「Inspector頼り・Find()頼り」から卒業したい開発者には、UI Toolkit + Claude Codeの組み合わせを試す価値がある。

なお、[com.unity.dt.app-ui v2.2パッケージ](https://docs.unity3d.com/Packages/com.unity.dt.app-ui@2.2/manual/claude-plugin.html) にはClaude Code連携が公式追加されており、スラッシュコマンド `/app-ui` でApp UIコンポーネントをAIに直接生成させることもできる。[2025年6月のAI coding tools状況レポート](https://discussions.unity.com/t/unity-ai-coding-tools-current-state-june-2025/1664497) でもUnity公式の積極的な連携姿勢が確認できる。FigmaとMCPを組み合わせたデザイン → UXML直接生成のワークフローについては「Figma MCP × Claude CodeでUnity UI Toolkitを8分で変換した実録」で詳しく解説している。
