#!/usr/bin/env bash
# run-tests.sh — Tangle config.org, load it, and run ERT tests for config.org features
# Usage: bash ~/.emacs.d/test/run-tests.sh [optional-test-file.el]
set -euo pipefail

CONFIG_ORG="$HOME/.emacs.d/config.org"
CONFIG_EL="$HOME/.emacs.d/config.el"
TEST_DIR="$HOME/.emacs.d/test"

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
  TEST_FILES="$TEST_FILE"
else
  TEST_FILES=$(find "$TEST_DIR" -name "*-test.el" -type f | sort)
fi

# Build the load commands for test files
LOAD_CMDS=""
for f in $TEST_FILES; do
  LOAD_CMDS="$LOAD_CMDS (load \"$f\")"
done

emacs -q --batch \
  --eval "(progn
  ;; Load org-mode first (needed by config.el)
  (require 'org)
  (require 'org-agenda)
  (require 'cl-lib)
  ;; Load the tangled config (ignore errors from package-specific setup)
  (condition-case err
    (load \"$CONFIG_EL\" t)
    (error (message \"Config load warning (non-fatal): %s\" err)))
  ;; Load test files
  $LOAD_CMDS
  ;; Run tests
  (ert-run-tests-batch-and-exit))" 2>&1

echo ""
echo "=== TESTS COMPLETE ==="
