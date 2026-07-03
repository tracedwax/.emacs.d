;;; tdw-diary-test.el --- ERT tests for the Today's Diary agenda block -*- lexical-binding: t; -*-

;; The Today's Diary block (formerly "Clock Log") must show, for one day:
;;   1. Meetings from gcal.org (plain timestamps), past AND future.
;;   2. CLOCK lines (closed and still-open) from every task file.
;; and must NEVER show:
;;   3. SCHEDULED tasks (the leak that once resurrected timesheet.org).
;;   4. Tasks with plain active timestamps in task files (the leak Trace
;;      has now seen 18 times: "Schedule 1:1 with Dimitri" etc.).
;;
;; These tests exercise `tdw-diary-build-agenda', which binds EXACTLY the
;; options `tdw-diary-agenda-options' returns -- the same options the
;; Unordered View splices into its block -- so the view and the tests
;; cannot drift apart.
;;
;; All fixture dates are fixed at 2026-07-03 so the suite is deterministic
;; forever, independent of the day it runs.

(require 'ert)
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

(defun tdw-diary-test--build ()
  "Build the diary agenda over fresh fixtures; return the buffer string."
  (let* ((dir (make-temp-file "tdw-diary-test" t))
         (gcal (expand-file-name "gcal.org" dir))
         (tasks (expand-file-name "org-gtd-tasks.org" dir)))
    (unwind-protect
        (progn
          (with-temp-file gcal (insert tdw-diary-test--gcal-content))
          (with-temp-file tasks (insert tdw-diary-test--tasks-content))
          (tdw-diary-build-agenda (list gcal tasks) tdw-diary-test--day))
      (delete-directory dir t))))

(defmacro tdw-diary-test--with-agenda (var &rest body)
  (declare (indent 1))
  `(let ((,var (tdw-diary-test--build))) ,@body))

(ert-deftest tdw-diary-shows-past-meeting ()
  (tdw-diary-test--with-agenda s
    (should (string-match-p "Morning standup" s))))

(ert-deftest tdw-diary-shows-future-meeting ()
  (tdw-diary-test--with-agenda s
    (should (string-match-p "Dentist" s))))

(ert-deftest tdw-diary-shows-closed-clock ()
  (tdw-diary-test--with-agenda s
    (should (string-match-p "Task with closed clock" s))))

(ert-deftest tdw-diary-shows-open-clock ()
  (tdw-diary-test--with-agenda s
    (should (string-match-p "Task with open clock" s))))

(ert-deftest tdw-diary-never-shows-scheduled-tasks ()
  "The leak that once resurrected timesheet.org."
  (tdw-diary-test--with-agenda s
    (should-not (string-match-p "Scheduled canary" s))))

(ert-deftest tdw-diary-never-shows-dateonly-timestamp-tasks ()
  "The 2026-07-03 regression: date-only plain timestamps on tasks."
  (tdw-diary-test--with-agenda s
    (should-not (string-match-p "Dateonly timestamp canary" s))))

(ert-deftest tdw-diary-never-shows-timed-timestamp-tasks ()
  "Timed plain timestamps on tasks must not leak either."
  (tdw-diary-test--with-agenda s
    (should-not (string-match-p "Timed timestamp canary" s))))

;; Guard the wiring in config.org itself: the block must use the shared
;; options builder (no inline copy that can drift) and the human name
;; "Today's Diary", not the old hallucinated "Clock Log".

(defun tdw-diary-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "config.org" user-emacs-directory))
    (buffer-string)))

(ert-deftest tdw-diary-config-uses-shared-options ()
  (should (string-match-p "tdw-diary-agenda-options" (tdw-diary-test--config))))

(ert-deftest tdw-diary-config-renamed-to-todays-diary ()
  (let ((config (tdw-diary-test--config)))
    (should (string-match-p "Today's Diary (" config))
    (should-not (string-match-p "Clock Log (" config))))

(provide 'tdw-diary-test)
;;; tdw-diary-test.el ends here
