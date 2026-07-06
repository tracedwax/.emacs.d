;;; tgl-routing-test.el --- Tests for org-gtd cross-repo tgl routing -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests the tgl_-tag routing layer that redirects org-gtd refiles into the
;; correct context repo: home-dir path localization, the mtime-cached routing
;; table (tgl-repo-routing.json), first-tgl_-tag extraction, and the :around
;; advice on org-gtd-refile--do that let-binds org-gtd-directory, warning and
;; falling back to the default directory instead of erroring.

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defmacro tgl-test--with-routing (json &rest body)
  "Write JSON string to a temp routing file, point the routing layer at it,
reset the cache, run BODY, clean up.  `file' (the routing file path) is bound."
  (declare (indent 1))
  `(let* ((file (make-temp-file "tgl-routing" nil ".json"))
          (tdw/tgl-routing-file file)
          (tdw/tgl-routing--cache nil)
          (tdw/tgl-routing--cache-mtime nil))
     (ignore tdw/tgl-routing-file tdw/tgl-routing--cache tdw/tgl-routing--cache-mtime)
     (unwind-protect
         (progn
           (with-temp-file file (insert ,json))
           ,@body)
       (delete-file file))))

(defmacro tgl-test--on-heading (text &rest body)
  "Insert TEXT into an org buffer, leave point at the start, run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,text)
     (goto-char (point-min))
     ,@body))

;;; Path localization

(deftest tgl-localize/translates-foreign-home ()
  "gtd_dir paths written on thecleverone's account resolve under the current home."
  (assert-equal (concat (expand-file-name "~/") "workspace/x/gtd")
                (tdw/tgl-routing--localize-path "/Users/thecleverone/workspace/x/gtd")))

(deftest tgl-localize/leaves-non-users-path-alone ()
  "Paths outside /Users/<someone>/ pass through untouched."
  (assert-equal "/opt/gtd" (tdw/tgl-routing--localize-path "/opt/gtd")))

;;; Routing table lookup

(deftest tgl-routing/gtd-dir-for-known-tag ()
  "A tag present in the routing JSON resolves to its gtd_dir."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/opt/repos/admin/gtd\"}}"
    (assert-equal "/opt/repos/admin/gtd" (tdw/tgl-routing-gtd-dir "tgl_admin"))))

(deftest tgl-routing/nil-for-unknown-tag ()
  "A tag absent from the routing JSON resolves to nil."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/opt/repos/admin/gtd\"}}"
    (assert-nil (tdw/tgl-routing-gtd-dir "tgl_nope"))))

(deftest tgl-routing/nil-when-file-missing ()
  "A missing routing file yields nil, never an error."
  (let ((tdw/tgl-routing-file "/nonexistent/nowhere.json")
        (tdw/tgl-routing--cache nil)
        (tdw/tgl-routing--cache-mtime nil))
    (ignore tdw/tgl-routing-file tdw/tgl-routing--cache tdw/tgl-routing--cache-mtime)
    (assert-nil (tdw/tgl-routing-gtd-dir "tgl_admin"))))

(deftest tgl-routing/localizes-gtd-dir ()
  "Lookup localizes the entry's home-dir prefix."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/Users/thecleverone/ws/admin/gtd\"}}"
    (assert-equal (concat (expand-file-name "~/") "ws/admin/gtd")
                  (tdw/tgl-routing-gtd-dir "tgl_admin"))))

(deftest tgl-routing/reloads-when-mtime-changes ()
  "The cache is invalidated when the routing file's mtime changes."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/opt/a\"}}"
    (assert-equal "/opt/a" (tdw/tgl-routing-gtd-dir "tgl_admin"))
    (with-temp-file file (insert "{\"tgl_admin\": {\"gtd_dir\": \"/opt/b\"}}"))
    (set-file-times file (time-add (current-time) 5))
    (assert-equal "/opt/b" (tdw/tgl-routing-gtd-dir "tgl_admin"))))

;;; Tag extraction

(deftest tgl-tag/extracts-first-tgl-tag ()
  "The first tgl_ tag on the heading wins; non-tgl tags are ignored."
  (tgl-test--on-heading "* TODO Thing :foo:tgl_admin:tgl_other:\n"
    (assert-equal "tgl_admin" (tdw/get-tgl-tag-from-heading))))

(deftest tgl-tag/nil-when-no-tgl-tag ()
  "A heading without any tgl_ tag yields nil."
  (tgl-test--on-heading "* TODO Thing :foo:bar:\n"
    (assert-nil (tdw/get-tgl-tag-from-heading))))

;;; Refile advice

(deftest refile-advice/routes-to-tagged-repo ()
  "The advice let-binds org-gtd-directory to the routed repo around the refile."
  (let ((target (file-name-as-directory (make-temp-file "tgl-target" t)))
        (captured nil))
    (unwind-protect
        (tgl-test--with-routing
            (format "{\"tgl_admin\": {\"gtd_dir\": %S}}" (directory-file-name target))
          (tgl-test--on-heading "* TODO Thing :tgl_admin:\n"
            (tdw/refile-to-context-repo
             (lambda (_type _element) (setq captured org-gtd-directory))
             'action nil)
            (assert-equal (directory-file-name target)
                          (directory-file-name captured))))
      (delete-directory target t))))

(deftest refile-advice/falls-back-when-no-tag ()
  "No tgl_ tag: warn and refile to the default org-gtd-directory."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/opt/a\"}}"
    (tgl-test--on-heading "* TODO Thing :foo:\n"
      (let ((default org-gtd-directory)
            (captured 'unset))
        (tdw/refile-to-context-repo
         (lambda (_type _element) (setq captured org-gtd-directory))
         'action nil)
        (assert-equal default captured)))))

(deftest refile-advice/falls-back-when-unknown-tag ()
  "tgl_ tag with no routing entry: warn and refile to the default directory."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/opt/a\"}}"
    (tgl-test--on-heading "* TODO Thing :tgl_mystery:\n"
      (let ((default org-gtd-directory)
            (captured 'unset))
        (tdw/refile-to-context-repo
         (lambda (_type _element) (setq captured org-gtd-directory))
         'action nil)
        (assert-equal default captured)))))

(deftest refile-advice/falls-back-when-target-dir-missing ()
  "Routing entry whose gtd_dir does not exist on disk: warn and use the default."
  (tgl-test--with-routing "{\"tgl_admin\": {\"gtd_dir\": \"/nonexistent/routed/gtd\"}}"
    (tgl-test--on-heading "* TODO Thing :tgl_admin:\n"
      (let ((default org-gtd-directory)
            (captured 'unset))
        (tdw/refile-to-context-repo
         (lambda (_type _element) (setq captured org-gtd-directory))
         'action nil)
        (assert-equal default captured)))))

;;; tgl-routing-test.el ends here
