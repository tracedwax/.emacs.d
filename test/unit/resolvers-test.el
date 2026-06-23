;;; resolvers-test.el --- Characterization tests for agenda prefix resolvers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Characterization tests that LOCK the current behavior of the org-gtd-agenda
;; prefix resolvers in config.org, so the POODR refactor cannot change their
;; results.  Values were captured from the live (already tangled) functions in
;; config.el, not guessed.
;;
;; Covered:
;;   - org-gtd-agenda--resolve-effort         (subtree effort -> "H:MM" string)
;;   - org-gtd-agenda--resolve-prefix-element (symbol/string -> resolved value)
;;   - org-gtd-agenda--resolve-prefix-chain   ((elements width) -> padded/truncated)
;;
;; NOT covered here: org-gtd-agenda--resolve-tier is already characterized in
;; on-deck-test.el and is deliberately left to that file.
;;
;; resolve-prefix-chain calls truncate-string-to-width with the upstream
;; variable `org-gtd-agenda-truncate-ellipsis'.  That defcustom lives in the
;; org-gtd package, which the test bootstrap does not load, so the variable is
;; unbound in the test image.  We pin it to its upstream default ("…",
;; U+2026) so the function behaves as it does in the live config.
;;
;; Uses e-unit (deftest, assert-equal, assert-true, assert-nil).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

;; Pin the upstream truncate ellipsis to its package default so the chain
;; resolver does not hit a void-variable error in the test image.
(defvar org-gtd-agenda-truncate-ellipsis "…")
(setq org-gtd-agenda-truncate-ellipsis "…")

;;;; ——— org-gtd-agenda--resolve-effort ———

(deftest resolvers/effort-no-effort-returns-zero-string ()
  "resolve-effort returns \"0:00\" when the entry and subtree have no EFFORT."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    (assert-equal "0:00" (org-gtd-agenda--resolve-effort))))

(deftest resolvers/effort-single-entry-formats-h-mm ()
  "resolve-effort formats a single entry's EFFORT as H:MM."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n:PROPERTIES:\n:EFFORT: 1:30\n:END:\n")
    (goto-char (point-min))
    (assert-equal "1:30" (org-gtd-agenda--resolve-effort))))

(deftest resolvers/effort-single-entry-zero-pads-minutes ()
  "resolve-effort zero-pads the minutes field (0:15)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n:PROPERTIES:\n:EFFORT: 0:15\n:END:\n")
    (goto-char (point-min))
    (assert-equal "0:15" (org-gtd-agenda--resolve-effort))))

(deftest resolvers/effort-sums-parent-and-children ()
  "resolve-effort sums EFFORT across the parent and its children (0:30+0:45+1:00=2:15)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent\n:PROPERTIES:\n:EFFORT: 0:30\n:END:\n")
    (insert "** TODO Child1\n:PROPERTIES:\n:EFFORT: 0:45\n:END:\n")
    (insert "** TODO Child2\n:PROPERTIES:\n:EFFORT: 1:00\n:END:\n")
    (goto-char (point-min))
    (assert-equal "2:15" (org-gtd-agenda--resolve-effort))))

(deftest resolvers/effort-excludes-done-children ()
  "resolve-effort excludes DONE children from the subtree total (parent 0:30 only)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Parent\n:PROPERTIES:\n:EFFORT: 0:30\n:END:\n")
    (insert "** DONE Child1\n:PROPERTIES:\n:EFFORT: 0:45\n:END:\n")
    (goto-char (point-min))
    (assert-equal "0:30" (org-gtd-agenda--resolve-effort))))

;;;; ——— org-gtd-agenda--resolve-prefix-element ———

(deftest resolvers/element-effort-delegates-to-resolve-effort ()
  "The 'effort element resolves via resolve-effort (EFFORT 0:45 -> \"0:45\")."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n:PROPERTIES:\n:EFFORT: 0:45\n:END:\n")
    (goto-char (point-min))
    (assert-equal "0:45" (org-gtd-agenda--resolve-prefix-element 'effort))))

(deftest resolvers/element-tier-returns-p0-siren ()
  "The 'tier element returns the tier emoji string (🚨 for :p0:)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo  :p0:\n")
    (goto-char (point-min))
    (assert-equal "🚨" (org-gtd-agenda--resolve-prefix-element 'tier))))

(deftest resolvers/element-score-aliases-to-tier ()
  "The 'score element is an alias for tier (🥎 for :on_deck:)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo  :on_deck:\n")
    (goto-char (point-min))
    (assert-equal "🥎" (org-gtd-agenda--resolve-prefix-element 'score))))

(deftest resolvers/element-urg-imp-aliases-to-tier ()
  "The 'urg-imp element is an alias for tier (🔔 for :bells_ringing:)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo  :bells_ringing:\n")
    (goto-char (point-min))
    (assert-equal "🔔" (org-gtd-agenda--resolve-prefix-element 'urg-imp))))

(deftest resolvers/element-tier-empty-when-no-tier-tags ()
  "The 'tier element returns \"\" when the entry has no tier tags."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    (assert-equal "" (org-gtd-agenda--resolve-prefix-element 'tier))))

(deftest resolvers/element-p0-siren-when-tagged ()
  "The 'p0 element returns 🚨 when the entry is tagged :p0:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo  :p0:\n")
    (goto-char (point-min))
    (assert-equal "🚨" (org-gtd-agenda--resolve-prefix-element 'p0))))

(deftest resolvers/element-p0-empty-when-untagged ()
  "The 'p0 element returns \"\" when the entry is not tagged :p0:."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    (assert-equal "" (org-gtd-agenda--resolve-prefix-element 'p0))))

(deftest resolvers/element-string-returned-as-is ()
  "A string element is returned verbatim (literal separator)."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    (assert-equal " — " (org-gtd-agenda--resolve-prefix-element " — "))))

(deftest resolvers/element-unknown-symbol-returns-nil ()
  "An unrecognized symbol element resolves to nil."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    (assert-nil (org-gtd-agenda--resolve-prefix-element 'bogus))))

;;;; ——— org-gtd-agenda--resolve-prefix-chain ———

(deftest resolvers/chain-concatenates-literals-and-pads-to-width ()
  "resolve-chain concatenates literal elements and right-pads with spaces to WIDTH."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    ;; "ab"+"cd" = "abcd" (4), padded with 14 spaces to width 18.
    (assert-equal (concat "abcd" (make-string 14 ?\s))
                  (org-gtd-agenda--resolve-prefix-chain '("ab" "cd") 18))))

(deftest resolvers/chain-mixes-effort-separator-and-tier ()
  "resolve-chain mixes a resolved effort, a literal separator, and a tier emoji."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo  :p0:\n:PROPERTIES:\n:EFFORT: 1:00\n:END:\n")
    (goto-char (point-min))
    ;; "1:00" + " " + "🚨" = "1:00 🚨"; the emoji is 2 display columns wide, so
    ;; the result is padded to display width 25 with 18 trailing spaces.
    (assert-equal (concat "1:00 🚨" (make-string 18 ?\s))
                  (org-gtd-agenda--resolve-prefix-chain '(effort " " tier) 25))))

(deftest resolvers/chain-all-empty-is-pure-padding ()
  "resolve-chain of a single empty-resolving element is WIDTH spaces."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    ;; tier resolves to "" (no tier tags), padded to width 10.
    (assert-equal (make-string 10 ?\s)
                  (org-gtd-agenda--resolve-prefix-chain '(tier) 10))))

(deftest resolvers/chain-truncates-and-appends-ellipsis ()
  "resolve-chain truncates over-wide content to WIDTH, appending the ellipsis."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    ;; "abcdefghij" truncated to width 5 -> "abcd" + "…".
    (assert-equal "abcd…"
                  (org-gtd-agenda--resolve-prefix-chain '("abcdefghij") 5))))

(deftest resolvers/chain-treats-unknown-element-as-empty ()
  "resolve-chain treats an unknown (nil-resolving) element as the empty string."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Foo\n")
    (goto-char (point-min))
    ;; 'bogus -> nil -> "", then "x" = "x", padded with 7 spaces to width 8.
    (assert-equal (concat "x" (make-string 7 ?\s))
                  (org-gtd-agenda--resolve-prefix-chain '(bogus "x") 8))))

;;; resolvers-test.el ends here
