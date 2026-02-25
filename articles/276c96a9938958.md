---
title: "Claude Code: スキルを/検索から非表示にする方法"
emoji: "📌"
type: "tech"
topics:
  - "claudecode"
  - "skills"
  - "agentskills"
published: true
published_at: "2026-01-10 17:00"
---


## はじめに

Claude Codeでカスタムスキルを作成していると、/で検索したときに全てのスキルが表示されて、目的のコマンドが見つけにくくなることがあります。

この記事では、スキルを/検索から非表示にしつつ、コマンド経由での実行は可能にする方法を紹介します。

## この記事のポイント

スキルのfrontmatterに`user-invocable: false`を追加するだけで、/検索から非表示にできます。

```yaml:.claude/skills/review-note-skill/SKILL.md
---
name: review-note
description: note記事のマークダウン記法をチェックするスキル
user-invocable: false  # ← これを追加
---
```

## 問題: /検索が混雑する

Claude Codeでは、skills/ディレクトリ配下のスキルが全て/検索に表示されます。

例えば以下のような構成の場合:

```text:ディレクトリ構成
.claude/
├── commands/
│   └── review-note.md          # ユーザーが実行するコマンド
└── skills/
    └── review-note-skill/
        └── SKILL.md            # 内部で使うスキル
```

**問題点:**
- `/review-note`（コマンド）
- `/review-note-skill`（スキル）

両方が検索に表示され、ユーザーが混乱します。

:::message
**よくある混乱**: 内部で使うスキルまで検索に表示されると、どちらを実行すべきか分かりにくくなります。
:::

## 解決策: user-invocable: false

### 設定方法

スキルのfrontmatterに`user-invocable: false`を追加:

```yaml:.claude/skills/review-note-skill/SKILL.md
---
name: review-note
description: |
  note記事のマークダウン記法を専門的にチェックするスキル。
  共通フォーマット + note固有記法の2つの観点で検証する。
user-invocable: false  # ← 追加
---
```

### 効果

- ✅ `/review-note`（コマンド） → 検索に表示される
- ❌ `/review-note-skill`（スキル） → 検索に表示されない
- ✅ コマンド経由での実行は可能

:::message alert
**注意**: `user-invocable: false`を設定しても、コマンドから参照すれば実行できます。完全に無効化されるわけではありません。
:::

### コマンドからの呼び出し

スキルは非表示でも、コマンド内で参照すれば実行できます:

```markdown:.claude/commands/review-note.md
## 実行スキル

@~/.claude/skills/review-note-skill/SKILL.md を参照して実行。
```

## 使用例: 内部スキルを全て非表示化

以下のようなスキルは、コマンド経由でのみ使用するため、全て非表示にするのが推奨です:

### ドキュメント作成系

```yaml:.claude/skills/prd-writing-skill/SKILL.md
---
name: prd-writing
description: PRD作成ガイド
user-invocable: false
---
```

### レビュー系

```yaml:.claude/skills/review-note-skill/SKILL.md
---
name: review-note
description: note記法チェック
user-invocable: false
---
```

### 記事執筆系

```yaml:.claude/skills/write-note-skill/SKILL.md
---
name: write-note-skill
description: note記事執筆
user-invocable: false
---
```

## メリット

:::message
**UIがスッキリ**: /検索がコマンドだけに絞られ、目的のコマンドが見つけやすくなります。
:::

1. **UIがスッキリ** - /検索がコマンドだけに絞られる
2. **ユーザー体験向上** - 混乱が減り、目的のコマンドが見つけやすい
3. **設計の明確化** - コマンド（UI層）とスキル（ロジック層）の分離が明確になる

## まとめ

- スキルのfrontmatterに`user-invocable: false`を追加
- /検索に表示されなくなる
- コマンド経由での実行は継続可能
- 内部で使うスキルは全て非表示推奨

## 参考

- [Claude Code公式ドキュメント - Settings](https://code.claude.com/docs/en/settings)
- [GitHub Issue #15842](https://github.com/anthropics/claude-code/issues/15842)
