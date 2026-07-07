;;; tdw-diary.el --- Today's Diary agenda block semantics -*- lexical-binding: t; -*-

;; The Today's Diary block (formerly "Clock Log") shows one day of:
;;   - meetings from gcal.org (plain timestamps, past AND future), and
;;   - CLOCK lines (closed and open) from every task file,
;; and nothing else.  In particular, tasks must never leak in, neither
;; via SCHEDULED (excluded by entry types) nor via plain active
;; timestamps in task files (excluded by the skip function).
;;
;; This file exists so the Unordered View block in config.org and the
;; suite in test/unit/tdw-diary-test.el share ONE definition of those
;; semantics: the view splices in `tdw-diary-agenda-options', and the
;; tests run `tdw-diary-build-agenda', which binds exactly what that
;; function returns.  Change the options and the tests see it; break
;; the semantics and the tests fail.

(require 'org)
(require 'org-agenda)

(defvar tdw-diary-timestamp-file-regexp "\\(?:\\`\\|/\\)gcal\\.org\\'"
  "Files whose plain-timestamp entries may appear in Today's Diary.
Everything else contributes only CLOCK log lines.")

(defun tdw-diary--timestamp-file-p ()
  "Non-nil if the current buffer's file may contribute timestamp entries."
  (let ((file (buffer-file-name (buffer-base-buffer))))
    (and file (string-match-p tdw-diary-timestamp-file-regexp file))))

(defun tdw-diary-skip-non-gcal-timestamps ()
  "Skip function for Today's Diary.
Keep CLOCK log lines from any file; keep timestamp entries only from
files matching `tdw-diary-timestamp-file-regexp'.  Both agenda
collectors (`org-agenda-get-timestamps' AND `org-agenda-get-progress')
consult the skip function with point on the matched line, so CLOCK
lines must be whitelisted explicitly or the log itself disappears."
  (unless (or (save-excursion
                (beginning-of-line)
                (looking-at-p (concat "[ \t]*" (regexp-quote org-clock-string))))
              (tdw-diary--timestamp-file-p))
    (org-entry-end-position)))

(defun tdw-diary-agenda-options (files header)
  "Semantic agenda options for the Today's Diary block.
FILES is the full file list (gcal.org first, then task files); HEADER
is the overriding header string.  Returns (variable value-form) pairs
ready to splice into an agenda block or bind directly.

Log mode must be t, NOT \\='only: \\='only makes org fetch ONLY :closed
log items and ignore `org-agenda-entry-types', which is the bug that
emptied the calendar when timesheet.org died.  :timestamp (and no
:scheduled/:deadline) is what lets meetings in while keeping
SCHEDULED tasks out."
  `((org-agenda-overriding-header ,header)
    (org-agenda-span 1)
    (org-agenda-start-day nil)
    (org-agenda-include-diary nil)
    (org-agenda-start-with-log-mode t)
    ;; start-with-log-mode is copied into org-agenda-show-log only when
    ;; org-agenda-mode initializes a buffer; block/series agendas run the
    ;; mode once BEFORE per-block option bindings, so without show-log
    ;; here the production diary block drops every clock line while
    ;; standalone rendering keeps them.
    (org-agenda-show-log t)
    (org-agenda-log-mode-items '(clock))
    (org-agenda-files ',files)
    (org-agenda-entry-types '(:timestamp))
    (org-agenda-skip-function #'tdw-diary-skip-non-gcal-timestamps)
    ;; `org-agenda-skip-function-global' (config.org) skips DONE/CNCL entries
    ;; in every OTHER view, but Today's Diary must keep CLOCK lines regardless
    ;; of the parent task's TODO state.  `org-agenda-skip' ORs the global and
    ;; per-block skip functions, so the global one must be neutralized here,
    ;; not folded into the per-block skip function above.
    (org-agenda-skip-function-global nil)))

(defun tdw-diary-build-agenda (files &optional day)
  "Build the Today's Diary agenda for FILES (on DAY) and return its text.
Binds exactly the options `tdw-diary-agenda-options' returns, so tests
exercise the very options the Unordered View uses.  For tests."
  (let* ((options (tdw-diary-agenda-options files "Today's Diary"))
         (variables (mapcar #'car options))
         (values (mapcar (lambda (option) (eval (cadr option) t)) options)))
    (cl-progv variables values
      (let ((org-agenda-sticky nil)
            (org-agenda-buffer-name "*tdw-diary-test-agenda*"))
        (org-agenda-list nil day 1)
        (with-current-buffer org-agenda-buffer-name
          (prog1 (buffer-string)
            (kill-buffer)))))))

(provide 'tdw-diary)
;;; tdw-diary.el ends here
