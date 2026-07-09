;;; tdw-gtd-clock.el --- Deterministic GTD clock adjustment -*- lexical-binding: t; -*-

;; Deterministic replacement for the adjust-timer workflow's mechanical
;; steps (duration parsing, latest-clock-out lookup, CLOCK-line
;; consolidation, tag swap) so a weak model just has to call
;; `tdw-gtd-adjust-timer' with a title and a duration, instead of doing
;; timestamp arithmetic and regex line-replacement by hand.

;;; Code:

(defun tdw-gtd-parse-duration (duration-string)
  "Parse DURATION-STRING into a total number of minutes.
Accepts \"H:MM\" (e.g. \"2:15\"), \"Nh\", \"NhMm\", \"N.Nh\", and
\"N minutes\"/\"Nmin\"/\"Nm\" forms (with or without a space before the
unit). Signals `user-error' if DURATION-STRING matches none of these."
  (let ((s (string-trim duration-string)))
    (cond
     ((string-match "\\`\\([0-9]+\\):\\([0-9][0-9]\\)\\'" s)
      (+ (* 60 (string-to-number (match-string 1 s)))
         (string-to-number (match-string 2 s))))
     ((string-match
       "\\`\\(?:\\([0-9]+\\(?:\\.[0-9]+\\)?\\)[ \t]*h\\)?[ \t]*\\(?:\\([0-9]+\\)[ \t]*m\\(?:in\\(?:ute\\)?s?\\)?\\)?\\'"
       s)
      (let ((hours (match-string 1 s))
            (minutes (match-string 2 s)))
        (unless (or hours minutes)
          (user-error "tdw-gtd-parse-duration: unparseable duration %S" duration-string))
        (+ (round (* 60 (if hours (string-to-number hours) 0)))
           (if minutes (string-to-number minutes) 0))))
     (t (user-error "tdw-gtd-parse-duration: unparseable duration %S" duration-string)))))

(provide 'tdw-gtd-clock)
;;; tdw-gtd-clock.el ends here
