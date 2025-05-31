#!/usr/bin/env bash
set -e

if [[ -z "$1" ]]; then
  echo "Usage: ./scripts/init.sh <project-name>"
  exit 1
fi

PROJECT=$1
ROOT="$PWD/$PROJECT"

read -rp "➡️  Anthropic API Key を入力: " AN_API_KEY

mkdir -p "$ROOT" && cd "$ROOT"

echo "# $PROJECT" > README.md

git init -b main >/dev/null

gh repo create "$PROJECT" --private --source=. --remote=origin --push -y

gh secret set ANTHROPIC_API_KEY -b"$AN_API_KEY"

mkdir -p .github/workflows
cp "$(dirname "$0")/../.github/workflows/claude.yml" .github/workflows/

git add .github/workflows/claude.yml README.md

git commit -m "chore: bootstrap Claude project" >/dev/null

git push -u origin main

echo "✅  完了！ PR を作成して @claude コマンドを投げてください。"

