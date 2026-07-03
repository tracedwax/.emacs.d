#!/bin/sh
# Run the .emacs.d ERT suites in batch. Exit 0 = all green.
cd "$(dirname "$0")/.." || exit 1
exec emacs -Q --batch \
  --eval "(setq user-emacs-directory (expand-file-name \"./\"))" \
  -L lisp -L tests \
  -l tdw-diary-test \
  -f ert-run-tests-batch-and-exit
