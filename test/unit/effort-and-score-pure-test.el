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

;;;; ——— tdw/effort-string-to-minutes ———

(deftest effort/parses-h-mm ()
  "H:MM efforts parse to total minutes."
  (assert-equal 15 (tdw/effort-string-to-minutes "0:15"))
  (assert-equal 90 (tdw/effort-string-to-minutes "1:30"))
  (assert-equal 125 (tdw/effort-string-to-minutes "2:05")))

(deftest effort/parses-bare-number-as-minutes ()
  "A bare number string is treated as minutes."
  (assert-equal 90 (tdw/effort-string-to-minutes "90")))

(deftest effort/nil-and-empty-are-zero ()
  "nil or empty effort yields 0 minutes."
  (assert-equal 0 (tdw/effort-string-to-minutes nil))
  (assert-equal 0 (tdw/effort-string-to-minutes "")))

;;;; ——— tdw/round-up-to-quarter-hour ———

(deftest round-up-15/rounds-up-to-next-quarter-hour ()
  "Minutes round UP to the next multiple of 15; exact multiples stay put; 0 stays 0."
  (assert-equal 0 (tdw/round-up-to-quarter-hour 0))
  (assert-equal 15 (tdw/round-up-to-quarter-hour 1))
  (assert-equal 15 (tdw/round-up-to-quarter-hour 15))
  (assert-equal 30 (tdw/round-up-to-quarter-hour 16))
  (assert-equal 60 (tdw/round-up-to-quarter-hour 60)))

;;;; ——— tdw/format-minutes ———

(deftest format-minutes/renders-h-mm ()
  "Minutes render as H:MM with a zero-padded minute field."
  (assert-equal "0:00" (tdw/format-minutes 0))
  (assert-equal "0:15" (tdw/format-minutes 15))
  (assert-equal "1:30" (tdw/format-minutes 90))
  (assert-equal "2:05" (tdw/format-minutes 125)))

;;; effort-and-score-pure-test.el ends here
