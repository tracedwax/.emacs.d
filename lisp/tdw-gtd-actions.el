;;; tdw-gtd-actions.el --- Deterministic NEXT-action filing -*- lexical-binding: t; -*-

;; Deterministic replacement for the old venndoor add-next-action
;; workflow's mechanical steps (deadline math, org formatting, tag-based
;; repo routing, Actions-subtree placement) so a weak model just calls
;; `tdw-gtd-add-next-action' with a title, instead of reasoning through
;; env-var scripts and routing-table lookups. Judgment (what the title
;; is, which tag when ambiguous) stays in the calling skill's prompt
;; layer - this file only does the parts with one correct answer.

;;; Code:

(require 'tdw-gtd-inbox)
(require 'tdw-gtd-tags)

(defun tdw-gtd-actions--slug (title)
  "Reduce TITLE to the alphanumeric-and-hyphen slug org-gtd uses in IDs."
  (replace-regexp-in-string
   "\\`-\\|-\\'" ""
   (replace-regexp-in-string "[^A-Za-z0-9]+" "-" title)))

(defun tdw-gtd-actions--format-entry (title tag deadline now)
  "Format one `** NEXT' Actions entry, matching the convention already in
the context repos' org-gtd-tasks.org files: drawer before DEADLINE,
bare capture timestamp last."
  (format "** NEXT %s :%s:\n:PROPERTIES:\n:ORG_GTD: Actions\n:ID:      %s-%s\n:END:\nDEADLINE: %s\n%s\n"
          title tag
          (tdw-gtd-actions--slug title)
          (format-time-string "%Y-%m-%d-%H-%M-%S" now)
          (tdw-gtd--format-deadline deadline)
          (tdw-gtd--format-capture-timestamp now)))

(defun tdw-gtd-add-next-action (title &optional tag deadline-time now-time)
  "File a `** NEXT TITLE :TAG:' single action into the routed tasks file.
TAG defaults to `tdw-gtd-guess-tag' on TITLE. DEADLINE-TIME defaults to
the next Friday on-or-after NOW-TIME (default: now). The target file is
org-gtd-tasks.org in the tag's context repo GTD dir per
`tdw-gtd-tags-gtd-dir-for-tag', falling back to `org-gtd-directory' for
unrouted tags. The entry lands at the end of the `* Actions' subtree
(created at end of file if missing), never inside a later top-level
section. Returns (:entry TEXT :file PATH)."
  (let* ((now (or now-time (current-time)))
         (tag (or tag (tdw-gtd-guess-tag title)))
         (deadline (or deadline-time (tdw-gtd-next-friday-from now)))
         (dir (or (tdw-gtd-tags-gtd-dir-for-tag tag) org-gtd-directory))
         (file (expand-file-name "org-gtd-tasks.org" dir))
         (entry (tdw-gtd-actions--format-entry title tag deadline now)))
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-min))
      (if (re-search-forward "^\\* Actions[ \t]*\\(?::.*:\\)?$" nil t)
          ;; End of the Actions subtree = next top-level heading or eof.
          (if (re-search-forward "^\\* " nil t)
              (goto-char (match-beginning 0))
            (goto-char (point-max)))
        (goto-char (point-max))
        (unless (bobp) (unless (bolp) (insert "\n")))
        (insert "* Actions\n"))
      (unless (bolp) (insert "\n"))
      (insert entry)
      (save-buffer))
    (list :entry entry :file file)))

(provide 'tdw-gtd-actions)
;;; tdw-gtd-actions.el ends here
