#!/usr/bin/env bash
set -e

# 🌸 プロジェクト名の入力（空なら再度聞く）
while [[ -z "$PROJECT" ]]; do
  read -rp "新しいプロジェクト名を入力してください（必須）: " PROJECT
done

# 🌸 環境変数からAPIキー取得（必須チェック）
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "❌ 環境変数 ANTHROPIC_API_KEY が見つかりません。~/.zshrc に設定してから再実行してください。"
  exit 1
fi
API_KEY="$ANTHROPIC_API_KEY"

# 🌸 プロジェクトディレクトリ作成＆移動
mkdir -p ~/Projects/"$PROJECT" && cd ~/Projects/"$PROJECT"

# 🌸 最初のREADME作成
echo "# $PROJECT" > README.md

# 🌸 GitHubリポジトリ作成＆初期化
git init -b main
gh repo create "$PROJECT" --private --source=. --remote=origin --push -y

# 🌸 SecretsにAPIキー登録
gh secret set ANTHROPIC_API_KEY -b"$API_KEY"

# 🌸 Workflow配置
mkdir -p .github/workflows
curl -sL https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/.github/workflows/claude.yml -o .github/workflows/claude.yml

# 🌸 初回コミット
git add .
git commit -m "chore: bootstrap Claude project"
git push -u origin main

# 🌸 ブランチ作成＆PR作成
git switch -c feat/first
echo "\n<!-- placeholder -->" >> README.md
git add README.md
git commit -m "chore: start feat/first"
git push -u origin feat/first
gh pr create --fill --web

# 🌸 PRコメントにClaude呼び出し
PR_NUMBER=$(gh pr view --json number -q .number)
gh api repos/:owner/:repo/issues/"$PR_NUMBER"/comments -f body='@claude scaffold a simple auto-reply app'

echo "✅ '$PROJECT' が作成され、Claudeがコード生成を開始しました！"
