;;; predicates-test.el --- Characterization tests for config.org entry predicates -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Characterization tests that LOCK the current behavior of the Ordered-View
;; tag/score predicates in config.org, so the upcoming POODR refactor cannot
;; regress them.  All expected values were CAPTURED from the live, tangled
;; functions (via `emacs -q --batch -l test-bootstrap.el'), not guessed.
;;
;; Covered predicates:
;;   tdw/has-tag-p, tdw/p0-p, tdw/bells-ringing-p, tdw/on-deck-p,
;;   tdw/recently-considered-p, tdw/paused-p, tdw/big-rock-p, tdw/unestimated-p.
;;
;; Each buffer predicate reads the org entry at point, so tests build a
;; temp buffer, insert a single TODO with tags, and call the predicate.
;;
;; Uses e-unit (deftest, assert-true, assert-nil, assert-equal).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— tdw/has-tag-p ———

(deftest predicates/has-tag-p-returns-tag-list-when-present ()
  "tdw/has-tag-p returns the membership tail (the tag list) when TAG is present.
Captured: (\"tag1\" \"tag2\") for tag1 on a :tag1:tag2: entry."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :tag1:tag2:\n")
    (goto-char (point-min))
    (assert-equal '("tag1" "tag2") (tdw/has-tag-p "tag1"))))

(deftest predicates/has-tag-p-returns-nil-when-absent ()
  "tdw/has-tag-p returns nil when TAG is not on the entry."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :tag1:tag2:\n")
    (goto-char (point-min))
    (assert-nil (tdw/has-tag-p "nope"))))

;;;; ——— tdw/p0-p ———

(deftest predicates/p0-p-non-nil-when-tagged ()
  "tdw/p0-p is non-nil when entry carries :p0:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :p0:\n")
    (goto-char (point-min))
    (assert-true (tdw/p0-p))))

(deftest predicates/p0-p-nil-when-other-tag ()
  "tdw/p0-p is nil when entry lacks :p0: (has only an unrelated tag)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :other:\n")
    (goto-char (point-min))
    (assert-nil (tdw/p0-p))))

;;;; ——— tdw/bells-ringing-p ———

(deftest predicates/bells-ringing-p-non-nil-when-tagged ()
  "tdw/bells-ringing-p is non-nil when entry carries :bells_ringing:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :bells_ringing:\n")
    (goto-char (point-min))
    (assert-true (tdw/bells-ringing-p))))

(deftest predicates/bells-ringing-p-nil-when-untagged ()
  "tdw/bells-ringing-p is nil on an untagged entry."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (assert-nil (tdw/bells-ringing-p))))

;;;; ——— tdw/on-deck-p ———

(deftest predicates/on-deck-p-non-nil-when-tagged ()
  "tdw/on-deck-p is non-nil when entry carries :on_deck:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :on_deck:\n")
    (goto-char (point-min))
    (assert-true (tdw/on-deck-p))))

(deftest predicates/on-deck-p-nil-when-untagged ()
  "tdw/on-deck-p is nil on an untagged entry."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (assert-nil (tdw/on-deck-p))))

;;;; ——— tdw/recently-considered-p ———

(deftest predicates/recently-considered-p-non-nil-when-tagged ()
  "tdw/recently-considered-p is non-nil when entry carries :recently_considered:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :recently_considered:\n")
    (goto-char (point-min))
    (assert-true (tdw/recently-considered-p))))

(deftest predicates/recently-considered-p-nil-when-untagged ()
  "tdw/recently-considered-p is nil on an untagged entry."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (assert-nil (tdw/recently-considered-p))))

;;;; ——— tdw/paused-p ———

(deftest predicates/paused-p-non-nil-when-tagged ()
  "tdw/paused-p is non-nil when entry carries :paused:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :paused:\n")
    (goto-char (point-min))
    (assert-true (tdw/paused-p))))

(deftest predicates/paused-p-nil-when-untagged ()
  "tdw/paused-p is nil on an untagged entry."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (assert-nil (tdw/paused-p))))

;;;; ——— tdw/big-rock-p (score >= 10) ———
;;
;; Score = floor((2*urg + imp) / effort-tier), where the tier is
;; 0-5min=1, 6-15min=2, 16-60min=3, 60+=4, and the level weights are
;; wh=8 vh=5 h=3 sh=2 m=1 l=0.  big-rock-p is (>= score 10).
;; Values below were captured from tdw/compute-score-at-point.

(deftest predicates/big-rock-p-non-nil-when-score-15 ()
  "High urgency+impact at small effort scores 15 (>= 10): big rock.
Captured: vh_urgency + vh_impact, EFFORT 0:05 -> score 15 -> t."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:05")
    (goto-char (point-min))
    (assert-true (tdw/big-rock-p))))

(deftest predicates/big-rock-p-non-nil-at-boundary-score-10 ()
  "Score exactly 10 is a big rock (boundary is inclusive: >= 10).
Captured: vh_urgency + l_impact, EFFORT 0:05 -> raw 10, tier 1 -> score 10 -> t."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :vh_urgency:l_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:05")
    (goto-char (point-min))
    (assert-true (tdw/big-rock-p))))

(deftest predicates/big-rock-p-nil-just-below-boundary-score-9 ()
  "Score 9 is NOT a big rock (just below the inclusive >= 10 boundary).
Captured: h_urgency + h_impact, EFFORT 0:05 -> raw 9, tier 1 -> score 9 -> nil."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :h_urgency:h_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:05")
    (goto-char (point-min))
    (assert-nil (tdw/big-rock-p))))

(deftest predicates/big-rock-p-nil-when-large-effort-dilutes-score ()
  "Same high urgency+impact but a 1-hour effort dilutes the score below 10.
Captured: vh_urgency + vh_impact, EFFORT 1:00 -> raw 15, tier 3 -> score 5 -> nil."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "1:00")
    (goto-char (point-min))
    (assert-nil (tdw/big-rock-p))))

;;;; ——— tdw/unestimated-p ———

(deftest predicates/unestimated-p-non-nil-when-no-effort ()
  "tdw/unestimated-p is non-nil when the entry has no EFFORT property.
Captured: no EFFORT -> t."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (assert-true (tdw/unestimated-p))))

(deftest predicates/unestimated-p-non-nil-when-effort-zero ()
  "tdw/unestimated-p is non-nil when EFFORT is 0:00 (zero minutes).
Captured: EFFORT 0:00 -> t."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:00")
    (goto-char (point-min))
    (assert-true (tdw/unestimated-p))))

(deftest predicates/unestimated-p-nil-when-effort-positive ()
  "tdw/unestimated-p is nil when EFFORT is a positive duration.
Captured: EFFORT 1:00 -> nil."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Title\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "1:00")
    (goto-char (point-min))
    (assert-nil (tdw/unestimated-p))))

;;; predicates-test.el ends here
