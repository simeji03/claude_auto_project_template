#!/usr/bin/env bash
set -e

# 🌸 Professional-grade curl | bash safety with heredoc pattern
if [[ ! -t 0 ]] && [[ "${AUTO_SETUP_DIRECT_RUN:-}" != "1" ]]; then
  echo "🔄 パイプ実行（curl | bash）を検出しました。安全モードに切り替えます..." >&2

  # Read the entire script into memory first
  SCRIPT_CONTENT=$(cat)

  # Execute with proper stdin
  env AUTO_SETUP_DIRECT_RUN=1 bash -c "$SCRIPT_CONTENT" < /dev/tty
  exit $?
fi

# 🎯 Enterprise-grade logging and error handling
readonly LOG_FILE="/tmp/auto_setup_$(date +%s).log"
readonly SCRIPT_VERSION="2.2.0"
readonly REQUIRED_COMMANDS="git gh curl"
readonly CONFIG_FILE="$HOME/.claude_auto_project_config"

# Advanced error handling with rollback
readonly CLEANUP_STACK=()

# Add cleanup action to stack
add_cleanup() {
  local action="$1"
  CLEANUP_STACK+=("$action")
  log "クリーンアップアクションを追加: $action"
}

# Execute all cleanup actions
execute_cleanup() {
  log "⚠️  エラーが発生しました。クリーンアップを実行中..."

  # Execute in reverse order
  for ((i=${#CLEANUP_STACK[@]}-1; i>=0; i--)); do
    local action="${CLEANUP_STACK[i]}"
    log "クリーンアップ実行: $action"
    eval "$action" || warning "クリーンアップアクションが失敗: $action"
  done

  CLEANUP_STACK=()
  log "クリーンアップが完了しました"
}

# Enhanced error function with rollback
error_with_rollback() {
  local message="$*"
  log "❌ エラー: $message"
  execute_cleanup
  exit 1
}

# Trap for automatic cleanup on exit
trap 'execute_cleanup' ERR EXIT

# Configuration management
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE" 2>/dev/null || true
  fi
}

save_config() {
  cat > "$CONFIG_FILE" << EOF
# Claude Auto Project Template Configuration
# Last updated: $(date)

# Recent custom paths (most recent first)
RECENT_CUSTOM_PATHS=(
$(printf '  "%s"\n' "${RECENT_CUSTOM_PATHS[@]}")
)

# User preferences
DEFAULT_PROJECT_LOCATION="${DEFAULT_PROJECT_LOCATION:-}"
PREFERRED_LICENSE="${PREFERRED_LICENSE:-MIT}"
DEFAULT_VISIBILITY="${DEFAULT_VISIBILITY:-private}"

# Project statistics
PROJECT_COUNT=${PROJECT_COUNT:-0}
LAST_PROJECT_DATE="${LAST_PROJECT_DATE:-}"
LAST_PROJECT_NAME="${LAST_PROJECT_NAME:-}"
TOTAL_PRIVATE_REPOS=${TOTAL_PRIVATE_REPOS:-0}
TOTAL_PUBLIC_REPOS=${TOTAL_PUBLIC_REPOS:-0}

# Template usage statistics
$(declare -p TEMPLATE_STATS 2>/dev/null || echo "declare -A TEMPLATE_STATS=()")
EOF
  success "設定が保存されました: $CONFIG_FILE"
}

# Add custom path to recent list
add_recent_path() {
  local new_path="$1"
  local updated_paths=()

  # Add new path first
  updated_paths+=("$new_path")

  # Add existing paths (except duplicates, max 5)
  local count=1
  for path in "${RECENT_CUSTOM_PATHS[@]}"; do
    if [[ "$path" != "$new_path" ]] && [[ $count -lt 5 ]]; then
      updated_paths+=("$path")
      ((count++))
    fi
  done

  RECENT_CUSTOM_PATHS=("${updated_paths[@]}")
}

# Logging functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

error() {
  log "❌ エラー: $*"
  exit 1
}

success() {
  log "✅ 成功: $*"
}

warning() {
  log "⚠️  警告: $*"
}

# Retry function for critical operations
retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local cmd="$*"

  for ((i=1; i<=max_attempts; i++)); do
    log "試行 $i/$max_attempts: $cmd"
    if eval "$cmd"; then
      return 0
    else
      if [[ $i -lt $max_attempts ]]; then
        warning "コマンドが失敗しました。${delay}秒後にリトライします..."
        sleep "$delay"
      else
        error "コマンドが$max_attempts回試行後も失敗しました: $cmd"
      fi
    fi
  done
}

# Comprehensive prerequisites check
check_prerequisites() {
  log "🔍 前提条件をチェック中..."

  # Check required commands
  for cmd in $REQUIRED_COMMANDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "必要なコマンドが見つかりません: $cmd"
    fi
  done

  # Check GitHub CLI authentication
  if ! gh auth status >/dev/null 2>&1; then
    error "GitHub CLIが認証されていません。以下を実行してください: gh auth login --scopes repo,workflow"
  fi

  # Get GitHub username
  GH_USERNAME=$(gh api user --jq .login 2>/dev/null) || error "GitHubユーザー名の取得に失敗しました"
  log "GitHubユーザー: $GH_USERNAME"

  # Check GitHub token permissions
  local token_output
  token_output=$(gh auth status 2>&1)

  log "🔍 GitHubトークン情報をチェック中..."

  for required_scope in "repo" "workflow"; do
    if ! echo "$token_output" | grep -q "$required_scope"; then
      error "必要なGitHubトークンスコープが不足しています: $required_scope

🔧 解決方法:
以下のコマンドを実行して再認証してください:
gh auth login --scopes repo,workflow

🔍 現在の認証情報:
$token_output"
    fi
  done

  # Check ANTHROPIC_API_KEY
  if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    error "環境変数 ANTHROPIC_API_KEY が設定されていません。~/.zshrc に設定してください

🔧 設定方法:
echo 'export ANTHROPIC_API_KEY=\"your-api-key-here\"' >> ~/.zshrc
source ~/.zshrc"
  fi

  if [[ ${#ANTHROPIC_API_KEY} -lt 50 ]]; then
    error "ANTHROPIC_API_KEY が無効です（短すぎます）"
  fi

  success "すべての前提条件が確認されました"
}

# Enhanced project name validation
validate_project_name() {
  local name="$1"

  # Empty check
  if [[ -z "$name" ]]; then
    return 1
  fi

  # Pattern check (alphanumeric, hyphens, underscores only)
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    return 1
  fi

  # Start/end character check
  if [[ "$name" =~ ^[-_] ]] || [[ "$name" =~ [-_]$ ]]; then
    return 1
  fi

  # Length check (GitHub limit: 100, but we use 39 for safety)
  if [[ ${#name} -gt 39 ]] || [[ ${#name} -lt 3 ]]; then
    return 1
  fi

  # Reserved names check
  local reserved_names="aux con prn nul com1 com2 com3 com4 com5 com6 com7 com8 com9 lpt1 lpt2 lpt3 lpt4 lpt5 lpt6 lpt7 lpt8 lpt9"
  if echo "$reserved_names" | grep -qi "\b$name\b"; then
    return 1
  fi

  return 0
}

# Robust project name input
get_project_name() {
  local project_name=""
  local attempts=0
  local max_attempts=5

  while [[ $attempts -lt $max_attempts ]]; do
    echo -n "新しいプロジェクト名を入力してください（英数字・ハイフン・アンダースコア、3-39文字）: " >&2
    read project_name

    if validate_project_name "$project_name"; then
      log "プロジェクト名が検証されました: $project_name"
      echo "$project_name"
      return 0
    else
      ((attempts++))
      warning "無効なプロジェクト名です: '$project_name'"
      echo "   - 英数字・ハイフン・アンダースコアのみ使用可能" >&2
      echo "   - 3-39文字の長さ" >&2
      echo "   - ハイフン・アンダースコアで始まったり終わったりしない" >&2
      echo "   - システム予約語は使用不可" >&2

      if [[ $attempts -eq $max_attempts ]]; then
        error "プロジェクト名の試行回数が上限に達しました"
      fi
    fi
  done
}

# Check for existing conflicts
check_conflicts() {
  local project_name="$1"
  local project_dir="$2"

  # Check local directory
  if [[ -d "$project_dir/$project_name" ]]; then
    error "プロジェクトディレクトリが既に存在します: $project_dir/$project_name"
  fi

  # Check GitHub repository
  if gh repo view "$GH_USERNAME/$project_name" >/dev/null 2>&1; then
    error "GitHubリポジトリが既に存在します: $GH_USERNAME/$project_name"
  fi

  success "プロジェクト '$project_name' に競合はありません"
}

# Create and setup local project
setup_local_project() {
  local project_name="$1"
  local project_dir="$2/$project_name"

  log "ローカルプロジェクトディレクトリを作成中..."
  mkdir -p "$project_dir" || error "プロジェクトディレクトリの作成に失敗しました"
  cd "$project_dir" || error "プロジェクトディレクトリへの移動に失敗しました"

  log "Gitリポジトリを初期化中..."
  git init -b main >/dev/null 2>&1 || error "Gitリポジトリの初期化に失敗しました"

  log "初期READMEを作成中..."
  cat > README.md << EOF
# $project_name

Claude Code Action統合により自動生成されたプロジェクトです。

## はじめに

このプロジェクトはClaude Auto Project Templateでブートストラップされました。

## 開発手順

1. コードを変更
2. プルリクエストを作成
3. コメントで \`@claude\` を呼び出してAIサポートを受ける
4. Claudeと一緒に素晴らしい機能を構築！

## 機能

- 🤖 Claude AI統合
- 🚀 自動化ワークフロー
- 📝 スマートなコード生成
- 🔄 継続的改善

---

生成日: $(date)
EOF

  log "Claudeワークフローを設定中..."
  mkdir -p .github/workflows

  cat > .github/workflows/claude.yml << 'EOF'
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
      issues: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          fetch-depth: 0
      - name: Claude Code Action
        uses: anthropics/claude-code-action@v0.0.7
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          trigger_phrase: '@claude'
          github_token: ${{ secrets.GITHUB_TOKEN }}
EOF

  success "ローカルプロジェクトのセットアップが完了しました"
}

# Create GitHub repository with robust error handling
create_github_repo() {
  local project_name="$1"
  local visibility="$2"

  log "GitHubリポジトリを作成中..."

  # Create repository with retry
  local visibility_flag=""
  if [[ "$visibility" == "public" ]]; then
    visibility_flag="--public"
  else
    visibility_flag="--private"
  fi

  retry 3 2 "gh repo create '$project_name' $visibility_flag --clone=false --description 'Claude統合により自動生成されたプロジェクト'"

  # Add remote
  retry 3 1 "git remote add origin https://github.com/$GH_USERNAME/$project_name.git"

  # Verify remote was added
  if ! git remote get-url origin >/dev/null 2>&1; then
    error "リモートoriginの追加に失敗しました"
  fi

  success "GitHubリポジトリが作成されました: $GH_USERNAME/$project_name ($visibility)"
}

# Setup GitHub secrets
setup_github_secrets() {
  local project_name="$1"

  log "GitHubシークレットを設定中..."

  # Set ANTHROPIC_API_KEY secret
  retry 3 2 "gh secret set ANTHROPIC_API_KEY -b'$ANTHROPIC_API_KEY' -R '$GH_USERNAME/$project_name'"

  # Verify secret was set
  if ! gh secret list -R "$GH_USERNAME/$project_name" | grep -q "ANTHROPIC_API_KEY"; then
    error "ANTHROPIC_API_KEYシークレットの確認に失敗しました"
  fi

  success "GitHubシークレットが設定されました"
}

# Commit and push with robust handling
commit_and_push() {
  local project_name="$1"

  log "初期ファイルをコミット中..."
  git add . || error "ファイルのgit addに失敗しました"
  git commit -m "chore: $project_name をClaude統合でブートストラップ

- プロジェクト説明付きREADMEを追加
- Claude Code Actionワークフローを設定
- 自動化開発環境をセットアップ
- AI支援開発の準備完了" >/dev/null 2>&1 || error "ファイルのコミットに失敗しました"

  log "GitHubにプッシュ中..."
  retry 5 3 "git push -u origin main"

  success "コードがmainブランチにプッシュされました"
}

# Create feature branch and PR
create_feature_pr() {
  local project_name="$1"

  log "フィーチャーブランチを作成中..."
  git checkout -b feat/initial-development >/dev/null 2>&1 || error "フィーチャーブランチの作成に失敗しました"

  # Add a placeholder file to trigger PR
  cat >> README.md << EOF

## 次のステップ

開発準備完了！PRコメントで@claudeを使用して開発を開始してください。

<!-- 開発プレースホルダー -->
EOF

  git add README.md || error "README変更のaddに失敗しました"
  git commit -m "feat: 初期開発の準備

- 開発プレースホルダーを追加
- Claude支援の準備完了
- 最初のPRワークフローをトリガー" >/dev/null 2>&1 || error "フィーチャー変更のコミットに失敗しました"

  retry 3 2 "git push -u origin feat/initial-development"

  log "プルリクエストを作成中..."
  local pr_url
  pr_url=$(retry 3 2 "gh pr create --title 'feat: 初期開発セットアップ' --body '$project_name の初期セットアップ

## Claudeの準備完了！

このPRはプロジェクト構造をセットアップし、AI支援開発の準備が整いました。

### 次にすること:
1. \`@claude 簡単な自動返信アプリを構築してください\` とコメント
2. Claudeに自動的にアプリケーションを構築してもらう
3. 生成されたコードをレビューして改良

ハッピーコーディング！ 🚀' --head feat/initial-development --base main") || error "プルリクエストの作成に失敗しました"

  success "プルリクエストが作成されました: $pr_url"
  return 0
}

# Trigger Claude automatically
trigger_claude() {
  local project_name="$1"
  local template="$2"
  local license="$3"

  log "Claudeの自動コード生成をトリガー中..."

  # Get PR number
  local pr_number
  pr_number=$(gh pr view feat/initial-development --json number --jq .number 2>/dev/null) || error "PR番号の取得に失敗しました"

  # Generate template-specific instructions
  local template_instructions=""
  case $template in
    "react-typescript")
      template_instructions="
## 技術要件
- React 18+ with TypeScript
- Vite for build tool
- ESLint + Prettier configuration
- React Router for navigation
- Styled-components or Tailwind CSS
- Jest + React Testing Library for testing"
      ;;
    "nodejs-express")
      template_instructions="
## 技術要件
- Node.js with Express.js
- TypeScript configuration
- ESLint + Prettier setup
- Jest for testing
- Docker configuration
- API documentation with Swagger"
      ;;
    "python-fastapi")
      template_instructions="
## 技術要件
- Python 3.8+ with FastAPI
- Poetry for dependency management
- Pydantic for data validation
- pytest for testing
- uvicorn for ASGI server
- Docker configuration"
      ;;
    "nextjs-typescript")
      template_instructions="
## 技術要件
- Next.js 14+ with TypeScript
- Tailwind CSS for styling
- ESLint + Prettier configuration
- Jest + Testing Library
- Vercel deployment ready"
      ;;
    "vuejs-typescript")
      template_instructions="
## 技術要件
- Vue.js 3+ with TypeScript
- Vite for build tool
- Vue Router + Pinia
- Vitest for testing
- ESLint + Prettier setup"
      ;;
    "custom")
      template_instructions="
## 技術要件
- 最適な技術スタックを提案してください
- モダンなベストプラクティスを適用
- 完全なプロジェクト構造を作成"
      ;;
    *)
      template_instructions="
## 技術要件
- シンプルで分かりやすいアーキテクチャ
- モダンなベストプラクティス
- 適切なプロジェクト構造"
      ;;
  esac

  local license_note=""
  if [[ "$license" != "none" ]]; then
    license_note="
## ライセンス
- $license ライセンスファイルを作成してください"
  fi

  # Post Claude comment
  retry 3 2 "gh api repos/$GH_USERNAME/$project_name/issues/$pr_number/comments -f body='@claude 以下の要件で完全なアプリケーションを構築してください:

## プロジェクト概要
プロジェクト名: $project_name
テンプレート: $template

$template_instructions

## 基本要件
- 自動返信機能またはプロジェクト固有の機能
- モダンなUI/UX
- 適切なエラーハンドリング
- 包括的なドキュメント
- 単体テスト
- 本番対応の設定

$license_note

## 品質要件
- TypeScriptを使用（該当する場合）
- ESLint/Prettier設定
- CI/CD ready
- Docker対応（該当する場合）
- 詳細なREADME

完全な本番対応アプリケーションを作成してください。よろしくお願いします！'"

  success "Claudeが正常にトリガーされました！PRで自動コード生成を確認してください。"
}

# Get project directory preference
get_project_directory() {
  echo "" >&2
  echo "📁 プロジェクトの作成場所を選択してください:" >&2
  echo "1. ~/Projects/ (推奨)" >&2
  echo "2. ~/Desktop/" >&2
  echo "3. ~/Documents/" >&2
  echo "4. 現在のディレクトリ ($PWD)" >&2

  # Show recent custom paths if available
  local option_count=5
  if [[ ${#RECENT_CUSTOM_PATHS[@]} -gt 0 ]]; then
    echo "--- 最近使用したカスタムパス ---" >&2
    local i=0
    for path in "${RECENT_CUSTOM_PATHS[@]}"; do
      if [[ $i -lt 3 ]]; then  # Show max 3 recent paths
        echo "$option_count. $path" >&2
        ((option_count++))
        ((i++))
      fi
    done
    echo "--- ---" >&2
  fi

  echo "$option_count. 新しいカスタムパス" >&2
  local custom_option=$option_count
  echo "" >&2

  local choice=""
  while true; do
    echo -n "選択してください (1-$option_count): " >&2
    read choice

    case $choice in
      1)
        echo "$HOME/Projects"
        return 0
        ;;
      2)
        echo "$HOME/Desktop"
        return 0
        ;;
      3)
        echo "$HOME/Documents"
        return 0
        ;;
      4)
        echo "$PWD"
        return 0
        ;;
      5|6|7)
        # Check if it's a recent custom path
        local recent_index=$((choice - 5))
        if [[ $recent_index -lt ${#RECENT_CUSTOM_PATHS[@]} ]]; then
          local selected_path="${RECENT_CUSTOM_PATHS[$recent_index]}"
          if [[ -d "$selected_path" ]] || mkdir -p "$selected_path" 2>/dev/null; then
            echo "$selected_path"
            return 0
          else
            warning "パスにアクセスできません: $selected_path"
          fi
        elif [[ $choice -eq $custom_option ]]; then
          # New custom path
          echo -n "新しいカスタムパスを入力してください: " >&2
          read custom_path

          # Expand tilde
          custom_path="${custom_path/#\~/$HOME}"

          if [[ -z "$custom_path" ]]; then
            warning "パスが入力されていません。"
            continue
          fi

          if [[ -d "$custom_path" ]] || mkdir -p "$custom_path" 2>/dev/null; then
            add_recent_path "$custom_path"
            save_config
            success "カスタムパスを保存しました: $custom_path"
            echo "$custom_path"
            return 0
          else
            warning "無効なパスまたは作成できません: $custom_path"
          fi
        fi
        ;;
      *)
        warning "無効な選択です。1-$option_count の数字を入力してください。"
        ;;
    esac
  done
}

# Project template selection
get_project_template() {
  echo "" >&2
  echo "🎨 プロジェクトテンプレートを選択してください:" >&2
  echo "1. Vanilla (基本テンプレート)" >&2
  echo "2. React + TypeScript" >&2
  echo "3. Node.js + Express" >&2
  echo "4. Python + FastAPI" >&2
  echo "5. Next.js + TypeScript" >&2
  echo "6. Vue.js + TypeScript" >&2
  echo "7. カスタム（Claudeに相談）" >&2
  echo "" >&2

  local choice=""
  while true; do
    echo -n "選択してください (1-7): " >&2
    read choice

    case $choice in
      1)
        echo "vanilla"
        return 0
        ;;
      2)
        echo "react-typescript"
        return 0
        ;;
      3)
        echo "nodejs-express"
        return 0
        ;;
      4)
        echo "python-fastapi"
        return 0
        ;;
      5)
        echo "nextjs-typescript"
        return 0
        ;;
      6)
        echo "vuejs-typescript"
        return 0
        ;;
      7)
        echo "custom"
        return 0
        ;;
      *)
        warning "無効な選択です。1-7の数字を入力してください。"
        ;;
    esac
  done
}

# License selection
get_project_license() {
  echo "" >&2
  echo "📄 ライセンスを選択してください:" >&2
  echo "1. MIT (推奨 - 最も自由度が高い)" >&2
  echo "2. Apache 2.0 (特許保護付き)" >&2
  echo "3. GPL v3 (コピーレフト)" >&2
  echo "4. BSD 3-Clause" >&2
  echo "5. ISC" >&2
  echo "6. Unlicense (パブリックドメイン)" >&2
  echo "7. ライセンスなし" >&2
  echo "" >&2

  local choice="${PREFERRED_LICENSE:-1}"
  echo -n "選択してください (1-7) [デフォルト: $choice]: " >&2
  read user_choice

  choice="${user_choice:-$choice}"

  case $choice in
    1|"MIT")
      echo "MIT"
      return 0
      ;;
    2|"Apache")
      echo "Apache-2.0"
      return 0
      ;;
    3|"GPL")
      echo "GPL-3.0"
      return 0
      ;;
    4|"BSD")
      echo "BSD-3-Clause"
      return 0
      ;;
    5|"ISC")
      echo "ISC"
      return 0
      ;;
    6|"Unlicense")
      echo "Unlicense"
      return 0
      ;;
    7|"none")
      echo "none"
      return 0
      ;;
    *)
      warning "無効な選択です。MITライセンスを使用します。"
      echo "MIT"
      return 0
      ;;
  esac
}

# Repository visibility selection
get_repository_visibility() {
  echo "" >&2
  echo "🔒 リポジトリの可視性を選択してください:" >&2
  echo "1. Private (非公開 - 推奨)" >&2
  echo "2. Public (公開)" >&2
  echo "" >&2

  local choice="${DEFAULT_VISIBILITY:-private}"
  if [[ "$choice" == "private" ]]; then
    local default_num="1"
  else
    local default_num="2"
  fi

  echo -n "選択してください (1-2) [デフォルト: $default_num]: " >&2
  read user_choice

  user_choice="${user_choice:-$default_num}"

  case $user_choice in
    1|"private")
      echo "private"
      return 0
      ;;
    2|"public")
      echo "public"
      return 0
      ;;
    *)
      warning "無効な選択です。Privateを使用します。"
      echo "private"
      return 0
      ;;
  esac
}

# Update project statistics
update_project_stats() {
  local project_name="$1"
  local template="$2"
  local license="$3"
  local visibility="$4"

  # Initialize stats if not exists
  if [[ -z "$PROJECT_COUNT" ]]; then
    PROJECT_COUNT=0
  fi

  if [[ -z "$TEMPLATE_STATS" ]]; then
    declare -A TEMPLATE_STATS
  fi

  # Update counters
  ((PROJECT_COUNT++))
  TEMPLATE_STATS["$template"]=$((${TEMPLATE_STATS["$template"]:-0} + 1))
  LAST_PROJECT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
  LAST_PROJECT_NAME="$project_name"

  # Update total stats
  TOTAL_PRIVATE_REPOS=$((${TOTAL_PRIVATE_REPOS:-0} + $([ "$visibility" = "private" ] && echo 1 || echo 0)))
  TOTAL_PUBLIC_REPOS=$((${TOTAL_PUBLIC_REPOS:-0} + $([ "$visibility" = "public" ] && echo 1 || echo 0)))

  success "プロジェクト統計を更新しました (総計: $PROJECT_COUNT プロジェクト)"
}

# Show project statistics
show_project_stats() {
  if [[ "$PROJECT_COUNT" -gt 0 ]]; then
    echo "" >&2
    echo "📊 プロジェクト統計:" >&2
    echo "   総プロジェクト数: $PROJECT_COUNT" >&2
    echo "   最新プロジェクト: $LAST_PROJECT_NAME ($LAST_PROJECT_DATE)" >&2
    echo "   プライベートリポジトリ: ${TOTAL_PRIVATE_REPOS:-0}" >&2
    echo "   パブリックリポジトリ: ${TOTAL_PUBLIC_REPOS:-0}" >&2

    if [[ ${#TEMPLATE_STATS[@]} -gt 0 ]]; then
      echo "   使用テンプレート:" >&2
      for template in "${!TEMPLATE_STATS[@]}"; do
        echo "     - $template: ${TEMPLATE_STATS[$template]} 回" >&2
      done
    fi
    echo "" >&2
  fi
}

# Enhanced validation with detailed error messages
validate_environment() {
  log "🔍 環境検証を実行中..."

  # Check disk space (require at least 100MB)
  local available_space
  available_space=$(df "$PWD" | tail -1 | awk '{print $4}')
  if [[ $available_space -lt 102400 ]]; then  # 100MB in KB
    error_with_rollback "ディスク容量が不足しています。最低100MB必要です。"
  fi

  # Check network connectivity
  if ! curl -s --connect-timeout 5 "https://api.github.com" >/dev/null; then
    error_with_rollback "GitHub APIへの接続に失敗しました。ネットワーク接続を確認してください。"
  fi

  # Check GitHub API rate limit
  local rate_limit
  rate_limit=$(gh api rate_limit --jq '.rate.remaining' 2>/dev/null || echo "0")
  if [[ $rate_limit -lt 10 ]]; then
    error_with_rollback "GitHub API レート制限に近づいています。残り: $rate_limit 回"
  fi

  success "環境検証が完了しました"
}

# Real-time sync and monitoring like Cursor
monitor_claude_progress() {
  local project_name="$1"
  local project_dir="$2"

  log "🤖 Claudeの進捗をリアルタイム監視中..."
  echo "" >&2
  echo "┌─────────────────────────────────────────────────────────┐" >&2
  echo "│  🤖 Claude AI エージェント - リアルタイム監視モード      │" >&2
  echo "│                                                         │" >&2
  echo "│  💡 Cursor風の体験: 変更を自動検出してローカル同期     │" >&2
  echo "└─────────────────────────────────────────────────────────┘" >&2
  echo "" >&2

  local check_count=0
  local max_checks=60  # 30分間監視 (30秒間隔)
  local last_commit=""
  local initial_commit
  initial_commit=$(git rev-parse HEAD)

  echo "🔍 監視開始: feat/initial-development ブランチ" >&2
  echo "⏱️  30秒間隔でチェック (最大30分)" >&2
  echo "🛑 Ctrl+C で監視を停止" >&2
  echo "" >&2

  while [[ $check_count -lt $max_checks ]]; do
    ((check_count++))

    # Progress indicator
    local dots=$(printf "%.0s." $(seq 1 $((check_count % 4))))
    printf "\r🔄 チェック中 %s [%d/%d]" "$dots" "$check_count" "$max_checks" >&2

    # Check for new commits
    git fetch origin feat/initial-development >/dev/null 2>&1
    local latest_commit
    latest_commit=$(git rev-parse origin/feat/initial-development)

    if [[ "$latest_commit" != "$last_commit" ]] && [[ "$latest_commit" != "$initial_commit" ]]; then
      echo "" >&2
      echo "✨ 新しい変更を検出しました！" >&2
      echo "" >&2

      # Show commit details
      git log --oneline -1 "$latest_commit" >&2
      echo "" >&2

      # Pull changes
      log "📥 変更をローカルに同期中..."
      git pull origin feat/initial-development >/dev/null 2>&1

      # Show file changes
      local changed_files
      changed_files=$(git diff --name-only "$last_commit".."$latest_commit" 2>/dev/null || git ls-files)

      if [[ -n "$changed_files" ]]; then
        echo "📁 変更されたファイル:" >&2
        echo "$changed_files" | while read -r file; do
          if [[ -f "$file" ]]; then
            local file_size
            file_size=$(wc -l < "$file" 2>/dev/null || echo "0")
            echo "   ✅ $file ($file_size 行)" >&2
          fi
        done
        echo "" >&2

        # Auto-install dependencies if package.json exists
        if [[ -f "package.json" ]]; then
          log "📦 依存関係を自動インストール中..."
          npm install >/dev/null 2>&1 && success "依存関係のインストール完了" || warning "依存関係のインストールでエラーが発生"
        fi

        # Auto-install Python dependencies if requirements.txt exists
        if [[ -f "requirements.txt" ]]; then
          log "🐍 Python依存関係を自動インストール中..."
          pip install -r requirements.txt >/dev/null 2>&1 && success "Python依存関係のインストール完了" || warning "Python依存関係のインストールでエラーが発生"
        fi

        # Open in preferred editor
        open_in_editor "$project_dir"

        # Show success message
        echo "🎉 同期完了！以下で開発を続行できます:" >&2
        echo "" >&2
        echo "   📂 プロジェクトフォルダ: $project_dir" >&2
        if [[ -f "package.json" ]]; then
          echo "   🚀 開発サーバー起動: npm run dev" >&2
        fi
        if [[ -f "requirements.txt" ]]; then
          echo "   🐍 Python サーバー起動: python app.py" >&2
        fi
        echo "   🔗 GitHub PR: https://github.com/$GH_USERNAME/$project_name/pull/1" >&2
        echo "" >&2

        return 0
      fi

      last_commit="$latest_commit"
    fi

    # Check if Claude is still working (look for recent comments)
    local recent_comments
    recent_comments=$(gh api repos/"$GH_USERNAME"/"$project_name"/issues/1/comments --jq '.[].created_at' 2>/dev/null | tail -1)
    if [[ -n "$recent_comments" ]]; then
      local comment_age
      comment_age=$(date -d "$recent_comments" +%s 2>/dev/null || echo "0")
      local current_time
      current_time=$(date +%s)
      local age_minutes=$(( (current_time - comment_age) / 60 ))

      if [[ $age_minutes -lt 5 ]]; then
        printf " (Claudeが作業中...)" >&2
      fi
    fi

    sleep 30
  done

  echo "" >&2
  warning "監視時間が終了しました。手動で確認してください: https://github.com/$GH_USERNAME/$project_name/pull/1"
}

# Smart editor detection and opening
open_in_editor() {
  local project_dir="$1"

  # Detect preferred editor
  if command -v cursor >/dev/null 2>&1; then
    log "🎯 Cursorでプロジェクトを開いています..."
    cursor "$project_dir" >/dev/null 2>&1 &
  elif command -v code >/dev/null 2>&1; then
    log "💻 VS Codeでプロジェクトを開いています..."
    code "$project_dir" >/dev/null 2>&1 &
  elif command -v subl >/dev/null 2>&1; then
    log "📝 Sublime Textでプロジェクトを開いています..."
    subl "$project_dir" >/dev/null 2>&1 &
  else
    log "📂 Finderでプロジェクトフォルダを開いています..."
    open "$project_dir" >/dev/null 2>&1 &
  fi
}

# Main execution function
main() {
  log "🚀 Claude自動プロジェクトセットアップ v$SCRIPT_VERSION を開始"

  # Load user configuration
  load_config

  # Enhanced environment validation
  validate_environment

  # Check if running in existing Git repo
  if [[ -d ".git" ]]; then
    error "既存のGitリポジトリ内では実行できません。クリーンなディレクトリで実行してください。"
  fi

  # Run all setup steps
  check_prerequisites

  local project_name
  project_name=$(get_project_name)

  local project_dir
  project_dir=$(get_project_directory)

  check_conflicts "$project_name" "$project_dir"

  local template
  template=$(get_project_template)

  local license
  license=$(get_project_license)

  local visibility
  visibility=$(get_repository_visibility)

  # Setup with cleanup tracking
  setup_local_project "$project_name" "$project_dir"
  add_cleanup "rm -rf '$project_dir/$project_name' 2>/dev/null || true"

  create_github_repo "$project_name" "$visibility"
  add_cleanup "gh repo delete '$GH_USERNAME/$project_name' --yes 2>/dev/null || true"

  setup_github_secrets "$project_name"

  commit_and_push "$project_name"

  create_feature_pr "$project_name"

  trigger_claude "$project_name" "$template" "$license"

  # Update project statistics
  update_project_stats "$project_name" "$template" "$license" "$visibility"

  # Save configuration with new stats
  save_config

  # Show project statistics
  show_project_stats

  # Clear cleanup stack on success
  CLEANUP_STACK=()

  # Final success message
  log "🎉 成功: $project_name の準備が完了しました！"
  echo "" >&2
  echo "=========================================" >&2
  echo "🎊 プロジェクト作成完了！" >&2
  echo "=========================================" >&2
  echo "📍 プロジェクト場所: $project_dir/$project_name" >&2
  echo "🔗 GitHubリポジトリ: https://github.com/$GH_USERNAME/$project_name" >&2
  echo "📋 プルリクエスト: https://github.com/$GH_USERNAME/$project_name/pulls" >&2
  echo "" >&2

  # Interactive next steps (Cursor-style UX)
  echo "🚀 次に何をしますか？" >&2
  echo "1. 🤖 Claudeの進捗をリアルタイムで監視 (推奨)" >&2
  echo "2. 🎯 今すぐCursorで開く" >&2
  echo "3. 💻 VS Codeで開く" >&2
  echo "4. 📂 Finderで開く" >&2
  echo "5. 🌐 GitHubでPRを確認" >&2
  echo "6. 📊 統計のみ表示して終了" >&2
  echo "" >&2

  local choice=""
  echo -n "選択してください (1-6) [デフォルト: 1]: " >&2
  read choice
  choice="${choice:-1}"

  case $choice in
    1)
      echo "" >&2
      echo "🤖 Claudeの作業をリアルタイムで監視します..." >&2
      monitor_claude_progress "$project_name" "$project_dir/$project_name"
      ;;
    2)
      if command -v cursor >/dev/null 2>&1; then
        log "🎯 Cursorで開いています..."
        cursor "$project_dir/$project_name" &
        echo "✅ Cursorでプロジェクトを開きました！" >&2
      else
        warning "Cursorがインストールされていません。VS Codeで開きます..."
        code "$project_dir/$project_name" &
      fi
      ;;
    3)
      log "💻 VS Codeで開いています..."
      code "$project_dir/$project_name" &
      echo "✅ VS Codeでプロジェクトを開きました！" >&2
      ;;
    4)
      log "📂 Finderで開いています..."
      open "$project_dir/$project_name" &
      echo "✅ Finderでフォルダを開きました！" >&2
      ;;
    5)
      log "🌐 GitHubでPRを開いています..."
      open "https://github.com/$GH_USERNAME/$project_name/pull/1" &
      echo "✅ ブラウザでPRを開きました！" >&2
      ;;
    6)
      echo "📊 統計のみ表示して終了します。" >&2
      ;;
    *)
      warning "無効な選択です。統計を表示して終了します。"
      ;;
  esac

  echo "" >&2
  echo "💡 いつでも以下のコマンドでアクセスできます:" >&2
  echo "   cd '$project_dir/$project_name'" >&2
  echo "   gh pr view 1 --web  # PRをブラウザで開く" >&2
  echo "" >&2
  echo "📊 セットアップログ: $LOG_FILE" >&2
  echo "=========================================" >&2
}

# Execute main function
main "$@"