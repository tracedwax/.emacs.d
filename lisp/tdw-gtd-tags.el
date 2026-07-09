;;; tdw-gtd-tags.el --- Deterministic tgl_* tag guessing -*- lexical-binding: t; -*-

;; Deterministic replacement for the tag-guessing algorithm in
;; .agent/workflows/_tgl-tag-guessing.md so a weak model just has to call
;; `tdw-gtd-guess-tag' with some free text, instead of reasoning through
;; keyword matching and category defaults by hand. The only real judgment
;; left is deciding what text to pass in (a headline, a meeting title) -
;; the algorithm itself has exactly one correct answer at every step.

;;; Code:

(require 'json)
(require 'cl-lib)

(defvar tdw-gtd-tags-routing-candidates
  '("~/my-venndoor-life/outputs/tags/tgl-repo-routing.json"
    "~/my-bfc-life/outputs/tags/tgl-repo-routing.json")
  "Candidate locations for the tgl tag routing table, tried in order.
Deliberately independent of config.org's `tdw/tgl-routing-file', which is
hardcoded to thecleverone's home dir and only resolves there - this list
tries the authoritative venndoor-life copy first, falling back to
trace's accessible my-bfc-life copy, so tag-guessing works on either
account without touching that existing (in-production, refiling-critical)
variable.")

(defun tdw-gtd-tags--routing-file ()
  "First existing candidate from `tdw-gtd-tags-routing-candidates', or nil."
  (seq-find #'file-readable-p
            (mapcar #'expand-file-name tdw-gtd-tags-routing-candidates)))

(defun tdw-gtd-tags--routing-table ()
  "Return the routing table (alist of tag-string -> entry-alist), freshly
parsed from `tdw-gtd-tags--routing-file', or nil if none exists. Not
cached: called infrequently (interactive capture/tagging), and caching
would risk stale data leaking across the account-dependent candidate
files this tries in order."
  (let ((file (tdw-gtd-tags--routing-file)))
    (when file
      (let ((json-object-type 'alist)
            (json-key-type 'string)
            (json-array-type 'list))
        (json-read-file file)))))

(defconst tdw-gtd-tags--category-keywords
  '(("tgl_non_billable_travel" "flight" "flights" "hotel" "airport" "travel" "commute")
    ("tgl_internal_operations" "invoice" "invoicing" "contract" "tooling" "hr")
    ("tgl_no_project" "health" "family" "personal")
    ("tgl_barefoot_internal_sales" "standup" "daily plan" "gtd" "check-in" "checkin"
     "planning" "team sync" "barefoot internal" "sales" "pipeline"))
  "Category-default (TAG . KEYWORDS) lists, checked in this order, per
.agent/workflows/_tgl-tag-guessing.md's category-defaults step. Only
consulted when no customer keyword match is found, so no ordering
conflict with client-specific matches.")

(defun tdw-gtd-tags--keyword-match (text)
  "Match TEXT (case-insensitively) against the routing table's customer
names. Returns the best tag, or nil if none match. Prefers a tag
containing \"presales\" when more than one customer name matches."
  (let* ((table (tdw-gtd-tags--routing-table))
         (lower (downcase text))
         (matches
          (when table
            (cl-loop for (tag . entry) in table
                     for customer = (cdr (assoc "end_user_customer" entry))
                     when (and customer (stringp customer)
                               (string-match-p (regexp-quote (downcase customer)) lower))
                     collect tag))))
    (cond
     ((null matches) nil)
     ((null (cdr matches)) (car matches))
     (t (or (cl-find-if (lambda (tg) (string-match-p "presales" tg)) matches)
            (car matches))))))

(defun tdw-gtd-tags--category-default (text)
  "First category-default tag whose keyword appears in TEXT, or nil."
  (let ((lower (downcase text)))
    (cl-loop for (tag . keywords) in tdw-gtd-tags--category-keywords
             when (cl-some (lambda (kw) (string-match-p (regexp-quote kw) lower)) keywords)
             return tag)))

(defun tdw-gtd-guess-tag (text &optional user-tag)
  "Guess the single tgl_* tag for TEXT (free-form task/meeting text).
If USER-TAG is given and non-blank, returns it verbatim - the user's own
choice always wins. Otherwise: keyword-matches TEXT against the routing
table's customer names (preferring a \"presales\" tag on ties), then
category-default keywords, then falls back to tgl_barefoot_internal_sales
if nothing matches at all. Never invents a tag outside these sources."
  (if (and user-tag (not (string-empty-p (string-trim user-tag))))
      (string-trim user-tag)
    (or (tdw-gtd-tags--keyword-match text)
        (tdw-gtd-tags--category-default text)
        "tgl_barefoot_internal_sales")))

(provide 'tdw-gtd-tags)
;;; tdw-gtd-tags.el ends here
