;;; tdw-gtd-calendar-test.el --- Tests for deterministic calendar sync -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw-gtd-sync-calendar' is a from-scratch deterministic replacement for
;; a "sync-calendar" capability that has no existing prior-art workflow
;; doc to port from (unlike the other 3 skills) - designed from the
;; Today's Diary convention already pinned in tdw-diary-test.el
;; (`** <title>` / `:PROPERTIES:` / `:ORG_GTD: Calendar` / `:END:` / a
;; plain active timestamp) plus the standard Google Calendar API v3 event
;; shape (RFC3339 datetime or a bare YYYY-MM-DD date for all-day), which
;; `gws calendar events list` returns.
;;
;; Idempotent per day: syncing DATE replaces every existing entry for that
;; date and nothing else, so re-running with fresh events never
;; accumulates stale/cancelled meetings (the exact class of bug
;; `tdw-diary-test.el` already guards against on the read side).

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-gtd-calendar)

;;;; tdw-gtd--parse-event-time

(deftest gtd-calendar/parses-rfc3339-datetime-with-offset ()
  (assert-equal "2026-07-09 14:00 +0000"
                (format-time-string "%Y-%m-%d %H:%M %z"
                                     (tdw-gtd--parse-event-time "2026-07-09T09:00:00-05:00")
                                     t)))

(deftest gtd-calendar/parses-date-only-as-midnight-local-time ()
  "All-day events are timezone-ambiguous by nature (Google represents them
as a bare date, and the org format targets a bare date too) - encode as
LOCAL midnight, not UTC, so this must format back with local time too,
not a UTC-forced comparison that would drift with the runner's timezone."
  (assert-equal "2026-07-09 00:00"
                (format-time-string "%Y-%m-%d %H:%M"
                                     (tdw-gtd--parse-event-time "2026-07-09"))))

;;;; tdw-gtd--format-calendar-entry

(deftest gtd-calendar/formats-timed-entry ()
  (assert-equal
   "** Standup\n:PROPERTIES:\n:ORG_GTD:  Calendar\n:END:\n<2026-07-09 Thu 09:00-09:15>\n"
   (tdw-gtd--format-calendar-entry
    "Standup"
    (tdw-gtd--parse-event-time "2026-07-09T09:00:00-04:00")
    (tdw-gtd--parse-event-time "2026-07-09T09:15:00-04:00"))))

(deftest gtd-calendar/formats-all-day-entry-with-no-time-range ()
  (assert-equal
   "** Company holiday\n:PROPERTIES:\n:ORG_GTD:  Calendar\n:END:\n<2026-07-09 Thu>\n"
   (tdw-gtd--format-calendar-entry
    "Company holiday"
    (tdw-gtd--parse-event-time "2026-07-09")
    nil)))

;;;; tdw-gtd--remove-calendar-entries-for-date (pure string transform)

(defconst tdw-gtd-calendar-test--two-day-fixture "\
* Calendar
** Old meeting
:PROPERTIES:
:ORG_GTD:  Calendar
:END:
<2026-07-03 Fri 09:30-09:45>
** Other day meeting
:PROPERTIES:
:ORG_GTD:  Calendar
:END:
<2026-07-04 Sat 10:00-10:30>
")

(deftest gtd-calendar/removes-only-the-matching-date ()
  (let ((result (tdw-gtd--remove-calendar-entries-for-date
                 tdw-gtd-calendar-test--two-day-fixture "2026-07-03")))
    (assert-nil (string-match-p "Old meeting" result))
    (assert-true (string-match-p "Other day meeting" result))))

(deftest gtd-calendar/no-match-leaves-content-untouched ()
  (assert-equal tdw-gtd-calendar-test--two-day-fixture
                (tdw-gtd--remove-calendar-entries-for-date
                 tdw-gtd-calendar-test--two-day-fixture "2026-01-01")))

;;;; tdw-gtd-sync-calendar (integration: real file + org-gtd-directory)

(defmacro tdw-gtd-calendar-test--with-fixture (var content &rest body)
  "Bind VAR to a temp gcal.org path containing CONTENT, with
`org-gtd-directory' let-bound to its parent, run BODY, then clean up."
  (declare (indent 2))
  `(let* ((dir (make-temp-file "tdw-gtd-calendar-test" t))
          (org-gtd-directory dir)
          (,var (expand-file-name "gcal.org" dir)))
     (unwind-protect
         (progn
           (with-temp-file ,var (insert ,content))
           ,@body)
       (let ((buf (find-buffer-visiting ,var)))
         (when buf (kill-buffer buf)))
       (delete-directory dir t))))

(defun tdw-gtd-calendar-test--file-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(deftest gtd-calendar/sync-writes-fresh-events-for-the-target-date ()
  (tdw-gtd-calendar-test--with-fixture gcal-file "* Calendar\n"
    (tdw-gtd--sync-calendar-events
     '(("Standup" "2026-07-09T09:00:00-04:00" "2026-07-09T09:15:00-04:00"))
     (tdw-gtd--parse-event-time "2026-07-09"))
    (assert-true (string-match-p "Standup" (tdw-gtd-calendar-test--file-contents gcal-file)))))

(deftest gtd-calendar/sync-removes-stale-same-date-entries-first ()
  "Idempotent re-sync: an old entry for the target date that's no longer
in EVENTS (e.g. a cancelled meeting) must not survive the sync."
  (tdw-gtd-calendar-test--with-fixture gcal-file
      "\
* Calendar
** Cancelled meeting
:PROPERTIES:
:ORG_GTD:  Calendar
:END:
<2026-07-09 Thu 14:00-14:30>
"
    (tdw-gtd--sync-calendar-events
     '(("Standup" "2026-07-09T09:00:00-04:00" "2026-07-09T09:15:00-04:00"))
     (tdw-gtd--parse-event-time "2026-07-09"))
    (let ((contents (tdw-gtd-calendar-test--file-contents gcal-file)))
      (assert-nil (string-match-p "Cancelled meeting" contents))
      (assert-true (string-match-p "Standup" contents)))))

(deftest gtd-calendar/sync-preserves-other-dates ()
  (tdw-gtd-calendar-test--with-fixture gcal-file
      "\
* Calendar
** Yesterday's meeting
:PROPERTIES:
:ORG_GTD:  Calendar
:END:
<2026-07-08 Wed 10:00-10:30>
"
    (tdw-gtd--sync-calendar-events
     '(("Standup" "2026-07-09T09:00:00-04:00" "2026-07-09T09:15:00-04:00"))
     (tdw-gtd--parse-event-time "2026-07-09"))
    (assert-true (string-match-p "Yesterday's meeting"
                                  (tdw-gtd-calendar-test--file-contents gcal-file)))))

(deftest gtd-calendar/sync-handles-multiple-events ()
  (tdw-gtd-calendar-test--with-fixture gcal-file "* Calendar\n"
    (tdw-gtd--sync-calendar-events
     '(("Standup" "2026-07-09T09:00:00-04:00" "2026-07-09T09:15:00-04:00")
       ("Lunch" "2026-07-09T12:00:00-04:00" "2026-07-09T13:00:00-04:00")
       ("Company holiday" "2026-07-09" nil))
     (tdw-gtd--parse-event-time "2026-07-09"))
    (let ((contents (tdw-gtd-calendar-test--file-contents gcal-file)))
      (assert-true (string-match-p "Standup" contents))
      (assert-true (string-match-p "Lunch" contents))
      (assert-true (string-match-p "Company holiday" contents)))))

;;;; tdw-gtd--parse-events-json (pure transform of a raw Calendar API response)

(deftest gtd-calendar/parses-json-timed-event ()
  (assert-equal
   '(("Standup" "2026-07-09T09:00:00-04:00" "2026-07-09T09:15:00-04:00"))
   (tdw-gtd--parse-events-json
    "{\"items\": [{\"summary\": \"Standup\", \"start\": {\"dateTime\": \"2026-07-09T09:00:00-04:00\"}, \"end\": {\"dateTime\": \"2026-07-09T09:15:00-04:00\"}}]}")))

(deftest gtd-calendar/parses-json-all-day-event-ignoring-exclusive-end-date ()
  "Google's all-day end.date is EXCLUSIVE (the day AFTER the event, even
for a 1-day event) - must not be treated as a time-range end. The parsed
triple's END must be nil for any all-day event, regardless of what
end.date says, so the formatter shows a bare date, not a bogus range."
  (assert-equal
   '(("Company holiday" "2026-07-09" nil))
   (tdw-gtd--parse-events-json
    "{\"items\": [{\"summary\": \"Company holiday\", \"start\": {\"date\": \"2026-07-09\"}, \"end\": {\"date\": \"2026-07-10\"}}]}")))

(deftest gtd-calendar/parses-json-multiple-events ()
  (assert-equal 2
                (length (tdw-gtd--parse-events-json
                         "{\"items\": [{\"summary\": \"A\", \"start\": {\"dateTime\": \"2026-07-09T09:00:00-04:00\"}, \"end\": {\"dateTime\": \"2026-07-09T09:15:00-04:00\"}}, {\"summary\": \"B\", \"start\": {\"dateTime\": \"2026-07-09T10:00:00-04:00\"}, \"end\": {\"dateTime\": \"2026-07-09T10:15:00-04:00\"}}]}"))))

(deftest gtd-calendar/parses-json-empty-items ()
  (assert-nil (tdw-gtd--parse-events-json "{\"items\": []}")))

;;;; tdw-gtd-sync-calendar (public entry point: raw gws JSON straight through)

(deftest gtd-calendar/public-sync-calendar-accepts-raw-gws-json ()
  "The model passes gws's raw --format json output straight through - no
elisp list construction, no date math, no reformatting."
  (tdw-gtd-calendar-test--with-fixture gcal-file "* Calendar\n"
    (tdw-gtd-sync-calendar
     "{\"items\": [{\"summary\": \"Standup\", \"start\": {\"dateTime\": \"2026-07-09T09:00:00-04:00\"}, \"end\": {\"dateTime\": \"2026-07-09T09:15:00-04:00\"}}]}"
     (tdw-gtd--parse-event-time "2026-07-09"))
    (assert-true (string-match-p "Standup" (tdw-gtd-calendar-test--file-contents gcal-file)))))

;;;; Wiring guard: config.org must actually load this module.

(defun tdw-gtd-calendar-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "~/.emacs.d/config.org"))
    (buffer-string)))

(deftest gtd-calendar/config-requires-the-module ()
  "config.org must require tdw-gtd-calendar, or the live daemon never gets it."
  (assert-true (string-match-p "(require 'tdw-gtd-calendar)"
                                (tdw-gtd-calendar-test--config))))

(provide 'tdw-gtd-calendar-test)
;;; tdw-gtd-calendar-test.el ends here
