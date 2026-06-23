;;; project-tier-table-test.el --- Tests for project-aware tier selection -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests the pure core behind project-aware tier-section selection.  A project's
;; tier tag lives on the PARENT, but org-gtd 4.6.1 may file the project's tasks
;; in the separate `* Actions' subtree, where they do NOT inherit the parent's
;; tier tag.  So a tier section (P0/Bells/...) must select an entry when its
;; PROJECT qualifies (any member carries the tier), not just when the entry
;; itself carries the tier.
;;
;; `tdw/--project-tier-table' folds a list of heading plists into a hash:
;;   project-id -> union of tier tags across that project's members.
;; A heading plist: (:id .. :project <project-id-or-nil> :tiers <list-of-strings>)
;; For a parent, :project is its own id; for a task, the parent id; nil if
;; standalone.
;;
;; `tdw/--project-qualifies-for-tier-p' answers: does PROJECT-ID carry TIER?

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(deftest project-tier-table/parent-tier-covers-its-tasks ()
  "A task whose parent carries the tier qualifies (colgate split-container case)."
  (let* ((headings (list '(:id "P"  :project "P" :tiers ("p0"))
                         '(:id "t1" :project "P" :tiers ())
                         '(:id "t2" :project "P" :tiers ())))
         (table (tdw/--project-tier-table headings)))
    (assert-true (tdw/--project-qualifies-for-tier-p "P" "p0" table))
    (assert-nil  (tdw/--project-qualifies-for-tier-p "P" "on_deck" table))))

(deftest project-tier-table/union-of-member-tiers ()
  "The project's tier set is the union of every member's own tiers."
  (let* ((headings (list '(:id "P"  :project "P" :tiers ("p0"))
                         '(:id "t1" :project "P" :tiers ("on_deck"))))
         (table (tdw/--project-tier-table headings)))
    (assert-true (tdw/--project-qualifies-for-tier-p "P" "p0" table))
    (assert-true (tdw/--project-qualifies-for-tier-p "P" "on_deck" table))
    (assert-nil  (tdw/--project-qualifies-for-tier-p "P" "paused" table))))

(deftest project-tier-table/standalone-not-in-table ()
  "A standalone action (:project nil) contributes nothing and never qualifies."
  (let* ((headings (list '(:id "s" :project nil :tiers ("p0"))))
         (table (tdw/--project-tier-table headings)))
    (assert-nil (tdw/--project-qualifies-for-tier-p nil "p0" table))))

(deftest project-tier-table/unknown-project-does-not-qualify ()
  "A project id absent from the table never qualifies."
  (let ((table (tdw/--project-tier-table '())))
    (assert-nil (tdw/--project-qualifies-for-tier-p "P" "p0" table))))

;;; project-tier-table-test.el ends here
