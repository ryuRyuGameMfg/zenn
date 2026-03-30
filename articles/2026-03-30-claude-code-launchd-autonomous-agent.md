---
title: "OpenClawのAPI料金に疲れた人へ：Claude Code × macOS launchd で月額固定の自律AIエージェントを自作する"
emoji: "⚙️"
type: "tech"
topics: ["claude", "claudecode", "macos", "aiagent", "automation"]
published: true
---

## はじめに：「OpenClaw、結局コスパ悪くない？」問題

OpenClaw を導入してみた。Mac mini を買った。いざ動かしてみると、API 料金が思ったより高い。

- OpenRouter 経由で GPT-4o を使うと、1回のタスクで数十円〜数百円が消える
- 自動化すればするほど課金が積み上がる
- ローカル LLM に切り替えようとしたら、M3 Max クラスのマシンが必要と知る

OpenClaw や OpenRouter は優れたツールです。ただし、AIタスクを自動化・ループ実行するほどAPIコストが線形に増えていく構造は避けられません。

OpenRouter の仕組みについては、こちらの記事が参考になります：

https://ai-tsu-ru.com/openrouter-complete-guide/

「もっとシンプルに、**Claude Code のサブスクリプション（月額固定）** だけで自分の MacBook で動かせないか？」

そう思って作ったのが本記事で紹介するシステムです。実際にこの記事自体が、そのシステム（zenn-engine）によって自律生成・管理されています。

---

## このシステムの全体像

**「Claude Code ヘッドレスモード（`-p`）× macOS launchd」** の組み合わせです。外部サービスへの依存はゼロ。

```text
┌─────────────────────────────────────────────┐
│  macOS launchd（スケジューラ）               │
│  └─ 毎週金曜 17:00 に自動起動              │
└──────────────┬──────────────────────────────┘
               │ bash zenn-engine.sh
               ▼
┌─────────────────────────────────────────────┐
│  Claude Code ヘッドレスモード               │
│  echo "$prompt" | claude -p \               │
│    --allowedTools "Read,Write,Edit,Bash"    │
│  └─ 指定フォルダのみ操作可能               │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Telegram 通知（完了・エラー時）             │
└─────────────────────────────────────────────┘
```

---

## コスト比較：OpenClaw + API課金 vs このシステム

| 項目 | OpenClaw + API課金 | このシステム |
|------|-------------------|-------------|
| モデル課金 | $0.002〜$0.03/1Kトークン | **月額固定** |
| 実行基盤 | OpenRouter / 外部API | macOS launchd（無料） |
| 外部サービス依存 | あり | **なし** |
| 自分の Mac で動作 | 可（要常駐サービス） | **MacBook / Mac mini で動作** |
| セキュリティ | サードパーティ API 経由 | **ローカル完結** |

**Claude Code の料金選択肢**:

- **Max プラン（$200/月）**: ほぼ使い放題。ヘッドレスモードも込み。自動化ループを何度回しても追加料金ゼロ。
- **Pro プラン（$20/月）**: 上限が早めに来るが、週1〜2回の実行なら問題なく動く。

API 従量課金がないため、自動化が活発になるほどコスパが改善するのが最大の特徴です。

Claude Code の料金・プランの詳細はこちら（公式日本語ドキュメント）：

https://platform.claude.com/docs/ja/about-claude/pricing

---

## 仕組みの解説

### macOS launchd：外部ツール不要のスケジューラ

`cron` の macOS 版です。`~/Library/LaunchAgents/` に plist ファイルを置くだけで、指定した時刻にスクリプトを自動実行できます。

```xml
<!-- com.ryuryu.zenn-engine.plist（抜粋） -->
<key>ProgramArguments</key>
<array>
  <string>/bin/bash</string>
  <string>/Users/yourname/repository/zenn-engine/zenn-engine.sh</string>
</array>
<key>StartCalendarInterval</key>
<array>
  <dict>
    <key>Weekday</key><integer>5</integer><!-- 金曜 -->
    <key>Hour</key><integer>17</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
</array>
```

登録と起動はターミナルから2行で完了します。

```bash
cp com.ryuryu.zenn-engine.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.ryuryu.zenn-engine.plist
```

n8n や Make.com などの外部ワークフローツールは一切不要です。launchd の設定方法・plist の書き方について詳しくはこちら：

https://zenn.dev/arsaga/articles/4d1a2de87d428a

### Claude Code ヘッドレスモード（`-p` フラグ）

Claude Code には対話モード以外に、パイプ経由でプロンプトを渡すヘッドレスモードがあります。

```bash
# プロンプトをパイプで渡して実行
echo "$prompt" | claude -p --allowedTools "Read,Write,Edit,Bash,Glob,Grep"
```

ポイントは `--allowedTools` です。Claude が使えるツールをホワイトリスト管理できるため、**AI が触れる範囲を明示的にコントロール**できます。

さらに `CLAUDE.md` にプロジェクトのルール（操作可能フォルダ・禁止事項）を書いておくと、それが毎回のプロンプトに自動注入されます。

```markdown
<!-- CLAUDE.md の例 -->
## 操作制約
- 操作可能範囲: ~/repository/zenn-engine/ 内のみ
- articles/ 内の既存ファイルは削除禁止
- git push は articles/ への変更がある場合のみ実行
```

ヘッドレスモードの詳細・出力形式オプションは公式日本語ドキュメントで解説されています：

https://code.claude.com/docs/ja/headless

実際の活用パターン（CI自動化・コードレビュー等）については、こちらのZenn記事が参考になります：

https://zenn.dev/sora_biz/articles/claude-code-headless-mode

---

## フォルダ構造（そのまま使えるテンプレート）

OpenClaw の設計思想（SOUL / MEMORY / AGENT の分離）を参考にしています。

```
project-name/
├── SOUL.md         # 不変の原則（AI は変更不可）
├── STRATEGY.md     # 目標・戦略（AI提案 → ユーザー承認）
├── MEMORY.md       # 常時コンテキスト（~100行に維持）
├── AGENT.md        # 行動アルゴリズム・モード定義
├── state.json      # 実行状態管理（現在のモード・カウンタ）
├── input.md        # ユーザーの指示を書く場所
├── engine.sh       # メインスクリプト（claude -p を呼ぶ）
├── prompts/
│   ├── mode-create.md   # タスクA用プロンプト
│   └── mode-review.md   # タスクB用プロンプト
└── memory/
    ├── metrics.json
    └── daily/      # 日次実行記録
```

`state.json` でモードを管理することで、「create → analyze → improve → rewrite」のような4ステップループを実現しています。

---

## セキュリティ上の利点

OpenRouter などの外部 API を経由する場合、プロンプト内容がサードパーティのサーバーを通ります。このシステムはすべてローカルで完結します。

- **操作範囲の制限**: `CLAUDE.md` に「このフォルダ以外は操作禁止」と書けば、AI はそれに従う
- **ツールの制限**: `--allowedTools` で使用可能なツールをホワイトリスト管理
- **Telegram 通知**: エンドツーエンド暗号化のチャネル経由。完了通知のみ送信し、機密データは外部に出ない

OpenClaw の思想は優れていますが、「第三者 API を経由したくない」「自分のマシン内だけで完結させたい」という場合、このアプローチは有効な選択肢になります。

---

## Telegram 通知の追加（オプション）

完了・エラー時にスマートフォンへ通知を送ることができます。

```bash
# telegram-notify.sh（抜粋）
BOT_TOKEN="your-bot-token"
CHAT_ID="your-chat-id"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=${1}" > /dev/null
```

セットアップは Telegram の BotFather でボットを作成し、トークンを取得するだけです。外出中でもスマホで実行結果を確認できます。Telegram は E2E 暗号化に対応しており、通知チャネルとしてセキュリティ的にも優れています。

BotFather を使ったボット作成・トークン取得の手順はこちら：

https://apidog.com/jp/blog/beginners-guide-to-telegram-bot-api-jp/

Bash から curl でメッセージを送る実装例はこちら：

https://zenn.dev/rescuenow/articles/7940e89422253d

---

## まとめ：OpenClaw に挫折した人こそ試す価値がある

このシステムの本質は「**`echo "$prompt" | claude -p` × macOS launchd**」というシンプルな組み合わせです。

- 月額固定コストで自動化ループを無制限に回せる
- Mac に最初から入っている機能だけで動く（外部ツール不要）
- 操作範囲を制限することでセキュアに運用できる
- Telegram で外出先からも結果を確認できる

OpenClaw の設計思想（記憶・役割・ルールの分離）は非常に優れています。ただし「API 料金の問題を解決したい」「外部サービスへの依存を減らしたい」という場合、このアプローチが有効な選択肢になります。macOS 限定にはなりますが、手元の MacBook Pro で今日から動かせます。

---

## 自分でセットアップするのが難しい場合

この記事で紹介したシステムをベースに、あなたのユースケースに合わせた自律 AI エージェントを構築するサポートを行っています。

- どのフォルダを管理させるか
- どのタスクを自動化するか
- Telegram 通知の設定

など、要件ヒアリングから実装・テストまで対応可能です。

**ご相談・お見積もりはこちら** → ゲーム開発所RYURYU ご相談窓口（ご連絡ください）
