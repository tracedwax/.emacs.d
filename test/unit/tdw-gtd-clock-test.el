;;; tdw-gtd-clock-test.el --- Tests for deterministic GTD clock adjustment -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw-gtd-parse-duration' and `tdw-gtd-adjust-timer' are the
;; deterministic replacement for the adjust-timer workflow's mechanical
;; steps (duration parsing, latest-clock-out lookup, CLOCK-line
;; consolidation, tag swap) so a weak model just has to call one function
;; with a title/duration, instead of doing timestamp arithmetic by hand.
;;
;; Duration-parsing cases are pinned exactly against the table in
;; .agent/workflows/adjust-timer.md.

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-gtd-clock)

;;;; tdw-gtd-parse-duration

(deftest gtd-clock/parses-bare-minutes ()
  (assert-equal 30 (tdw-gtd-parse-duration "30m")))

(deftest gtd-clock/parses-bare-hours ()
  (assert-equal 60 (tdw-gtd-parse-duration "1h")))

(deftest gtd-clock/parses-hours-and-minutes ()
  (assert-equal 90 (tdw-gtd-parse-duration "1h30m")))

(deftest gtd-clock/parses-spelled-out-minutes ()
  (assert-equal 45 (tdw-gtd-parse-duration "45 minutes")))

(deftest gtd-clock/parses-colon-form ()
  (assert-equal 135 (tdw-gtd-parse-duration "2:15")))

(deftest gtd-clock/parses-decimal-hours ()
  (assert-equal 90 (tdw-gtd-parse-duration "1.5h")))

(deftest gtd-clock/parses-large-bare-minutes ()
  (assert-equal 90 (tdw-gtd-parse-duration "90m")))

(deftest gtd-clock/parses-abbreviated-min ()
  "Not in the documented table, but a reasonable abbreviation to accept."
  (assert-equal 45 (tdw-gtd-parse-duration "45min")))

(deftest gtd-clock/parses-hours-only-with-space ()
  (assert-equal 120 (tdw-gtd-parse-duration "2 h")))

(deftest gtd-clock/rejects-unparseable-input ()
  (assert-true
   (condition-case nil
       (progn (tdw-gtd-parse-duration "banana") nil)
     (error t))))

;;;; Wiring guard: config.org must actually load this module.

(defun tdw-gtd-clock-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "~/.emacs.d/config.org"))
    (buffer-string)))

(deftest gtd-clock/config-requires-the-module ()
  "config.org must require tdw-gtd-clock, or the live daemon never gets it."
  (assert-true (string-match-p "(require 'tdw-gtd-clock)"
                                (tdw-gtd-clock-test--config))))

(provide 'tdw-gtd-clock-test)
;;; tdw-gtd-clock-test.el ends here
