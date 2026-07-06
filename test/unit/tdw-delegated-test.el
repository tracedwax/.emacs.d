;;; tdw-delegated-test.el --- Tests for the Delegated agenda sections -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; The Unordered View has three Delegated sections (Overdue, Due Today,
;; Due After Today).  As shipped they showed ZERO items forever: the
;; org-gtd view DSL's (when . X) filter reads the ORG_GTD_TIMESTAMP
;; property, while real delegated tasks carry their check-in date on
;; the DEADLINE planning line (plus DELEGATED_TO), so every predicate
;; failed and every section rendered empty.
;;
;; These tests exercise `tdw-delegated-build-agenda' (lisp/tdw-delegated.el),
;; which renders EXACTLY the blocks `tdw-delegated-agenda-blocks' returns,
;; the same blocks the Unordered View splices in, so the view and the
;; tests cannot drift apart.  The contract they pin:
;;
;;   1. A WAIT + ORG_GTD=Delegated item lands in exactly one section,
;;      chosen by its check-in day vs today.
;;   2. The check-in day is DEADLINE when present (the line Trace edits),
;;      else the ORG_GTD_TIMESTAMP property (what org-gtd-delegate writes).
;;   3. Items with neither date, a non-WAIT keyword, a non-Delegated
;;      ORG_GTD, or a done state appear in NO section.
;;
;; All fixture dates are computed relative to (org-today) at run time,
;; so the suite is deterministic on any day it runs.

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-delegated)

(defun tdw-delegated-test--date (offset)
  "Active org date string for today plus OFFSET days (noon, DST-safe)."
  (let ((greg (calendar-gregorian-from-absolute (+ (org-today) offset))))
    (format-time-string
     "<%Y-%m-%d %a>"
     (encode-time 0 0 12 (nth 1 greg) (nth 0 greg) (nth 2 greg)))))

(defun tdw-delegated-test--tasks-content ()
  "Org fixture covering both date shapes and every exclusion rule."
  (let ((yesterday (tdw-delegated-test--date -1))
        (today (tdw-delegated-test--date 0))
        (tomorrow (tdw-delegated-test--date 1)))
    (concat
     "#+TODO: TODO NEXT WAIT | DONE CNCL\n"
     "* Delegated\n"
     ;; Shape 1: check-in on the DEADLINE planning line (the bug report's shape)
     "** WAIT Overdue invoice chase\n"
     "DEADLINE: " yesterday "\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Eric Sherred\n:END:\n"
     "** WAIT Signature chase due today\n"
     "DEADLINE: " today "\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Dana Smith\n:END:\n"
     "** WAIT Vendor quote due tomorrow\n"
     "DEADLINE: " tomorrow "\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Jason Berlinsky\n:END:\n"
     ;; Shape 2: check-in in ORG_GTD_TIMESTAMP (what org-gtd-delegate writes)
     "** WAIT Prop overdue report\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Alice\n"
     ":ORG_GTD_TIMESTAMP: " yesterday "\n:END:\n"
     "** WAIT Prop today report\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Alice\n"
     ":ORG_GTD_TIMESTAMP: " today "\n:END:\n"
     "** WAIT Prop tomorrow report\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Alice\n"
     ":ORG_GTD_TIMESTAMP: " tomorrow "\n:END:\n"
     ;; Both shapes disagreeing: DEADLINE (tomorrow) must win over property (yesterday)
     "** WAIT Both dates report\n"
     "DEADLINE: " tomorrow "\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Bob\n"
     ":ORG_GTD_TIMESTAMP: " yesterday "\n:END:\n"
     ;; Exclusions
     "** WAIT Dateless delegation\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Carol\n:END:\n"
     "** NEXT Wrong keyword delegation\n"
     "DEADLINE: " today "\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Dave\n:END:\n"
     "** WAIT Wrong type delegation\n"
     "DEADLINE: " today "\n"
     ":PROPERTIES:\n:ORG_GTD:  Actions\n:END:\n"
     "** DONE Completed delegation\n"
     "DEADLINE: " yesterday "\n"
     ":PROPERTIES:\n:ORG_GTD:  Delegated\n:DELEGATED_TO: Eve\n:END:\n")))

(defvar tdw-delegated-test--agenda-cache nil
  "Cached agenda text: the fixtures are static per run, one build serves all.")

(defun tdw-delegated-test--agenda ()
  "Build (once) and return the Delegated block agenda over the fixtures."
  (or tdw-delegated-test--agenda-cache
      (let* ((dir (make-temp-file "tdw-delegated-test" t))
             (tasks (expand-file-name "org-gtd-tasks.org" dir)))
        (unwind-protect
            (progn
              (with-temp-file tasks (insert (tdw-delegated-test--tasks-content)))
              (setq tdw-delegated-test--agenda-cache
                    (tdw-delegated-build-agenda (list tasks))))
          (delete-directory dir t)))))

(defun tdw-delegated-test--section (header)
  "Return the agenda text of the block titled HEADER, up to the next block."
  (let* ((agenda (tdw-delegated-test--agenda))
         (start (string-match (regexp-quote header) agenda)))
    (unless start (error "Header %S not found in agenda:\n%s" header agenda))
    (substring agenda start
               (or (string-match "^=====" agenda (+ start (length header)))
                   (length agenda)))))

(defun tdw-delegated-test--in-section-only (title header)
  "Non-nil if TITLE appears in the HEADER section and in no other section."
  (let ((sections '("Delegated (Overdue)"
                    "Delegated (Due Today)"
                    "Delegated (Due After Today)")))
    (and (string-match-p (regexp-quote title)
                         (tdw-delegated-test--section header))
         (cl-notany (lambda (other)
                      (string-match-p (regexp-quote title)
                                      (tdw-delegated-test--section other)))
                    (remove header sections)))))

;;;; Shape 1: DEADLINE carries the check-in date (the reported bug)

(deftest delegated/deadline-yesterday-in-overdue-only ()
  "WAIT + Delegated + DEADLINE yesterday shows under Overdue and only there."
  (assert-true (tdw-delegated-test--in-section-only
                "Overdue invoice chase" "Delegated (Overdue)")))

(deftest delegated/deadline-today-in-due-today-only ()
  "WAIT + Delegated + DEADLINE today shows under Due Today and only there."
  (assert-true (tdw-delegated-test--in-section-only
                "Signature chase due today" "Delegated (Due Today)")))

(deftest delegated/deadline-tomorrow-in-due-after-today-only ()
  "WAIT + Delegated + DEADLINE tomorrow shows under Due After Today only."
  (assert-true (tdw-delegated-test--in-section-only
                "Vendor quote due tomorrow" "Delegated (Due After Today)")))

;;;; Shape 2: ORG_GTD_TIMESTAMP fallback (items created via org-gtd-delegate)

(deftest delegated/property-yesterday-in-overdue-only ()
  "ORG_GTD_TIMESTAMP yesterday (no DEADLINE) shows under Overdue only."
  (assert-true (tdw-delegated-test--in-section-only
                "Prop overdue report" "Delegated (Overdue)")))

(deftest delegated/property-today-in-due-today-only ()
  "ORG_GTD_TIMESTAMP today (no DEADLINE) shows under Due Today only."
  (assert-true (tdw-delegated-test--in-section-only
                "Prop today report" "Delegated (Due Today)")))

(deftest delegated/property-tomorrow-in-due-after-today-only ()
  "ORG_GTD_TIMESTAMP tomorrow (no DEADLINE) shows under Due After Today only."
  (assert-true (tdw-delegated-test--in-section-only
                "Prop tomorrow report" "Delegated (Due After Today)")))

;;;; Precedence: the planning line Trace edits beats the stored property

(deftest delegated/deadline-wins-over-property ()
  "With DEADLINE tomorrow and ORG_GTD_TIMESTAMP yesterday, DEADLINE wins."
  (assert-true (tdw-delegated-test--in-section-only
                "Both dates report" "Delegated (Due After Today)")))

;;;; Exclusions: wrong date-lessness, keyword, type, or done state

(deftest delegated/dateless-item-nowhere ()
  "A delegated item with no check-in date appears in no section."
  (assert-nil (string-match-p "Dateless delegation"
                              (tdw-delegated-test--agenda))))

(deftest delegated/non-wait-keyword-excluded ()
  "A NEXT item is not a delegation in flight; it must not appear."
  (assert-nil (string-match-p "Wrong keyword delegation"
                              (tdw-delegated-test--agenda))))

(deftest delegated/non-delegated-type-excluded ()
  "A WAIT item whose ORG_GTD is not Delegated must not appear."
  (assert-nil (string-match-p "Wrong type delegation"
                              (tdw-delegated-test--agenda))))

(deftest delegated/done-item-excluded ()
  "A completed delegation must not appear, even with a past deadline."
  (assert-nil (string-match-p "Completed delegation"
                              (tdw-delegated-test--agenda))))

(provide 'tdw-delegated-test)
;;; tdw-delegated-test.el ends here
