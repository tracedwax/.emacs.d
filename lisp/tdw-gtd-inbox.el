;;; tdw-gtd-inbox.el --- Deterministic GTD inbox capture -*- lexical-binding: t; -*-

;;; Commentary:
;; Stub - implementation lands in the GREEN step. A bare `(provide ...)'
;; with no functions defined yet is required for a clean RED run: with no
;; file at all, `(require 'tdw-gtd-inbox)' at the top of the test file
;; fails uncaught during file load (not caught per-test by e-unit), which
;; aborts the test runner's --eval form before it reaches `kill-emacs' -
;; control then falls through to Emacs's normal startup sequence, whose
;; `emacs-startup-hook' calls `tdw-unordered-view', which has its own
;; unrelated void-function bug in this batch/test environment. That
;; crash looks alarming but has nothing to do with this module; a stub
;; file avoids it entirely and gives clean per-test void-function errors
;; instead.

;;; Code:

(provide 'tdw-gtd-inbox)
;;; tdw-gtd-inbox.el ends here
