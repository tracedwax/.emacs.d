;;; paren-deep-research.el --- Per-block paren checker for org literate configs -*- lexical-binding: t; -*-

;; Purpose: Agent-only diagnostic tool. Parses an org file, extracts every
;; elisp/emacs-lisp source block, checks each one individually for balanced
;; parentheses, and prints structured plain-text diagnostics with drowning
;; detail so an AI agent can locate and fix the problem without human help.
;;
;; Usage:
;;   CONFIG_ORG=/path/to/config.org emacs --batch -l paren-deep-research.el
;;
;; Exit codes:
;;   0 = all blocks balanced
;;   1 = one or more blocks have paren errors

(require 'org)
(require 'org-element)

(defun pdr--get-parent-heading (element)
  "Walk up from ELEMENT to find the nearest parent headline.
Returns the raw heading text or \"(top-level)\" if none found."
  (let ((parent (org-element-property :parent element)))
    (while (and parent
                (not (eq (org-element-type parent) 'headline)))
      (setq parent (org-element-property :parent parent)))
    (if parent
        (org-element-property :raw-value parent)
      "(top-level)")))

(defun pdr--line-at-pos (pos)
  "Return the 1-indexed line number at buffer position POS."
  (save-excursion
    (goto-char pos)
    (count-lines (point-min) (line-beginning-position))  ;; 0-indexed
    ))

(defun pdr--extract-context-lines (code error-line-0indexed)
  "Extract context lines around ERROR-LINE-0INDEXED from CODE string.
Returns a list of (LINE-NUM-1indexed . LINE-TEXT) pairs, with 3 lines
of context above and below."
  (let* ((lines (split-string code "\n"))
         (total (length lines))
         (start (max 0 (- error-line-0indexed 3)))
         (end (min total (+ error-line-0indexed 4)))
         (result '()))
    (let ((cursor (nthcdr start lines)))
      (cl-loop for i from start below end
               do (push (cons (1+ i) (car cursor)) result)
               do (setq cursor (cdr cursor))))
    (nreverse result)))

(defun pdr--format-context (context-lines error-line-1indexed error-col)
  "Format CONTEXT-LINES with a caret at ERROR-COL on ERROR-LINE-1INDEXED.
Each element of CONTEXT-LINES is (LINE-NUM . TEXT)."
  (let ((parts '()))
    (dolist (pair context-lines)
      (let* ((lnum (car pair))
             (text (cdr pair))
             (prefix (if (= lnum error-line-1indexed) ">" " "))
             (line (format "  %s %3d | %s\n" prefix lnum text)))
        (push line parts)
        ;; Add caret line after the error line
        (when (= lnum error-line-1indexed)
          (let* ((gutter-width (+ 8))  ;; "  > NNN | " = 8 + digits
                 (caret-offset (+ gutter-width error-col))
                 (caret-line (concat (make-string caret-offset ? ) "^ error here\n")))
            (push caret-line parts)))))
    (mapconcat #'identity (nreverse parts) "")))

(defun pdr--check-block (code)
  "Check CODE string for paren balance.
Returns nil if balanced, or a plist with error details if not:
  :type - \"scan-error\" or \"depth-mismatch\"
  :position - buffer position of error (for scan-error)
  :line-0indexed - 0-indexed line number within the block
  :column - 0-indexed column within the line
  :depth - final paren depth (for depth-mismatch)
  :message - human-readable error description"
  (with-temp-buffer
    (insert code)
    (goto-char (point-min))
    (emacs-lisp-mode)
    ;; First: try scan-sexps for hard errors (mismatched parens)
    (let ((scan-result
           (condition-case data
               (progn
                 (scan-sexps (point-min) (point-max))
                 nil)  ;; no error
             (scan-error
              (let* ((err-pos (nth 2 data))
                     (err-msg (nth 1 data)))
                (goto-char err-pos)
                (let* ((line-0 (count-lines (point-min) (line-beginning-position)))
                       (col (- err-pos (line-beginning-position))))
                  (list :type "scan-error"
                        :position err-pos
                        :line-0indexed line-0
                        :column col
                        :depth nil
                        :message err-msg)))))))
      (if scan-result
          scan-result
        ;; Second: check depth at end via parse-partial-sexp
        (let* ((state (parse-partial-sexp (point-min) (point-max)))
               (depth (nth 0 state))
               (in-string (nth 3 state))
               (in-comment (nth 4 state)))
          (cond
           ((not (zerop depth))
            (list :type "depth-mismatch"
                  :position (point-max)
                  :line-0indexed (count-lines (point-min) (point-max))
                  :column 0
                  :depth depth
                  :message (format "Block ends at paren depth %d (expected 0 -- %s)"
                                   depth
                                   (if (> depth 0)
                                       (format "missing %d closer(s)" depth)
                                     (format "%d extra closer(s)" (abs depth))))))
           (in-string
            (list :type "unterminated-string"
                  :position (point-max)
                  :line-0indexed (count-lines (point-min) (point-max))
                  :column 0
                  :depth 0
                  :message "Block ends inside an unterminated string"))
           (in-comment
            (list :type "unterminated-comment"
                  :position (point-max)
                  :line-0indexed (count-lines (point-min) (point-max))
                  :column 0
                  :depth 0
                  :message "Block ends inside an unterminated block comment"))
           (t nil)))))))

(defun pdr--defun-depth-report (code)
  "Walk through CODE incrementally, reporting paren depth at each (defun.
Returns a list of plists, one per defun found:
  :name - function name
  :line-1indexed - 1-indexed line within the block
  :depth-before - paren depth just before this (defun
Uses incremental `parse-partial-sexp' (O(n) single pass, not O(n²))."
  (with-temp-buffer
    (insert code)
    (goto-char (point-min))
    (emacs-lisp-mode)
    (let ((results nil)
          (parse-state nil)
          (last-pos (point-min)))
      ;; Single forward pass: find each defun, parse incrementally to it
      (while (re-search-forward "^[[:space:]]*(defun \\([^ \t\n(]+\\)" nil t)
        (let* ((name (match-string 1))
               (defun-start (match-beginning 0))
               (search-resume (point))  ;; save where re-search-forward left point
               (line-1 (line-number-at-pos defun-start)))
          ;; Incremental parse from where we left off
          (setq parse-state (parse-partial-sexp last-pos defun-start nil nil parse-state))
          (let ((depth-before (nth 0 parse-state)))
            (push (list :name name
                        :line-1indexed line-1
                        :depth-before depth-before)
                  results))
          (setq last-pos defun-start)
          (goto-char search-resume)))  ;; restore point for next re-search-forward
      (nreverse results))))

(defun pdr--run (file)
  "Run paren-deep-research on FILE. Print results. Return error count."
  (let ((error-count 0)
        (block-index 0)
        (total-blocks 0)
        (elisp-blocks '()))

    ;; Parse the org file
    (with-temp-buffer
      (insert-file-contents file)
      (org-mode)
      (let ((ast (org-element-parse-buffer)))

        ;; Collect all elisp source blocks with metadata
        (org-element-map ast 'src-block
          (lambda (block)
            (let ((lang (org-element-property :language block)))
              (when (and lang (member (downcase lang) '("elisp" "emacs-lisp")))
                (let* ((code (org-element-property :value block))
                       (begin (org-element-property :begin block))
                       (post-aff (org-element-property :post-affiliated block))
                       ;; Line of #+begin_src in the org file (1-indexed)
                       (org-begin-line (count-lines 1 post-aff))
                       ;; Count lines in the code to get end line
                       (code-lines (cl-count ?\n code))
                       (org-end-line (+ org-begin-line code-lines))
                       (heading (pdr--get-parent-heading block)))
                  (push (list :code code
                              :heading heading
                              :org-begin-line org-begin-line
                              :org-end-line org-end-line
                              :code-lines code-lines)
                        elisp-blocks))))))

        (setq elisp-blocks (nreverse elisp-blocks))
        (setq total-blocks (length elisp-blocks))

        ;; Check each block
        (dolist (block-info elisp-blocks)
          (setq block-index (1+ block-index))
          (let* ((code (plist-get block-info :code))
                 (heading (plist-get block-info :heading))
                 (org-begin (plist-get block-info :org-begin-line))
                 (org-end (plist-get block-info :org-end-line))
                 (error-info (pdr--check-block code)))

            (when error-info
              (setq error-count (1+ error-count))
              (let* ((err-type (plist-get error-info :type))
                     (err-line-0 (plist-get error-info :line-0indexed))
                     (err-line-1 (1+ err-line-0))
                     (err-col (plist-get error-info :column))
                     (err-depth (plist-get error-info :depth))
                     (err-msg (plist-get error-info :message))
                     (org-error-line (+ org-begin err-line-1))
                     (context (pdr--extract-context-lines code err-line-0))
                     (formatted-ctx (pdr--format-context context err-line-1 err-col)))

                (princ (format "\n══════════════════════════════════════════════════════════════\n"))
                (princ (format "BLOCK %d/%d — FAILED\n" block-index total-blocks))
                (princ (format "Heading: %s\n" heading))
                (princ (format "config.org lines: %d–%d (%d lines of code)\n"
                               org-begin org-end (plist-get block-info :code-lines)))
                (princ (format "Error at block-line %d, column %d (config.org line %d)\n"
                               err-line-1 err-col org-error-line))
                (when err-depth
                  (princ (format "Paren depth at error: %d\n" err-depth)))
                (princ (format "Type: %s\n" err-msg))
                (princ (format "\nContext:\n"))
                (princ formatted-ctx)

                ;; Per-defun depth report for blocks with errors
                (let ((defun-report (pdr--defun-depth-report code)))
                  (when defun-report
                    (princ (format "\nDefun depth report (%d functions):\n" (length defun-report)))
                    (let ((expected-depth (plist-get (car defun-report) :depth-before)))
                      (dolist (entry defun-report)
                        (let* ((name (plist-get entry :name))
                               (line (plist-get entry :line-1indexed))
                               (d-before (plist-get entry :depth-before))
                               (org-line (+ org-begin line))
                               (marker (if (/= d-before expected-depth)
                                           (format " *** WRONG (expected %d)" expected-depth)
                                         "")))
                          (princ (format "  %s line %d (org:%d) depth %d%s\n"
                                         name line org-line d-before marker)))))))

                (princ (format "══════════════════════════════════════════════════════════════\n"))))))))

    ;; Summary
    (if (zerop error-count)
        (princ (format "\nPARENS OK: %d/%d blocks balanced\n" total-blocks total-blocks))
      (princ (format "\nPARENS FAILED: %d/%d blocks have errors\n" error-count total-blocks)))

    error-count))

;; --- Entry point (only when run directly via emacs --batch -l, not via require) ---
;; When loaded as a library, callers set pdr--inhibit-entry before require.
(defvar pdr--inhibit-entry nil
  "When non-nil, skip the auto-run entry point.
Set this before `require'ing paren-deep-research to use it as a library.")

(provide 'paren-deep-research)

(when (and noninteractive
           (not pdr--inhibit-entry))
  (let* ((file (or (getenv "CONFIG_ORG")
                   (expand-file-name "~/.emacs.d/config.org")))
         (errors (pdr--run file)))
    (kill-emacs (if (zerop errors) 0 1))))

;;; paren-deep-research.el ends here
