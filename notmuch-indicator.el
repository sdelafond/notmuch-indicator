;;; notmuch-indicator.el --- Add notmuch count to the global-mode-string (mode line) -*- lexical-binding: t -*-

;; Copyright (C) 2022  Free Software Foundation, Inc.

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: THIS-IS-A-SAMPLE Development <~protesilaos/THIS-IS-A-SAMPLE@lists.sr.ht>
;; URL: https://git.sr.ht/~protesilaos/notmuch-indicator
;; Mailing-List: https://lists.sr.ht/~protesilaos/THIS-IS-A-SAMPLE
;; Version: 0.0.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, mail

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Work-in-progress.
;;
;; This is a simple package that renders an indicator with an email count
;; of the `notmuch' index on the Emacs mode line.  The underlying mechanism
;; is that of `notmuch-count(1)', which is used to find the number of items
;; that match the given search terms.
;;
;; The indicator is enabled when `notmuch-indicator-mode' is on.
;;
;; The user option `notmuch-indicator-args' provides the means to define
;; search terms and associate them with a given label.  The label is purely
;; cosmetic, though it helps characterise the resulting counter.
;;
;; The value of `notmuch-indicator-args' is a list of plists (property
;; lists).  Each plist consists of two properties, both of which accept a
;; string value:
;;
;; 1. The `:terms' holds the command-line arguments passed to
;;    `notmuch-count(1)' (read the Notmuch documentation for the
;;    technicalities).
;;
;; 2. The `:label' is an arbitrary string that is prepended to the return
;;    value of the above.
;;
;; Multiple plists represent separate `notmuch-count(1)' queries.  These
;; are run sequentially.  Their return values are joined into a single
;; string.
;;
;; For instance, a value like the following defines three commands:
;;
;;     (setq notmuch-indicator-args
;;           '((:terms "tag:unread and tag:inbox" :label "@")
;;             (:terms "from:authorities and tag:unread" :label "👺")
;;             (:terms "--output threads tag:loveletter" :label "💕")))
;;
;; These form a string like: `@50 👺1000 💕0'.
;;
;; The user option `notmuch-indicator-refresh-count' determines how often
;; the indicator will be refreshed.  It accepts a numeric argument which
;; represents seconds.
;;
;; The user option `notmuch-indicator-force-refresh-commands' accepts as
;; its value a list of symbols.  Those are commands that will forcefully
;; update the indicator after they are invoked.
;;
;; The user option `notmuch-indicator-hide-empty-counters' hides zero
;; counters from the indicator, when it is set to a non-nil value.

;;; Code:

(defgroup notmuch-indicator ()
  "WORK-IN-PROGRESS."
  :group 'notmuch)

;;;; User options

(defcustom notmuch-indicator-args
  '((:terms "tag:unread and tag:inbox" :label "@"))
  "List of plists specifying terms for `notmuch-count(1)'.

Each plist consists of two properties, both of which accept a
string value:

1. The `:terms' holds the command-line arguments passed to
   `notmuch-count(1)' (read the Notmuch documentation for the
   technicalities).

2. The `:label' is an arbitrary string that is prepended to
   the return value of the above.

Multiple plists represent separate `notmuch-count(1)' queries.
These are run sequentially.  Their return values are joined into
a single string.

For instance, a value like the following defines two commands:

    (setq notmuch-indicator-args
          \='((:terms \"tag:unread and tag:inbox\" :label \"@\")
            (:terms \"--output threads from:VIP\" :label \"🤡\")))

These form a string like: @50 🤡10."
  :type 'list ; TODO 2022-09-19: Use correct type
  :group 'notmuch-indicator)

(defcustom notmuch-indicator-hide-empty-counters nil
  "When non-nil, hide output of searches that have zero results."
  :type 'boolean
  :group 'notmuch-indicator)

;; TODO 2022-09-19: If this changes, the `notmuch-indicator-mode' needs
;; to be restarted.  We can add a custom setter here.  Perhaps there is
;; also some elegant way to handle this when the variable is changed
;; with `setq'.
(defcustom notmuch-indicator-refresh-count (* 60 3)
  "How often to update the indicator, in seconds.
It probably is better to not set this to a very low number.

Also see `notmuch-indicator-force-refresh-commands'."
  :type 'number
  :group 'notmuch-indicator)

(defcustom notmuch-indicator-force-refresh-commands
  '(notmuch-refresh-this-buffer)
  "List of commands that update the notmuch-indicator after invoked.
Normally, the indicator runs on a timer, controlled by the user
option `notmuch-indicator-refresh-count'."
  :type '(repeat symbol)
  :group 'notmuch-indicator)

;;;; Helper functions and the minor-mode

(defun notmuch-indicator--format-output (properties)
  "Format PROPERTIES of `notmuch-indicator-args'."
  (let ((count (shell-command-to-string (format "notmuch count %s" (plist-get properties :terms)))))
    (if (and (zerop (string-to-number count)) notmuch-indicator-hide-empty-counters)
        ""
      (format "%s%s" (or (plist-get properties :label)  "") (replace-regexp-in-string "\n" " " count)))))

(defun notmuch-indicator--return-count ()
  "Parse `notmuch-indicator-args' and format them as single string."
  (mapconcat
   (lambda (props)
     (notmuch-indicator--format-output props))
   notmuch-indicator-args
   " "))

(defvar notmuch-indicator--last-state nil
  "Internal variable used to store the indicator's state.")

(defun notmuch-indicator--indicator ()
  "Prepare new mail count mode line indicator."
  (let* ((count (concat (notmuch-indicator--return-count) " "))
         (old-indicator notmuch-indicator--last-state))
    (when old-indicator
      (setq global-mode-string (delete old-indicator global-mode-string)))
    (cond
     (count
      (setq global-mode-string (push count global-mode-string))
      (setq notmuch-indicator--last-state count))
     (t
      (setq notmuch-indicator--last-state nil))))
  (force-mode-line-update t))

(defun notmuch-indicator--running-p ()
  "Return non-nil if `notmuch-indicator--indicator' is running."
  (delq nil
        (mapcar (lambda (timer)
                  (eq (timer--function timer) 'notmuch-indicator--indicator))
                timer-list)))

(defun notmuch-indicator--run ()
  "Run the timer with a delay, starting it if necessary.
The delay is specified by `notmuch-indicator-refresh-count'."
  (unless (notmuch-indicator--running-p)
    (notmuch-indicator--indicator)
    (run-at-time t notmuch-indicator-refresh-count #'notmuch-indicator--indicator)))

(defun notmuch-indicator--refresh ()
  "Refresh the active indicator."
  (when (notmuch-indicator--running-p)
    (cancel-function-timers #'notmuch-indicator--indicator)
    (notmuch-indicator--run)))

;;;###autoload
(define-minor-mode notmuch-indicator-mode
  "Display counter with output from `notmuch-count(1)'.
For the search terms and the label that can accompany them, refer
to the user option `notmuch-indicator-args'.

To control how often the indicator is updated, check the user
option `notmuch-indicator-refresh-count'.."
  :init-value nil
  :global t
  (if notmuch-indicator-mode
      (progn
        (notmuch-indicator--run)
        (dolist (fn notmuch-indicator-force-refresh-commands)
          (advice-add fn :after #'notmuch-indicator--refresh)))
    (cancel-function-timers #'notmuch-indicator--indicator)
    (setq global-mode-string (delete notmuch-indicator--last-state global-mode-string))
    (dolist (fn notmuch-indicator-force-refresh-commands)
      (advice-remove fn #'notmuch-indicator--refresh))
    (force-mode-line-update t)))

(provide 'notmuch-indicator)
;;; notmuch-indicator.el ends here
