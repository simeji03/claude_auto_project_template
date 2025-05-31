#!/usr/bin/env bash
set -e

# 🌸 Professional-grade curl | bash safety test
if [[ ! -t 0 ]] && [[ "${TEST_DIRECT_RUN:-}" != "1" ]]; then
  echo "🔄 Detected piped execution (curl | bash). Testing safe mode..." >&2

  # Read the entire script into memory first
  SCRIPT_CONTENT=$(cat)

  # Execute with proper stdin
  env TEST_DIRECT_RUN=1 bash -c "$SCRIPT_CONTENT" < /dev/tty
  exit $?
fi

echo "✅ Safe mode active! Testing input functionality..." >&2
echo -n "Enter test project name: " >&2
read TEST_PROJECT

echo "✅ You entered: $TEST_PROJECT" >&2
echo "✅ Test completed successfully!" >&2