;;; on-deck-test.el --- E-unit tests for On Deck category in config.org -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; E-unit tests for the "On Deck" category feature added to the Sanity and
;; Unordered views in config.org.  Tests are structured in TDD red-green
;; cycles: each group is written first, expected to fail, then made to pass.
;;
;; Migrated from ERT to e-unit.

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— Predicate: tdw/on-deck-p ———

(deftest on-deck/predicate-returns-non-nil-when-tagged ()
  "tdw/on-deck-p returns non-nil when entry has :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_deck:\n")
    (goto-char (point-min))
    (assert-true (tdw/on-deck-p))))

(deftest on-deck/predicate-returns-nil-when-not-tagged ()
  "tdw/on-deck-p returns nil when entry lacks :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task\n")
    (goto-char (point-min))
    (assert-nil (tdw/on-deck-p))))

;;;; ——— Skip functions should NOT exclude on_fire or on_deck items ———

(defmacro on-deck-test--with-scored-entry (tags effort-str &rest body)
  "Create a temp buffer with a scored org entry and execute BODY at entry.
TAGS is a list of strings, EFFORT-STR is e.g. \"0:30\".
Sets score_15 tag for a high-scoring entry (>= 10)."
  (declare (indent 2))
  `(with-temp-buffer
     (org-mode)
     (insert (format "* TODO Test task  :%s:\n" (mapconcat #'identity ,tags ":")))
     (when ,effort-str
       (goto-char (point-min))
       (org-set-property "EFFORT" ,effort-str))
     (goto-char (point-min))
     ,@body))

;; Unestimated skip function: on_fire items should NOT be skipped
(deftest on-deck/skip-unestimated-does-not-skip-on-fire ()
  "tdw/skip-unless-unestimated should NOT skip items tagged :on_fire: without effort."
  (on-deck-test--with-scored-entry '("on_fire" "l_urgency" "l_impact") nil
    (assert-nil (tdw/skip-unless-unestimated))))

;; Unestimated skip function: on_deck items should NOT be skipped
(deftest on-deck/skip-unestimated-does-not-skip-on-deck ()
  "tdw/skip-unless-unestimated should NOT skip items tagged :on_deck: without effort."
  (on-deck-test--with-scored-entry '("on_deck" "l_urgency" "l_impact") nil
    (assert-nil (tdw/skip-unless-unestimated))))

;;;; ——— Prefix emoji: org-gtd-agenda--resolve-tier ———

(deftest on-deck/resolve-tier-includes-softball-for-on-deck ()
  "resolve-tier includes 🥎 when entry has :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_deck:\n")
    (goto-char (point-min))
    (assert-true (string-match-p "🥎" (org-gtd-agenda--resolve-tier)))))

(deftest on-deck/resolve-tier-includes-siren-for-p0 ()
  "resolve-tier includes 🚨 when entry has :p0: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :p0:\n")
    (goto-char (point-min))
    (assert-true (string-match-p "🚨" (org-gtd-agenda--resolve-tier)))))

(deftest on-deck/resolve-tier-shows-both-p0-and-on-deck ()
  "resolve-tier shows both 🚨 and 🥎 when entry carries both tiers."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :p0:on_deck:\n")
    (goto-char (point-min))
    (let ((result (org-gtd-agenda--resolve-tier)))
      (assert-true (string-match-p "🚨" result))
      (assert-true (string-match-p "🥎" result)))))

(deftest on-deck/resolve-tier-empty-for-untiered ()
  "resolve-tier returns the empty string when no tier tag is present."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task\n")
    (goto-char (point-min))
    (assert-equal "" (org-gtd-agenda--resolve-tier))))

;;;; ——— Effort totals ———

(deftest on-deck/effort-totals-returns-8-elements ()
  "tdw/effort-totals-by-tier returns an 8-element list:
(TOTAL P0 BELLS DECK OTHER N-UNESTIMATED CONSIDERED PAUSED)."
  (let ((result (tdw/effort-totals-by-tier)))
    (assert-equal 8 (length result))))

;;;; ——— Tier-setting command ———

(deftest on-deck/set-tier-command-exists ()
  "tdw/agenda-set-tier (the command that sets on_deck and the other tiers) is defined."
  (assert-true (fboundp 'tdw/agenda-set-tier)))

(deftest on-deck/toggle-adds-on-deck-tag ()
  "Toggling on_deck on an untagged entry should add the tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task\n")
    (goto-char (point-min))
    (org-toggle-tag "on_deck" 'on)
    (assert-true (member "on_deck" (org-get-tags nil t)))))

(deftest on-deck/toggle-removes-on-deck-tag ()
  "Toggling on_deck off on a tagged entry should remove the tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_deck:\n")
    (goto-char (point-min))
    (org-toggle-tag "on_deck" 'off)
    (assert-nil (member "on_deck" (org-get-tags nil t)))))

;;;; ——— View function definitions ———

(deftest on-deck/unordered-view-is-interactive-command ()
  "tdw-unordered-view should be defined as an interactive command.
Regression: missing close paren in sanity view caused the unordered view
defun to be swallowed inside the sanity view defun."
  (assert-true (fboundp 'tdw-unordered-view))
  (assert-true (commandp 'tdw-unordered-view)))

;;; on-deck-test.el ends here
