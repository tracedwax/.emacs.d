;;; tdw-gtd-tags-test.el --- Tests for deterministic tgl_* tag guessing -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; `tdw-gtd-guess-tag' is the deterministic core of the guess-calendar-tags
;; skill (and every other workflow that needs a tgl_* tag): user-tag wins
;; verbatim -> keyword match against customer names in the routing table ->
;; presales tiebreak -> category defaults -> fallback. Matches the algorithm
;; in .agent/workflows/_tgl-tag-guessing.md exactly.
;;
;; Tests use a small fixture routing table (not the real ~64-entry
;; tgl-repo-routing.json), injected via `tdw-gtd-tags-routing-candidates',
;; so the suite doesn't drift with real tag data.

;;; Code:

(require 'e-unit)
(e-unit-initialize)
(require 'tdw-gtd-tags)

(defun tdw-gtd-tags-test--date (day month year)
  "Return a time value for YEAR-MONTH-DAY at midnight, local time."
  (encode-time 0 0 0 day month year))

(defconst tdw-gtd-tags-test--fixture-json "\
{
  \"tgl_barefoot_internal_sales\": {\"end_user_customer\": null},
  \"tgl_no_project\": {\"end_user_customer\": null},
  \"tgl_acme_widgets\": {\"end_user_customer\": \"Acme Widgets\"},
  \"tgl_presales_acme_widgets\": {\"end_user_customer\": \"Acme Widgets\"},
  \"tgl_globex_corp\": {\"end_user_customer\": \"Globex Corp\"}
}
")

(defmacro tdw-gtd-tags-test--with-fixture-table (&rest body)
  "Run BODY with `tdw-gtd-tags-routing-candidates' pointed at a temp fixture."
  (declare (indent 0))
  `(let* ((file (make-temp-file "tdw-gtd-tags-test" nil ".json")))
     (unwind-protect
         (progn
           (with-temp-file file (insert tdw-gtd-tags-test--fixture-json))
           (let ((tdw-gtd-tags-routing-candidates (list file)))
             ,@body))
       (delete-file file))))

(deftest gtd-tags/user-tag-wins-verbatim ()
  "User-provided tag is used as-is, even if not in the routing table at all."
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_totally_explicit"
                  (tdw-gtd-guess-tag "anything at all" "tgl_totally_explicit"))))

(deftest gtd-tags/empty-user-tag-falls-through-to-guessing ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_globex_corp"
                  (tdw-gtd-guess-tag "Call with Globex Corp about renewal" ""))))

(deftest gtd-tags/keyword-match-single-customer ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_globex_corp"
                  (tdw-gtd-guess-tag "Call with Globex Corp about renewal"))))

(deftest gtd-tags/keyword-match-is-case-insensitive ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_globex_corp"
                  (tdw-gtd-guess-tag "call with GLOBEX CORP about renewal"))))

(deftest gtd-tags/presales-tiebreak-on-multiple-matches ()
  "Acme Widgets matches two tags; the one with \"presales\" wins."
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_presales_acme_widgets"
                  (tdw-gtd-guess-tag "Acme Widgets kickoff meeting"))))

(deftest gtd-tags/category-default-travel ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_non_billable_travel"
                  (tdw-gtd-guess-tag "Book flight to Denver"))))

(deftest gtd-tags/category-default-ops ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_internal_operations"
                  (tdw-gtd-guess-tag "Renew software license contract"))))

(deftest gtd-tags/category-default-personal ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_no_project"
                  (tdw-gtd-guess-tag "Family health checkup"))))

(deftest gtd-tags/category-default-internal-sales ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_barefoot_internal_sales"
                  (tdw-gtd-guess-tag "Daily standup"))))

(deftest gtd-tags/category-default-reached-via-keyword-not-tag-name ()
  "\"sales\" reaches tgl_barefoot_internal_sales via the category-default
keyword list, not a spurious keyword-match against the tag's own name
(that tag's end_user_customer is null - it cannot keyword-match)."
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_barefoot_internal_sales"
                  (tdw-gtd-guess-tag "Talk about internal sales strategy"))))

(deftest gtd-tags/final-fallback-when-nothing-matches ()
  (tdw-gtd-tags-test--with-fixture-table
    (assert-equal "tgl_barefoot_internal_sales"
                  (tdw-gtd-guess-tag "Completely unrelated random text"))))

;;;; tdw-gtd-guess-calendar-tags (batch wrapper: scans + tags a whole day)

(defmacro tdw-gtd-tags-test--with-calendar-fixture (var content &rest body)
  "Bind VAR to a temp gcal.org path containing CONTENT, with
`org-gtd-directory' let-bound to its parent, run BODY, then clean up."
  (declare (indent 2))
  `(let* ((dir (make-temp-file "tdw-gtd-tags-test" t))
          (org-gtd-directory dir)
          (,var (expand-file-name "gcal.org" dir)))
     (unwind-protect
         (progn
           (with-temp-file ,var (insert ,content))
           ,@body)
       (let ((buf (find-buffer-visiting ,var)))
         (when buf (kill-buffer buf)))
       (delete-directory dir t))))

(defun tdw-gtd-tags-test--file-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

;; Fixture format confirmed against a real (redacted) gcal.org via
;; thecleverone (OACP msg-...-9134): top-level "*" heading (NOT "**"),
;; 2-space-indented :PROPERTIES: drawer with :CATEGORY:/:ORG_GTD:/:UID:/
;; :Effort: fields (gcal-to-org.py's real output), two-bracket timestamp
;; range "<date time>--<time>", not the single-bracket "<date t-t>" this
;; suite originally guessed at.

(deftest gtd-tags/guess-calendar-tags-tags-an-untagged-meeting ()
  (tdw-gtd-tags-test--with-fixture-table
    (tdw-gtd-tags-test--with-calendar-fixture gcal-file
        "\
#+TITLE: Google Calendar
#+FILETAGS: :gcal:

* Call with Globex Corp about renewal
  :PROPERTIES:
  :CATEGORY: GCal
  :ORG_GTD: Calendar
  :UID: abc123@google.com
  :Effort:   0:30
  :END:
  <2026-07-09 Thu 09:00>--<09:30>
"
      (tdw-gtd-guess-calendar-tags (tdw-gtd-tags-test--date 9 7 2026))
      (assert-true (string-match-p ":tgl_globex_corp:"
                                    (tdw-gtd-tags-test--file-contents gcal-file))))))

(deftest gtd-tags/guess-calendar-tags-skips-already-tagged-meeting ()
  (tdw-gtd-tags-test--with-fixture-table
    (tdw-gtd-tags-test--with-calendar-fixture gcal-file
        "\
* Call with Globex Corp about renewal  :tgl_barefoot_internal_sales:
  :PROPERTIES:
  :CATEGORY: GCal
  :ORG_GTD: Calendar
  :UID: abc123@google.com
  :Effort:   0:30
  :END:
  <2026-07-09 Thu 09:00>--<09:30>
"
      (tdw-gtd-guess-calendar-tags (tdw-gtd-tags-test--date 9 7 2026))
      (let ((contents (tdw-gtd-tags-test--file-contents gcal-file)))
        ;; still the ORIGINAL tag, not overwritten by a guessed one
        (assert-true (string-match-p ":tgl_barefoot_internal_sales:" contents))
        (assert-nil (string-match-p ":tgl_globex_corp:" contents))))))

(deftest gtd-tags/guess-calendar-tags-only-affects-the-target-date ()
  (tdw-gtd-tags-test--with-fixture-table
    (tdw-gtd-tags-test--with-calendar-fixture gcal-file
        "\
* Call with Globex Corp about renewal
  :PROPERTIES:
  :CATEGORY: GCal
  :ORG_GTD: Calendar
  :UID: abc123@google.com
  :Effort:   0:30
  :END:
  <2026-07-08 Wed 09:00>--<09:30>
"
      (tdw-gtd-guess-calendar-tags (tdw-gtd-tags-test--date 9 7 2026))
      (assert-nil (string-match-p ":tgl_globex_corp:"
                                   (tdw-gtd-tags-test--file-contents gcal-file))))))

(deftest gtd-tags/guess-calendar-tags-returns-a-title-tag-report ()
  (tdw-gtd-tags-test--with-fixture-table
    (tdw-gtd-tags-test--with-calendar-fixture gcal-file
        "\
* Call with Globex Corp about renewal
  :PROPERTIES:
  :CATEGORY: GCal
  :ORG_GTD: Calendar
  :UID: abc123@google.com
  :Effort:   0:30
  :END:
  <2026-07-09 Thu 09:00>--<09:30>
* Daily standup
  :PROPERTIES:
  :CATEGORY: GCal
  :ORG_GTD: Calendar
  :UID: def456@google.com
  :Effort:   0:15
  :END:
  <2026-07-09 Thu 09:30>--<09:45>
"
      (let ((report (tdw-gtd-guess-calendar-tags (tdw-gtd-tags-test--date 9 7 2026))))
        (assert-equal 2 (length report))
        (assert-equal "tgl_globex_corp" (cdr (assoc "Call with Globex Corp about renewal" report)))
        (assert-equal "tgl_barefoot_internal_sales" (cdr (assoc "Daily standup" report)))))))

(deftest gtd-tags/guess-calendar-tags-returns-empty-when-nothing-untagged ()
  (tdw-gtd-tags-test--with-fixture-table
    (tdw-gtd-tags-test--with-calendar-fixture gcal-file "#+TITLE: Google Calendar\n"
      (assert-nil (tdw-gtd-guess-calendar-tags (tdw-gtd-tags-test--date 9 7 2026))))))

(deftest gtd-tags/guess-calendar-tags-handles-all-day-single-bracket-timestamp ()
  "All-day entries (gcal-to-org.py) format as a single bracket, no range."
  (tdw-gtd-tags-test--with-fixture-table
    (tdw-gtd-tags-test--with-calendar-fixture gcal-file
        "\
* Company holiday
  :PROPERTIES:
  :CATEGORY: GCal
  :ORG_GTD: Calendar
  :UID: ghi789@google.com
  :END:
  <2026-07-09 Thu>
"
      (tdw-gtd-guess-calendar-tags (tdw-gtd-tags-test--date 9 7 2026))
      (assert-true (string-match-p ":tgl_barefoot_internal_sales:"
                                    (tdw-gtd-tags-test--file-contents gcal-file))))))

;;;; Wiring guard: config.org must actually load this module.

(defun tdw-gtd-tags-test--config ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "~/.emacs.d/config.org"))
    (buffer-string)))

(deftest gtd-tags/config-requires-the-module ()
  "config.org must require tdw-gtd-tags, or the live daemon never gets it."
  (assert-true (string-match-p "(require 'tdw-gtd-tags)"
                                (tdw-gtd-tags-test--config))))

(provide 'tdw-gtd-tags-test)
;;; tdw-gtd-tags-test.el ends here
