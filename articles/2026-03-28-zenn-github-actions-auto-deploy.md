---
title: "Zenn × GitHub Actions で自動デプロイを設定する方法【textlint + PR プレビュー対応】"
emoji: "🚀"
type: "tech"
topics: ["Zenn", "GitHubActions", "GitHub", "CI", "textlint"]
published: true
---

## はじめに：Zenn CLI × GitHub の標準構成を超える

Zenn の公式ドキュメントでは「GitHub リポジトリと連携して push したら自動デプロイ」という構成が紹介されています。しかしこの標準構成には次の課題があります。

- **誤字・表記ゆれがそのまま公開される**（レビューなし）
- **PR を出しても記事プレビューが見えない**（レビュアーがローカル環境を用意する必要がある）
- **複数ブランチ運用で記事が意図せず公開されるリスク**がある

本記事では、GitHub Actions を使って以下の3段階構成を実装する方法を解説します。

1. **textlint による日本語校正チェック**（PR 作成時に自動実行）
2. **main ブランチへのマージで Zenn に自動デプロイ**（Zenn GitHub 連携）
3. **PR ごとに記事プレビュー URL をコメント投稿**（オプション）

実際にこのリポジトリ（zenn-engine）で稼働している構成をベースにしています。

---

## 前提条件

- Zenn アカウントと GitHub リポジトリを連携済み
- Node.js 18 以上がローカルにインストール済み
- `zenn-cli` がインストール済み（`npx zenn`で動作確認）

Zenn CLI の初期セットアップがまだの場合は先に公式ドキュメントを参照してください。

---

## Step 1：textlint の導入

### パッケージのインストール

```bash
npm install --save-dev textlint \
  textlint-rule-preset-ja-technical-writing \
  textlint-rule-preset-jtf-style \
  textlint-rule-spellcheck-tech-word \
  textlint-filter-rule-comments
```

`preset-ja-technical-writing` は技術文書向けの日本語ルールセットです。「である調・ですます調の混在」「1文の長さ」「半角スペースの有無」などをチェックします。

### .textlintrc の設定

プロジェクトルートに `.textlintrc` を作成します。

```json
{
  "filters": {
    "comments": true
  },
  "rules": {
    "preset-ja-technical-writing": {
      "sentence-length": {
        "max": 100
      },
      "no-exclamation-question-mark": false,
      "no-doubled-joshi": {
        "min_interval": 1,
        "strict": false
      }
    },
    "preset-jtf-style": {
      "2.1.6.カンマ": false,
      "2.2.1.ひらがなと漢字の使い分け": false
    }
  }
}
```

`no-exclamation-question-mark` を `false` にしているのは、Zenn 記事では感嘆符を使う場面があるためです。プロジェクトのスタイルに合わせて調整してください。

### ローカルでの動作確認

```bash
# articles/ 以下の全 .md ファイルをチェック
npx textlint "articles/**/*.md"

# 自動修正可能な箇所を修正
npx textlint --fix "articles/**/*.md"
```

---

## Step 2：GitHub Actions ワークフローの作成

`.github/workflows/` ディレクトリを作成し、以下の2つのワークフローファイルを配置します。

### ワークフロー 1：PR 時の textlint チェック

```yaml
# .github/workflows/textlint.yml
name: textlint

on:
  pull_request:
    paths:
      - "articles/**"
      - "books/**"

jobs:
  textlint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run textlint
        run: npx textlint "articles/**/*.md" "books/**/*.md"
```

`paths` フィルターで `articles/` または `books/` が変更された PR にのみ実行されます。不要なワークフロー起動を防げます。

### ワークフロー 2：main マージ後のデプロイ確認

Zenn の GitHub 連携は push をトリガーに自動で動くため、追加の deploy ワークフローは不要です。ただし、**デプロイ後に記事 URL をコメントで通知したい場合**は以下を追加します。

```yaml
# .github/workflows/notify-deploy.yml
name: Notify Deploy

on:
  push:
    branches:
      - main
    paths:
      - "articles/**"

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Get changed articles
        id: changed
        run: |
          SLUGS=$(git diff --name-only HEAD~1 HEAD -- 'articles/*.md' \
            | sed 's|articles/||' | sed 's|\.md||' | tr '\n' ' ')
          echo "slugs=$SLUGS" >> $GITHUB_OUTPUT

      - name: Post to Slack (optional)
        if: steps.changed.outputs.slugs != ''
        run: |
          echo "デプロイされた記事: ${{ steps.changed.outputs.slugs }}"
          # Slack Webhook を使う場合はここに追加
```

---

## Step 3：PR プレビュー URL の自動コメント（オプション）

PR を出したときに「この記事のプレビューはここで見られます」とコメントが来ると、レビューが格段に楽になります。

Zenn CLI の `zenn preview` をクラウドで動かすのは難しいため、**PR ブランチの記事ファイルへの直接リンク**と **GitHub の blob URL** をコメントする方式を採用します。

```yaml
# .github/workflows/pr-preview-comment.yml
name: PR Preview Comment

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - "articles/**"

permissions:
  pull-requests: write

jobs:
  comment:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Get new/changed articles
        id: articles
        run: |
          BASE=${{ github.event.pull_request.base.sha }}
          HEAD=${{ github.event.pull_request.head.sha }}
          FILES=$(git diff --name-only $BASE $HEAD -- 'articles/*.md' | head -5)
          echo "files<<EOF" >> $GITHUB_OUTPUT
          echo "$FILES" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Post preview comment
        uses: actions/github-script@v7
        with:
          script: |
            const files = `${{ steps.articles.outputs.files }}`.trim().split('\n').filter(Boolean);
            if (files.length === 0) return;

            const repo = context.repo;
            const sha = context.payload.pull_request.head.sha;
            const branch = context.payload.pull_request.head.ref;

            const links = files.map(f => {
              const slug = f.replace('articles/', '').replace('.md', '');
              const blobUrl = `https://github.com/${repo.owner}/${repo.repo}/blob/${branch}/${f}`;
              return `- \`${slug}\`: [GitHub で確認](${blobUrl})`;
            }).join('\n');

            const body = `## 記事プレビュー\n\n変更された記事:\n${links}\n\n> Zenn 公開後のプレビュー: \`zenn preview\` をローカルで実行してください。`;

            await github.rest.issues.createComment({
              ...repo,
              issue_number: context.issue.number,
              body
            });
```

このワークフローを有効にするには、リポジトリの Settings → Actions → General → Workflow permissions で「Read and write permissions」を有効にしてください。

---

## 完成後の運用フロー

```
feature/new-article ブランチで記事を書く
    ↓
PR を作成する
    ↓
textlint が自動チェック（失敗したら修正）
    ↓
PR コメントに変更記事の GitHub リンクが投稿される
    ↓
レビュー・承認
    ↓
main にマージ
    ↓
Zenn が自動デプロイ（記事が公開される）
    ↓
（オプション）デプロイ通知が Slack に届く
```

---

## まとめ

本記事で構築した GitHub Actions 構成のポイントをまとめます。

| 機能 | ワークフローファイル | トリガー |
|------|------------------|---------|
| textlint 校正 | `textlint.yml` | PR 作成・更新時 |
| デプロイ通知 | `notify-deploy.yml` | main へのマージ時 |
| PR プレビューコメント | `pr-preview-comment.yml` | PR 作成・更新時 |

標準の Zenn × GitHub 連携に「textlint による品質ゲート」と「PR プレビューコメント」を加えることで、記事の品質管理を自動化できます。

特に複数人で Zenn リポジトリを管理している場合や、自律的に記事を生成・公開するパイプラインを構築している場合に効果的です。自律コンテンツエンジン（zenn-engine）との組み合わせで、生成から公開まで完全自動化できます。
