;;; tdw-gtd-clock-test.el --- Tests for deterministic GTD clock adjustment -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw-gtd-parse-duration' and `tdw-gtd-adjust-timer' are the
;; deterministic replacement for the adjust-timer workflow's mechanical
;; steps (duration parsing, latest-clock-out lookup, CLOCK-line
;; consolidation, tag swap) so a weak model just has to call one function
;; with a title/duration, instead of doing timestamp arithmetic by hand.
;;
;; Duration-parsing cases are pinned exactly against the table in
;; .agent/workflows/adjust-timer.md.

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-gtd-clock)

;;;; tdw-gtd-parse-duration

(deftest gtd-clock/parses-bare-minutes ()
  (assert-equal 30 (tdw-gtd-parse-duration "30m")))

(deftest gtd-clock/parses-bare-hours ()
  (assert-equal 60 (tdw-gtd-parse-duration "1h")))

(deftest gtd-clock/parses-hours-and-minutes ()
  (assert-equal 90 (tdw-gtd-parse-duration "1h30m")))

(deftest gtd-clock/parses-spelled-out-minutes ()
  (assert-equal 45 (tdw-gtd-parse-duration "45 minutes")))

(deftest gtd-clock/parses-colon-form ()
  (assert-equal 135 (tdw-gtd-parse-duration "2:15")))

(deftest gtd-clock/parses-decimal-hours ()
  (assert-equal 90 (tdw-gtd-parse-duration "1.5h")))

(deftest gtd-clock/parses-large-bare-minutes ()
  (assert-equal 90 (tdw-gtd-parse-duration "90m")))

(deftest gtd-clock/parses-abbreviated-min ()
  "Not in the documented table, but a reasonable abbreviation to accept."
  (assert-equal 45 (tdw-gtd-parse-duration "45min")))

(deftest gtd-clock/parses-hours-only-with-space ()
  (assert-equal 120 (tdw-gtd-parse-duration "2 h")))

(deftest gtd-clock/rejects-unparseable-input ()
  (assert-true
   (condition-case nil
       (progn (tdw-gtd-parse-duration "banana") nil)
     (error t))))

;;;; tdw-gtd--format-clock-line

(deftest gtd-clock/format-right-aligns-single-digit-hour ()
  "Real org-gtd-tasks.org data (via thecleverone) shows the H:MM field is
right-aligned to width 2 on the hour, not always exactly two literal
spaces: a 1-digit hour keeps the extra space (\"=>  0:30\"), a 2-digit
hour doesn't (\"=> 11:00\") - the format string must pad the hour to
width 2, not hardcode two spaces before a bare %d."
  (assert-equal
   "CLOCK: [2026-06-01 Mon 21:00]--[2026-06-01 Mon 21:30] =>  0:30"
   (tdw-gtd--format-clock-line (encode-time 0 0 21 1 6 2026)
                                (encode-time 0 30 21 1 6 2026)
                                30)))

(deftest gtd-clock/format-does-not-double-space-two-digit-hour ()
  (assert-equal
   "CLOCK: [2026-06-13 Sat 08:00]--[2026-06-13 Sat 19:00] => 11:00"
   (tdw-gtd--format-clock-line (encode-time 0 0 8 13 6 2026)
                                (encode-time 0 0 19 13 6 2026)
                                660)))

;;;; tdw-gtd--replace-logbook-clock (pure string transform)

(deftest gtd-clock/consolidates-single-entry ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-03 Fri 08:00]--[2026-07-03 Fri 10:00] =>  2:00
:END:
:PROPERTIES:
:ID:       some-id
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-03 Fri 09:30\\]--\\[2026-07-03 Fri 10:00\\] =>  0:30"
      (tdw-gtd--replace-logbook-clock text 30)))))

(deftest gtd-clock/consolidates-multiple-entries-using-latest-end-by-value ()
  "Picks the latest end time by VALUE, not by line position - the later
entry (09:20) appears first in the text, before the earlier one (08:40)."
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-03 Fri 09:00]--[2026-07-03 Fri 09:20] =>  0:20
CLOCK: [2026-07-03 Fri 08:00]--[2026-07-03 Fri 08:40] =>  0:40
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-03 Fri 09:05\\]--\\[2026-07-03 Fri 09:20\\] =>  0:15"
      (tdw-gtd--replace-logbook-clock text 15)))))

(deftest gtd-clock/only-one-clock-line-remains-after-consolidation ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-03 Fri 09:00]--[2026-07-03 Fri 09:20] =>  0:20
CLOCK: [2026-07-03 Fri 08:00]--[2026-07-03 Fri 08:40] =>  0:40
:END:
"))
    (let ((result (tdw-gtd--replace-logbook-clock text 15)))
      (assert-equal 1 (cl-count-if (lambda (line) (string-prefix-p "CLOCK:" (string-trim line)))
                                    (split-string result "\n"))))))

(deftest gtd-clock/consolidates-entry-spanning-midnight ()
  "Real data (via thecleverone): a CLOCK entry can start one calendar day
and end just after midnight the next. Proper date arithmetic (not naive
same-day string math) must carry the day rollover correctly."
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-06-04 Thu 23:30]--[2026-06-05 Fri 00:00] =>  0:30
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-06-04 Thu 23:45\\]--\\[2026-06-05 Fri 00:00\\] =>  0:15"
      (tdw-gtd--replace-logbook-clock text 15)))))

(deftest gtd-clock/consolidates-to-a-two-digit-hour-duration ()
  "Real data (via thecleverone): an all-day block totaling 11:00 - the
consolidated line must right-align correctly, not double-space."
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-06-13 Sat 08:00]--[2026-06-13 Sat 19:00] => 11:00
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-06-13 Sat 08:00\\]--\\[2026-06-13 Sat 19:00\\] => 11:00"
      (tdw-gtd--replace-logbook-clock text 660)))))

(deftest gtd-clock/creates-logbook-when-absent-using-now-time ()
  (let* ((text "\
** NEXT Fresh task                                   :tgl_foo:
:PROPERTIES:
:ID:       fresh-id
:END:
")
         (now (encode-time 0 0 15 3 7 2026))
         (result (tdw-gtd--replace-logbook-clock text 20 now)))
    (assert-true (string-match-p
                  "\\* NEXT Fresh task.*\n:LOGBOOK:\nCLOCK: \\[2026-07-03 Fri 14:40\\]--\\[2026-07-03 Fri 15:00\\] =>  0:20\n:END:\n:PROPERTIES:"
                  result))))

(deftest gtd-clock/refuses-to-consolidate-with-open-clock ()
  "An open (still running) CLOCK entry must not be silently discarded."
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-03 Fri 08:00]--[2026-07-03 Fri 08:40] =>  0:40
CLOCK: [2026-07-03 Fri 11:00]
:END:
"))
    (assert-true
     (condition-case nil
         (progn (tdw-gtd--replace-logbook-clock text 15) nil)
       (error t)))))

;;;; tdw-gtd--set-tgl-tag (pure string transform)

(deftest gtd-clock/tag-swap-replaces-existing-tgl-tag ()
  (let* ((text "** NEXT Some task :tgl_old:other_tag:\n:LOGBOOK:\n:END:\n")
         (result (tdw-gtd--set-tgl-tag text "tgl_new")))
    (assert-true (string-match-p ":tgl_new:" result))
    (assert-true (string-match-p ":other_tag:" result))
    (assert-nil (string-match-p ":tgl_old:" result))))

(deftest gtd-clock/tag-swap-appends-when-no-tags-exist ()
  (let ((text "** NEXT Some task\n:LOGBOOK:\n:END:\n"))
    (assert-true (string-match-p "Some task :tgl_new:" (tdw-gtd--set-tgl-tag text "tgl_new")))))

(deftest gtd-clock/tag-swap-preserves-non-tgl-tags ()
  (let ((text "** NEXT Some task :other_tag:\n"))
    (assert-true (string-match-p ":other_tag:tgl_new:" (tdw-gtd--set-tgl-tag text "tgl_new")))))

;;;; tdw-gtd-adjust-timer (integration: real file + org-gtd-directory)

(defmacro tdw-gtd-clock-test--with-tasks-fixture (var content &rest body)
  "Bind VAR to a temp org-gtd-tasks.org path containing CONTENT, with
`org-gtd-directory' let-bound to its parent dir, run BODY, then clean up."
  (declare (indent 2))
  `(let* ((dir (make-temp-file "tdw-gtd-clock-test" t))
          (org-gtd-directory dir)
          (,var (expand-file-name "org-gtd-tasks.org" dir)))
     (unwind-protect
         (progn
           (with-temp-file ,var (insert ,content))
           ,@body)
       (let ((buf (find-buffer-visiting ,var)))
         (when buf (kill-buffer buf)))
       (delete-directory dir t))))

(defun tdw-gtd-clock-test--file-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(deftest gtd-clock/adjust-timer-consolidates-the-matched-task ()
  (tdw-gtd-clock-test--with-tasks-fixture tasks-file
      "\
* Actions
** NEXT Submit Q3 board deck                          :tgl_orbit:
:LOGBOOK:
CLOCK: [2026-07-03 Fri 08:45]--[2026-07-03 Fri 09:25] =>  0:40
:END:
:PROPERTIES:
:ORG_GTD:  Actions
:END:
** NEXT Some other task                               :tgl_orbit:
:LOGBOOK:
:END:
"
    (tdw-gtd-adjust-timer "Submit Q3 board deck" "30m")
    (let ((contents (tdw-gtd-clock-test--file-contents tasks-file)))
      (assert-true (string-match-p
                    "CLOCK: \\[2026-07-03 Fri 08:55\\]--\\[2026-07-03 Fri 09:25\\] =>  0:30"
                    contents))
      (assert-true (string-match-p "Some other task" contents)))))

(deftest gtd-clock/adjust-timer-swaps-tag-when-given ()
  (tdw-gtd-clock-test--with-tasks-fixture tasks-file
      "\
* Actions
** NEXT Submit Q3 board deck                          :tgl_orbit:
:LOGBOOK:
CLOCK: [2026-07-03 Fri 08:45]--[2026-07-03 Fri 09:25] =>  0:40
:END:
"
    (tdw-gtd-adjust-timer "Submit Q3 board deck" "30m" "tgl_new_project")
    (let ((contents (tdw-gtd-clock-test--file-contents tasks-file)))
      (assert-true (string-match-p ":tgl_new_project:" contents))
      (assert-nil (string-match-p ":tgl_orbit:" contents)))))

(deftest gtd-clock/adjust-timer-errors-on-ambiguous-match ()
  (tdw-gtd-clock-test--with-tasks-fixture tasks-file
      "\
* Actions
** NEXT Draft the report                              :tgl_orbit:
:LOGBOOK:
:END:
** NEXT Draft the other report                        :tgl_orbit:
:LOGBOOK:
:END:
"
    (assert-true
     (condition-case nil
         (progn (tdw-gtd-adjust-timer "Draft the" "30m") nil)
       (error t)))))

(deftest gtd-clock/adjust-timer-errors-on-no-match ()
  (tdw-gtd-clock-test--with-tasks-fixture tasks-file
      "\
* Actions
** NEXT Something else entirely                       :tgl_orbit:
:LOGBOOK:
:END:
"
    (assert-true
     (condition-case nil
         (progn (tdw-gtd-adjust-timer "Nonexistent task" "30m") nil)
       (error t)))))

;;;; tdw-gtd-parse-clock-time

(defvar tdw-gtd-clock-test--now (encode-time 0 0 12 9 7 2026)
  "Fixed \"now\" (2026-07-09 Thu 12:00) so date-defaulting tests are deterministic.")

(deftest gtd-clock/parse-clock-time-military-hhmm ()
  (assert-equal (encode-time 0 0 10 9 7 2026)
                (tdw-gtd-parse-clock-time "1000" tdw-gtd-clock-test--now)))

(deftest gtd-clock/parse-clock-time-colon-form ()
  (assert-equal (encode-time 0 30 11 9 7 2026)
                (tdw-gtd-parse-clock-time "11:30" tdw-gtd-clock-test--now)))

(deftest gtd-clock/parse-clock-time-am-pm ()
  (assert-equal (encode-time 0 0 10 9 7 2026)
                (tdw-gtd-parse-clock-time "10am" tdw-gtd-clock-test--now))
  (assert-equal (encode-time 0 30 22 9 7 2026)
                (tdw-gtd-parse-clock-time "10:30pm" tdw-gtd-clock-test--now)))

(deftest gtd-clock/parse-clock-time-noon-and-midnight-pm-am ()
  (assert-equal (encode-time 0 0 12 9 7 2026)
                (tdw-gtd-parse-clock-time "12pm" tdw-gtd-clock-test--now))
  (assert-equal (encode-time 0 0 0 9 7 2026)
                (tdw-gtd-parse-clock-time "12am" tdw-gtd-clock-test--now)))

(deftest gtd-clock/parse-clock-time-with-explicit-date ()
  (assert-equal (encode-time 0 0 10 8 7 2026)
                (tdw-gtd-parse-clock-time "2026-07-08 1000" tdw-gtd-clock-test--now)))

(deftest gtd-clock/parse-clock-time-short-military ()
  "A 3-digit hhmm like \"930\" means 09:30."
  (assert-equal (encode-time 0 30 9 9 7 2026)
                (tdw-gtd-parse-clock-time "930" tdw-gtd-clock-test--now)))

(deftest gtd-clock/parse-clock-time-rejects-garbage ()
  (assert-true
   (condition-case nil
       (progn (tdw-gtd-parse-clock-time "banana" tdw-gtd-clock-test--now) nil)
     (error t))))

;;;; tdw-gtd--select-clock-entry

(defvar tdw-gtd-clock-test--multi-entry-text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 08:00]--[2026-07-09 Thu 08:40] =>  0:40
CLOCK: [2026-07-08 Wed 10:00]--[2026-07-08 Wed 10:30] =>  0:30
CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:20] =>  0:20
:END:
"
  "Three closed chunks, out of order, with a same-clock-time entry on another day.")

(defun tdw-gtd-clock-test--selected-line (text selector)
  (let ((bounds (tdw-gtd--select-clock-entry text selector tdw-gtd-clock-test--now)))
    (substring text (car bounds) (cdr bounds))))

(deftest gtd-clock/select-defaults-to-latest-closed-entry ()
  "No selector, no open clock: pick the entry with the latest start."
  (assert-equal
   "CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:20] =>  0:20"
   (tdw-gtd-clock-test--selected-line tdw-gtd-clock-test--multi-entry-text nil)))

(deftest gtd-clock/select-defaults-to-open-entry-when-running ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 11:00]
CLOCK: [2026-07-09 Thu 08:00]--[2026-07-09 Thu 08:40] =>  0:40
:END:
"))
    (assert-equal "CLOCK: [2026-07-09 Thu 11:00]"
                  (tdw-gtd-clock-test--selected-line text nil))))

(deftest gtd-clock/select-by-start-time-defaults-to-today ()
  "\"1000\" on 2026-07-09 picks the Thu 10:00 entry, not Wed's 10:00."
  (assert-equal
   "CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:20] =>  0:20"
   (tdw-gtd-clock-test--selected-line tdw-gtd-clock-test--multi-entry-text "1000")))

(deftest gtd-clock/select-by-start-time-with-explicit-date ()
  (assert-equal
   "CLOCK: [2026-07-08 Wed 10:00]--[2026-07-08 Wed 10:30] =>  0:30"
   (tdw-gtd-clock-test--selected-line tdw-gtd-clock-test--multi-entry-text
                                      "2026-07-08 1000")))

(deftest gtd-clock/select-no-match-error-lists-candidates ()
  (let ((err (condition-case e
                 (progn (tdw-gtd--select-clock-entry
                         tdw-gtd-clock-test--multi-entry-text "1400"
                         tdw-gtd-clock-test--now)
                        nil)
               (error (cadr e)))))
    (assert-true err)
    (assert-true (string-match-p "2026-07-09 Thu 10:00" err))))

(deftest gtd-clock/select-errors-when-no-clock-entries-at-all ()
  (let ((text "** NEXT Fresh task\n:LOGBOOK:\n:END:\n"))
    (assert-true
     (condition-case nil
         (progn (tdw-gtd--select-clock-entry text nil tdw-gtd-clock-test--now) nil)
       (error t)))))

;;;; tdw-gtd--edit-clock-in-text (pure string transform)

(deftest gtd-clock/edit-new-start-on-open-clock-stays-open ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 10:00]
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-09 Thu 11:00\\]\n"
      (tdw-gtd--edit-clock-in-text text nil "1100" nil tdw-gtd-clock-test--now)))))

(deftest gtd-clock/edit-new-start-on-closed-entry-keeps-end ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:30] =>  0:30
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-09 Thu 10:15\\]--\\[2026-07-09 Thu 10:30\\] =>  0:15"
      (tdw-gtd--edit-clock-in-text text nil "1015" nil tdw-gtd-clock-test--now)))))

(deftest gtd-clock/edit-full-range-closes-open-clock ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 10:00]
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-09 Thu 11:00\\]--\\[2026-07-09 Thu 11:30\\] =>  0:30"
      (tdw-gtd--edit-clock-in-text text nil "1100" "1130" tdw-gtd-clock-test--now)))))

(deftest gtd-clock/edit-end-only-keeps-start ()
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:30] =>  0:30
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-09 Thu 10:00\\]--\\[2026-07-09 Thu 11:00\\] =>  1:00"
      (tdw-gtd--edit-clock-in-text text nil nil "1100" tdw-gtd-clock-test--now)))))

(deftest gtd-clock/edit-duration-keeps-start-moves-end ()
  "\"45m\" in the end slot means start + 45 minutes."
  (let ((text "\
** NEXT Some task                                    :tgl_foo:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:30] =>  0:30
:END:
"))
    (assert-true
     (string-match-p
      "CLOCK: \\[2026-07-09 Thu 10:00\\]--\\[2026-07-09 Thu 10:45\\] =>  0:45"
      (tdw-gtd--edit-clock-in-text text nil nil "45m" tdw-gtd-clock-test--now)))))

(deftest gtd-clock/edit-by-selector-leaves-other-entries-untouched ()
  (let* ((result (tdw-gtd--edit-clock-in-text
                  tdw-gtd-clock-test--multi-entry-text
                  "1000" "1100" "1130" tdw-gtd-clock-test--now)))
    (assert-true (string-match-p
                  "CLOCK: \\[2026-07-09 Thu 11:00\\]--\\[2026-07-09 Thu 11:30\\] =>  0:30"
                  result))
    (assert-true (string-match-p
                  "CLOCK: \\[2026-07-09 Thu 08:00\\]--\\[2026-07-09 Thu 08:40\\] =>  0:40"
                  result))
    (assert-true (string-match-p
                  "CLOCK: \\[2026-07-08 Wed 10:00\\]--\\[2026-07-08 Wed 10:30\\] =>  0:30"
                  result))))

(deftest gtd-clock/edit-errors-without-new-start-or-end ()
  (assert-true
   (condition-case nil
       (progn (tdw-gtd--edit-clock-in-text
               tdw-gtd-clock-test--multi-entry-text nil nil nil
               tdw-gtd-clock-test--now)
              nil)
     (error t))))

;;;; tdw-gtd-edit-clock (integration: real file + org-gtd-directory)

(deftest gtd-clock/edit-clock-edits-the-matched-task-in-file ()
  (tdw-gtd-clock-test--with-tasks-fixture tasks-file
      "\
* Actions
** NEXT Meeting prep                                  :tgl_orbit:
:LOGBOOK:
CLOCK: [2026-07-09 Thu 10:00]--[2026-07-09 Thu 10:30] =>  0:30
CLOCK: [2026-07-09 Thu 08:00]--[2026-07-09 Thu 08:40] =>  0:40
:END:
** NEXT Some other task                               :tgl_orbit:
:LOGBOOK:
:END:
"
    (tdw-gtd-edit-clock "Meeting prep" "1000" "1100" "1130"
                        tdw-gtd-clock-test--now)
    (let ((contents (tdw-gtd-clock-test--file-contents tasks-file)))
      (assert-true (string-match-p
                    "CLOCK: \\[2026-07-09 Thu 11:00\\]--\\[2026-07-09 Thu 11:30\\] =>  0:30"
                    contents))
      (assert-true (string-match-p
                    "CLOCK: \\[2026-07-09 Thu 08:00\\]--\\[2026-07-09 Thu 08:40\\] =>  0:40"
                    contents)))))

;;;; Wiring guard: config.org must actually load this module.

(defun tdw-gtd-clock-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "~/.emacs.d/config.org"))
    (buffer-string)))

(deftest gtd-clock/config-requires-the-module ()
  "config.org must require tdw-gtd-clock, or the live daemon never gets it."
  (assert-true (string-match-p "(require 'tdw-gtd-clock)"
                                (tdw-gtd-clock-test--config))))

(provide 'tdw-gtd-clock-test)
;;; tdw-gtd-clock-test.el ends here
