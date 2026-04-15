#!/usr/bin/env bash
# run-tests.sh — Tangle config.org, load it, and run ERT tests for config.org features
# Usage: bash ~/.emacs.d/test/run-tests.sh [optional-test-file.el]
set -euo pipefail

CONFIG_ORG="$HOME/.emacs.d/config.org"
CONFIG_EL="$HOME/.emacs.d/config.el"
TEST_DIR="$HOME/.emacs.d/test"
BOOTSTRAP="$HOME/.emacs.d/test/test-bootstrap.el"

# Optional: run a specific test file, or all test files in test/unit/
TEST_FILE="${1:-}"

echo "=== Step 1: Tangle config.org ==="
emacs -q --batch --eval "
(progn
  (require 'org)
  (setq org-babel-default-header-args:emacs-lisp '((:tangle . \"yes\")))
  (org-babel-tangle-file \"$CONFIG_ORG\" \"$CONFIG_EL\"))" 2>&1

echo ""
echo "=== Step 2: Run ERT tests ==="

if [ -n "$TEST_FILE" ]; then
  TEST_LOADS="-l $TEST_FILE"
else
  TEST_LOADS=""
  for f in $(find "$TEST_DIR" -name "*-test.el" -type f | sort); do
    TEST_LOADS="$TEST_LOADS -l $f"
  done
fi

emacs -q --batch \
  -l "$BOOTSTRAP" \
  $TEST_LOADS \
  -f ert-run-tests-batch-and-exit 2>&1

echo ""
echo "=== TESTS COMPLETE ==="
