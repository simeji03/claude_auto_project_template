#!/usr/bin/env bash
set -e

if [[ -z "$1" ]]; then
  echo "Usage: ./scripts/new_feature.sh <branch-name>"
  exit 1
fi

BR=$1

git switch -c "$BR"

echo "\n<!-- placeholder -->" >> README.md

git add README.md
git commit -m "chore: start $BR" >/dev/null
git push -u origin "$BR"

gh pr create --fill --web

