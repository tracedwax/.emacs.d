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

;; Big Rock skip function: on_fire items that are big rocks should NOT be skipped
(deftest on-deck/skip-big-rock-does-not-skip-on-fire ()
  "tdw/skip-unless-big-rock should NOT skip items tagged :on_fire: that qualify as big rocks."
  (on-deck-test--with-scored-entry '("on_fire" "score_15" "vh_urgency" "vh_impact") "0:30"
    (assert-nil (tdw/skip-unless-big-rock))))

;; Big Rock skip function: on_deck items that are big rocks should NOT be skipped
(deftest on-deck/skip-big-rock-does-not-skip-on-deck ()
  "tdw/skip-unless-big-rock should NOT skip items tagged :on_deck: that qualify as big rocks."
  (on-deck-test--with-scored-entry '("on_deck" "score_15" "vh_urgency" "vh_impact") "0:30"
    (assert-nil (tdw/skip-unless-big-rock))))

;; Quick Win skip function: on_fire items that are quick wins should NOT be skipped
(deftest on-deck/skip-quick-win-does-not-skip-on-fire ()
  "tdw/skip-unless-quick-win should NOT skip items tagged :on_fire: that qualify as quick wins."
  (on-deck-test--with-scored-entry '("on_fire" "l_urgency" "l_impact") "0:05"
    (assert-nil (tdw/skip-unless-quick-win))))

;; Quick Win skip function: on_deck items that are quick wins should NOT be skipped
(deftest on-deck/skip-quick-win-does-not-skip-on-deck ()
  "tdw/skip-unless-quick-win should NOT skip items tagged :on_deck: that qualify as quick wins."
  (on-deck-test--with-scored-entry '("on_deck" "l_urgency" "l_impact") "0:05"
    (assert-nil (tdw/skip-unless-quick-win))))

;; Other Rock skip function: on_fire items should NOT be skipped
(deftest on-deck/skip-other-rock-does-not-skip-on-fire ()
  "tdw/skip-unless-other-rock should NOT skip items tagged :on_fire: that qualify as other rocks."
  (on-deck-test--with-scored-entry '("on_fire" "l_urgency" "l_impact") "0:30"
    (assert-nil (tdw/skip-unless-other-rock))))

;; Other Rock skip function: on_deck items should NOT be skipped
(deftest on-deck/skip-other-rock-does-not-skip-on-deck ()
  "tdw/skip-unless-other-rock should NOT skip items tagged :on_deck: that qualify as other rocks."
  (on-deck-test--with-scored-entry '("on_deck" "l_urgency" "l_impact") "0:30"
    (assert-nil (tdw/skip-unless-other-rock))))

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

;;;; ——— Prefix emoji for on_deck ———

(deftest on-deck/resolve-score-includes-baseball-emoji ()
  "org-gtd-agenda--resolve-score includes ⚾️ when entry has :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_deck:l_urgency:l_impact:\n")
    (goto-char (point-min))
    (let ((result (org-gtd-agenda--resolve-score)))
      (assert-true (string-match-p "⚾️" result)))))

(deftest on-deck/resolve-urg-imp-includes-baseball-emoji ()
  "org-gtd-agenda--resolve-urg-imp includes ⚾️ when entry has :on_deck: tag."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_deck:l_urgency:l_impact:\n")
    (goto-char (point-min))
    (let ((result (org-gtd-agenda--resolve-urg-imp)))
      (assert-true (string-match-p "⚾️" result)))))

(deftest on-deck/resolve-score-shows-both-fire-and-deck ()
  "resolve-score shows both 🔥 and ⚾️ when entry has both tags."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_fire:on_deck:l_urgency:l_impact:\n")
    (goto-char (point-min))
    (let ((result (org-gtd-agenda--resolve-score)))
      (assert-true (string-match-p "🔥" result))
      (assert-true (string-match-p "⚾️" result)))))

(deftest on-deck/resolve-urg-imp-shows-both-fire-and-deck ()
  "resolve-urg-imp shows both 🔥 and ⚾️ when entry has both tags."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :on_fire:on_deck:l_urgency:l_impact:\n")
    (goto-char (point-min))
    (let ((result (org-gtd-agenda--resolve-urg-imp)))
      (assert-true (string-match-p "🔥" result))
      (assert-true (string-match-p "⚾️" result)))))

;;;; ——— Effort totals: on_deck bucket ———

(deftest on-deck/effort-totals-returns-7-elements ()
  "tdw/get-sanity-effort-totals should return a 7-element list (was 6).
Elements: (TOTAL ON-FIRE ON-DECK BIG-ROCKS QUICK-WINS OTHER N-UNESTIMATED)."
  (let ((result (tdw/get-sanity-effort-totals)))
    (assert-equal 7 (length result))))

;;;; ——— Toggle function: tdw/agenda-toggle-on-deck ———

;; Note: The toggle function requires `org-get-at-bol 'org-hd-marker` which
;; is only available in an agenda buffer.  We test the existence and core
;; tag-toggling behavior separately.

(deftest on-deck/toggle-function-exists ()
  "tdw/agenda-toggle-on-deck should be defined as a function."
  (assert-true (fboundp 'tdw/agenda-toggle-on-deck)))

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
