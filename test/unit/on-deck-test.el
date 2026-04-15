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
(ert-deftest on-deck/skip-big-rock-does-not-skip-on-fire ()
  "tdw/skip-unless-big-rock should NOT skip items tagged :on_fire: that qualify as big rocks."
  (on-deck-test--with-scored-entry '("on_fire" "score_15" "vh_urgency" "vh_impact") "0:30"
    (should-not (tdw/skip-unless-big-rock))))

;; Big Rock skip function: on_deck items that are big rocks should NOT be skipped
(ert-deftest on-deck/skip-big-rock-does-not-skip-on-deck ()
  "tdw/skip-unless-big-rock should NOT skip items tagged :on_deck: that qualify as big rocks."
  (on-deck-test--with-scored-entry '("on_deck" "score_15" "vh_urgency" "vh_impact") "0:30"
    (should-not (tdw/skip-unless-big-rock))))

;; Quick Win skip function: on_fire items that are quick wins should NOT be skipped
(ert-deftest on-deck/skip-quick-win-does-not-skip-on-fire ()
  "tdw/skip-unless-quick-win should NOT skip items tagged :on_fire: that qualify as quick wins."
  (on-deck-test--with-scored-entry '("on_fire" "l_urgency" "l_impact") "0:05"
    (should-not (tdw/skip-unless-quick-win))))

;; Quick Win skip function: on_deck items that are quick wins should NOT be skipped
(ert-deftest on-deck/skip-quick-win-does-not-skip-on-deck ()
  "tdw/skip-unless-quick-win should NOT skip items tagged :on_deck: that qualify as quick wins."
  (on-deck-test--with-scored-entry '("on_deck" "l_urgency" "l_impact") "0:05"
    (should-not (tdw/skip-unless-quick-win))))

;; Other Rock skip function: on_fire items should NOT be skipped
(ert-deftest on-deck/skip-other-rock-does-not-skip-on-fire ()
  "tdw/skip-unless-other-rock should NOT skip items tagged :on_fire: that qualify as other rocks."
  (on-deck-test--with-scored-entry '("on_fire" "l_urgency" "l_impact") "0:30"
    (should-not (tdw/skip-unless-other-rock))))

;; Other Rock skip function: on_deck items should NOT be skipped
(ert-deftest on-deck/skip-other-rock-does-not-skip-on-deck ()
  "tdw/skip-unless-other-rock should NOT skip items tagged :on_deck: that qualify as other rocks."
  (on-deck-test--with-scored-entry '("on_deck" "l_urgency" "l_impact") "0:30"
    (should-not (tdw/skip-unless-other-rock))))

;; Unestimated skip function: on_fire items should NOT be skipped
(ert-deftest on-deck/skip-unestimated-does-not-skip-on-fire ()
  "tdw/skip-unless-unestimated should NOT skip items tagged :on_fire: without effort."
  (on-deck-test--with-scored-entry '("on_fire" "l_urgency" "l_impact") nil
    (should-not (tdw/skip-unless-unestimated))))

;; Unestimated skip function: on_deck items should NOT be skipped
(ert-deftest on-deck/skip-unestimated-does-not-skip-on-deck ()
  "tdw/skip-unless-unestimated should NOT skip items tagged :on_deck: without effort."
  (on-deck-test--with-scored-entry '("on_deck" "l_urgency" "l_impact") nil
    (should-not (tdw/skip-unless-unestimated))))

;;; on-deck-test.el ends here
