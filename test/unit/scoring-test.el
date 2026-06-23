;;; scoring-test.el --- Characterization tests for at-point scoring helpers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Characterization tests that LOCK the current behavior of the at-point
;; scoring helpers in config.org, so the upcoming POODR refactor cannot
;; regress them:
;;
;;   - tdw/compute-score-at-point (KEYSTONE): floor((2*urg + imp) / tier),
;;     where tier comes from EFFORT minutes (0-5=1, 6-15=2, 16-60=3, 60+=4).
;;   - tdw--score-effort-at-point: the positional list skip functions read,
;;     (score effort-mins p0-p done-p gc-next-p flyby-p).
;;
;; Every value here was CAPTURED from the live tangled config.el via
;; test-bootstrap, not guessed.
;;
;; Uses e-unit (deftest, assert-equal, assert-true, assert-nil).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— KEYSTONE: tdw/compute-score-at-point ———

(deftest scoring/score-vh-vh-effort-1h-is-5 ()
  "vh_urgency + vh_impact with EFFORT 1:00 (60min, tier 3): raw=2*5+5=15, floor(15/3)=5."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "1:00")
    (goto-char (point-min))
    (assert-equal 5 (tdw/compute-score-at-point))))

(deftest scoring/score-l-l-no-effort-is-0 ()
  "l_urgency + l_impact, no effort (default 5min, tier 1): raw=0, floor(0/1)=0."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :l_urgency:l_impact:\n")
    (goto-char (point-min))
    (assert-equal 0 (tdw/compute-score-at-point))))

(deftest scoring/score-m-h-no-effort-is-5 ()
  "m_urgency + h_impact, no effort (tier 1): raw=2*1+3=5, floor(5/1)=5."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :m_urgency:h_impact:\n")
    (goto-char (point-min))
    (assert-equal 5 (tdw/compute-score-at-point))))

(deftest scoring/score-h-m-no-effort-is-7 ()
  "h_urgency + m_impact, no effort (tier 1): raw=2*3+1=7, floor(7/1)=7.
Asymmetry check: urgency is weighted 2x, so h/m beats m/h."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :h_urgency:m_impact:\n")
    (goto-char (point-min))
    (assert-equal 7 (tdw/compute-score-at-point))))

(deftest scoring/score-vh-vh-effort-30min-is-5 ()
  "vh + vh with EFFORT 0:30 (30min, tier 3): raw=15, floor(15/3)=5."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:30")
    (goto-char (point-min))
    (assert-equal 5 (tdw/compute-score-at-point))))

(deftest scoring/score-vh-vh-effort-5min-is-15 ()
  "vh + vh with EFFORT 0:05 (5min, tier 1): raw=15, floor(15/1)=15.
Boundary: 5 minutes is still tier 1."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:05")
    (goto-char (point-min))
    (assert-equal 15 (tdw/compute-score-at-point))))

(deftest scoring/score-wh-wh-no-effort-is-24 ()
  "wh + wh, no effort (tier 1): raw=2*8+8=24, floor(24/1)=24. Max single-entry score."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :wh_urgency:wh_impact:\n")
    (goto-char (point-min))
    (assert-equal 24 (tdw/compute-score-at-point))))

(deftest scoring/score-h-h-effort-2h-is-2 ()
  "h + h with EFFORT 2:00 (120min, tier 4): raw=2*3+3=9, floor(9/4)=2.
Big-effort items get divided down hard."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :h_urgency:h_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "2:00")
    (goto-char (point-min))
    (assert-equal 2 (tdw/compute-score-at-point))))

(deftest scoring/score-untagged-no-effort-is-0 ()
  "No urgency/impact tags and no effort: both default to l (0), score is 0."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task\n")
    (goto-char (point-min))
    (assert-equal 0 (tdw/compute-score-at-point))))

;;;; ——— tdw--score-effort-at-point: positional list ———

(deftest scoring/score-effort-list-length-is-6 ()
  "The list returned by tdw--score-effort-at-point has exactly 6 elements:
(score effort-mins p0-p done-p gc-next-p flyby-p)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "1:00")
    (goto-char (point-min))
    (assert-equal 6 (length (tdw--score-effort-at-point)))))

(deftest scoring/score-effort-list-vh-vh-1h ()
  "vh/vh + EFFORT 1:00 yields (5 60 nil nil nil nil):
score 5, effort-mins 60, no p0/done/gc_next/flyby."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "1:00")
    (goto-char (point-min))
    (assert-equal '(5 60 nil nil nil nil) (tdw--score-effort-at-point))))

(deftest scoring/score-effort-list-l-l-no-effort ()
  "l/l, no effort yields (0 nil nil nil nil nil):
score 0 and effort-mins nil (unestimated, distinct from 0)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :l_urgency:l_impact:\n")
    (goto-char (point-min))
    (assert-equal '(0 nil nil nil nil nil) (tdw--score-effort-at-point))))

(deftest scoring/score-effort-nth-elements-skip-reads ()
  "skip-unless-unestimated reads nth 0 (score), nth 1 (effort-mins), nth 3 (done-p).
For a DONE p0 entry with EFFORT 0:30: score=0, effort-mins=30, done-p truthy."
  (with-temp-buffer
    (org-mode)
    (insert "* DONE Test task  :p0:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:30")
    (goto-char (point-min))
    (let ((info (tdw--score-effort-at-point)))
      (assert-equal 0 (nth 0 info))
      (assert-equal 30 (nth 1 info))
      (assert-true (nth 3 info)))))

(deftest scoring/score-effort-gc-next-and-flyby-flags ()
  "gc_next and flyby tags surface in nth 4 and nth 5 of the positional list."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :gc_next:flyby:\n")
    (goto-char (point-min))
    (let ((info (tdw--score-effort-at-point)))
      (assert-true (nth 4 info))
      (assert-true (nth 5 info)))))

;;;; ——— Downstream consumer: tdw/skip-unless-unestimated ———

(deftest scoring/skip-keeps-low-score-unestimated ()
  "Low-score (l/l) undone entry with no effort is KEPT (skip returns nil)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :l_urgency:l_impact:\n")
    (goto-char (point-min))
    (assert-nil (tdw/skip-unless-unestimated))))

(deftest scoring/skip-drops-high-score-estimated ()
  "High-score (vh/vh) entry with effort is SKIPPED (returns non-nil position)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Test task  :vh_urgency:vh_impact:\n")
    (goto-char (point-min))
    (org-set-property "EFFORT" "0:05")
    (goto-char (point-min))
    (assert-true (tdw/skip-unless-unestimated))))

;;; scoring-test.el ends here
