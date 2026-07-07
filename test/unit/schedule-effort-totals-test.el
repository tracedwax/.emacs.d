;;; schedule-effort-totals-test.el --- Tests for tdw/schedule-effort-totals -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw/schedule-effort-totals' feeds the "Today's Diary (X:XX spent,
;; Y:YY remaining)" header in the Unordered View.  It must sum SPENT-TOTAL
;; from BOTH:
;;   1. Past calendar meetings today (ORG_GTD=Calendar, rounded up to 15 min)
;;   2. Today's closed CLOCK entries logged against any task (raw minutes,
;;      NOT rounded to the quarter hour: that rounding rule applies to
;;      calendar meetings specifically)
;;
;; Before this fix, CLOCK entries were ignored entirely, so the header
;; undercounted spent time whenever the user clocked time on tasks even
;; though the Today's Diary body (built by tdw-diary-build-agenda) already
;; renders those CLOCK lines.
;;
;; Fixture dates are computed from the real "today" (not a fixed date)
;; because `tdw/schedule-effort-totals' itself uses `current-time' to
;; determine today's boundaries.
;;
;; Uses e-unit (deftest, assert-equal).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defun schedule-effort-totals-test--today (fmt)
  "Format today's date with FMT (a `format-time-string' spec)."
  (format-time-string fmt (current-time)))

(defun schedule-effort-totals-test--fixture-content ()
  "Return org content with a past Calendar meeting and a closed CLOCK today.
Calendar meeting: 09:00, Effort 0:20 (past, rounds up to 0:30).
Clocked task: 07:00--07:50 today, raw 50 minutes (no rounding)."
  (let ((today (schedule-effort-totals-test--today "%Y-%m-%d %a")))
    (format "\
* Calendar
** Past meeting
:PROPERTIES:
:ORG_GTD:  Calendar
:Effort:   0:20
:END:
<%s 00:01>
* Actions
** NEXT Task with closed clock today
:LOGBOOK:
CLOCK: [%s 07:00]--[%s 07:50] =>  0:50
:LOGBOOK-END:
:END:
"
            today today today)))

(defvar schedule-effort-totals-test--cache nil
  "Cached (RITUAL SPENT REMAINING) result: fixtures are static per test run.")

(defun schedule-effort-totals-test--totals ()
  "Build (once) the fixture file and return `tdw/schedule-effort-totals' over it."
  (or schedule-effort-totals-test--cache
      (let* ((dir (make-temp-file "schedule-effort-totals-test" t))
             (tasks (expand-file-name "org-gtd-tasks.org" dir)))
        (unwind-protect
            (progn
              (with-temp-file tasks
                (insert (schedule-effort-totals-test--fixture-content)))
              (let ((org-agenda-files (list tasks))
                    (tdw--ritual-habits '("__no-such-ritual__")))
                (setq schedule-effort-totals-test--cache
                      (tdw/schedule-effort-totals))))
          (delete-directory dir t)))))

(deftest schedule-effort-totals/spent-includes-past-calendar-meeting ()
  "Past calendar meeting effort (0:20, rounded up to 0:30) counts toward spent."
  (let ((spent (nth 1 (schedule-effort-totals-test--totals))))
    ;; With the CLOCK fix, spent = 0:30 (calendar) + 0:50 (clock) = 1:20.
    (assert-equal "1:20" spent)))

(deftest schedule-effort-totals/spent-includes-todays-closed-clock-raw-minutes ()
  "Today's closed CLOCK minutes (50) are added to spent WITHOUT quarter-hour rounding.
If CLOCK rounding were (wrongly) applied like calendar entries, 50 would round
up to 60, giving 0:30 + 1:00 = 1:30 instead of the correct 1:20."
  (let ((spent (nth 1 (schedule-effort-totals-test--totals))))
    (assert-equal "1:20" spent)))

;;; schedule-effort-totals-test.el ends here
