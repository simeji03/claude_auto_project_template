#!/usr/bin/env bash
set -e

# 1️⃣ プロジェクト名を聞く
read -rp "新しいプロジェクト名を入力してください: " PROJECT

# 2️⃣ Claude APIキーを聞く
read -rp "ClaudeのAPIキーを入力してください: " API_KEY

# 3️⃣ ローカル作成＆GitHubリポジトリ作成
mkdir -p ~/Projects/"$PROJECT"
cd ~/Projects/"$PROJECT"
echo "# $PROJECT" > README.md
git init -b main
gh repo create "$PROJECT" --private --source=. --remote=origin --push -y

# 4️⃣ Secrets登録
gh secret set ANTHROPIC_API_KEY -b"$API_KEY"

# 5️⃣ Claudeワークフロー配置
mkdir -p .github/workflows
cat > .github/workflows/claude.yml <<EOF
name: Claude Code Action

on:
  issue_comment:
    types: [created]

jobs:
  claude:
    if: contains(github.event.comment.body, '/claude') || contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - name: Claude Code Action
        uses: anthropics/claude-code-action@v0.0.7
        with:
          anthropic_api_key: \${{ secrets.ANTHROPIC_API_KEY }}
          trigger_phrases: '/claude, @claude'
          mode: pr
EOF

# 6️⃣ Commit & Push
git add .
git commit -m "chore: initial setup"
git push -u origin main

# 7️⃣ 機能ブランチ作成＆PR
git switch -c feat/first
echo "\n<!-- placeholder -->" >> README.md
git add README.md
git commit -m "chore: start feat/first"
git push -u origin feat/first
gh pr create --fill --web

# 8️⃣ PRコメントでClaude指示を自動投稿
PR_URL=$(gh pr view --json url -q .url)
PR_NUMBER=$(gh pr view --json number -q .number)
gh api repos/:owner/:repo/issues/"$PR_NUMBER"/comments -f body='@claude scaffold a simple auto-reply app'

echo "✅ プロジェクト '$PROJECT' が作成されました！ Claudeがコードを書き始めます！"

