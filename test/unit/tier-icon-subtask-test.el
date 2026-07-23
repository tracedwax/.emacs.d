;;; tier-icon-subtask-test.el --- Tier icon suppressed on project subtasks -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Project subtasks inherit the parent's tier tag (so tier agenda sections
;; still show them), but the tier emoji belongs to the project, not every
;; child: `org-gtd-agenda--resolve-tier' must return "" for a subtask.

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(defmacro tier-icon-test--on-heading (text &rest body)
  "Insert TEXT into an org buffer, leave point on the first heading, run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,text)
     (goto-char (point-min))
     ,@body))

(deftest resolve-tier/subtask-shows-no-icon ()
  "A project subtask with a tier tag renders no tier emoji."
  (tier-icon-test--on-heading
      (concat "* TODO A subtask :on_deck:tgl_admin:\n"
              ":PROPERTIES:\n"
              ":ORG_GTD:  Actions\n"
              ":ORG_GTD_PROJECT_IDS: Some-project-id\n"
              ":END:\n")
    (assert-equal "" (org-gtd-agenda--resolve-tier))))

(deftest resolve-tier/project-parent-shows-icon ()
  "A project parent with a tier tag still renders its emoji."
  (tier-icon-test--on-heading
      (concat "* TODO A project :on_deck:tgl_admin:\n"
              ":PROPERTIES:\n"
              ":ORG_GTD:  Projects\n"
              ":END:\n")
    (assert-equal "🥎" (org-gtd-agenda--resolve-tier))))

(deftest resolve-tier/standalone-action-shows-icon ()
  "A standalone action (no project linkage) still renders its emoji."
  (tier-icon-test--on-heading
      (concat "* NEXT A task :paused:tgl_admin:\n"
              ":PROPERTIES:\n"
              ":ORG_GTD:  Actions\n"
              ":END:\n")
    (assert-equal "🕐" (org-gtd-agenda--resolve-tier))))

;;; tier-icon-subtask-test.el ends here
