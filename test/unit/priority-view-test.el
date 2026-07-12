;;; priority-view-test.el --- Tests for the Priority View (C-c d 0) -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; The Priority View (`tdw-priority-view', bound to C-c d 0) shows only three
;; sections: Today's Diary, Daily Rituals, and P0. It reuses the same block
;; builders as the Unordered View so the two cannot drift.
;;
;; `tdw/priority-view-total' backs the banner's "Total Estimated Effort":
;; unlike the Unordered View (grand total across all tiers), it counts ONLY
;; the three visible sections (diary remaining + ritual + p0), so the banner
;; number matches what is on screen.
;;
;; Uses e-unit (deftest, assert-equal).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(deftest priority-view-total/sums-three-visible-sections ()
  "Total = diary-remaining + ritual + p0, formatted H:MM."
  (assert-equal "3:45" (tdw/priority-view-total "1:00" "0:45" "2:00")))

(deftest priority-view-total/carries-minutes ()
  "Minute carries roll into hours."
  (assert-equal "2:00" (tdw/priority-view-total "0:40" "0:40" "0:40")))

(deftest priority-view-total/handles-zeroes ()
  "All-zero sections total 0:00."
  (assert-equal "0:00" (tdw/priority-view-total "0:00" "0:00" "0:00")))

(deftest tier-block/matches-inlined-p0-form ()
  "`tdw/tier-block' returns the exact native block the views inlined by hand."
  (let ((expected
         `((native . (tags
                      "LEVEL>0+ORG_GTD={Projects\\|Actions}"
                      ((org-agenda-overriding-header "🚨🚨 P0 (2:00)")
                       (org-agenda-todo-keyword-format "")
                       (org-agenda-prefix-format
                        (quote ,(tdw/tier-prefix-format 25 "(effort \" \" urg-imp \" — \")")))
                       (org-agenda-skip-function
                        (lambda () (tdw/skip-unless-project-tier "p0")))
                       (org-agenda-sorting-strategy (quote (category-keep)))))))))
    (assert-equal expected (tdw/tier-block "🚨🚨 P0 (2:00)" "p0"))))

(deftest tier-block/parameterizes-header-and-tier ()
  "Header string and tier key flow through to the right slots."
  (let ((blk (tdw/tier-block "🔔🔔 Bells Ringing (1:30)" "bells_ringing")))
    (assert-equal "🔔🔔 Bells Ringing (1:30)"
                  (cadr (assq 'org-agenda-overriding-header
                              (nth 2 (cdr (assq 'native blk))))))))

(deftest priority-view-blocks/three-sections-in-order ()
  "Priority View = diary, then rituals, then P0 tier block, in that order."
  (let* ((blocks (tdw/priority-view-blocks "🕐 Diary" "⏰ Rituals" "🚨🚨 P0 (2:00)"))
         (headers (mapcar (lambda (blk)
                            (let ((form (cdr (assq 'native blk))))
                              (cadr (assq 'org-agenda-overriding-header
                                          (nth 2 form)))))
                          blocks)))
    (assert-equal 3 (length blocks))
    ;; Diary's header comes from tdw-diary-agenda-options, so just check the
    ;; last two headers and that block 3 is the P0 tier block.
    (assert-equal "⏰ Rituals" (nth 1 headers))
    (assert-equal "🚨🚨 P0 (2:00)" (nth 2 headers))
    (assert-equal (tdw/tier-block "🚨🚨 P0 (2:00)" "p0") (nth 2 blocks))))

(deftest priority-view/is-defined-and-interactive ()
  "`tdw-priority-view' is a defined interactive command."
  (assert-true (fboundp 'tdw-priority-view))
  (assert-true (commandp 'tdw-priority-view)))

;;; priority-view-test.el ends here
