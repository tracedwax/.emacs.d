#!/usr/bin/env bash
# check-elisp-parens.sh — Tangle config.org, deep-check parens per-block, byte-compile
# MANDATORY: Run after EVERY edit to config.org before marking a step complete.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ORG="${1:-$HOME/.emacs.d/config.org}"
CONFIG_EL="${CONFIG_ORG%.org}.el"

echo "=== Step 1: Per-block paren deep-research ==="
# This is the new per-block checker — it parses config.org directly (no tangle
# needed) and checks every elisp source block individually, printing structured
# diagnostics for each broken block.
CONFIG_ORG="$CONFIG_ORG" emacs --batch -l "$SCRIPT_DIR/paren-deep-research.el" 2>&1
PAREN_EXIT=$?

if [ $PAREN_EXIT -ne 0 ]; then
    echo ""
    echo "=== PAREN CHECK FAILED — fix the errors above before proceeding ==="
    exit 1
fi

echo ""
echo "=== Step 2: Tangle $(basename "$CONFIG_ORG") ==="
emacs -q --batch --eval "
(progn
  (require 'org)
  (setq org-babel-default-header-args:emacs-lisp '((:tangle . \"yes\")))
  (org-babel-tangle-file \"$CONFIG_ORG\" \"$CONFIG_EL\"))" 2>&1

echo ""
echo "=== Step 3: Byte-compile ==="
emacs -q --batch -f batch-byte-compile "$CONFIG_EL" 2>&1

echo ""
echo "=== ALL CHECKS PASSED ==="
