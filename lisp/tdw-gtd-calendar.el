;;; tdw-gtd-calendar.el --- Deterministic calendar sync -*- lexical-binding: t; -*-

;; Deterministic sync from Google Calendar event data into gcal.org,
;; matching the Today's Diary convention already pinned in
;; tdw-diary-test.el. `tdw-gtd-sync-calendar' takes the raw JSON string
;; `gws calendar events list --format json' already produces - the model
;; passes it straight through, no elisp list construction and no date
;; math of its own.

;;; Code:

(require 'iso8601)
(require 'json)

(defun tdw-gtd--parse-event-time (time-string)
  "Parse TIME-STRING - an RFC3339 datetime (e.g.
\"2026-07-09T09:00:00-05:00\") or a plain \"YYYY-MM-DD\" date (all-day) -
into a time value. All-day dates encode as local midnight: Google
represents them as a timezone-less date and the org target format is a
bare date too, so there is no \"correct\" instant to convert - local
midnight keeps the date itself stable."
  (let ((decoded (iso8601-parse time-string)))
    (if (nth 2 decoded)
        (encode-time decoded)
      (encode-time (append '(0 0 0) (nthcdr 3 decoded))))))

(defun tdw-gtd--format-calendar-entry (title start end)
  "Format one calendar event as an org heading matching the Today's
Diary convention (`** TITLE' / `:PROPERTIES:' / `:ORG_GTD:  Calendar' /
`:END:' / a plain active timestamp). START/END are time values; END nil
formats as an all-day date-only entry with no time range."
  (format "** %s\n:PROPERTIES:\n:ORG_GTD:  Calendar\n:END:\n%s\n"
          title
          (if end
              (format "<%s-%s>"
                      (format-time-string "%Y-%m-%d %a %H:%M" start)
                      (format-time-string "%H:%M" end))
            (format-time-string "<%Y-%m-%d %a>" start))))

(defun tdw-gtd--remove-calendar-entries-for-date (content date-string)
  "Return CONTENT with every calendar heading block (a `** ' heading line,
its :PROPERTIES:...:END: drawer, and the timestamp line right after)
whose timestamp date is DATE-STRING (\"YYYY-MM-DD\") removed."
  (let ((pos 0) (result ""))
    (while (string-match
            "\n\\*\\* [^\n]*\n:PROPERTIES:\n\\(?:[^\n]*\n\\)*?:END:\n<\\([0-9-]+\\)[^>]*>\n?"
            content pos)
      (let* ((block-date (match-string 1 content))
             (block-start (1+ (match-beginning 0)))
             (block-end (match-end 0)))
        (setq result (concat result (substring content pos block-start)))
        (unless (string-equal block-date date-string)
          (setq result (concat result (substring content block-start block-end))))
        (setq pos block-end)))
    (concat result (substring content pos))))

(defun tdw-gtd--sync-calendar-events (events &optional date calendar-file)
  "Replace all calendar entries for DATE (a time value, default: today)
in CALENDAR-FILE (default: gcal.org under `org-gtd-directory') with
EVENTS - a list of (TITLE START END) triples, START/END as RFC3339
datetime strings or plain YYYY-MM-DD date strings (all-day), END may be
nil. Idempotent per day: re-running with fresh EVENTS for the same DATE
reflects exactly what's in EVENTS - a meeting that's been cancelled
since the last sync does not survive. Entries for OTHER dates are
untouched. Returns the number of events written. Private: the calling
model uses the public `tdw-gtd-sync-calendar' (raw JSON) instead."
  (let* ((date-string (format-time-string "%Y-%m-%d" (or date (current-time))))
         (file (or calendar-file (expand-file-name "gcal.org" org-gtd-directory))))
    (with-current-buffer (find-file-noselect file)
      (let* ((cleaned (tdw-gtd--remove-calendar-entries-for-date
                        (buffer-string) date-string))
             (entries (mapconcat
                       (lambda (ev)
                         (tdw-gtd--format-calendar-entry
                          (nth 0 ev)
                          (tdw-gtd--parse-event-time (nth 1 ev))
                          (and (nth 2 ev) (tdw-gtd--parse-event-time (nth 2 ev)))))
                       events "")))
        (erase-buffer)
        (insert cleaned)
        (goto-char (point-max))
        (insert entries)
        (save-buffer)
        (length events)))))

(defun tdw-gtd--parse-events-json (json-string)
  "Parse JSON-STRING - a raw Google Calendar API v3 events.list response,
e.g. the output of `gws calendar events list --format json' - into a
list of (TITLE START END) triples. Ignores an all-day event's end.date
entirely (Google's end.date is EXCLUSIVE - the day AFTER the event even
for a single-day all-day event - so it is never a valid time-range end);
an all-day event's END is always nil in the result."
  (let* ((json-object-type 'alist)
         (json-key-type 'string)
         (json-array-type 'list)
         (parsed (json-read-from-string json-string))
         (items (cdr (assoc "items" parsed))))
    (mapcar
     (lambda (event)
       (let* ((title (or (cdr (assoc "summary" event)) "(untitled event)"))
              (start-obj (cdr (assoc "start" event)))
              (start-datetime (cdr (assoc "dateTime" start-obj)))
              (start-date (cdr (assoc "date" start-obj)))
              (all-day (and start-date (not start-datetime)))
              (end-obj (cdr (assoc "end" event)))
              (end-datetime (cdr (assoc "dateTime" end-obj))))
         (list title
               (or start-datetime start-date)
               (unless all-day end-datetime))))
     items)))

(defun tdw-gtd-sync-calendar (events-json &optional date calendar-file)
  "Replace all calendar entries for DATE (a time value, default: today)
in CALENDAR-FILE (default: gcal.org under `org-gtd-directory') with the
events in EVENTS-JSON - the raw JSON string from a Google Calendar API
v3 events.list response (e.g. `gws calendar events list --format json').
Pass that output straight through, unmodified: no elisp list
construction, no date parsing, no reformatting. Idempotent per day - see
`tdw-gtd--sync-calendar-events'. Returns the number of events written."
  (tdw-gtd--sync-calendar-events
   (tdw-gtd--parse-events-json events-json) date calendar-file))

(provide 'tdw-gtd-calendar)
;;; tdw-gtd-calendar.el ends here
