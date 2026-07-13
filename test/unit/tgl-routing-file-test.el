;;; tgl-routing-file-test.el --- Pin per-account tgl routing file resolution -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Pins the 2026-07-13 bug: `tdw/tgl-routing-file' hardcoded the
;; thecleverone-only path ~/my-venndoor-life/..., which does not exist on
;; the trace account.  The routing table silently read as nil, so every
;; clarified task fell through to the default org-gtd-directory
;; (my-test-life on trace) instead of its tgl_ tag's context repo.
;;
;; The fix resolves the routing file from per-account candidates; the
;; resolved file must be readable on WHICHEVER account runs this test.
;;
;; Uses e-unit (deftest, assert-true).

;;; Code:

(require 'e-unit)
(e-unit-initialize)

(deftest tgl-routing/resolved-file-is-readable-on-this-account ()
  "The resolved routing file exists and is readable on the current account."
  (assert-true (and (tdw/tgl-routing-resolved-file)
                    (file-readable-p (expand-file-name (tdw/tgl-routing-resolved-file))))))

(deftest tgl-routing/known-tag-resolves-to-context-repo-gtd-dir ()
  "tgl_gps_tam_and_ra routes to context-for-gps's gtd dir, localized to this account."
  (let ((dir (tdw/tgl-routing-gtd-dir "tgl_gps_tam_and_ra")))
    (assert-true (and dir (string-suffix-p "context-for-gps/orgnotes/gtd" dir)))))

(provide 'tgl-routing-file-test)
;;; tgl-routing-file-test.el ends here
