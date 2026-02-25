---
title: "Claude Codeで自作スキルを上位表示させる方法"
emoji: "📋"
type: "tech"
topics: ["claude", "cli", "カスタマイズ", "productivity", "automation"]
published: true
published_at: 2026-03-05 18:00
---

## はじめに

Claude Codeを使い込んでいくと、自作スキルが増えてきます。そして気づくのが、**スキル一覧での表示順序が思い通りにならない**という課題です。

よく使う自作スキルを上位に表示したいのに下の方に埋もれてしまう。Skill toolの説明文を見ると、たくさんのスキルが羅列されていて探すのに時間がかかる。

この記事では、スキル表示順序の仕組みと、自作スキルを効率的に配置する方法を解説します。

## スキル表示順序の仕組み

Claude Codeには4つのスキルタイプが存在し、それぞれに優先順位が設定されています。

https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview

| スキルタイプ | 配置場所 | 優先順位 |
|------------|---------|---------|
| Managed Skills | Anthropic管理 | 1位（最優先） |
| Personal Skills | `~/.claude/skills/` | 2位 |
| Project Skills | `<project>/.claude/skills/` | 3位 |
| Plugin Skills | プラグイン経由 | 4位（最下位） |

:::message
**ポイント**: Managed SkillsはAnthropicが公式に提供するスキルで、個人では追加・編集できません。自作スキルで上位表示を狙うには**Personal Skills**として配置するのが最も効果的です。
:::

同じスキルタイプ内では**アルファベット順**で表示されます。つまり、スキル名の先頭文字を工夫することで表示順序を調整できます。

## 自作スキルを上位表示させる方法

### アプローチ1：Personal Skillsに配置

`~/.claude/skills/`に配置するだけで、Project Skillsよりも上位に表示されます。

:::message alert
**注意**: Personal Skillsは全プロジェクトで利用可能になります。特定プロジェクトでのみ使いたいスキルはProject Skillsとして配置しましょう。
:::

### アプローチ2：スキル名の接頭辞を工夫

アルファベット順を活用し、よく使うスキルに適切な接頭辞を付けます。

| 接頭辞 | 意味 | 表示順序 |
|-------|------|---------|
| `a-` | 最優先スキル | 最上位 |
| `w-` | 作成系（write） | 上位 |
| `c-` | チェック系（check） | 中位 |
| `z-` | アーカイブ | 最下位 |

:::message
**実践例**: `w-note`（note記事作成）、`w-zenn`（Zenn記事作成）、`c-code`（コードチェック）のように機能別に接頭辞を統一すると、関連スキルがまとまって表示されます。
:::

## フロントマターによる制御

スキルの振る舞いはフロントマターで細かく制御できます。

### user-invocable

`user-invocable: true`でユーザーが明示的にスキルを呼び出せるようになります。`false`（デフォルト）ではSkill toolの説明文に表示されません。

### disable-model-invocation

`disable-model-invocation: true`でモデルの自動呼び出しを防ぎます。破壊的操作を含むスキルやコストが高い処理に設定しましょう。

| user-invocable | disable-model-invocation | 動作 |
|----------------|-------------------------|------|
| `true` | `false` | ユーザーもモデルも呼び出し可能 |
| `true` | `true` | ユーザーのみ呼び出し可能 |
| `false` | `false` | モデルのみ呼び出し可能（内部処理用） |
| `false` | `true` | 誰も呼び出せない（無効化状態） |

### その他のフィールド

```yaml
---
name: my-skill
description: "スキルの説明（Skill tool説明文に表示）"
user-invocable: true
disable-model-invocation: false
model: sonnet
allowed-tools: [Read, Write, Bash]
---
```

| フィールド | 説明 |
|-----------|------|
| `name` | スキル名（必須） |
| `description` | Skill tool説明文に表示される説明 |
| `model` | 使用するモデル（`sonnet`, `haiku`, `opus`） |
| `allowed-tools` | スキル内で使用可能なツール |

https://github.com/anthropics/skills

## スキル管理の運用Tips

スキルが増えてくると、コンテキスト管理も重要になります。

- **新規タスク開始時は`/clear`** -- 関連のないタスクでコンテキストを受け継がない
- **コンテキスト70-85%で`/compact`** -- 重要な情報を保持しつつトークン削減
- **実験的作業は新規セッション** -- `/resume`で過去の会話に戻せる

## まとめ

**スキル表示順序の制御**
1. **Personal Skillsに配置**で上位表示
2. **スキル名の接頭辞**を工夫してアルファベット順を活用
3. **フロントマター**で振る舞いを制御

スキル管理を最適化して、Claude Codeをより快適に使いこなしましょう。

---

**AIキャラクター開発に興味がある方へ**

https://coconala.com/services/3327092

https://coconala.com/services/2610064
