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

# 🎯 Enterprise-grade logging and error handling
readonly LOG_FILE="/tmp/auto_setup_$(date +%s).log"
readonly SCRIPT_VERSION="2.0.0"
readonly REQUIRED_COMMANDS="git gh curl"

# Logging functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

error() {
  log "❌ ERROR: $*"
  exit 1
}

success() {
  log "✅ SUCCESS: $*"
}

warning() {
  log "⚠️  WARNING: $*"
}

# Retry function for critical operations
retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local cmd="$*"

  for ((i=1; i<=max_attempts; i++)); do
    log "Attempt $i/$max_attempts: $cmd"
    if eval "$cmd"; then
      return 0
    else
      if [[ $i -lt $max_attempts ]]; then
        warning "Command failed, retrying in ${delay}s..."
        sleep "$delay"
      else
        error "Command failed after $max_attempts attempts: $cmd"
      fi
    fi
  done
}

# Comprehensive prerequisites check
check_prerequisites() {
  log "🔍 Checking prerequisites..."

  # Check required commands
  for cmd in $REQUIRED_COMMANDS; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "Required command not found: $cmd"
    fi
  done

  # Check GitHub CLI authentication
  if ! gh auth status >/dev/null 2>&1; then
    error "GitHub CLI not authenticated. Please run: gh auth login"
  fi

  # Get GitHub username
  GH_USERNAME=$(gh api user --jq .login 2>/dev/null) || error "Failed to get GitHub username"
  log "GitHub user: $GH_USERNAME"

  # Check GitHub token permissions
  local token_scopes
  token_scopes=$(gh auth status 2>&1 | grep "Token scopes:" | cut -d"'" -f2) || error "Failed to get token scopes"

  for required_scope in "repo" "workflow"; do
    if [[ ! "$token_scopes" =~ $required_scope ]]; then
      error "Missing required GitHub token scope: $required_scope"
    fi
  done

  # Check ANTHROPIC_API_KEY
  if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    error "Environment variable ANTHROPIC_API_KEY not set. Please set it in ~/.zshrc"
  fi

  if [[ ${#ANTHROPIC_API_KEY} -lt 50 ]]; then
    error "ANTHROPIC_API_KEY appears to be invalid (too short)"
  fi

  success "All prerequisites verified"
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
      log "Project name validated: $project_name"
      echo "$project_name"
      return 0
    else
      ((attempts++))
      warning "Invalid project name: '$project_name'"
      echo "   - 英数字・ハイフン・アンダースコアのみ使用可能" >&2
      echo "   - 3-39文字の長さ" >&2
      echo "   - ハイフン・アンダースコアで始まったり終わったりしない" >&2
      echo "   - システム予約語は使用不可" >&2

      if [[ $attempts -eq $max_attempts ]]; then
        error "Too many invalid attempts for project name"
      fi
    fi
  done
}

# Check for existing conflicts
check_conflicts() {
  local project_name="$1"

  # Check local directory
  if [[ -d ~/Projects/"$project_name" ]]; then
    error "Project directory already exists: ~/Projects/$project_name"
  fi

  # Check GitHub repository
  if gh repo view "$GH_USERNAME/$project_name" >/dev/null 2>&1; then
    error "GitHub repository already exists: $GH_USERNAME/$project_name"
  fi

  success "No conflicts found for project: $project_name"
}

# Create and setup local project
setup_local_project() {
  local project_name="$1"
  local project_dir="$HOME/Projects/$project_name"

  log "Creating local project directory..."
  mkdir -p "$project_dir" || error "Failed to create project directory"
  cd "$project_dir" || error "Failed to change to project directory"

  log "Initializing Git repository..."
  git init -b main >/dev/null 2>&1 || error "Failed to initialize Git repository"

  log "Creating initial README..."
  cat > README.md << EOF
# $project_name

Auto-generated project with Claude Code Action integration.

## Getting Started

This project was bootstrapped with Claude Auto Project Template.

## Development

1. Make changes to your code
2. Create a pull request
3. Comment \`@claude\` to invoke AI assistance
4. Let Claude help you build amazing features!

## Features

- 🤖 Claude AI integration
- 🚀 Automated workflows
- 📝 Smart code generation
- 🔄 Continuous improvement

---

Generated on $(date)
EOF

  log "Setting up Claude workflow..."
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

  success "Local project setup completed"
}

# Create GitHub repository with robust error handling
create_github_repo() {
  local project_name="$1"

  log "Creating GitHub repository..."

  # Create repository with retry
  retry 3 2 "gh repo create '$project_name' --private --clone=false --description 'Auto-generated project with Claude integration'"

  # Add remote
  retry 3 1 "git remote add origin https://github.com/$GH_USERNAME/$project_name.git"

  # Verify remote was added
  if ! git remote get-url origin >/dev/null 2>&1; then
    error "Failed to add remote origin"
  fi

  success "GitHub repository created: $GH_USERNAME/$project_name"
}

# Setup GitHub secrets
setup_github_secrets() {
  local project_name="$1"

  log "Setting up GitHub secrets..."

  # Set ANTHROPIC_API_KEY secret
  retry 3 2 "gh secret set ANTHROPIC_API_KEY -b'$ANTHROPIC_API_KEY' -R '$GH_USERNAME/$project_name'"

  # Verify secret was set
  if ! gh secret list -R "$GH_USERNAME/$project_name" | grep -q "ANTHROPIC_API_KEY"; then
    error "Failed to verify ANTHROPIC_API_KEY secret"
  fi

  success "GitHub secrets configured"
}

# Commit and push with robust handling
commit_and_push() {
  local project_name="$1"

  log "Committing initial files..."
  git add . || error "Failed to add files to git"
  git commit -m "chore: bootstrap $project_name with Claude integration

- Add README with project description
- Configure Claude Code Action workflow
- Set up automated development environment
- Ready for AI-assisted development" >/dev/null 2>&1 || error "Failed to commit files"

  log "Pushing to GitHub..."
  retry 5 3 "git push -u origin main"

  success "Code pushed to main branch"
}

# Create feature branch and PR
create_feature_pr() {
  local project_name="$1"

  log "Creating feature branch..."
  git checkout -b feat/initial-development >/dev/null 2>&1 || error "Failed to create feature branch"

  # Add a placeholder file to trigger PR
  cat >> README.md << EOF

## Next Steps

Ready for development! Use @claude in PR comments to start building.

<!-- Development placeholder -->
EOF

  git add README.md || error "Failed to add README changes"
  git commit -m "feat: prepare for initial development

- Add development placeholder
- Ready for Claude assistance
- Trigger first PR workflow" >/dev/null 2>&1 || error "Failed to commit feature changes"

  retry 3 2 "git push -u origin feat/initial-development"

  log "Creating pull request..."
  local pr_url
  pr_url=$(retry 3 2 "gh pr create --title 'feat: Initial development setup' --body 'Initial setup for $project_name

## Ready for Claude!

This PR sets up the project structure and is ready for AI-assisted development.

### What to do next:
1. Comment \`@claude scaffold a simple auto-reply app\` to start development
2. Let Claude build your application automatically
3. Review and iterate on the generated code

Happy coding! 🚀' --head feat/initial-development --base main") || error "Failed to create pull request"

  success "Pull request created: $pr_url"
  return 0
}

# Trigger Claude automatically
trigger_claude() {
  local project_name="$1"

  log "Triggering Claude for automatic code generation..."

  # Get PR number
  local pr_number
  pr_number=$(gh pr view feat/initial-development --json number --jq .number 2>/dev/null) || error "Failed to get PR number"

  # Post Claude comment
  retry 3 2 "gh api repos/$GH_USERNAME/$project_name/issues/$pr_number/comments -f body='@claude scaffold a simple auto-reply application with the following features:

## Requirements
- Simple and clean architecture
- Auto-reply functionality
- Modern UI/UX
- Proper error handling
- Documentation
- Tests

Please create a complete, production-ready application. Thanks!'"

  success "Claude triggered successfully! Check your PR for automatic code generation."
}

# Main execution function
main() {
  log "🚀 Starting Claude Auto Project Setup v$SCRIPT_VERSION"

  # Check if running in existing Git repo
  if [[ -d ".git" ]]; then
    error "Cannot run in existing Git repository. Please run in a clean directory."
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
  log "🎉 SUCCESS: $project_name is ready!"
  echo "" >&2
  echo "📍 Project Location: $HOME/Projects/$project_name" >&2
  echo "🔗 GitHub Repository: https://github.com/$GH_USERNAME/$project_name" >&2
  echo "📋 Pull Request: https://github.com/$GH_USERNAME/$project_name/pulls" >&2
  echo "" >&2
  echo "🤖 Claude is now generating your application!" >&2
  echo "   Check the PR comments for progress updates." >&2
  echo "" >&2
  echo "📊 Setup Log: $LOG_FILE" >&2
}

# Execute main function
main "$@"