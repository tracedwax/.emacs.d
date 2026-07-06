;;; tdw-diary-test.el --- Tests for the Today's Diary agenda block -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; The Today's Diary block (formerly "Clock Log") must show, for one day:
;;   1. Meetings from gcal.org (plain timestamps), past AND future.
;;   2. CLOCK lines (closed and still-open) from every task file.
;; and must NEVER show:
;;   3. SCHEDULED tasks (the leak that once resurrected timesheet.org).
;;   4. Tasks with plain active timestamps in task files (the leak Trace
;;      saw 18 times before it got a test: "Schedule 1:1 with Dimitri" etc.).
;;
;; These tests exercise `tdw-diary-build-agenda' (lisp/tdw-diary.el), which
;; binds EXACTLY the options `tdw-diary-agenda-options' returns, the same
;; options the Unordered View splices into its diary block, so the view and
;; the tests cannot drift apart.
;;
;; All fixture dates are fixed at 2026-07-03 so the suite is deterministic
;; forever, independent of the day it runs.

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-diary)

(defconst tdw-diary-test--day "2026-07-03")

(defconst tdw-diary-test--gcal-content "\
* Calendar
** Morning standup (past meeting)
:PROPERTIES:
:ORG_GTD:  Calendar
:END:
<2026-07-03 Fri 09:30-09:45>
** Dentist (future meeting)
:PROPERTIES:
:ORG_GTD:  Calendar
:END:
<2026-07-03 Fri 16:00-16:30>
")

(defconst tdw-diary-test--tasks-content "\
#+TODO: TODO NEXT WAIT | DONE CNCL
* Actions
** NEXT Task with closed clock
:LOGBOOK:
CLOCK: [2026-07-03 Fri 08:45]--[2026-07-03 Fri 09:25] =>  0:40
:END:
** NEXT Task with open clock
:LOGBOOK:
CLOCK: [2026-07-03 Fri 11:00]
:END:
** NEXT Scheduled canary
SCHEDULED: <2026-07-03 Fri>
** NEXT Dateonly timestamp canary
<2026-07-03 Fri>
** NEXT Timed timestamp canary
<2026-07-03 Fri 14:00-14:30>
")

(defvar tdw-diary-test--agenda-cache nil
  "Cached agenda text: the fixtures are static, one build serves all tests.")

(defun tdw-diary-test--agenda ()
  "Build (once) and return the diary agenda text over the fixtures."
  (or tdw-diary-test--agenda-cache
      (let* ((dir (make-temp-file "tdw-diary-test" t))
             (gcal (expand-file-name "gcal.org" dir))
             (tasks (expand-file-name "org-gtd-tasks.org" dir)))
        (unwind-protect
            (progn
              (with-temp-file gcal (insert tdw-diary-test--gcal-content))
              (with-temp-file tasks (insert tdw-diary-test--tasks-content))
              (setq tdw-diary-test--agenda-cache
                    (tdw-diary-build-agenda (list gcal tasks)
                                            tdw-diary-test--day)))
          (delete-directory dir t)))))

(deftest diary/shows-past-meeting ()
  "A gcal.org meeting earlier today renders."
  (assert-true (string-match-p "Morning standup" (tdw-diary-test--agenda))))

(deftest diary/shows-future-meeting ()
  "A gcal.org meeting later today renders."
  (assert-true (string-match-p "Dentist" (tdw-diary-test--agenda))))

(deftest diary/shows-closed-clock ()
  "A task clocked earlier today renders as a log line."
  (assert-true (string-match-p "Task with closed clock" (tdw-diary-test--agenda))))

(deftest diary/shows-open-clock ()
  "A still-running clock renders as a log line."
  (assert-true (string-match-p "Task with open clock" (tdw-diary-test--agenda))))

(deftest diary/never-shows-scheduled-tasks ()
  "The leak that once resurrected timesheet.org."
  (assert-nil (string-match-p "Scheduled canary" (tdw-diary-test--agenda))))

(deftest diary/never-shows-dateonly-timestamp-tasks ()
  "The 2026-07-03 regression: date-only plain timestamps on tasks."
  (assert-nil (string-match-p "Dateonly timestamp canary" (tdw-diary-test--agenda))))

(deftest diary/never-shows-timed-timestamp-tasks ()
  "Timed plain timestamps on tasks must not leak either."
  (assert-nil (string-match-p "Timed timestamp canary" (tdw-diary-test--agenda))))

(deftest diary/shows-active-clock-task-headline ()
  "The headline of the currently active clock task renders."
  (let ((org-clock-current-task "Task with open clock"))
    (setq tdw-diary-test--agenda-cache nil) ;; Force rebuild with mocked clock
    (assert-true (string-match-p "Task with open clock" (tdw-diary-test--agenda)))))

;;;; Wiring guards: config.org must consume the shared, tested definition.

(defun tdw-diary-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "~/.emacs.d/config.org"))
    (buffer-string)))

(deftest diary/config-uses-shared-options ()
  "The view block splices tdw-diary-agenda-options (no inline copy to drift)."
  (assert-true (string-match-p "tdw-diary-agenda-options" (tdw-diary-test--config))))

(deftest diary/config-renamed-to-todays-diary ()
  "Header says Today's Diary; the old Clock Log name is gone."
  (assert-true (string-match-p "Today's Diary (" (tdw-diary-test--config)))
  (assert-nil (string-match-p "Clock Log (" (tdw-diary-test--config))))

(provide 'tdw-diary-test)
;;; tdw-diary-test.el ends here
