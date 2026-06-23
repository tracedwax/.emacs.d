;;; inherit-metadata-test.el --- Tests for org-gtd parent-metadata inheritance -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Tests my/org-gtd-inherit--apply-metadata.  Project subtasks must inherit
;; TAGS from the parent, but must NOT get a stamped PRIORITY cookie — a stamped
;; priority makes subtasks indistinguishable from real tasks in the agenda.
;; (Priority still propagates for display via org's own inheritance; we just
;; refuse to write the cookie onto the subtask.)

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defmacro inherit-test--on-heading (text &rest body)
  "Insert TEXT into an org buffer, leave point on the first heading, run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,text)
     (goto-char (point-min))
     ,@body))

(deftest inherit-apply/does-not-stamp-priority ()
  "Applying parent metadata must NOT write a [#A] priority cookie on the task."
  (inherit-test--on-heading "* TODO A subtask\n"
    (my/org-gtd-inherit--apply-metadata '(:priority "A" :tags ("foo")))
    (goto-char (point-min))
    (let ((line (buffer-substring-no-properties (line-beginning-position)
                                                (line-end-position))))
      (assert-nil (string-match-p "\\[#A\\]" line)))))

(deftest inherit-apply/still-inherits-tags ()
  "Applying parent metadata still copies the parent's tags onto the task."
  (inherit-test--on-heading "* TODO A subtask\n"
    (my/org-gtd-inherit--apply-metadata '(:priority "A" :tags ("foo")))
    (goto-char (point-min))
    (assert-true (and (member "foo" (org-get-tags)) t))))

;;; inherit-metadata-test.el ends here
