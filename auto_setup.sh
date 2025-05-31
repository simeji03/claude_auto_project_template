#!/usr/bin/env bash
set -e

# ---1 プロジェクト名だけ聞く--------
read -rp "新しいプロジェクト名を入力してください: " PROJECT

# ---2 APIキーは環境変数から自動取得---
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "❌ 環境変数 ANTHROPIC_API_KEY が見つかりません。設定してから再実行してね。"
  exit 1
fi
API_KEY="$ANTHROPIC_API_KEY"

# ---3 ここから下は今までと同じ---
mkdir -p ~/Projects/"$PROJECT" && cd ~/Projects/"$PROJECT"
echo "# $PROJECT" > README.md
git init -b main
gh repo create "$PROJECT" --private --source=. --remote=origin --push -y
gh secret set ANTHROPIC_API_KEY -b"$API_KEY"

mkdir -p .github/workflows
curl -sL https://raw.githubusercontent.com/あなたのユーザー名/claude_auto_project_template/main/.github/workflows/claude.yml -o .github/workflows/claude.yml

git add .
git commit -m "chore: bootstrap Claude project"
git push -u origin main

git switch -c feat/first
echo "\n<!-- placeholder -->" >> README.md
git add README.md
git commit -m "chore: start feat/first"
git push -u origin feat/first
gh pr create --fill --web

PR_NUMBER=$(gh pr view --json number -q .number)
gh api repos/:owner/:repo/issues/"$PR_NUMBER"/comments -f body='@claude scaffold a simple auto-reply app'

echo "✅ '$PROJECT' が作成され、Claudeがコード生成を開始しました！"
