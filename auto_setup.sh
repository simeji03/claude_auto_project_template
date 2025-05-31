#!/usr/bin/env bash
set -e

# 🌸 Professional-grade curl | bash safety with heredoc pattern
if [[ ! -t 0 ]] && [[ "${AUTO_SETUP_DIRECT_RUN:-}" != "1" ]]; then
  echo "🔄 Detected piped execution (curl | bash). Switching to safe mode..." >&2

  # Read the entire script into memory first
  SCRIPT_CONTENT=$(cat)

  # Execute with proper stdin
  env AUTO_SETUP_DIRECT_RUN=1 bash -c "$SCRIPT_CONTENT" < /dev/tty
  exit $?
fi

# 🌸 実行環境チェック（既存Gitリポジトリでの実行を防ぐ）
if [[ -d ".git" ]]; then
  echo "❌ 既存のGitリポジトリ内でこのスクリプトを実行することはできません。" >&2
  echo "   別のディレクトリに移動してから実行してください。" >&2
  exit 1
fi

# 🌸 プロジェクト名の入力（検証付き）
PROJECT=""
while true; do
  echo -n "新しいプロジェクト名を入力してください（英数字・ハイフン・アンダースコアのみ）: " >&2
  read PROJECT

  # 空文字チェック
  if [[ -z "$PROJECT" ]]; then
    echo "❌ プロジェクト名は必須です。" >&2
    continue
  fi

  # 不正文字チェック（英数字、ハイフン、アンダースコアのみ許可）
  if [[ ! "$PROJECT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ プロジェクト名には英数字、ハイフン(-)、アンダースコア(_)のみ使用できます。" >&2
    echo "   入力された値: '$PROJECT'" >&2
    PROJECT=""
    continue
  fi

  # 最初と最後の文字チェック（ハイフンで始まったり終わったりしない）
  if [[ "$PROJECT" =~ ^[-_] ]] || [[ "$PROJECT" =~ [-_]$ ]]; then
    echo "❌ プロジェクト名はハイフンやアンダースコアで始まったり終わったりできません。" >&2
    PROJECT=""
    continue
  fi

  # 長さチェック（1-39文字、GitHubの制限）
  if [[ ${#PROJECT} -gt 39 ]]; then
    echo "❌ プロジェクト名は39文字以下にしてください。現在: ${#PROJECT}文字" >&2
    PROJECT=""
    continue
  fi

  echo "✅ プロジェクト名: '$PROJECT' で作成します。" >&2
  break
done

# 🌸 環境変数からAPIキー取得（必須チェック）
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "❌ 環境変数 ANTHROPIC_API_KEY が見つかりません。~/.zshrc に設定してから再実行してください。" >&2
  exit 1
fi
API_KEY="$ANTHROPIC_API_KEY"

# 🌸 プロジェクトディレクトリの重複チェック
if [[ -d ~/Projects/"$PROJECT" ]]; then
  echo "❌ プロジェクトディレクトリ '~/Projects/$PROJECT' は既に存在します。" >&2
  echo "   別のプロジェクト名を使用するか、既存のディレクトリを削除してください。" >&2
  exit 1
fi

# 🌸 プロジェクトディレクトリ作成＆移動
mkdir -p ~/Projects/"$PROJECT" && cd ~/Projects/"$PROJECT"

# 🌸 最初のREADME作成
echo "# $PROJECT" > README.md

# 🌸 GitHubリポジトリ作成＆初期化
git init -b main

# GitHubリポジトリの重複チェック
if gh repo view "$PROJECT" >/dev/null 2>&1; then
  echo "❌ GitHubリポジトリ '$PROJECT' は既に存在します。" >&2
  echo "   別のプロジェクト名を使用してください。" >&2
  exit 1
fi

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

echo "✅ '$PROJECT' が作成され、Claudeがコード生成を開始しました！" >&2
