;;; paren-deep-research-test.el --- E-unit tests for paren-deep-research.el -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests for the paren-deep-research diagnostic tool.
;; Validates pdr--check-block and pdr--defun-depth-report.

;;; Code:

(require 'e-unit)

;; Load the tool as a library, not as entry-point
(setq pdr--inhibit-entry t)
(require 'paren-deep-research
         (expand-file-name "~/.emacs.d/scripts/paren-deep-research.el"))

(e-unit-initialize)

;;;; ——— pdr--check-block ———

(deftest pdr/check-block-returns-nil-for-balanced-code ()
  "Balanced elisp returns nil (no error)."
  (assert-nil (pdr--check-block "(defun foo () (+ 1 2))\n(defun bar () nil)\n")))

(deftest pdr/check-block-detects-missing-close-paren ()
  "An unclosed paren returns a scan-error (scan-sexps catches it first)."
  (let ((result (pdr--check-block "(defun foo () (+ 1 2)\n")))
    (assert-true result)
    (assert-equal "scan-error" (plist-get result :type))))

(deftest pdr/check-block-detects-extra-close-paren ()
  "An extra close paren returns a scan-error."
  (let ((result (pdr--check-block "(defun foo () (+ 1 2)))\n")))
    (assert-true result)
    (assert-equal "scan-error" (plist-get result :type))))

;;;; ——— pdr--defun-depth-report ———

(deftest pdr/defun-depth-report-returns-entries-for-each-defun ()
  "Reports one entry per defun found in code."
  (let ((result (pdr--defun-depth-report
                 "(defun foo () nil)\n(defun bar () nil)\n")))
    (assert-equal 2 (length result))
    (assert-equal "foo" (plist-get (nth 0 result) :name))
    (assert-equal "bar" (plist-get (nth 1 result) :name))))

(deftest pdr/defun-depth-report-shows-zero-depth-for-toplevel ()
  "Top-level defuns have depth 0."
  (let ((result (pdr--defun-depth-report
                 "(defun foo () nil)\n(defun bar () nil)\n")))
    (assert-equal 0 (plist-get (nth 0 result) :depth-before))
    (assert-equal 0 (plist-get (nth 1 result) :depth-before))))

(deftest pdr/defun-depth-report-detects-leaked-paren ()
  "A defun missing a close paren causes the next defun to appear at higher depth."
  (let ((result (pdr--defun-depth-report
                 "(defun foo () (+ 1 2)\n(defun bar () nil)\n")))
    ;; foo is at depth 0 (correct)
    (assert-equal 0 (plist-get (nth 0 result) :depth-before))
    ;; bar should be at depth > 0 because foo leaked
    (assert-true (> (plist-get (nth 1 result) :depth-before) 0))))

(deftest pdr/defun-depth-report-handles-wrapper-forms ()
  "Defuns inside (with-eval-after-load ...) should be at depth 1."
  (let ((result (pdr--defun-depth-report
                 "(with-eval-after-load 'something\n  (defun foo () nil)\n  (defun bar () nil))\n")))
    (assert-equal 1 (plist-get (nth 0 result) :depth-before))
    (assert-equal 1 (plist-get (nth 1 result) :depth-before))))

;;; paren-deep-research-test.el ends here
