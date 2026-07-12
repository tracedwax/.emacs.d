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
(require 'tdw-gtd-tags)

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
defaults to the current time). Appends to org-gtd-tasks.org (NOT the dead
inbox.org staging file: every repo has ONE federated tasks file and Inbox
membership is the ORG_GTD property, not a separate file), resolved via the
live `org-gtd-directory' so this works under any account's config.
Operates on the file's existing buffer if one is open (preserving any
unrelated unsaved edits in it) rather than reverting from disk. Returns
the text of the entry written."
  (let* ((now (or now-time (current-time)))
         (deadline (or deadline-time (tdw-gtd-next-friday-from now)))
         (inbox-file (expand-file-name "org-gtd-tasks.org" org-gtd-directory))
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

(defun tdw-gtd--format-inbox-task (title tag deadline-time now-time delegate-to)
  "Format one org-gtd-tasks.org Inbox entry, same shape as
`tdw-gtd-add-inbox-item' plus TAG appended to the headline and an
optional DELEGATE-TO body line."
  (format "* TODO %s :%s:\n:PROPERTIES:\n:ORG_GTD: Inbox\n:END:\nDEADLINE: %s\n%s%s\n"
          title tag
          (tdw-gtd--format-deadline deadline-time)
          (if delegate-to (format "Delegated to: %s\n" delegate-to) "")
          (tdw-gtd--format-capture-timestamp now-time)))

(defun tdw-gtd-file-tasks-to-inbox (tasks &optional now-time tasks-file)
  "Append TASKS to org-gtd-tasks.org's Inbox (default: org-gtd-tasks.org
under `org-gtd-directory') in ONE save - the batch-filing counterpart to
`tdw-gtd-add-inbox-item' for already-groomed action items (e.g. from a
30-second-summary file), which target org-gtd-tasks.org directly rather
than the separate inbox.org staging file.

TASKS is a list of plists, each with:
  :title       (required) the action text.
  :tag         a tgl_* tag; guessed via `tdw-gtd-guess-tag' from :title if omitted.
  :deadline    a time value; defaults to the next Friday on-or-after NOW-TIME if omitted.
  :delegate-to a name; adds a \"Delegated to: NAME\" body line if given.

Returns the number of tasks filed."
  (let* ((now (or now-time (current-time)))
         (file (or tasks-file (expand-file-name "org-gtd-tasks.org" org-gtd-directory)))
         (entries (mapconcat
                   (lambda (task)
                     (let* ((title (plist-get task :title))
                            (tag (or (plist-get task :tag) (tdw-gtd-guess-tag title)))
                            (deadline (or (plist-get task :deadline)
                                          (tdw-gtd-next-friday-from now)))
                            (delegate-to (plist-get task :delegate-to)))
                       (tdw-gtd--format-inbox-task title tag deadline now delegate-to)))
                   tasks "")))
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-max))
      (unless (bobp) (unless (bolp) (insert "\n")))
      (insert entries)
      (save-buffer))
    (length tasks)))

(provide 'tdw-gtd-inbox)
;;; tdw-gtd-inbox.el ends here
