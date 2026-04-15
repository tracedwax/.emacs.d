;;; test-bootstrap.el --- Bootstrap for running config.org ERT tests -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Loads config.el in a way that extracts function definitions without
;; requiring the full package/use-package infrastructure.  Used by
;; run-tests.sh.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-agenda)
(require 'org-habit)

;; Save original use-package
(defvar test-bootstrap--orig-use-package (symbol-function 'use-package))

;; Redefine use-package to just evaluate :config body forms
;; with error protection so individual forms can fail without
;; preventing subsequent forms
(fset 'use-package nil)
(defmacro use-package (name &rest args)
  "Test stub: extract and evaluate :config body, skip everything else."
  (declare (indent 1))
  (let (config-body collecting)
    (while args
      (let ((head (car args)))
        (cond
         ((eq head :config)
          (setq collecting t)
          (setq args (cdr args)))
         ((and collecting (keywordp head))
          (setq collecting nil)
          (setq args (cdr args)))
         (collecting
          (push head config-body)
          (setq args (cdr args)))
         (t
          (setq args (cdr args))))))
    (when config-body
      `(progn
         ,@(mapcar (lambda (form)
                     `(condition-case err
                          ,form
                        (error (message "test-bootstrap: skipped form: %S" (car err)))))
                   (nreverse config-body))))))

;; Stub with-eval-after-load to evaluate body immediately  
(defmacro with-eval-after-load (_feature &rest body)
  "Test stub: evaluate BODY immediately rather than deferring."
  `(progn
     ,@(mapcar (lambda (form)
                 `(condition-case err
                      ,form
                    (error (message "test-bootstrap: eval-after-load skipped: %S" (car err)))))
               body)))

;; Load config.el form by form, skipping any that error
(let ((config-el (expand-file-name "~/.emacs.d/config.el")))
  (when (file-exists-p config-el)
    (with-temp-buffer
      (insert-file-contents config-el)
      (goto-char (point-min))
      (let ((forms-ok 0) (forms-err 0))
        (while (not (eobp))
          (condition-case err
              (let ((form (read (current-buffer))))
                (condition-case err2
                    (progn (eval form t) (cl-incf forms-ok))
                  (error (cl-incf forms-err))))
            (end-of-file nil)
            (error (cl-incf forms-err))))
        (message "test-bootstrap: loaded %d forms, skipped %d" forms-ok forms-err)))))

(provide 'test-bootstrap)

;;; test-bootstrap.el ends here
