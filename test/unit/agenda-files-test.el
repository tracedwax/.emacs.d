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
  "Build a fixture home dir with life repos, context repos, and a routing manifest.
The manifest declares purdue (exists) and colgate (missing on disk) with
thecleverone-local gtd_dir paths, plus a _meta entry to skip. An extra
unmanifested repo (context-for-rogue) exists on disk to prove discovery is
manifest-driven, not wildcard-driven."
  (let ((home (make-temp-file "agenda-files-test" t)))
    (dolist (f '("my-bfc-life/orgnotes/gtd/org-gtd-tasks.org"
                 "my-bfc-life/orgnotes/gtd/gcal.org"
                 "my-personal-life/orgnotes/gtd/org-gtd-tasks.org"
                 "workspace/non-oss/bfctrace/context-for-purdue/orgnotes/gtd/org-gtd-tasks.org"
                 "workspace/non-oss/bfctrace/context-for-rogue/orgnotes/gtd/org-gtd-tasks.org"
                 "workspace/non-oss/othergroup/context-for-offpath/orgnotes/gtd/org-gtd-tasks.org"
                 "my-test-life/orgnotes/gtd/org-gtd-tasks.org"))
      (let ((path (expand-file-name f home)))
        (make-directory (file-name-directory path) t)
        (write-region "" nil path)))
    (let ((manifest (expand-file-name "my-bfc-life/outputs/tags/tgl-repo-routing.json" home)))
      (make-directory (file-name-directory manifest) t)
      (write-region
       "{\"_meta\": {\"default_path\": null},
         \"tgl_purdue\": {\"gtd_dir\": \"/Users/thecleverone/workspace/non-oss/bfctrace/context-for-purdue/orgnotes/gtd\"},
         \"tgl_colgate\": {\"gtd_dir\": \"/Users/thecleverone/workspace/non-oss/bfctrace/context-for-colgate-palmolive/orgnotes/gtd\"},
         \"tgl_offpath\": {\"gtd_dir\": \"/Users/thecleverone/workspace/non-oss/othergroup/context-for-offpath/orgnotes/gtd\"}}"
       nil manifest))
    home))

(deftest agenda-files/includes-bfc-life-tasks ()
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true (member (expand-file-name "my-bfc-life/orgnotes/gtd/org-gtd-tasks.org" home)
                         files))))

(deftest agenda-files/discovers-manifest-declared-repos ()
  "A repo declared in tgl-repo-routing.json (with its thecleverone-local
gtd_dir rewritten onto this HOME) is picked up when it exists on disk."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true
     (member (expand-file-name
              "workspace/non-oss/bfctrace/context-for-purdue/orgnotes/gtd/org-gtd-tasks.org"
              home)
             files))))

(deftest agenda-files/manifest-entry-missing-on-disk-is-filtered ()
  "A manifest-declared repo that does not exist on this account is skipped
(this IS the account switch: venndoor entries filter out on trace)."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-nil
     (member (expand-file-name
              "workspace/non-oss/bfctrace/context-for-colgate-palmolive/orgnotes/gtd/org-gtd-tasks.org"
              home)
             files))))

(deftest agenda-files/still-discovers-unmanifested-repos-on-disk ()
  "A context repo on disk but absent from the manifest is still included
(wildcard backstop: dropping repos with real tasks from views is data loss)."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true
     (member (expand-file-name
              "workspace/non-oss/bfctrace/context-for-rogue/orgnotes/gtd/org-gtd-tasks.org"
              home)
             files))))

(deftest agenda-files/manifest-declared-offpath-repo-is-included ()
  "A manifest-declared repo OUTSIDE the wildcard roots is still picked up:
discovery must actually read tgl-repo-routing.json, not just glob."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home)))
    (assert-true
     (member (expand-file-name
              "workspace/non-oss/othergroup/context-for-offpath/orgnotes/gtd/org-gtd-tasks.org"
              home)
             files))))

(deftest agenda-files/no-duplicates-when-manifest-and-wildcard-agree ()
  "purdue is both manifested and on disk; it appears exactly once."
  (let* ((home (agenda-files-test--make-home))
         (files (tdw-agenda-files home))
         (purdue (expand-file-name
                  "workspace/non-oss/bfctrace/context-for-purdue/orgnotes/gtd/org-gtd-tasks.org"
                  home)))
    (assert-equal 1 (seq-count (lambda (f) (equal f purdue)) files))))

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
