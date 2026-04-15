#!/usr/bin/env bash
# run-tests.sh — Tangle config.org, load it, and run e-unit tests for config.org features
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
echo "=== Step 2: Run e-unit tests ==="

if [ -n "$TEST_FILE" ]; then
  # Run a single test file via e-unit-run-file
  emacs -q --batch \
    -l "$BOOTSTRAP" \
    --eval "(progn
      (e-unit-configure :verbose t)
      (e-unit-set-reporter 'console)
      (let ((results (e-unit-run-file \"$TEST_FILE\")))
        (if (null results)
            (progn (message \"No e-unit tests found\") (kill-emacs 1))
          (let* ((failed (length (cl-remove-if-not
                                  (lambda (r) (memq (plist-get r :status) '(fail error)))
                                  results))))
            (kill-emacs (if (zerop failed) 0 1))))))" 2>&1
else
  # Run all test files in test/unit/ via e-unit-run-directory
  emacs -q --batch \
    -l "$BOOTSTRAP" \
    --eval "(progn
      (e-unit-configure :verbose t)
      (e-unit-set-reporter 'console)
      (let ((results (e-unit-run-directory \"$TEST_DIR/unit\")))
        (if (null results)
            (progn (message \"No e-unit tests found\") (kill-emacs 1))
          (let* ((failed (length (cl-remove-if-not
                                  (lambda (r) (memq (plist-get r :status) '(fail error)))
                                  results))))
            (kill-emacs (if (zerop failed) 0 1))))))" 2>&1
fi

echo ""
echo "=== TESTS COMPLETE ==="
