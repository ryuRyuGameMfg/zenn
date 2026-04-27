---
title: "Figma MCP × Claude CodeでUnity UI Toolkitを8分で変換した実録"
emoji: "🎨"
type: "tech"
topics: ["unity", "claudecode", "figma", "uitoolkit", "mcp"]
published: false
---

## はじめに

UnityのUIを1から手作業で組む、毎回これなの？

uGUI時代、自分はずっとそう思っていた。Inspectorでレイアウトを手動設定し、Asset Storeから購入したUIアセットをプロジェクトに突っ込み、デザイナーから渡されたFigmaファイルを眺めながら寸法を目視で合わせる。「デザインが綺麗でも、Unityに持ってくると崩れる」という経験を何度繰り返しただろう。

Figma MCPとClaude Codeの組み合わせで、この流れが変わりつつある。FigmaのデザインデータをMCP経由でClaude Codeが直接解釈し、UXML/USSに変換できるようになった。**デザイン参照からコード生成までがワンストップになった**（体感）のは確かで、自分のプロジェクト「ai-character-core」で実際にワークフローを通してみた記録をまとめる。

ただ「Figmaで1クリック変換」は現時点では過大期待だ。8分という数字の内訳と、どこまで自動化されてどこで手作業が残るのかを正直に書く。

## Figma MCPとは

Figma MCPは2025年6月4日にFigmaが公式リリースしたMCPサーバーだ（[発表ブログ](https://www.figma.com/blog/introducing-figma-mcp-server/)）。Model Context Protocol経由でFigmaのデザインデータをLLMに渡し、コード生成や構造解析ができる。Claude Codeへのセットアップは1コマンドで完了する。

```bash
claude mcp add --transport http figma https://mcp.figma.com/mcp
```

主なツールは以下のとおり（[公式ツール一覧](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/)）。

| ツール | 役割 |
|---|---|
| `get_design_context` | デザインコンテキスト取得・コード生成 |
| `get_screenshot` | ビジュアルキャプチャ |
| `get_metadata` | レイヤーID・名前・サイズ取得 |
| `generate_figma_design` | Figmaにデザインレイヤーを作成（逆方向） |

今回使ったのは `generate_figma_design`（HTMLモック→Figmaキャプチャ）、`get_metadata`（構造取得）、`get_design_context`（コード参照用コンテキスト取得）の3つ。なお2026年2月には逆方向のClaude Code to Figmaも発表されている（[発表ブログ](https://www.figma.com/blog/introducing-claude-code-to-figma/)）。

:::message
Figma MCPはFigmaのPersonal Access Tokenが必要。接続後に `whoami` ツールで認証確認できる。
:::

## 実際のワークフロー（実測値）

ai-character-coreプロジェクトのキャラクター設定UI（CharacterSettingsUI）を対象に、HTMLモックからUXML/USSへのフル変換フローを実施した（実施日: 2026-04-24）。

```text
Step 1: HTMLモック作成         約2分  Claude Codeで生成
Step 2: HTTPサーバ起動          5秒   python3 -m http.server
Step 3: Figmaキャプチャ         10秒  generate_figma_design
Step 4: Figma構造取得           2秒   get_metadata
Step 5: Figmaコード取得         3秒   get_design_context
Step 6: UXML/USS変換            約5分 Tailwind → USS翻訳（手動）
─────────────────────────────────────────────────
合計                            約8分
```

**合計8分の内、5分は手動のTailwind→USS翻訳作業**だ。MCP自体が速いのは本当だが、自動変換で終わるわけではない。

各Stepのポイントを補足する。

Step 1ではClaude Codeにデザイン仕様を渡してHTMLモックを生成。TailwindのCDNを使うと、Figma MCPがクラス情報を読み取りやすくなる。

Step 3で `generate_figma_design` を実行すると、HTMLの見た目がFigmaのレイヤーとして展開される。この時点でネイティブUIコントロール（selectやinput[range]）は正確にキャプチャされない。

Step 6でFigmaから出力されたコードはReact+Tailwind形式のため、USSへの手動翻訳が必要になる。

:::details Tailwind → USS 変換マッピング（実作業で発生した対応表）

```text
Tailwind             →    USS
──────────────────────────────────────────────────
bg-[#252a40]         →    background-color: #252a40;
flex                 →    不要（VisualElementはdisplay:flexがデフォルト）
flex flex-col        →    flex-direction: column;
gap-[18px]           →    不可（margin-bottom個別指定で代替）
rounded-[12px]       →    border-radius: 12px;
text-[13px]          →    font-size: 13px;
shadow-[...]         →    box-shadow: ...; ※USS対応に制限あり
```

`gap` プロパティはUSSに存在しないため、子要素への `margin-bottom` 指定で代替する手作業が発生する。これが工数の大半を占める。
:::

また変換時に活用したデザイントークン定義は以下のようなものだ。

```css:Common.uss
:root {
    --color-accent: #4f46e5;
    --color-accent-hover: #4338ca;
    --color-bg-primary: #ffffff;
    --color-text-primary: #0f172a;
    --font-size-xs: 16px;
    --font-size-base: 22px;
    --radius-sm: 9px;
    --radius-md: 14px;
    --control-height-md: 54px;
}
```

デザイントークンをCSS変数で定義しておくと、Figmaの値との対応が取りやすくなる。

## 変換精度の実態

### 成功した要素

| 要素 | 変換品質 | 備考 |
|---|---|---|
| レイアウト構造（階層） | 100% | Figmaが正確に階層を保持 |
| カラーパレット | 100% | HEX値完全一致 |
| フォントサイズ・余白 | 95% | ピクセル単位で保持 |
| Flexboxレイアウト | 100% | flex-direction 完全移植 |
| ボーダー・角丸 | 100% | border-radius等そのまま |
| テキストラベル | 100% | 日本語含め正確 |
| タブバーの選択状態 | 100% | 下線・色強調まで保持 |

### 失敗・劣化した要素

| 要素 | 問題 | 原因 |
|---|---|---|
| `<select>` ドロップダウン | オプションが座標(-527,-494)に飛ぶ | HTML→Figma変換時のネイティブUI未対応 |
| スライダー（`<input type="range">`） | つまみが消失、トラックのみ | ネイティブUI非対応 |
| フォントウェイト | Semi Bold指定→Boldに丸め | USS仕様上の制約 |
| アニメーション（:hover） | Tailwindクラスから手動復元必要 | Figmaにアニメ情報が渡らない |

:::message alert
`<select>` や `<input type="range">` のようなブラウザネイティブUIコントロールは、HTMLからFigmaへの変換時に正確にキャプチャされない。これらを含む画面では、変換後の手動修正コストが大きくなる。
:::

結論としてはこうだ。

```text
期待: 「そのままきれいに変換」
  ↓
現実: 「構造80% + スタイル60% + 手動調整40%」（体感）

デザイン参照として使い、実装は手書き+AIになるケースが多い
```

## 推奨ワークフローと向き不向き

実測結果をふまえた現時点の推奨フローは以下のとおり。

```text
Figmaデザイン → MCP経由構造解析 → スクショ参照資料 → UXML手書き+AI
1日              5分               即時             1〜2時間/画面
```

**デザイン参照として割り切る**のが現時点での正しい使い方だ（体感）。MCP経由の構造解析とスクリーンショット取得を「正確な仕様書の入手」として使い、UXML/USSは手書き+Claude Codeの組み合わせで仕上げる。

### 向いているケース

- 構造が単純なフォーム系UI（設定画面・選択肢リスト）
- 色・余白・フォントサイズの忠実な転写が目的の場面
- 「このFigmaデザインをUXMLで再現して」とClaude Codeに依頼する際の参照資料

### 向いていないケース

- インタラクション重視のUI（アニメーション・複雑なイベント）
- `<select>` や `<input type="range">` などネイティブUI要素が多い画面
- Unity UI Toolkitの独自コンポーネント（VisualElementの継承クラス等）を前提とした設計

なお Unity 6 から UI Toolkit が本格推奨され、uGUIはバグ修正のみの維持フェーズに入っている（[Unity公式](https://docs.unity3d.com/6000.3/Documentation/Manual/ui-systems/introduction-ui-toolkit.html) / [uGUI移行ガイド](https://docs.unity3d.com/Manual/UIE-Transitioning-From-UGUI.html)）。新規プロジェクトではUI Toolkitへの移行を前提に考えておくと、このワークフローの恩恵を受けやすい。

## まとめ

uGUI時代は、Figmaのデザインを手元に置きながらInspectorを手動で操作して寸法を合わせていた。それに比べると、Figma MCPとClaude Codeを使ったワークフローで **非デザイナーでも構造とカラーの忠実な転写を8分で完了できる**（体感）のは確かな前進だ。

「1クリックで完成」は現時点では過大期待だが、MCP経由の構造解析+Claude Codeとの対話という形で「AIとの共同作業」が成立している。自分がデザイン意図を伝えながら、AIが変換・調整を担う。この分業が（体感）ワークフローを大幅に改善している。

手動調整が残る部分は正直に書いたが、それも今後のFigma MCPのアップデートで改善されていく可能性がある。今のうちにワークフローに組み込んで慣れておく価値は十分あると思っている。

Claude CodeによるUXML/USS/C#自動生成の実践例は「Claude CodeでUnity UI Toolkit自動生成｜UXML/USS実践ガイド」で詳しく解説している。