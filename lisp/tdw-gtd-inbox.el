;;; tdw-gtd-inbox.el --- Deterministic GTD inbox capture -*- lexical-binding: t; -*-

;; Deterministic replacement for the add-to-inbox workflow's mechanical
;; steps (next-Friday date math, org entry formatting, file append) so a
;; weak model just has to call `tdw-gtd-add-inbox-item' with a title,
;; instead of reasoning through date arithmetic and org syntax. Genuine
;; judgment (rewriting a vague title into a SMART one) stays in the
;; calling skill/workflow's prompt layer - this file only does the parts
;; that have exactly one correct answer.

;;; Code:

(require 'time-date)

(defun tdw-gtd-next-friday-from (time)
  "Return a time value for the next Friday on-or-after TIME's date.
If TIME's date is already a Friday, rolls to the following week instead
of returning TIME itself, so a task captured today is never immediately
due - \"following Friday\" means the next one, not necessarily today."
  (let* ((dow (nth 6 (decode-time time)))
         (diff (mod (- 5 dow) 7))
         (diff (if (zerop diff) 7 diff)))
    (time-add time (days-to-time diff))))

(defun tdw-gtd-next-friday ()
  "Return a time value for the next Friday on-or-after today."
  (tdw-gtd-next-friday-from (current-time)))

(defun tdw-gtd--format-deadline (time)
  "Format TIME as an org DEADLINE timestamp, e.g. \"<2026-07-10 Fri>\"."
  (format-time-string "<%Y-%m-%d %a>" time))

(defun tdw-gtd--format-capture-timestamp (time)
  "Format TIME as a bare org timestamp, e.g. \"[2026-07-09 Thu 14:30]\"."
  (format-time-string "[%Y-%m-%d %a %H:%M]" time))

(defun tdw-gtd-add-inbox-item (title &optional deadline-time now-time)
  "Append a TODO entry for TITLE to the GTD inbox file.
DEADLINE-TIME defaults to the next Friday on-or-after NOW-TIME (which
defaults to the current time). Resolves the inbox file via the live
`org-gtd-directory' rather than a hardcoded path, so this works
correctly under any account's config. Operates on the file's existing
buffer if one is open (preserving any unrelated unsaved edits in it)
rather than reverting from disk. Returns the text of the entry written."
  (let* ((now (or now-time (current-time)))
         (deadline (or deadline-time (tdw-gtd-next-friday-from now)))
         (inbox-file (expand-file-name "inbox.org" org-gtd-directory))
         (entry (format "* TODO %s\n:PROPERTIES:\n:ORG_GTD: Inbox\n:END:\nDEADLINE: %s\n%s\n"
                         title
                         (tdw-gtd--format-deadline deadline)
                         (tdw-gtd--format-capture-timestamp now))))
    (with-current-buffer (find-file-noselect inbox-file)
      (goto-char (point-max))
      (unless (bobp) (unless (bolp) (insert "\n")))
      (insert entry)
      (save-buffer))
    entry))

(provide 'tdw-gtd-inbox)
;;; tdw-gtd-inbox.el ends here
