;;; order-by-project-test.el --- Tests for project-membership agenda grouping -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests tdw/order-by-project, the pure reorder behind the agenda finalize pass.
;; A project must read as a unit: parent first, then its tasks in dependency
;; order (ORG_GTD_DEPENDS_ON), falling back to file order.  A project task must
;; NEVER appear without its parent (orphans are dropped).  Standalone
;; non-project actions (:project nil) pass through in place.
;;
;; Each input entry is a plist:
;;   :id         unique id
;;   :project    the project id it belongs to (own id for a parent), or nil
;;   :type       "Projects" (parent) or "Actions" (task)
;;   :depends-on list of ids this entry depends on (must come before it)
;;   :seq        original file-order index
;;   :payload    opaque

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defun obp-test--ids (entries)
  (mapcar (lambda (e) (plist-get e :id)) entries))

(deftest order-by-project/parent-first-then-dependency-order ()
  "Parent leads; tasks ordered by DEPENDS_ON regardless of input order."
  (let ((in (list '(:id "t3" :project "P" :type "Actions"  :depends-on ("t2") :seq 3)
                  '(:id "P"  :project "P" :type "Projects" :depends-on ()     :seq 0)
                  '(:id "t1" :project "P" :type "Actions"  :depends-on ()     :seq 1)
                  '(:id "t2" :project "P" :type "Actions"  :depends-on ("t1") :seq 2))))
    (assert-equal '("P" "t1" "t2" "t3")
                  (obp-test--ids (tdw/order-by-project in)))))

(deftest order-by-project/file-order-fallback-when-no-deps ()
  "With no dependencies, tasks keep file (:seq) order under the parent."
  (let ((in (list '(:id "P"  :project "P" :type "Projects" :depends-on () :seq 0)
                  '(:id "b"  :project "P" :type "Actions"  :depends-on () :seq 2)
                  '(:id "a"  :project "P" :type "Actions"  :depends-on () :seq 1))))
    (assert-equal '("P" "a" "b")
                  (obp-test--ids (tdw/order-by-project in)))))

(deftest order-by-project/orphan-task-is-dropped ()
  "A task whose project has no parent entry in the set never appears."
  (let ((in (list '(:id "t1" :project "P" :type "Actions" :depends-on () :seq 0))))
    (assert-nil (tdw/order-by-project in))))

(deftest order-by-project/standalone-action-kept ()
  "An action not belonging to any project (:project nil) passes through."
  (let ((in (list '(:id "s" :project nil :type "Actions" :depends-on () :seq 0))))
    (assert-equal '("s") (obp-test--ids (tdw/order-by-project in)))))

(deftest order-by-project/multiple-projects-keep-first-appearance-order ()
  "Project groups stay in the order their parent first appears."
  (let ((in (list '(:id "Pb" :project "Pb" :type "Projects" :depends-on () :seq 0)
                  '(:id "Pa" :project "Pa" :type "Projects" :depends-on () :seq 1)
                  '(:id "a1" :project "Pa" :type "Actions"  :depends-on () :seq 2))))
    (assert-equal '("Pb" "Pa" "a1")
                  (obp-test--ids (tdw/order-by-project in)))))

;;; order-by-project-test.el ends here
