;;; effort-and-score-pure-test.el --- Characterization tests for pure effort/score helpers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Pure-function characterization tests that LOCK the current behavior of the
;; effort parser, the 15-minute rounder, and the urgency/impact level scorer,
;; so the POODR refactor cannot change their results. Values were captured from
;; the live functions, not guessed.
;;
;; Uses e-unit (deftest, assert-equal).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— tdw/get-effort-minutes ———

(deftest effort/parses-h-mm ()
  "H:MM efforts parse to total minutes."
  (assert-equal 15 (tdw/get-effort-minutes "0:15"))
  (assert-equal 90 (tdw/get-effort-minutes "1:30"))
  (assert-equal 125 (tdw/get-effort-minutes "2:05")))

(deftest effort/parses-bare-number-as-minutes ()
  "A bare number string is treated as minutes."
  (assert-equal 90 (tdw/get-effort-minutes "90")))

(deftest effort/nil-and-empty-are-zero ()
  "nil or empty effort yields 0 minutes."
  (assert-equal 0 (tdw/get-effort-minutes nil))
  (assert-equal 0 (tdw/get-effort-minutes "")))

;;;; ——— tdw/round-up-15 ———

(deftest round-up-15/rounds-up-to-next-quarter-hour ()
  "Minutes round UP to the next multiple of 15; exact multiples stay put; 0 stays 0."
  (assert-equal 0 (tdw/round-up-15 0))
  (assert-equal 15 (tdw/round-up-15 1))
  (assert-equal 15 (tdw/round-up-15 15))
  (assert-equal 30 (tdw/round-up-15 16))
  (assert-equal 60 (tdw/round-up-15 60)))

;;;; ——— tdw/format-minutes ———

(deftest format-minutes/renders-h-mm ()
  "Minutes render as H:MM with a zero-padded minute field."
  (assert-equal "0:00" (tdw/format-minutes 0))
  (assert-equal "0:15" (tdw/format-minutes 15))
  (assert-equal "1:30" (tdw/format-minutes 90))
  (assert-equal "2:05" (tdw/format-minutes 125)))

;;;; ——— tdw/score-value-for-level ———

(deftest level-score/maps-level-abbreviations-to-weights ()
  "wh=8, vh=5, h=3, sh=2, m=1, l=0."
  (assert-equal 8 (tdw/score-value-for-level "wh"))
  (assert-equal 5 (tdw/score-value-for-level "vh"))
  (assert-equal 3 (tdw/score-value-for-level "h"))
  (assert-equal 2 (tdw/score-value-for-level "sh"))
  (assert-equal 1 (tdw/score-value-for-level "m"))
  (assert-equal 0 (tdw/score-value-for-level "l")))

(deftest level-score/unknown-level-scores-zero ()
  "An unrecognized level abbreviation scores 0 (same as l)."
  (assert-equal 0 (tdw/score-value-for-level "xx")))

;;; effort-and-score-pure-test.el ends here
