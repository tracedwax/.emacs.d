;;; tdw-delegated.el --- Delegated agenda section semantics -*- lexical-binding: t; -*-

;; The Unordered View shows delegated items (WAIT + ORG_GTD=Delegated)
;; in three sections bucketed by check-in date: Overdue, Due Today,
;; Due After Today.
;;
;; The check-in date has two legitimate shapes:
;;   - the DEADLINE planning line, which is what Trace actually edits
;;     when moving a check-in, and
;;   - the ORG_GTD_TIMESTAMP property, which is what org-gtd-delegate
;;     writes when an item is delegated through the clarify flow.
;; DEADLINE wins when both exist: the hand-edited planning line is the
;; live signal, the property is delegation-time state.  The org-gtd
;; view DSL cannot express this (its `when' filter reads only the
;; property, and its predicates compose with AND), which is why these
;; sections are native blocks instead of DSL specs.
;;
;; This file exists so the Unordered View block in config.org and the
;; suite in test/unit/tdw-delegated-test.el share ONE definition of
;; those semantics: the view splices in `tdw-delegated-agenda-blocks',
;; and the tests run `tdw-delegated-build-agenda', which renders
;; exactly the blocks that function returns.  Change the blocks and
;; the tests see it; break the semantics and the tests fail.

(require 'org)
(require 'org-agenda)

(defconst tdw-delegated-match "LEVEL>0+ORG_GTD=\"Delegated\"/WAIT"
  "Agenda match for delegations in flight.
Mirrors what the org-gtd view DSL builds for (type . delegated):
the ORG_GTD property value plus the WAIT keyword from
`org-gtd-keyword-mapping'.")

(defconst tdw-delegated-checkin-property "ORG_GTD_TIMESTAMP"
  "Property org-gtd-delegate stores the check-in date in.")

(defun tdw-delegated--checkin-day ()
  "Absolute day number of the entry's check-in date, or nil.
DEADLINE when present, else `tdw-delegated-checkin-property'."
  (if-let ((deadline (org-get-deadline-time (point))))
      (time-to-days deadline)
    (when-let* ((ts (org-entry-get (point) tdw-delegated-checkin-property))
                (time (ignore-errors (org-time-string-to-time ts))))
      (time-to-days time))))

(defun tdw-delegated--skip-unless (bucket)
  "Skip the entry at point unless its check-in day falls in BUCKET.
BUCKET is `past', `today', or `future', relative to (org-today).
Returns nil to keep the entry, or the entry end position to skip,
per `org-agenda-skip-function'.  Entries with no check-in date are
skipped from every bucket (the stuck-delegated review owns those)."
  (let ((day (tdw-delegated--checkin-day))
        (today (org-today)))
    (unless (and day
                 (pcase bucket
                   ('past (< day today))
                   ('today (= day today))
                   ('future (> day today))))
      (org-entry-end-position))))

(defun tdw-delegated-skip-unless-overdue ()
  "Keep only delegations whose check-in date is before today."
  (tdw-delegated--skip-unless 'past))

(defun tdw-delegated-skip-unless-due-today ()
  "Keep only delegations whose check-in date is today."
  (tdw-delegated--skip-unless 'today))

(defun tdw-delegated-skip-unless-due-later ()
  "Keep only delegations whose check-in date is after today."
  (tdw-delegated--skip-unless 'future))

(defconst tdw-delegated--sections
  '(("Delegated (Overdue)" tdw-delegated-skip-unless-overdue)
    ("Delegated (Due Today)" tdw-delegated-skip-unless-due-today)
    ("Delegated (Due After Today)" tdw-delegated-skip-unless-due-later))
  "Header and skip function for each Delegated section, in view order.")

(defun tdw-delegated-agenda-blocks (&optional extra-settings)
  "Three org-gtd native-block entries for the Delegated sections.
Each element is ((native . (tags-todo MATCH SETTINGS))), ready to
splice into an `org-gtd-view-show' blocks list.  EXTRA-SETTINGS is a
list of additional (VARIABLE VALUE-FORM) agenda settings appended to
every block; the view passes display options (prefix format) through
it so the semantics here stay display-agnostic and testable."
  (mapcar (pcase-lambda (`(,header ,skip-fn))
            `((native . (tags-todo
                         ,tdw-delegated-match
                         ((org-agenda-overriding-header ,header)
                          (org-agenda-skip-function ',skip-fn)
                          ,@extra-settings)))))
          tdw-delegated--sections))

(defun tdw-delegated-build-agenda (files)
  "Render the three Delegated blocks over FILES and return the text.
Runs exactly the blocks `tdw-delegated-agenda-blocks' returns, so
tests exercise the very blocks the Unordered View splices in.  For
tests."
  (let ((org-agenda-custom-commands
         `(("d" "Delegated sections"
            ,(mapcar (lambda (entry) (cdr (assq 'native entry)))
                     (tdw-delegated-agenda-blocks)))))
        (org-agenda-files files)
        (org-agenda-sticky nil)
        (org-agenda-buffer-name "*tdw-delegated-test-agenda*"))
    (org-agenda nil "d")
    (with-current-buffer org-agenda-buffer-name
      (prog1 (buffer-string)
        (kill-buffer)))))

(provide 'tdw-delegated)
;;; tdw-delegated.el ends here
