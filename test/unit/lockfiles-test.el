;;; lockfiles-test.el --- Pin that config disables interlock files -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Pins the 2026-07-13 gtd-daemon freeze bug: a stale .#org-gtd-tasks.org
;; lock file made every write hit Emacs's interactive "steal this lock?"
;; prompt.  A daemon has no display, so the prompt could never be answered
;; and every emacsclient call hung forever.  Trace is the only writer to
;; these files, so config.org must set `create-lockfiles' to nil.
;;
;; Uses e-unit (deftest, assert-nil).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(deftest lockfiles/config-disables-create-lockfiles ()
  "config.org sets `create-lockfiles' to nil so daemon writes never block on lock prompts."
  (assert-nil create-lockfiles))

(provide 'lockfiles-test)
;;; lockfiles-test.el ends here
