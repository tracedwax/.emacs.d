;;; agenda-files-test.el --- Tests for tdw-agenda-files -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Pins the unified org-agenda-files computation (tdw-agenda-files) that
;; replaces the old (user-login-name)-branched inline logic in config.org.
;; Contract:
;;   - Takes a HOME directory argument (defaults to "~") so tests can drive
;;     it against a fixture tree.
;;   - Returns only files that exist (seq-filter file-exists-p).
;;   - Same candidate list on every account: no user-login-name branch.
;;   - Auto-discovers context repos via wildcards under
;;     workspace/non-oss/bfctrace/ and workspace/non-oss/venndoor-group/.
;;   - my-test-life fixtures are NOT part of the live agenda.
;;
;; Uses e-unit (deftest, assert-true, assert-nil).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defun agenda-files-test--make-home ()
  "Build a fixture home dir with life repos and one context repo."
  (let ((home (make-temp-file "agenda-files-test" t)))
    (dolist (f '("my-bfc-life/orgnotes/gtd/org-gtd-tasks.org"
                 "my-bfc-life/orgnotes/gtd/gcal.org"
                 "my-personal-life/orgnotes/gtd/org-gtd-tasks.org"
                 "workspace/non-oss/bfctrace/context-for-purdue/orgnotes/gtd/org-gtd-tasks.org"
                 "my-test-life/orgnotes/gtd/org-gtd-tasks.org"))
      (let ((path (expand-file-name f home)))
        (make-directory (file-name-directory path) t)
        (write-region "" nil path)))
    home))

(deftest agenda-files/includes-bfc-life-tasks ()
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true (member (expand-file-name "my-bfc-life/orgnotes/gtd/org-gtd-tasks.org" home)
                         files))))

(deftest agenda-files/auto-discovers-context-repos ()
  "A context repo under workspace/non-oss/bfctrace/ is picked up by wildcard."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true
     (member (expand-file-name
              "workspace/non-oss/bfctrace/context-for-purdue/orgnotes/gtd/org-gtd-tasks.org"
              home)
             files))))

(deftest agenda-files/includes-personal-life-tasks ()
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true (member (expand-file-name "my-personal-life/orgnotes/gtd/org-gtd-tasks.org" home)
                         files))))

(deftest agenda-files/includes-gcal ()
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true (member (expand-file-name "my-bfc-life/orgnotes/gtd/gcal.org" home)
                         files))))

(deftest agenda-files/excludes-test-life-fixtures ()
  "my-test-life fixtures never appear in the live agenda."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-nil (member (expand-file-name "my-test-life/orgnotes/gtd/org-gtd-tasks.org" home)
                        files))))

(deftest agenda-files/filters-nonexistent-files ()
  "Candidates that do not exist on this account are filtered out."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-nil (seq-remove #'file-exists-p files))))

(provide 'agenda-files-test)
;;; agenda-files-test.el ends here
