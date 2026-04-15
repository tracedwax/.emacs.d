#!/usr/bin/env bash
# check-elisp-parens.sh — Tangle config.org, check parens, byte-compile
# MANDATORY: Run after EVERY edit to config.org before marking a step complete.
set -euo pipefail

CONFIG_ORG="${1:-$HOME/.emacs.d/config.org}"
CONFIG_EL="${CONFIG_ORG%.org}.el"

echo "=== Step 1: Tangle $(basename "$CONFIG_ORG") ==="
emacs -q --batch --eval "
(progn
  (require 'org)
  (setq org-babel-default-header-args:emacs-lisp '((:tangle . \"yes\")))
  (org-babel-tangle-file \"$CONFIG_ORG\" \"$CONFIG_EL\"))" 2>&1

echo ""
echo "=== Step 2: Check balanced parens ==="
emacs -q --batch --eval "
(condition-case err
    (progn
      (find-file \"$CONFIG_EL\")
      (check-parens)
      (message \"CHECK-PARENS: OK\"))
  (error (message \"PAREN ERROR: %s\" err)
         (kill-emacs 1)))" 2>&1

echo ""
echo "=== Step 3: Byte-compile ==="
emacs -q --batch -f batch-byte-compile "$CONFIG_EL" 2>&1

echo ""
echo "=== ALL CHECKS PASSED ==="
