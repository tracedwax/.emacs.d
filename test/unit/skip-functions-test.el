;;; skip-functions-test.el --- Characterization tests for agenda skip functions -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Characterization tests that LOCK the current behavior of the shared agenda
;; skip functions in config.org, so the POODR refactor cannot regress them:
;;
;;   - tdw/skip-unless-daily-ritual
;;   - tdw/skip-unless-non-ritual-habit
;;   - tdw/skip-unless-tickler-due
;;   - tdw/skip-unless-unestimated
;;   - tdw/skip-cncl-globally
;;
;; CONTRACT: each function returns nil to KEEP the entry at point, or a buffer
;; position (non-nil) to SKIP it.  These return values are consumed by
;; `org-agenda-skip-function', so the only thing that matters is nil vs non-nil.
;; All values below were captured from the live functions, not guessed.
;;
;; HARNESS NOTES:
;;   - Skip functions call `outline-next-heading' / `org-entry-end-position'
;;     to compute the skip position.  When the entry under test is the ONLY
;;     heading in the buffer, `outline-next-heading' returns nil, which would
;;     masquerade as a KEEP.  Every "skip" fixture therefore appends a trailing
;;     "* TODO Next" heading so the non-nil position is observable.
;;   - Habits are marked with the :STYLE: habit property drawer.
;;   - Ritual habit headings must match one of `tdw--ritual-habits'
;;     (e.g. "Meeting prep"); any other habit heading is non-ritual.
;;   - tdw/skip-cncl-globally reads the TODO state, so a #+TODO header is
;;     inserted to register CNCL as a recognized keyword (the live org config
;;     defines it; a bare temp buffer only knows TODO/DONE).
;;
;; Uses e-unit (deftest, assert-true, assert-nil).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— tdw/skip-unless-daily-ritual ———

(deftest predicates/daily-ritual-keeps-undone-ritual-habit ()
  "KEEP (nil): an undone habit whose heading matches a ritual name."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Meeting prep\n:PROPERTIES:\n:STYLE: habit\n:END:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-nil (tdw/skip-unless-daily-ritual))))

(deftest predicates/daily-ritual-skips-non-ritual-habit ()
  "SKIP (non-nil): a habit whose heading is not a ritual name."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Floss teeth\n:PROPERTIES:\n:STYLE: habit\n:END:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-daily-ritual))))

(deftest predicates/daily-ritual-skips-ritual-that-is-not-a-habit ()
  "SKIP (non-nil): a ritual-named heading that lacks :STYLE: habit."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Meeting prep\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-daily-ritual))))

(deftest predicates/daily-ritual-skips-done-ritual-habit ()
  "SKIP (non-nil): a ritual habit that is already DONE."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE Meeting prep\n:PROPERTIES:\n:STYLE: habit\n:END:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-daily-ritual))))

;;;; ——— tdw/skip-unless-non-ritual-habit ———

(deftest predicates/non-ritual-habit-keeps-undone-non-ritual-habit ()
  "KEEP (nil): an undone habit whose heading is NOT a ritual name."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Floss teeth\n:PROPERTIES:\n:STYLE: habit\n:END:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-nil (tdw/skip-unless-non-ritual-habit))))

(deftest predicates/non-ritual-habit-skips-ritual-habit ()
  "SKIP (non-nil): a ritual-named habit (those belong to the daily-ritual view)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Meeting prep\n:PROPERTIES:\n:STYLE: habit\n:END:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-non-ritual-habit))))

(deftest predicates/non-ritual-habit-skips-non-habit ()
  "SKIP (non-nil): a non-ritual heading that lacks :STYLE: habit."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Floss teeth\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-non-ritual-habit))))

;;;; ——— tdw/skip-unless-tickler-due ———

(defun skip-functions-test--date-offset (days)
  "Return a Y-m-d date string DAYS away from today."
  (format-time-string "%Y-%m-%d"
                      (time-add (current-time) (days-to-time days))))

(deftest predicates/tickler-keeps-scheduled-today ()
  "KEEP (nil): undone item scheduled for today."
  (with-temp-buffer
    (org-mode)
    (insert (format "* TODO Tickle\nSCHEDULED: <%s>\n* TODO Next\n"
                    (skip-functions-test--date-offset 0)))
    (goto-char (point-min))
    (assert-nil (tdw/skip-unless-tickler-due))))

(deftest predicates/tickler-keeps-scheduled-in-past ()
  "KEEP (nil): undone item scheduled before today is still due."
  (with-temp-buffer
    (org-mode)
    (insert (format "* TODO Tickle\nSCHEDULED: <%s>\n* TODO Next\n"
                    (skip-functions-test--date-offset -3)))
    (goto-char (point-min))
    (assert-nil (tdw/skip-unless-tickler-due))))

(deftest predicates/tickler-skips-scheduled-in-future ()
  "SKIP (non-nil): item scheduled after today is not yet due."
  (with-temp-buffer
    (org-mode)
    (insert (format "* TODO Tickle\nSCHEDULED: <%s>\n* TODO Next\n"
                    (skip-functions-test--date-offset 5)))
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-tickler-due))))

(deftest predicates/tickler-skips-unscheduled ()
  "SKIP (non-nil): item with no SCHEDULED date."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Tickle\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-tickler-due))))

(deftest predicates/tickler-skips-done-even-if-due ()
  "SKIP (non-nil): a DONE item scheduled for today is no longer due."
  (with-temp-buffer
    (org-mode)
    (insert (format "* DONE Tickle\nSCHEDULED: <%s>\n* TODO Next\n"
                    (skip-functions-test--date-offset 0)))
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-tickler-due))))

;;;; ——— tdw/skip-unless-unestimated ———

(deftest predicates/unestimated-keeps-low-score-no-effort ()
  "KEEP (nil): score < 10 and no effort set."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task  :l_urgency:l_impact:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-nil (tdw/skip-unless-unestimated))))

(deftest predicates/unestimated-skips-when-effort-is-set ()
  "SKIP (non-nil): an estimated entry (effort present) is not unestimated."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task  :l_urgency:l_impact:\n:PROPERTIES:\n:EFFORT: 1:00\n:END:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-unestimated))))

(deftest predicates/unestimated-skips-high-score ()
  "SKIP (non-nil): score >= 10 (wh urgency + wh impact) is excluded even with no effort."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task  :wh_urgency:wh_impact:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-unestimated))))

(deftest predicates/unestimated-skips-done ()
  "SKIP (non-nil): a DONE entry is excluded regardless of score/effort."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE Task  :l_urgency:l_impact:\n* TODO Next\n")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-unestimated))))

;;;; ——— tdw/skip-cncl-globally ———
;; The #+TODO header registers CNCL as a recognized keyword so
;; `org-get-todo-state' can see it (the live config defines CNCL; a bare
;; temp buffer otherwise only knows TODO/DONE).

(deftest predicates/cncl-global-skips-cncl ()
  "SKIP (non-nil): a CNCL (canceled) entry."
  (with-temp-buffer
    (insert "#+TODO: TODO | DONE CNCL\n* CNCL Task\n* TODO Next\n")
    (org-mode)
    (goto-char (point-min))
    (re-search-forward "CNCL Task")
    (beginning-of-line)
    (assert-true (tdw/skip-cncl-globally))))

(deftest predicates/cncl-global-skips-done ()
  "SKIP (non-nil): a DONE entry."
  (with-temp-buffer
    (insert "#+TODO: TODO | DONE CNCL\n* DONE Task\n* TODO Next\n")
    (org-mode)
    (goto-char (point-min))
    (re-search-forward "DONE Task")
    (beginning-of-line)
    (assert-true (tdw/skip-cncl-globally))))

(deftest predicates/cncl-global-keeps-todo ()
  "KEEP (nil): an active TODO entry."
  (with-temp-buffer
    (insert "#+TODO: TODO | DONE CNCL\n* TODO Task\n* TODO Next\n")
    (org-mode)
    (goto-char (point-min))
    (re-search-forward "TODO Task")
    (beginning-of-line)
    (assert-nil (tdw/skip-cncl-globally))))

(deftest predicates/cncl-global-keeps-stateless-heading ()
  "KEEP (nil): a heading with no TODO keyword at all."
  (with-temp-buffer
    (insert "#+TODO: TODO | DONE CNCL\n* Plain heading\n* TODO Next\n")
    (org-mode)
    (goto-char (point-min))
    (re-search-forward "Plain heading")
    (beginning-of-line)
    (assert-nil (tdw/skip-cncl-globally))))

;;; skip-functions-test.el ends here
