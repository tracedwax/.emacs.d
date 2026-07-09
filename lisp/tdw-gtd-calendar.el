;;; tdw-gtd-calendar.el --- Deterministic calendar sync -*- lexical-binding: t; -*-

;; Deterministic sync from Google Calendar event data (as returned by
;; `gws calendar events list', a standard Google Calendar API v3 response:
;; each event's start/end is either an RFC3339 datetime or a bare
;; YYYY-MM-DD date for an all-day event) into gcal.org, matching the
;; Today's Diary convention already pinned in tdw-diary-test.el. The
;; actual `gws' call stays outside this module - the model just needs to
;; pass the JSON-derived (TITLE START END) triples straight through, not
;; do any date math itself.

;;; Code:

(require 'iso8601)

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

(defun tdw-gtd-sync-calendar (events &optional date calendar-file)
  "Replace all calendar entries for DATE (a time value, default: today)
in CALENDAR-FILE (default: gcal.org under `org-gtd-directory') with
EVENTS - a list of (TITLE START END) triples, START/END as RFC3339
datetime strings or plain YYYY-MM-DD date strings (all-day), END may be
nil. Idempotent per day: re-running with fresh EVENTS for the same DATE
reflects exactly what's in EVENTS - a meeting that's been cancelled
since the last sync does not survive. Entries for OTHER dates are
untouched. Returns the number of events written."
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

(provide 'tdw-gtd-calendar)
;;; tdw-gtd-calendar.el ends here
