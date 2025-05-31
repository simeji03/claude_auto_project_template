#!/usr/bin/env bash
set -e

# 🌸 Ultimate curl | bash detection and self-downloading pattern
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
IS_PIPED=false

# Multiple detection methods for maximum reliability
if [[ "$SCRIPT_SOURCE" == "/dev/stdin" ]] || \
   [[ "$SCRIPT_SOURCE" == "/proc/self/fd/0" ]] || \
   [[ ! -f "$SCRIPT_SOURCE" ]] || \
   [[ "$0" == "bash" ]] || \
   [[ "${AUTO_SETUP_SELF_DOWNLOAD:-}" != "done" && ( ! -t 0 || "$SCRIPT_SOURCE" =~ ^/tmp ) ]]; then

  IS_PIPED=true
fi

if [[ "$IS_PIPED" == "true" && "${AUTO_SETUP_SELF_DOWNLOAD:-}" != "done" ]]; then
  echo "🔄 curl | bash execution detected. Self-downloading for safe execution..." >&2

  # Create temporary file with proper cleanup
  TEMP_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/auto_setup.XXXXXX.sh")
  trap "rm -f '$TEMP_SCRIPT'" EXIT INT TERM

  # Download script to temp file
  if ! curl -sSL https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/auto_setup.sh > "$TEMP_SCRIPT"; then
    echo "❌ Failed to download script. Please check your internet connection." >&2
    exit 1
  fi

  # Verify download
  if [[ ! -s "$TEMP_SCRIPT" ]]; then
    echo "❌ Downloaded script is empty. Please try again." >&2
    exit 1
  fi

  echo "✅ Script downloaded successfully. Executing with proper input handling..." >&2

  # Execute the downloaded script with proper environment
  env AUTO_SETUP_SELF_DOWNLOAD=done bash "$TEMP_SCRIPT"
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
  # Interactive input with explicit terminal handling
  if [[ -t 0 ]]; then
    # Standard terminal input
    echo -n "新しいプロジェクト名を入力してください（英数字・ハイフン・アンダースコアのみ）: " >&2
    read PROJECT
  else
    # Fallback for non-terminal environments
    echo -n "新しいプロジェクト名を入力してください（英数字・ハイフン・アンダースコアのみ）: " >&2
    read PROJECT < /dev/tty
  fi

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
