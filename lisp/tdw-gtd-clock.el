;;; tdw-gtd-clock.el --- Deterministic GTD clock adjustment -*- lexical-binding: t; -*-

;; Deterministic replacement for the adjust-timer workflow's mechanical
;; steps (duration parsing, latest-clock-out lookup, CLOCK-line
;; consolidation, tag swap) so a weak model just has to call
;; `tdw-gtd-adjust-timer' with a title and a duration, instead of doing
;; timestamp arithmetic and regex line-replacement by hand. Disambiguating
;; which task was meant, when the title text is ambiguous, is the one
;; judgment call this can't make silently - it signals a `user-error'
;; naming every candidate instead of guessing.

;;; Code:

(require 'cl-lib)

(defun tdw-gtd-parse-duration (duration-string)
  "Parse DURATION-STRING into a total number of minutes.
Accepts \"H:MM\" (e.g. \"2:15\"), \"Nh\", \"NhMm\", \"N.Nh\", and
\"N minutes\"/\"Nmin\"/\"Nm\" forms (with or without a space before the
unit). Signals `user-error' if DURATION-STRING matches none of these."
  (let ((s (string-trim duration-string)))
    (cond
     ((string-match "\\`\\([0-9]+\\):\\([0-9][0-9]\\)\\'" s)
      (+ (* 60 (string-to-number (match-string 1 s)))
         (string-to-number (match-string 2 s))))
     ((string-match
       "\\`\\(?:\\([0-9]+\\(?:\\.[0-9]+\\)?\\)[ \t]*h\\)?[ \t]*\\(?:\\([0-9]+\\)[ \t]*m\\(?:in\\(?:ute\\)?s?\\)?\\)?\\'"
       s)
      (let ((hours (match-string 1 s))
            (minutes (match-string 2 s)))
        (unless (or hours minutes)
          (user-error "tdw-gtd-parse-duration: unparseable duration %S" duration-string))
        (+ (round (* 60 (if hours (string-to-number hours) 0)))
           (if minutes (string-to-number minutes) 0))))
     (t (user-error "tdw-gtd-parse-duration: unparseable duration %S" duration-string)))))

(defun tdw-gtd--parse-org-timestamp (bracketed)
  "Parse a bracketed org timestamp like \"[2026-07-03 Fri 09:25]\" into a
time value. Self-contained rather than using org's own parser, since the
format here is always exactly this one shape."
  (if (string-match "\\[\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\) [A-Za-z]+ \\([0-9]+\\):\\([0-9]+\\)\\]" bracketed)
      (encode-time 0
                   (string-to-number (match-string 5 bracketed))
                   (string-to-number (match-string 4 bracketed))
                   (string-to-number (match-string 3 bracketed))
                   (string-to-number (match-string 2 bracketed))
                   (string-to-number (match-string 1 bracketed)))
    (error "tdw-gtd--parse-org-timestamp: unparseable timestamp %S" bracketed)))

(defun tdw-gtd--format-clock-line (start-time end-time minutes)
  "Format a consolidated CLOCK line, matching org's own right-aligned
H:MM convention (as seen throughout org-gtd-tasks.org): the hour field
is padded to width 2, so a 1-digit hour gets an extra space (\"=>  0:30\")
and a 2-digit hour doesn't (\"=> 11:00\") - NOT always exactly two
literal spaces before a bare hour digit."
  (format "CLOCK: %s--%s => %2d:%02d"
          (format-time-string "[%Y-%m-%d %a %H:%M]" start-time)
          (format-time-string "[%Y-%m-%d %a %H:%M]" end-time)
          (/ minutes 60)
          (% minutes 60)))

(defun tdw-gtd--latest-clock-out-in (logbook-body)
  "Return the time value of the latest clock-out timestamp among CLOCK
lines in LOGBOOK-BODY, or nil if there are none (no CLOCK lines, or all
of them still open)."
  (let ((latest nil) (pos 0))
    (while (string-match "^[ \t]*CLOCK: \\[[^]]+\\]--\\(\\[[^]]+\\]\\)" logbook-body pos)
      ;; Capture match-end BEFORE calling tdw-gtd--parse-org-timestamp:
      ;; that function does its own string-match internally, which would
      ;; clobber this match's data if read afterward - pos would then
      ;; never advance and this loop would spin forever.
      (let ((end-bracket (match-string 1 logbook-body))
            (next-pos (match-end 0)))
        (let ((end-time (tdw-gtd--parse-org-timestamp end-bracket)))
          (when (or (null latest) (time-less-p latest end-time))
            (setq latest end-time)))
        (setq pos next-pos)))
    latest))

(defun tdw-gtd--replace-logbook-clock (text minutes &optional now-time)
  "Return TEXT (a headline plus whatever follows it) with its :LOGBOOK:
CLOCK entries consolidated into ONE entry totaling MINUTES. Ends at the
latest existing clock-out found in TEXT, or NOW-TIME (default: current
time) if there is none to anchor on. Creates a :LOGBOOK: drawer right
after the headline line if TEXT doesn't have one yet. Signals
`user-error' rather than silently discarding an open (still running)
CLOCK entry."
  (let (logbook-beg logbook-end logbook-body)
    ;; NB: `^'/`$' are only anchors at the very start/end of a regexp (or
    ;; right after \\( or \\|) - mid-pattern, as they'd be after the
    ;; leading ".*\n" here, they'd match a literal caret/dollar character
    ;; instead. Anchor on literal newlines here rather than `^'/`$'.
    (when (string-match "\n[ \t]*:LOGBOOK:[ \t]*\n\\(\\(?:.*\n\\)*?\\)[ \t]*:END:[ \t]*" text)
      (setq logbook-beg (1+ (match-beginning 0))
            logbook-end (match-end 0)
            logbook-body (match-string 1 text)))
    (when (and logbook-body (string-match "^[ \t]*CLOCK: \\[[^]]+\\][ \t]*$" logbook-body))
      (user-error "tdw-gtd-adjust-timer: task has an open (still running) CLOCK entry - clock it out before adjusting"))
    (let* ((end-time (or (and logbook-body (tdw-gtd--latest-clock-out-in logbook-body))
                          now-time (current-time)))
           (start-time (time-subtract end-time (seconds-to-time (* 60 minutes))))
           (new-clock-line (tdw-gtd--format-clock-line start-time end-time minutes)))
      (if logbook-beg
          (concat (substring text 0 logbook-beg)
                  ":LOGBOOK:\n" new-clock-line "\n:END:"
                  (substring text logbook-end))
        (let ((nl (string-match "\n" text)))
          (if nl
              (concat (substring text 0 (1+ nl))
                      ":LOGBOOK:\n" new-clock-line "\n:END:\n"
                      (substring text (1+ nl)))
            (concat text "\n:LOGBOOK:\n" new-clock-line "\n:END:\n")))))))

(defun tdw-gtd--set-tgl-tag-in-headline (headline new-tag)
  "Return HEADLINE (its first line only) with its tgl_* tag replaced by
NEW-TAG, preserving any other tags, or NEW-TAG appended if it has none."
  (if (string-match "\\`\\(.*?\\)[ \t]*\\(:\\(?:[a-zA-Z0-9_]+:\\)+\\)[ \t]*\\'" headline)
      (let* ((prefix (match-string 1 headline))
             (tag-string (match-string 2 headline))
             (tags (split-string tag-string ":" t))
             (tags (cl-remove-if (lambda (tg) (string-prefix-p "tgl_" tg)) tags))
             (tags (append tags (list new-tag))))
        (format "%s :%s:" prefix (mapconcat #'identity tags ":")))
    (format "%s :%s:" (string-trim-right headline) new-tag)))

(defun tdw-gtd--set-tgl-tag (text new-tag)
  "Return TEXT with its headline's (first line's) tgl_* tag set to NEW-TAG."
  (let* ((nl (or (string-match "\n" text) (length text)))
         (headline (substring text 0 nl))
         (rest (substring text nl)))
    (concat (tdw-gtd--set-tgl-tag-in-headline headline new-tag) rest)))

(defun tdw-gtd--headline-bounds (title-substring)
  "In the current buffer, return (BEG . END) for the single subtree whose
headline contains TITLE-SUBSTRING (case-insensitive), where BEG is the
headline line's start and END is just before the next same-or-shallower
headline (or point-max). Signals `user-error', naming every candidate
line, if zero or more than one headline matches - never guesses."
  (let ((case-fold-search t)
        (regexp (concat "^\\(\\*+\\) .*" (regexp-quote title-substring)))
        (matches nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward regexp nil t)
        (push (cons (line-number-at-pos) (match-beginning 0)) matches)
        (end-of-line))
      (setq matches (nreverse matches)))
    (cond
     ((null matches)
      (user-error "tdw-gtd-adjust-timer: no headline matched %S" title-substring))
     ((> (length matches) 1)
      (user-error "tdw-gtd-adjust-timer: %d headlines matched %S (lines %s) - use more specific text"
                  (length matches) title-substring
                  (mapconcat (lambda (m) (number-to-string (car m))) matches ", ")))
     (t
      (let* ((beg (cdr (car matches)))
             (level (save-excursion (goto-char beg) (skip-chars-forward "*") (current-column)))
             (end (save-excursion
                    (goto-char beg)
                    (end-of-line)
                    (if (re-search-forward (format "^\\*\\{1,%d\\} " level) nil t)
                        (line-beginning-position)
                      (point-max)))))
        (cons beg end))))))

(defun tdw-gtd-adjust-timer (title-substring duration-string &optional new-tag now-time)
  "Consolidate the CLOCK entries of the task whose headline contains
TITLE-SUBSTRING (case-insensitive) into one entry totaling
DURATION-STRING (any form `tdw-gtd-parse-duration' accepts), optionally
replacing its tgl_* tag with NEW-TAG. Resolves org-gtd-tasks.org via the
live `org-gtd-directory'. Signals `user-error' naming the candidates if
zero or more than one headline matches, rather than guessing. Returns
the updated headline+logbook text."
  (let* ((minutes (tdw-gtd-parse-duration duration-string))
         (tasks-file (expand-file-name "org-gtd-tasks.org" org-gtd-directory)))
    (with-current-buffer (find-file-noselect tasks-file)
      (let* ((bounds (tdw-gtd--headline-bounds title-substring))
             (beg (car bounds))
             (end (cdr bounds))
             (text (buffer-substring-no-properties beg end))
             (updated (tdw-gtd--replace-logbook-clock text minutes now-time))
             (updated (if new-tag (tdw-gtd--set-tgl-tag updated new-tag) updated)))
        (goto-char beg)
        (delete-region beg end)
        (insert updated)
        (save-buffer)
        updated))))

(provide 'tdw-gtd-clock)
;;; tdw-gtd-clock.el ends here
