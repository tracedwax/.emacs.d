;;; paren-deep-research-test.el --- E-unit tests for paren-deep-research -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Comprehensive e-unit tests for paren-deep-research.el, the per-block
;; paren checker for org literate configs.  Tests use synthetic org content
;; (no dependency on the actual config.org).

;;; Code:

(require 'e-unit)

;; Inhibit the auto-run entry point so require doesn't trigger kill-emacs
(defvar pdr--inhibit-entry t)
(require 'paren-deep-research)

(e-unit-initialize)

;;; ──────────────────────────────────────────────────────────────
;;; Helper: create a temp org file, run pdr--run, return error count + output
;;; ──────────────────────────────────────────────────────────────

(defun pdr-test--run-on-string (org-content)
  "Run pdr--run on ORG-CONTENT string.  Returns (ERROR-COUNT . OUTPUT-STRING)."
  (let ((tmpfile (make-temp-file "pdr-test-" nil ".org"))
        (output ""))
    (unwind-protect
        (progn
          (with-temp-file tmpfile
            (insert org-content))
          (let ((output-buf (generate-new-buffer " *pdr-test-output*")))
            (unwind-protect
                (let ((standard-output output-buf))
                  (let ((count (pdr--run tmpfile)))
                    (with-current-buffer output-buf
                      (setq output (buffer-string)))
                    (cons count output)))
              (kill-buffer output-buf))))
      (delete-file tmpfile))))

;;; ──────────────────────────────────────────────────────────────
;;; Balanced blocks (should pass)
;;; ──────────────────────────────────────────────────────────────

(deftest pdr/balanced-single-defun ()
  "A single balanced defun block passes."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo () (+ 1 2))\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/balanced-multiple-top-level-forms ()
  "Multiple balanced top-level forms in one block pass."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo () 1)\n(defun bar () 2)\n(setq x 3)\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/balanced-nested-let-progn-cond ()
  "Nested let/progn/cond with correct parens passes."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun complex ()\n  (let ((x 1))\n    (progn\n      (cond\n       ((= x 1) (message \"one\"))\n       ((= x 2) (message \"two\"))\n       (t (message \"other\"))))))\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/balanced-strings-containing-parens ()
  "Parens inside strings do not confuse the scanner."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(message \"hello (world) [test]\")\n(setq x \"unbalanced ( here\")\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/balanced-comments-containing-parens ()
  "Parens inside comments do not confuse the scanner."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n;; This has (unbalanced parens\n(defun foo () 1)\n;; another unbalanced )\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/balanced-empty-block ()
  "An empty source block passes."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/balanced-only-comments ()
  "A block with only comments passes."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n;; just a comment\n;; another comment\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

;;; ──────────────────────────────────────────────────────────────
;;; Unbalanced blocks (should fail with correct diagnostics)
;;; ──────────────────────────────────────────────────────────────

(deftest pdr/unbalanced-missing-closing-paren ()
  "Missing closing paren is detected as an error."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo ()\n  (+ 1 2)\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))
    (assert-true (string-match-p "FAILED" (cdr result)))))

(deftest pdr/unbalanced-extra-closing-paren ()
  "Extra closing paren reports scan-error."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo () 1))\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))
    (assert-true (string-match-p "FAILED" (cdr result)))))

(deftest pdr/unbalanced-mismatched-bracket-types ()
  "Mismatched bracket types (] reports scan-error."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo () (list 1 2]\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))
    (assert-true (string-match-p "FAILED" (cdr result)))))

(deftest pdr/unbalanced-unterminated-string ()
  "Unterminated string reports unterminated-string error."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(setq x \"unterminated\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))))

(deftest pdr/unbalanced-unterminated-string-multiline ()
  "Unterminated string spanning multiple lines is detected."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(setq x \"hello\n(defun foo () 1)\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))))

(deftest pdr/unbalanced-error-in-second-of-three ()
  "Error in second block, first and third should pass."
  (let* ((org (concat
               "* Block 1\n#+begin_src emacs-lisp\n(defun ok1 () 1)\n#+end_src\n"
               "* Block 2\n#+begin_src emacs-lisp\n(defun broken (\n#+end_src\n"
               "* Block 3\n#+begin_src emacs-lisp\n(defun ok2 () 2)\n#+end_src\n"))
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))
    (assert-true (string-match-p "BLOCK 2/3" (cdr result)))))

(deftest pdr/unbalanced-deeply-nested-error ()
  "Error deep in nesting (5+ levels) is detected."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun deep ()\n  (let ((a 1))\n    (progn\n      (cond\n       ((= a 1)\n        (let ((b 2))\n          (list b\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))
    (assert-true (string-match-p "FAILED" (cdr result)))))

;;; ──────────────────────────────────────────────────────────────
;;; Metadata accuracy
;;; ──────────────────────────────────────────────────────────────

(deftest pdr/metadata-block-number-reporting ()
  "Output includes correct block N/M numbering."
  (let* ((org (concat
               "* OK\n#+begin_src emacs-lisp\n(defun ok () 1)\n#+end_src\n"
               "* Broken\n#+begin_src emacs-lisp\n(defun broken ()\n#+end_src\n"))
         (result (pdr-test--run-on-string org)))
    (assert-true (string-match-p "BLOCK 2/2" (cdr result)))))

(deftest pdr/metadata-heading-extraction ()
  "Output includes the parent org heading text."
  (let* ((org "* My Custom Heading\n#+begin_src emacs-lisp\n(defun broken ()\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-true (string-match-p "My Custom Heading" (cdr result)))))

(deftest pdr/metadata-error-line-within-block ()
  "Output includes the error line number within the block."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo () 1)\n(defun bar () 2))\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-true (string-match-p "block-line" (cdr result)))))

(deftest pdr/metadata-context-lines ()
  "Output includes context lines around the error."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo () 1)\n(defun bar () 2)\n(defun baz () 3))\n(defun qux () 4)\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    ;; The context should include surrounding lines
    (assert-true (string-match-p "Context:" (cdr result)))))

(deftest pdr/metadata-paren-depth-for-mismatch ()
  "Unbalanced blocks report error details."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun foo ()\n  (let ((x 1))\n    (+ x 2)\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-true (string-match-p "FAILED" (cdr result)))))

(deftest pdr/metadata-config-org-line-range ()
  "Output includes config.org line range for the block."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun broken ()\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-true (string-match-p "lines:" (cdr result)))))

;;; ──────────────────────────────────────────────────────────────
;;; Edge cases
;;; ──────────────────────────────────────────────────────────────

(deftest pdr/edge-zero-elisp-blocks ()
  "Org file with zero elisp blocks passes with 0 errors."
  (let* ((org "* Just a heading\nSome text\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))
    (assert-true (string-match-p "0/0" (cdr result)))))

(deftest pdr/edge-only-non-elisp-blocks ()
  "Org file with only non-elisp blocks (python, shell) passes."
  (let* ((org (concat
               "* Python\n#+begin_src python\nprint('hello'\n#+end_src\n"
               "* Shell\n#+begin_src shell\necho (((\n#+end_src\n"))
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

(deftest pdr/edge-elisp-language-tag ()
  "Block with 'elisp' language tag (not 'emacs-lisp') is checked."
  (let* ((org "* Heading\n#+begin_src elisp\n(defun broken ()\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))))

(deftest pdr/edge-emacs-lisp-language-tag ()
  "Block with 'emacs-lisp' language tag is checked."
  (let* ((org "* Heading\n#+begin_src emacs-lisp\n(defun broken ()\n#+end_src\n")
         (result (pdr-test--run-on-string org)))
    (assert-equal 1 (car result))))

(deftest pdr/edge-large-block ()
  "Large block (1000+ lines) is handled correctly."
  (let* ((lines (mapconcat
                 (lambda (i) (format "(defun func-%d () %d)" i i))
                 (number-sequence 1 1000)
                 "\n"))
         (org (concat "* Large\n#+begin_src emacs-lisp\n" lines "\n#+end_src\n"))
         (result (pdr-test--run-on-string org)))
    (assert-equal 0 (car result))))

;;; ──────────────────────────────────────────────────────────────
;;; Unit tests for pdr--check-block directly
;;; ──────────────────────────────────────────────────────────────

(deftest pdr/check-block-returns-nil-for-balanced ()
  "pdr--check-block returns nil for balanced code."
  (assert-nil (pdr--check-block "(defun foo () (+ 1 2))")))

(deftest pdr/check-block-returns-plist-for-unbalanced ()
  "pdr--check-block returns a plist for unbalanced code."
  (let ((result (pdr--check-block "(defun foo ()")))
    (assert-true (listp result))
    (assert-true (plist-get result :type))
    (assert-true (plist-get result :message))))

(deftest pdr/check-block-scan-error-type ()
  "Extra closer returns scan-error type."
  (let ((result (pdr--check-block "(defun foo () 1))")))
    (assert-equal "scan-error" (plist-get result :type))))

(deftest pdr/check-block-depth-mismatch-type ()
  "Missing closer returns an error (scan-error or depth-mismatch)."
  (let ((result (pdr--check-block "(defun foo () (+ 1 2)")))
    (assert-true (member (plist-get result :type) '("scan-error" "depth-mismatch")))
    (assert-true (plist-get result :message))))

(deftest pdr/check-block-empty-string ()
  "Empty string is balanced."
  (assert-nil (pdr--check-block "")))

;;; ──────────────────────────────────────────────────────────────
;;; Unit tests for pdr--extract-context-lines
;;; ──────────────────────────────────────────────────────────────

(deftest pdr/extract-context-includes-surrounding-lines ()
  "Context extraction returns lines around the error line."
  (let* ((code "(line 0)\n(line 1)\n(line 2)\n(line 3)\n(line 4)\n(line 5)\n(line 6)")
         (context (pdr--extract-context-lines code 3)))
    ;; Should include lines 0-6 (3 above line 3, line 3, and 3 below)
    (assert-true (> (length context) 1))
    ;; Context items are (line-num-1indexed . text) pairs
    (assert-equal 1 (car (car context)))))

(deftest pdr/extract-context-at-start-of-file ()
  "Context extraction at line 0 doesn't go negative."
  (let* ((code "(line 0)\n(line 1)\n(line 2)")
         (context (pdr--extract-context-lines code 0)))
    (assert-true (>= (car (car context)) 1))))

(deftest pdr/extract-context-at-end-of-file ()
  "Context extraction at last line doesn't overflow."
  (let* ((code "(line 0)\n(line 1)\n(line 2)")
         (context (pdr--extract-context-lines code 2)))
    (assert-true (> (length context) 0))))

;;; paren-deep-research-test.el ends here
