;;; render-scrubbers-test.el --- Characterization tests for agenda render scrubbers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Pure/buffer-level characterization tests that LOCK the current behavior of the
;; agenda render "scrubber" helpers in config.org, so the upcoming POODR refactor
;; cannot regress them:
;;
;;   - tdw/clean-heading       (string -> string)
;;   - tdw/strip-tag-separators (operates on the current buffer, returns nil)
;;   - tdw/format-view-banner  (label/icon/effort -> banner string)
;;
;; All asserted values were CAPTURED from the live functions via
;; test-bootstrap.el, not guessed. Banner strings are compared with
;; `substring-no-properties' since the live function propertizes its output.
;; Anything needing a live agenda buffer is skipped.
;;
;; Uses e-unit (deftest, assert-equal, assert-true, assert-nil).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;;;; ——— tdw/clean-heading (string arg) ———

(deftest scrubbers/clean-heading-strips-keyword-and-trailing-tags ()
  "A TODO keyword and trailing tags are removed; inner text is trimmed."
  (assert-equal "Buy milk"
                (tdw/clean-heading "TODO Buy milk  :errand:home:")))

(deftest scrubbers/clean-heading-strips-keyword-priority-and-tags ()
  "A NEXT keyword, a priority cookie, and trailing tags are all removed."
  (assert-equal "Fix the bug"
                (tdw/clean-heading "NEXT [#A] Fix the bug  :work:")))

(deftest scrubbers/clean-heading-strips-done-priority-and-tags ()
  "DONE keyword, [#B] priority, and trailing tags are removed."
  (assert-equal "Ship release"
                (tdw/clean-heading "DONE [#B] Ship release  :proj:done:")))

(deftest scrubbers/clean-heading-strips-wait-keyword-only ()
  "A WAIT keyword with no priority or tags is removed."
  (assert-equal "Respond to email"
                (tdw/clean-heading "WAIT Respond to email")))

(deftest scrubbers/clean-heading-leaves-plain-heading-untouched ()
  "A heading with no keyword, priority, or tags is returned unchanged."
  (assert-equal "Just a heading"
                (tdw/clean-heading "Just a heading")))

(deftest scrubbers/clean-heading-empty-string-stays-empty ()
  "The empty string round-trips to the empty string."
  (assert-equal "" (tdw/clean-heading "")))

;;;; ——— tdw/strip-tag-separators (operates on current buffer) ———

(deftest scrubbers/strip-tag-separators-removes-space-double-colon ()
  "A lingering ' ::' separator (space + double colon) is removed from each line."
  (with-temp-buffer
    (insert "  Buy milk ::\n  Other line ::\n")
    (tdw/strip-tag-separators)
    (assert-equal "  Buy milk\n  Other line\n" (buffer-string))))

(deftest scrubbers/strip-tag-separators-leaves-lines-without-separator ()
  "Lines that lack a ' ::' separator are left unchanged."
  (with-temp-buffer
    (insert "  Buy milk\n  Other line\n")
    (tdw/strip-tag-separators)
    (assert-equal "  Buy milk\n  Other line\n" (buffer-string))))

(deftest scrubbers/strip-tag-separators-requires-leading-space ()
  "Only ' ::' is stripped; a bare '::' with no leading space stays put."
  (with-temp-buffer
    (insert "a ::\nb::\n")
    (tdw/strip-tag-separators)
    (assert-equal "a\nb::\n" (buffer-string))))

(deftest scrubbers/strip-tag-separators-returns-nil ()
  "The function is called for buffer side effects and returns nil."
  (with-temp-buffer
    (insert "x ::\n")
    (assert-nil (tdw/strip-tag-separators))))

;;;; ——— tdw/format-view-banner (label icon effort &optional show-effort) ———

(deftest scrubbers/format-view-banner-contains-upcased-label ()
  "The banner contains the UPCASED label followed by ' VIEW'."
  (let ((banner (substring-no-properties
                 (tdw/format-view-banner "Inbox" "📥" "2:15"))))
    (assert-true (string-match-p "INBOX VIEW" banner))))

(deftest scrubbers/format-view-banner-contains-icon ()
  "The banner contains the icon argument verbatim."
  (let ((banner (substring-no-properties
                 (tdw/format-view-banner "Inbox" "📥" "2:15"))))
    (assert-true (string-match-p "📥" banner))))

(deftest scrubbers/format-view-banner-default-omits-effort-line ()
  "Without SHOW-EFFORT the banner is a single rule line: no effort total line."
  (let ((banner (substring-no-properties
                 (tdw/format-view-banner "Inbox" "📥" "2:15"))))
    (assert-nil (string-match-p "Total Estimated Effort" banner))))

(deftest scrubbers/format-view-banner-show-effort-adds-total-line ()
  "With SHOW-EFFORT the banner includes a 'Total Estimated Effort: <effort>' line."
  (let ((banner (substring-no-properties
                 (tdw/format-view-banner "Inbox" "📥" "2:15" t))))
    (assert-true (string-match-p "Total Estimated Effort: 2:15" banner))))

(deftest scrubbers/format-view-banner-upcases-lowercase-label ()
  "A lowercase/mixed-case label like 'Unordered' is upcased in the banner."
  (let ((banner (substring-no-properties
                 (tdw/format-view-banner "Unordered" "📋" "0:00"))))
    (assert-true (string-match-p "UNORDERED VIEW" banner))))

(deftest scrubbers/format-view-banner-uses-rule-characters ()
  "The banner is flanked by '═' rule characters."
  (let ((banner (substring-no-properties
                 (tdw/format-view-banner "Inbox" "📥" "2:15"))))
    (assert-true (string-match-p "═" banner))))

;;; render-scrubbers-test.el ends here
