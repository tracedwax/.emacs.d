;;; refile-target-test.el --- Tests for same-repo refile targeting -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests tdw/same-repo-refile-target: move commands must refile within the
;; entry's OWN repo (the sibling org-gtd-tasks.org), never across repos, and
;; create the ORG_GTD_REFILE container if it is absent.

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defmacro refile-test--in-repo (files &rest body)
  "Create a temp repo dir containing FILES (alist of name . contents), run BODY,
clean up buffers + dir.  `dir', `tasks' (the org-gtd-tasks.org path) are bound."
  (declare (indent 1))
  `(let* ((dir (file-name-as-directory (make-temp-file "gtd-repo" t)))
          (tasks (expand-file-name "org-gtd-tasks.org" dir))
          (created nil))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) dir)))
               (with-temp-file path (insert (cdr f)))
               (push (find-file-noselect path) created)))
           ,@body)
       (dolist (b created) (when (buffer-live-p b) (kill-buffer b)))
       (when (get-file-buffer tasks) (kill-buffer (get-file-buffer tasks)))
       (delete-directory dir t))))

(deftest same-repo-refile/finds-container-in-sibling-file ()
  "Returns the Actions container in the org-gtd-tasks.org beside the current file."
  (refile-test--in-repo
      '(("org-gtd-tasks.org" . "* Actions\n:PROPERTIES:\n:ORG_GTD_REFILE: Actions\n:END:\n")
        ("gcal.org" . "* Cal\n"))
    (with-current-buffer (find-file-noselect (expand-file-name "gcal.org" dir))
      (let ((target (tdw/same-repo-refile-target "Actions")))
        (assert-equal (expand-file-name tasks) (expand-file-name (nth 1 target)))
        (assert-equal "Actions" (nth 0 target))))))

(deftest same-repo-refile/matches-multivalue-refile-prop ()
  "TYPE matches as a member of a space-separated ORG_GTD_REFILE value."
  (refile-test--in-repo
      '(("org-gtd-tasks.org" . "* Bucket\n:PROPERTIES:\n:ORG_GTD_REFILE: Action Someday\n:END:\n"))
    (with-current-buffer (find-file-noselect tasks)
      (assert-equal "Bucket" (nth 0 (tdw/same-repo-refile-target "Someday"))))))

(deftest same-repo-refile/creates-container-when-absent ()
  "Creates an ORG_GTD_REFILE=TYPE container at end of file when none matches."
  (refile-test--in-repo
      '(("org-gtd-tasks.org" . "* Actions\n:PROPERTIES:\n:ORG_GTD_REFILE: Actions\n:END:\n"))
    (with-current-buffer (find-file-noselect tasks)
      (let ((target (tdw/same-repo-refile-target "Someday")))
        (assert-equal "Someday" (nth 0 target))
        (assert-true (with-temp-buffer (insert-file-contents tasks)
                       (and (string-match-p "ORG_GTD_REFILE: Someday" (buffer-string)) t)))))))

;;; refile-target-test.el ends here
