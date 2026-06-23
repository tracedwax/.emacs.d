;;; order-project-first-test.el --- Tests for tier-section project grouping -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests tdw/order-project-first, the pure reorder used by the agenda finalize
;; pass.  org-gtd 4 stores a project parent (ORG_GTD=Projects) in the * Projects
;; container and its tasks (ORG_GTD=Actions) in the * Actions container, so file
;; order scatters them.  We regroup each tier section by the tgl_ project tag and
;; put the parent first within its group, so the agenda reads
;; "project [0/n], then its tasks below it".

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defun order-project-first-test--payloads (entries)
  (mapcar (lambda (e) (plist-get e :payload)) entries))

(deftest order-project-first/parent-before-tasks-within-group ()
  "The ORG_GTD=Projects entry sorts above its Actions, in stable order."
  (let ((in (list '(:tgl "jb" :type "Actions"  :payload "a1")
                  '(:tgl "jb" :type "Projects" :payload "P")
                  '(:tgl "jb" :type "Actions"  :payload "a2"))))
    (assert-equal '("P" "a1" "a2")
                  (order-project-first-test--payloads (tdw/order-project-first in)))))

(deftest order-project-first/keeps-group-first-appearance-order ()
  "Groups stay in first-seen order; entries do not bleed across groups."
  (let ((in (list '(:tgl "jb"  :type "Actions"  :payload "j1")
                  '(:tgl "col" :type "Actions"  :payload "c1")
                  '(:tgl "jb"  :type "Projects" :payload "jP"))))
    (assert-equal '("jP" "j1" "c1")
                  (order-project-first-test--payloads (tdw/order-project-first in)))))

(deftest order-project-first/untagged-entries-form-their-own-group ()
  "Entries with no tgl tag are kept together, not merged into a tagged group."
  (let ((in (list '(:tgl nil :type "Actions"  :payload "loose")
                  '(:tgl "jb" :type "Projects" :payload "P"))))
    (assert-equal '("loose" "P")
                  (order-project-first-test--payloads (tdw/order-project-first in)))))

;;; order-project-first-test.el ends here
