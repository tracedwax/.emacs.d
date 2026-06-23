;;; subtree-effort-test.el --- Characterization tests for subtree effort helpers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Characterization tests that LOCK the current behavior of the subtree-effort
;; helpers in config.org, so the upcoming POODR refactor cannot regress them:
;;
;;   - tdw/subtree-remaining-effort-minutes   (sums remaining/non-DONE descendant effort)
;;   - tdw/effort-counts-p           (would an entry be counted?)
;;   - tdw/ancestor-counts-p  (is an ancestor already counted?)
;;
;; All expected values were CAPTURED from the live tangled functions via
;; test-bootstrap.el, not guessed.
;;
;; Note on the test harness: under test-bootstrap.el, `org-todo-keywords' is the
;; stock `((sequence "TODO" "DONE"))'. CNCL is therefore NOT a recognized TODO
;; keyword in temp buffers, so `org-get-todo-state' returns nil for a "CNCL"
;; heading.  These tests avoid relying on CNCL being recognized inside org temp
;; buffers; CNCL exclusion is instead locked through `tdw/effort-counts-p',
;; which checks the literal string.
;;
;; Uses e-unit (deftest, assert-true, assert-nil, assert-equal).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— tdw/subtree-remaining-effort-minutes ———

(deftest subtree-effort/sums-parent-and-live-children-excluding-done ()
  "Sum is parent effort + each non-DONE child effort; DONE children excluded.
Parent 1:00 + Child A 0:30 + Child C 0:15 = 105; DONE Child B (2:00) excluded."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent
:PROPERTIES:
:EFFORT: 1:00
:END:
** TODO Child A
:PROPERTIES:
:EFFORT: 0:30
:END:
** DONE Child B
:PROPERTIES:
:EFFORT: 2:00
:END:
** TODO Child C
:PROPERTIES:
:EFFORT: 0:15
:END:
")
    (goto-char (point-min))
    (assert-equal 105 (tdw/subtree-remaining-effort-minutes))))

(deftest subtree-effort/parent-with-no-effort-and-no-children-is-zero ()
  "A lone heading with no EFFORT property sums to 0."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Lonely\n")
    (goto-char (point-min))
    (assert-equal 0 (tdw/subtree-remaining-effort-minutes))))

(deftest subtree-effort/parent-effort-no-children ()
  "A lone heading with EFFORT 0:45 sums to its own 45 minutes."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Solo
:PROPERTIES:
:EFFORT: 0:45
:END:
")
    (goto-char (point-min))
    (assert-equal 45 (tdw/subtree-remaining-effort-minutes))))

(deftest subtree-effort/done-child-effort-is-excluded ()
  "Effort of a DONE child is not added to the remaining load.
Parent 0:30 counts; DONE child 5:00 is dropped, leaving 30."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent
:PROPERTIES:
:EFFORT: 0:30
:END:
** DONE Done Child
:PROPERTIES:
:EFFORT: 5:00
:END:
")
    (goto-char (point-min))
    (assert-equal 30 (tdw/subtree-remaining-effort-minutes))))

(deftest subtree-effort/nested-grandchildren-are-summed ()
  "Effort is summed across all descendant levels, not just direct children.
Top 0:10 + Mid 0:20 + Leaf 0:30 = 60."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Top
:PROPERTIES:
:EFFORT: 0:10
:END:
** TODO Mid
:PROPERTIES:
:EFFORT: 0:20
:END:
*** TODO Leaf
:PROPERTIES:
:EFFORT: 0:30
:END:
")
    (goto-char (point-min))
    (assert-equal 60 (tdw/subtree-remaining-effort-minutes))))

(deftest subtree-effort/child-without-todo-state-is-counted ()
  "A child with no TODO keyword is not DONE, so its effort counts.
Parent 0:30 + plain child 0:15 = 45."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent
:PROPERTIES:
:EFFORT: 0:30
:END:
** Plain Child
:PROPERTIES:
:EFFORT: 0:15
:END:
")
    (goto-char (point-min))
    (assert-equal 45 (tdw/subtree-remaining-effort-minutes))))

;;;; ——— tdw/effort-counts-p (default branch: tdw--ef-target-gtd is nil) ———

(deftest subtree-effort/counted-next-action-is-counted ()
  "NEXT in Actions is counted."
  (assert-true (tdw/effort-counts-p "NEXT" "Actions")))

(deftest subtree-effort/counted-todo-action-is-counted ()
  "TODO in Actions is counted."
  (assert-true (tdw/effort-counts-p "TODO" "Actions")))

(deftest subtree-effort/counted-todo-nil-gtd-is-counted ()
  "TODO with no ORG_GTD value is counted (nil is not an excluded category)."
  (assert-true (tdw/effort-counts-p "TODO" nil)))

(deftest subtree-effort/counted-todo-inbox-not-counted ()
  "TODO in Inbox is excluded."
  (assert-nil (tdw/effort-counts-p "TODO" "Inbox")))

(deftest subtree-effort/counted-todo-someday-not-counted ()
  "TODO in Someday is excluded."
  (assert-nil (tdw/effort-counts-p "TODO" "Someday")))

(deftest subtree-effort/counted-todo-habit-not-counted ()
  "TODO in Habit is excluded."
  (assert-nil (tdw/effort-counts-p "TODO" "Habit")))

(deftest subtree-effort/counted-todo-delegated-not-counted ()
  "TODO in Delegated is excluded."
  (assert-nil (tdw/effort-counts-p "TODO" "Delegated")))

(deftest subtree-effort/counted-todo-projects-not-counted ()
  "TODO in Projects is excluded."
  (assert-nil (tdw/effort-counts-p "TODO" "Projects")))

(deftest subtree-effort/counted-done-action-not-counted ()
  "A DONE entry is never counted in the default branch."
  (assert-nil (tdw/effort-counts-p "DONE" "Actions")))

(deftest subtree-effort/counted-nil-todo-not-counted ()
  "An entry with no TODO state is not counted in the default branch."
  (assert-nil (tdw/effort-counts-p nil "Actions")))

(deftest subtree-effort/counted-waiting-not-counted ()
  "A non-NEXT/TODO keyword (WAITING) is not counted in the default branch."
  (assert-nil (tdw/effort-counts-p "WAITING" "Actions")))

;;;; ——— tdw/effort-counts-p (target branch: tdw--ef-target-gtd bound) ———

(deftest subtree-effort/target-matching-todo-is-counted ()
  "With a target GTD, a non-finished entry whose ORG_GTD matches is counted."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-true (tdw/effort-counts-p "TODO" "Calendar"))))

(deftest subtree-effort/target-matching-next-is-counted ()
  "With a target GTD, NEXT with a matching ORG_GTD is counted."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-true (tdw/effort-counts-p "NEXT" "Calendar"))))

(deftest subtree-effort/target-non-todo-keyword-counted ()
  "With a target GTD, any non-DONE/CNCL keyword matching the GTD is counted,
including keywords the default branch would reject (e.g. WAITING)."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-true (tdw/effort-counts-p "WAITING" "Calendar"))))

(deftest subtree-effort/target-mismatched-gtd-not-counted ()
  "With a target GTD, an entry whose ORG_GTD differs is not counted."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-nil (tdw/effort-counts-p "TODO" "Actions"))))

(deftest subtree-effort/target-done-not-counted ()
  "With a target GTD, a DONE entry is excluded even if the GTD matches."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-nil (tdw/effort-counts-p "DONE" "Calendar"))))

(deftest subtree-effort/target-cncl-not-counted ()
  "With a target GTD, a CNCL entry is excluded even if the GTD matches."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-nil (tdw/effort-counts-p "CNCL" "Calendar"))))

(deftest subtree-effort/target-nil-todo-not-counted ()
  "With a target GTD, an entry with no TODO state is excluded."
  (let ((tdw--ef-target-gtd "Calendar"))
    (assert-nil (tdw/effort-counts-p nil "Calendar"))))

;;;; ——— tdw/ancestor-counts-p ———

(deftest subtree-effort/ancestor-counted-when-parent-counted ()
  "Returns non-nil when the parent heading is itself counted (TODO + Actions)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent
:PROPERTIES:
:ORG_GTD: Actions
:END:
** TODO Child
:PROPERTIES:
:ORG_GTD: Actions
:END:
")
    (goto-char (point-max))
    (org-back-to-heading t)
    (assert-true (tdw/ancestor-counts-p))))

(deftest subtree-effort/ancestor-not-counted-when-parent-excluded ()
  "Returns nil when the only ancestor is an excluded category (Inbox)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent
:PROPERTIES:
:ORG_GTD: Inbox
:END:
** TODO Child
:PROPERTIES:
:ORG_GTD: Actions
:END:
")
    (goto-char (point-max))
    (org-back-to-heading t)
    (assert-nil (tdw/ancestor-counts-p))))

(deftest subtree-effort/ancestor-none-for-top-level-heading ()
  "Returns nil for a top-level heading: it has no ancestors to check."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Top
:PROPERTIES:
:ORG_GTD: Actions
:END:
")
    (goto-char (point-min))
    (assert-nil (tdw/ancestor-counts-p))))

(deftest subtree-effort/ancestor-counted-via-grandparent ()
  "Walks all the way up: a counted grandparent counts even when the
intervening parent is an excluded category."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO GP
:PROPERTIES:
:ORG_GTD: Actions
:END:
** TODO Parent
:PROPERTIES:
:ORG_GTD: Inbox
:END:
*** TODO Child
:PROPERTIES:
:ORG_GTD: Actions
:END:
")
    (goto-char (point-max))
    (org-back-to-heading t)
    (assert-true (tdw/ancestor-counts-p))))

(deftest subtree-effort/ancestor-not-counted-when-parent-done ()
  "A DONE ancestor is not counted, so it does not suppress the child."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE Parent
:PROPERTIES:
:ORG_GTD: Actions
:END:
** TODO Child
:PROPERTIES:
:ORG_GTD: Actions
:END:
")
    (goto-char (point-max))
    (org-back-to-heading t)
    (assert-nil (tdw/ancestor-counts-p))))

;;; subtree-effort-test.el ends here
