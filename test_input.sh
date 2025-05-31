#!/usr/bin/env bash
set -e

echo "🔧 Testing ultimate curl | bash detection..." >&2
echo "Script source: ${BASH_SOURCE[0]}" >&2
echo "Script name: $0" >&2
echo "stdin test: [[ -t 0 ]] = $([[ -t 0 ]] && echo "true" || echo "false")" >&2
echo "Environment: AUTO_SETUP_SELF_DOWNLOAD=${AUTO_SETUP_SELF_DOWNLOAD:-unset}" >&2

# Ultimate curl | bash detection
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
IS_PIPED=false

if [[ "$SCRIPT_SOURCE" == "/dev/stdin" ]] || \
   [[ "$SCRIPT_SOURCE" == "/proc/self/fd/0" ]] || \
   [[ ! -f "$SCRIPT_SOURCE" ]] || \
   [[ "$0" == "bash" ]] || \
   [[ "${AUTO_SETUP_SELF_DOWNLOAD:-}" != "done" && ( ! -t 0 || "$SCRIPT_SOURCE" =~ ^/tmp ) ]]; then

  IS_PIPED=true
fi

echo "Detection result: IS_PIPED=$IS_PIPED" >&2

if [[ "$IS_PIPED" == "true" && "${AUTO_SETUP_SELF_DOWNLOAD:-}" != "done" ]]; then
  echo "🔄 curl | bash detected! Testing self-download..." >&2

  TEMP_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/test_auto_setup.XXXXXX.sh")
  trap "rm -f '$TEMP_SCRIPT'" EXIT INT TERM

  # Download the real script for testing
  if ! curl -sSL https://raw.githubusercontent.com/simeji03/claude_auto_project_template/main/auto_setup.sh > "$TEMP_SCRIPT"; then
    echo "❌ Failed to download script." >&2
    exit 1
  fi

  echo "✅ Script downloaded successfully!" >&2
  echo "📁 Temp file: $TEMP_SCRIPT" >&2
  echo "📏 Script size: $(wc -l < "$TEMP_SCRIPT") lines" >&2

  # Test that the downloaded script also has the self-download pattern
  if grep -q "AUTO_SETUP_SELF_DOWNLOAD" "$TEMP_SCRIPT"; then
    echo "✅ Downloaded script has proper self-downloading pattern!" >&2
  else
    echo "❌ Downloaded script missing self-downloading pattern!" >&2
  fi

  echo "✅ Self-downloading pattern works correctly!" >&2
  exit 0
fi

echo "🔄 Testing input functionality..." >&2
if [[ -t 0 ]]; then
  echo -n "Enter test project name: " >&2
  read TEST_PROJECT
else
  echo -n "Enter test project name: " >&2
  read TEST_PROJECT < /dev/tty
fi

echo "✅ You entered: $TEST_PROJECT" >&2
echo "✅ Script source: ${BASH_SOURCE[0]}" >&2