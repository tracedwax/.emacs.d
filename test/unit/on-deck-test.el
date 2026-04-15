;;; on-deck-test.el --- Tests for On Deck category in config.org -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; ERT tests for the "On Deck" category feature added to the Sanity and
;; Unordered views in config.org.  Tests are structured in TDD red-green
;; cycles: each group is written first, expected to fail, then made to pass.

;;; Code:

(require 'ert)

;;;; ——— Predicate: tdw/on-deck-p ———

(ert-deftest on-deck/predicate-returns-non-nil-when-tagged ()
  "tdw/on-deck-p returns non-nil when entry has :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_deck:\n")
    (goto-char (point-min))
    (should (tdw/on-deck-p))))

(ert-deftest on-deck/predicate-returns-nil-when-not-tagged ()
  "tdw/on-deck-p returns nil when entry lacks :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task\n")
    (goto-char (point-min))
    (should-not (tdw/on-deck-p))))

;;; on-deck-test.el ends here
