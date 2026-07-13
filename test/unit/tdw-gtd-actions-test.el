;;; tdw-gtd-actions-test.el --- Tests for deterministic NEXT-action filing -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw-gtd-add-next-action' is the deterministic core of the
;; add-next-action skill: it files ONE `** NEXT <title> :<tag>:` entry
;; (:ORG_GTD: Actions drawer, ID, DEADLINE, capture timestamp) under the
;; `* Actions' heading of the routed repo's org-gtd-tasks.org. Routing is
;; tag -> `tdw-gtd-tags-gtd-dir-for-tag', falling back to
;; `org-gtd-directory' for unrouted tags.
;;
;; Date anchors reuse the add-to-inbox convention: capture on 2026-02-15
;; (a Sunday) defaults the deadline to 2026-02-20 (Friday).

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-gtd-actions)

(defun tdw-gtd-actions-test--date (day month year)
  "Return a time value for YEAR-MONTH-DAY at midnight, local time."
  (encode-time 0 0 0 day month year))

(defun tdw-gtd-actions-test--file-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defmacro tdw-gtd-actions-test--with-fixture (var initial &rest body)
  "Bind VAR to a temp org-gtd-tasks.org seeded with INITIAL,
`org-gtd-directory' to its parent, run BODY. Empties the routing-table
candidates so no test can resolve a tag against the REAL routing table
and write into a real repo (which happened on first run: tgl_no_project
routed 6 test entries into my-personal-life)."
  (declare (indent 2))
  `(let* ((dir (make-temp-file "tdw-gtd-actions-test" t))
          (org-gtd-directory dir)
          (tdw-gtd-tags-routing-candidates nil)
          (,var (expand-file-name "org-gtd-tasks.org" dir)))
     (unwind-protect
         (progn
           (with-temp-file ,var (insert ,initial))
           ,@body)
       (let ((buf (find-buffer-visiting ,var)))
         (when buf (kill-buffer buf)))
       (delete-directory dir t))))

(defconst tdw-gtd-actions-test--actions-fixture
  "* Actions
:PROPERTIES:
:ORG_GTD_REFILE: Actions
:END:

** NEXT Existing task  :tgl_no_project:
:PROPERTIES:
:ORG_GTD: Actions
:ID:      Existing-task-2026-01-01-00-00-00
:END:

* Projects
:PROPERTIES:
:ORG_GTD_REFILE: Projects
:END:
"
  "A tasks file with an Actions section followed by another top heading.")

;;;; Entry format

(deftest gtd-actions/entry-format-next-with-tag-and-drawer ()
  "Headline is `** NEXT <title> :<tag>:'; drawer has ORG_GTD Actions and an
ID derived from the title; DEADLINE then capture timestamp follow."
  (tdw-gtd-actions-test--with-fixture tasks-file "* Actions\n"
    (tdw-gtd-add-next-action "Send SOW to Acme" "tgl_no_project"
                             (tdw-gtd-actions-test--date 20 2 2026)
                             (tdw-gtd-actions-test--date 15 2 2026))
    (assert-true
     (string-match-p
      (concat "\\*\\* NEXT Send SOW to Acme :tgl_no_project:\n"
              ":PROPERTIES:\n"
              ":ORG_GTD: Actions\n"
              ":ID: +Send-SOW-to-Acme-2026-02-15-[0-9-]+\n"
              ":END:\n"
              "DEADLINE: <2026-02-20 Fri>\n"
              "\\[2026-02-15 Sun [0-9][0-9]:[0-9][0-9]\\]")
      (tdw-gtd-actions-test--file-contents tasks-file)))))

(deftest gtd-actions/deadline-defaults-to-next-friday ()
  (tdw-gtd-actions-test--with-fixture tasks-file "* Actions\n"
    (tdw-gtd-add-next-action "Send SOW to Acme" "tgl_no_project" nil
                             (tdw-gtd-actions-test--date 15 2 2026))
    (assert-true (string-match-p "DEADLINE: <2026-02-20 Fri>"
                                  (tdw-gtd-actions-test--file-contents tasks-file)))))

(deftest gtd-actions/tag-guessed-when-omitted ()
  "Nil tag falls through to `tdw-gtd-guess-tag' on the title."
  (tdw-gtd-actions-test--with-fixture tasks-file "* Actions\n"
    (let ((tdw-gtd-tags-routing-candidates nil))
      (tdw-gtd-add-next-action "Prep the standup notes" nil nil
                               (tdw-gtd-actions-test--date 15 2 2026)))
    (assert-true (string-match-p ":tgl_barefoot_internal_sales:"
                                  (tdw-gtd-actions-test--file-contents tasks-file)))))

;;;; Placement

(deftest gtd-actions/inserts-inside-existing-actions-section ()
  "The new entry lands at the end of the * Actions subtree, BEFORE the next
top-level heading, not at end of file."
  (tdw-gtd-actions-test--with-fixture tasks-file tdw-gtd-actions-test--actions-fixture
    (tdw-gtd-add-next-action "Send SOW to Acme" "tgl_no_project"
                             (tdw-gtd-actions-test--date 20 2 2026)
                             (tdw-gtd-actions-test--date 15 2 2026))
    (let ((contents (tdw-gtd-actions-test--file-contents tasks-file)))
      (assert-true (< (string-match "\\*\\* NEXT Send SOW to Acme" contents)
                      (string-match "^\\* Projects" contents))))))

(deftest gtd-actions/creates-actions-heading-when-missing ()
  (tdw-gtd-actions-test--with-fixture tasks-file ""
    (tdw-gtd-add-next-action "Send SOW to Acme" "tgl_no_project"
                             (tdw-gtd-actions-test--date 20 2 2026)
                             (tdw-gtd-actions-test--date 15 2 2026))
    (let ((contents (tdw-gtd-actions-test--file-contents tasks-file)))
      (assert-true (string-match-p "^\\* Actions" contents))
      (assert-true (< (string-match "^\\* Actions" contents)
                      (string-match "\\*\\* NEXT Send SOW to Acme" contents))))))

(deftest gtd-actions/preserves-existing-entries ()
  (tdw-gtd-actions-test--with-fixture tasks-file tdw-gtd-actions-test--actions-fixture
    (tdw-gtd-add-next-action "Send SOW to Acme" "tgl_no_project"
                             (tdw-gtd-actions-test--date 20 2 2026)
                             (tdw-gtd-actions-test--date 15 2 2026))
    (let ((contents (tdw-gtd-actions-test--file-contents tasks-file)))
      (assert-true (string-match-p "\\*\\* NEXT Existing task" contents))
      (assert-true (string-match-p "^\\* Projects" contents)))))

;;;; Routing

(deftest gtd-actions/routes-to-context-repo-dir-for-routed-tag ()
  "A tag with a gtd_dir in the routing table files into THAT repo's
org-gtd-tasks.org, not org-gtd-directory's."
  (let* ((route-dir (make-temp-file "tdw-gtd-actions-route" t))
         (routed-file (expand-file-name "org-gtd-tasks.org" route-dir))
         (json-file (make-temp-file "tdw-gtd-actions-routing" nil ".json")))
    (unwind-protect
        (progn
          (with-temp-file routed-file (insert "* Actions\n"))
          (with-temp-file json-file
            (insert (format "{\"tgl_routed\": {\"gtd_dir\": %S}}" route-dir)))
          (tdw-gtd-actions-test--with-fixture tasks-file "* Actions\n"
            (let ((tdw-gtd-tags-routing-candidates (list json-file)))
              (tdw-gtd-add-next-action "Routed task" "tgl_routed"
                                       (tdw-gtd-actions-test--date 20 2 2026)
                                       (tdw-gtd-actions-test--date 15 2 2026)))
            (assert-true (string-match-p "Routed task"
                                          (tdw-gtd-actions-test--file-contents routed-file)))
            (assert-nil (string-match-p "Routed task"
                                         (tdw-gtd-actions-test--file-contents tasks-file)))))
      (let ((buf (find-buffer-visiting routed-file)))
        (when buf (kill-buffer buf)))
      (delete-directory route-dir t)
      (delete-file json-file))))

(deftest gtd-actions/falls-back-to-org-gtd-directory-for-unrouted-tag ()
  (tdw-gtd-actions-test--with-fixture tasks-file "* Actions\n"
    (let ((tdw-gtd-tags-routing-candidates nil))
      (tdw-gtd-add-next-action "Unrouted task" "tgl_admin"
                               (tdw-gtd-actions-test--date 20 2 2026)
                               (tdw-gtd-actions-test--date 15 2 2026)))
    (assert-true (string-match-p "Unrouted task"
                                  (tdw-gtd-actions-test--file-contents tasks-file)))))

;;;; Return value

(deftest gtd-actions/returns-plist-with-entry-and-file ()
  "Returns (:entry <text> :file <path>) so the calling skill can report
exactly what was written and where."
  (tdw-gtd-actions-test--with-fixture tasks-file "* Actions\n"
    (let ((result (tdw-gtd-add-next-action "Send SOW to Acme" "tgl_no_project"
                                           (tdw-gtd-actions-test--date 20 2 2026)
                                           (tdw-gtd-actions-test--date 15 2 2026))))
      (assert-true (string-match-p "Send SOW to Acme" (plist-get result :entry)))
      (assert-equal tasks-file (plist-get result :file)))))

;;;; Wiring guard: config.org must actually load this module.

(deftest gtd-actions/config-requires-the-module ()
  "config.org must require tdw-gtd-actions, or the live daemon never gets it."
  (assert-true (string-match-p "(require 'tdw-gtd-actions)"
                                (with-temp-buffer
                                  (insert-file-contents
                                   (expand-file-name "~/.emacs.d/config.org"))
                                  (buffer-string)))))

(provide 'tdw-gtd-actions-test)
;;; tdw-gtd-actions-test.el ends here
