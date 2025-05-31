#!/usr/bin/env bash
set -e

# Test self-downloading pattern
if [[ "${BASH_SOURCE[0]}" == "/dev/stdin" ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/0" ]]; then
  echo "🔄 curl | bash detected. Self-downloading..." >&2

  TEMP_SCRIPT=$(mktemp)
  trap "rm -f '$TEMP_SCRIPT'" EXIT

  # For testing, we'll use the actual auto_setup.sh
  curl -s https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/auto_setup.sh > "$TEMP_SCRIPT"

  exec bash "$TEMP_SCRIPT"
fi

echo "🔄 Testing input functionality..." >&2
echo -n "Enter test project name: " >&2
read TEST_PROJECT

echo "✅ You entered: $TEST_PROJECT" >&2
echo "✅ Script source: ${BASH_SOURCE[0]}" >&2