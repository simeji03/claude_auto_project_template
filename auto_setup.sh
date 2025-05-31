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
readonly SCRIPT_VERSION="2.0.0"
readonly REQUIRED_COMMANDS="git gh curl"

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
  local token_scopes
  token_scopes=$(gh auth status 2>&1 | grep "Token scopes:" | cut -d"'" -f2) || error "トークンスコープの取得に失敗しました"

  for required_scope in "repo" "workflow"; do
    if [[ ! "$token_scopes" =~ $required_scope ]]; then
      error "必要なGitHubトークンスコープが不足しています: $required_scope

🔧 解決方法:
以下のコマンドを実行して再認証してください:
gh auth login --scopes repo,workflow"
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

  # Check local directory
  if [[ -d ~/Projects/"$project_name" ]]; then
    error "プロジェクトディレクトリが既に存在します: ~/Projects/$project_name"
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
  local project_dir="$HOME/Projects/$project_name"

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
    steps:
      - uses: actions/checkout@v4
      - name: Claude Code Action
        uses: anthropics/claude-code-action@v0.0.7
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          trigger_phrases: '/claude, @claude'
          mode: pr
EOF

  success "ローカルプロジェクトのセットアップが完了しました"
}

# Create GitHub repository with robust error handling
create_github_repo() {
  local project_name="$1"

  log "GitHubリポジトリを作成中..."

  # Create repository with retry
  retry 3 2 "gh repo create '$project_name' --private --clone=false --description 'Claude統合により自動生成されたプロジェクト'"

  # Add remote
  retry 3 1 "git remote add origin https://github.com/$GH_USERNAME/$project_name.git"

  # Verify remote was added
  if ! git remote get-url origin >/dev/null 2>&1; then
    error "リモートoriginの追加に失敗しました"
  fi

  success "GitHubリポジトリが作成されました: $GH_USERNAME/$project_name"
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

  log "Claudeの自動コード生成をトリガー中..."

  # Get PR number
  local pr_number
  pr_number=$(gh pr view feat/initial-development --json number --jq .number 2>/dev/null) || error "PR番号の取得に失敗しました"

  # Post Claude comment
  retry 3 2 "gh api repos/$GH_USERNAME/$project_name/issues/$pr_number/comments -f body='@claude 以下の機能を持つシンプルな自動返信アプリケーションを構築してください:

## 要件
- シンプルで分かりやすいアーキテクチャ
- 自動返信機能
- モダンなUI/UX
- 適切なエラーハンドリング
- ドキュメント
- テスト

完全な本番対応アプリケーションを作成してください。よろしくお願いします！'"

  success "Claudeが正常にトリガーされました！PRで自動コード生成を確認してください。"
}

# Main execution function
main() {
  log "🚀 Claude自動プロジェクトセットアップ v$SCRIPT_VERSION を開始"

  # Check if running in existing Git repo
  if [[ -d ".git" ]]; then
    error "既存のGitリポジトリ内では実行できません。クリーンなディレクトリで実行してください。"
  fi

  # Run all setup steps
  check_prerequisites

  local project_name
  project_name=$(get_project_name)

  check_conflicts "$project_name"

  setup_local_project "$project_name"

  create_github_repo "$project_name"

  setup_github_secrets "$project_name"

  commit_and_push "$project_name"

  create_feature_pr "$project_name"

  trigger_claude "$project_name"

  # Final success message
  log "🎉 成功: $project_name の準備が完了しました！"
  echo "" >&2
  echo "📍 プロジェクト場所: $HOME/Projects/$project_name" >&2
  echo "🔗 GitHubリポジトリ: https://github.com/$GH_USERNAME/$project_name" >&2
  echo "📋 プルリクエスト: https://github.com/$GH_USERNAME/$project_name/pulls" >&2
  echo "" >&2
  echo "🤖 Claudeがアプリケーションを生成中です！" >&2
  echo "   進行状況はPRコメントで確認してください。" >&2
  echo "" >&2
  echo "📊 セットアップログ: $LOG_FILE" >&2
}

# Execute main function
main "$@"