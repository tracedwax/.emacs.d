;;; tdw-gtd-inbox-test.el --- Tests for deterministic GTD inbox capture -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw-gtd-add-inbox-item' is the deterministic replacement for the
;; add-to-inbox workflow's mechanical steps (next-Friday date math, org
;; formatting, file append) so a weak model just has to call one function
;; with a title, instead of reasoning through date arithmetic and org syntax.
;;
;; All next-Friday tests anchor on 2026-07-03, a known Friday (the same
;; anchor date `tdw-diary-test.el' already relies on), so the suite is
;; deterministic regardless of the day it runs. The entry-format tests reuse
;; the exact example dates from `.agent/workflows/add-to-inbox.md'
;; (2026-02-15 Sun -> 2026-02-20 Fri) so the pinned format matches the
;; documented convention precisely.

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-gtd-inbox)

(defun tdw-gtd-inbox-test--date (day month year)
  "Return a time value for YEAR-MONTH-DAY at midnight, local time."
  (encode-time 0 0 0 day month year))

;;;; tdw-gtd-next-friday-from

(deftest gtd-inbox/next-friday-from-monday-is-this-week ()
  "Monday rolls forward 4 days to this week's Friday."
  (assert-equal "2026-07-03 Fri"
                (format-time-string "%Y-%m-%d %a"
                                     (tdw-gtd-next-friday-from
                                      (tdw-gtd-inbox-test--date 29 6 2026)))))

(deftest gtd-inbox/next-friday-from-thursday-is-tomorrow ()
  "Thursday rolls forward 1 day to this week's Friday."
  (assert-equal "2026-07-03 Fri"
                (format-time-string "%Y-%m-%d %a"
                                     (tdw-gtd-next-friday-from
                                      (tdw-gtd-inbox-test--date 2 7 2026)))))

(deftest gtd-inbox/next-friday-from-friday-rolls-to-next-week ()
  "Friday itself rolls a full week forward rather than returning today.
A task captured on a Friday shouldn't default to being due immediately."
  (assert-equal "2026-07-10 Fri"
                (format-time-string "%Y-%m-%d %a"
                                     (tdw-gtd-next-friday-from
                                      (tdw-gtd-inbox-test--date 3 7 2026)))))

(deftest gtd-inbox/next-friday-from-saturday-is-next-week ()
  "Saturday rolls forward to next week's Friday (this week's has passed)."
  (assert-equal "2026-07-10 Fri"
                (format-time-string "%Y-%m-%d %a"
                                     (tdw-gtd-next-friday-from
                                      (tdw-gtd-inbox-test--date 4 7 2026)))))

(deftest gtd-inbox/next-friday-from-sunday-is-next-week ()
  "Sunday rolls forward to next week's Friday."
  (assert-equal "2026-07-10 Fri"
                (format-time-string "%Y-%m-%d %a"
                                     (tdw-gtd-next-friday-from
                                      (tdw-gtd-inbox-test--date 5 7 2026)))))

;;;; tdw-gtd-add-inbox-item

(defmacro tdw-gtd-inbox-test--with-fixture (var &rest body)
  "Bind VAR to a temp inbox.org path, `org-gtd-directory' to its parent, run BODY."
  (declare (indent 1))
  `(let* ((dir (make-temp-file "tdw-gtd-inbox-test" t))
          (org-gtd-directory dir)
          (,var (expand-file-name "inbox.org" dir)))
     (unwind-protect
         (progn
           (with-temp-file ,var (insert ""))
           ,@body)
       (delete-directory dir t))))

(defun tdw-gtd-inbox-test--file-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(deftest gtd-inbox/entry-format-matches-org-gtd-convention ()
  "Properties drawer comes before DEADLINE (this repo's convention, not the
usual org ordering), followed by a bare capture timestamp - pinned against
the exact example in .agent/workflows/add-to-inbox.md."
  (tdw-gtd-inbox-test--with-fixture inbox-file
    (tdw-gtd-add-inbox-item "Buy milk"
                             (tdw-gtd-inbox-test--date 20 2 2026)
                             (tdw-gtd-inbox-test--date 15 2 2026))
    (assert-true
     (string-match-p
      "\\* TODO Buy milk\n:PROPERTIES:\n:ORG_GTD: Inbox\n:END:\nDEADLINE: <2026-02-20 Fri>\n\\[2026-02-15 Sun [0-9][0-9]:[0-9][0-9]\\]"
      (tdw-gtd-inbox-test--file-contents inbox-file)))))

(deftest gtd-inbox/deadline-defaults-to-next-friday-of-now ()
  "Omitting the deadline arg defaults to `tdw-gtd-next-friday-from' of NOW."
  (tdw-gtd-inbox-test--with-fixture inbox-file
    (tdw-gtd-add-inbox-item "Buy milk" nil (tdw-gtd-inbox-test--date 15 2 2026))
    (assert-true (string-match-p "DEADLINE: <2026-02-20 Fri>"
                                  (tdw-gtd-inbox-test--file-contents inbox-file)))))

(deftest gtd-inbox/appends-without-clobbering-existing-content ()
  "A second item lands after the first, not overwriting it."
  (tdw-gtd-inbox-test--with-fixture inbox-file
    (tdw-gtd-add-inbox-item "First item"
                             (tdw-gtd-inbox-test--date 20 2 2026)
                             (tdw-gtd-inbox-test--date 15 2 2026))
    (tdw-gtd-add-inbox-item "Second item"
                             (tdw-gtd-inbox-test--date 20 2 2026)
                             (tdw-gtd-inbox-test--date 15 2 2026))
    (let ((contents (tdw-gtd-inbox-test--file-contents inbox-file)))
      (assert-true (string-match-p "First item" contents))
      (assert-true (string-match-p "Second item" contents)))))

(deftest gtd-inbox/works-with-no-optional-args ()
  "Real usage passes only a title; must produce a well-formed entry."
  (tdw-gtd-inbox-test--with-fixture inbox-file
    (tdw-gtd-add-inbox-item "Buy milk")
    (let ((contents (tdw-gtd-inbox-test--file-contents inbox-file)))
      (assert-true (string-match-p "\\* TODO Buy milk" contents))
      (assert-true (string-match-p
                    "DEADLINE: <[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [A-Za-z][A-Za-z][A-Za-z]>"
                    contents)))))

(deftest gtd-inbox/returns-the-formatted-entry ()
  "Returns the text it wrote, so a calling skill can report it back."
  (tdw-gtd-inbox-test--with-fixture inbox-file
    (let ((result (tdw-gtd-add-inbox-item
                    "Buy milk"
                    (tdw-gtd-inbox-test--date 20 2 2026)
                    (tdw-gtd-inbox-test--date 15 2 2026))))
      (assert-true (string-match-p "Buy milk" result))
      (assert-true (string-match-p "2026-02-20" result)))))

;;;; tdw-gtd-file-tasks-to-inbox (batch: groomed 30ss action items -> org-gtd-tasks.org)

(defmacro tdw-gtd-inbox-test--with-tasks-fixture (var &rest body)
  "Bind VAR to a temp org-gtd-tasks.org path, `org-gtd-directory' to its
parent, run BODY."
  (declare (indent 1))
  `(let* ((dir (make-temp-file "tdw-gtd-inbox-test" t))
          (org-gtd-directory dir)
          (,var (expand-file-name "org-gtd-tasks.org" dir)))
     (unwind-protect
         (progn
           (with-temp-file ,var (insert "* Inbox\n"))
           ,@body)
       (let ((buf (find-buffer-visiting ,var)))
         (when buf (kill-buffer buf)))
       (delete-directory dir t))))

(deftest gtd-inbox/file-tasks-appends-with-explicit-tag-and-deadline ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (tdw-gtd-file-tasks-to-inbox
     (list (list :title "Send SOW to Acme" :tag "tgl_no_project"
                 :deadline (tdw-gtd-inbox-test--date 20 2 2026)))
     (tdw-gtd-inbox-test--date 15 2 2026))
    (let ((contents (tdw-gtd-inbox-test--file-contents tasks-file)))
      (assert-true (string-match-p "\\* TODO Send SOW to Acme :tgl_no_project:" contents))
      (assert-true (string-match-p ":ORG_GTD: Inbox" contents))
      (assert-true (string-match-p "DEADLINE: <2026-02-20 Fri>" contents)))))

(deftest gtd-inbox/file-tasks-guesses-tag-when-not-given ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (tdw-gtd-file-tasks-to-inbox
     (list (list :title "Daily standup notes"))
     (tdw-gtd-inbox-test--date 15 2 2026))
    (assert-true (string-match-p ":tgl_barefoot_internal_sales:"
                                  (tdw-gtd-inbox-test--file-contents tasks-file)))))

(deftest gtd-inbox/file-tasks-includes-delegate-line-when-given ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (tdw-gtd-file-tasks-to-inbox
     (list (list :title "Review the deck" :tag "tgl_no_project" :delegate-to "Jason"))
     (tdw-gtd-inbox-test--date 15 2 2026))
    (assert-true (string-match-p "Delegated to: Jason"
                                  (tdw-gtd-inbox-test--file-contents tasks-file)))))

(deftest gtd-inbox/file-tasks-omits-delegate-line-when-not-given ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (tdw-gtd-file-tasks-to-inbox
     (list (list :title "Review the deck" :tag "tgl_no_project"))
     (tdw-gtd-inbox-test--date 15 2 2026))
    (assert-nil (string-match-p "Delegated to:"
                                 (tdw-gtd-inbox-test--file-contents tasks-file)))))

(deftest gtd-inbox/file-tasks-writes-multiple-in-one-call ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (tdw-gtd-file-tasks-to-inbox
     (list (list :title "First task" :tag "tgl_no_project")
           (list :title "Second task" :tag "tgl_no_project")
           (list :title "Third task" :tag "tgl_no_project"))
     (tdw-gtd-inbox-test--date 15 2 2026))
    (let ((contents (tdw-gtd-inbox-test--file-contents tasks-file)))
      (assert-true (string-match-p "First task" contents))
      (assert-true (string-match-p "Second task" contents))
      (assert-true (string-match-p "Third task" contents)))))

(deftest gtd-inbox/file-tasks-returns-the-count-filed ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (assert-equal 2
                  (tdw-gtd-file-tasks-to-inbox
                   (list (list :title "First task" :tag "tgl_no_project")
                         (list :title "Second task" :tag "tgl_no_project"))
                   (tdw-gtd-inbox-test--date 15 2 2026)))))

(deftest gtd-inbox/file-tasks-preserves-existing-content ()
  (tdw-gtd-inbox-test--with-tasks-fixture tasks-file
    (tdw-gtd-file-tasks-to-inbox
     (list (list :title "New task" :tag "tgl_no_project"))
     (tdw-gtd-inbox-test--date 15 2 2026))
    (assert-true (string-match-p "\\* Inbox" (tdw-gtd-inbox-test--file-contents tasks-file)))))

;;;; Wiring guard: config.org must actually load this module.

(defun tdw-gtd-inbox-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "~/.emacs.d/config.org"))
    (buffer-string)))

(deftest gtd-inbox/config-requires-the-module ()
  "config.org must require tdw-gtd-inbox, or the live daemon never gets it."
  (assert-true (string-match-p "(require 'tdw-gtd-inbox)"
                                (tdw-gtd-inbox-test--config))))

(provide 'tdw-gtd-inbox-test)
;;; tdw-gtd-inbox-test.el ends here
