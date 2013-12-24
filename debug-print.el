; -*- lexical-binding: t -*-

;;; debug-print.el ---

;; Copyright (C) 2013  Ken Okada

;; Author: Ken Okada <keno@senecio>
;; Keywords: lisp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This program provides a nice ``printf debugging'' environment by
;; the way Gauche do. Sometimes printf debugging with `message' bothers you.
;; For example, if you want to observe the variable `foo' in the expression
;;   (let ((foo (something-with-side-effect)
;;         (bar (something-depends-on foo))
;;     ...)
;; you have to use frustrating idiom:
;;   (let ((foo (progn
;;                (let ((tmp (something-with-side-effect)))
;;                  (message "%s" tmp)
;;                  tmp)))
;;         (bar (something-depends-on foo))
;;     ...)
;; (In this case one can use `let*' but it is an example.) This program
;; allows you to write as follows:
;;   (let ((foo ::?= (something-with-side-effect)
;;         (bar (something-depends-oidn foo))
;;     ...)
;; After rewrite, move point to the last of expression as usual, and do
;; `debug-print-eval-last-sexp'. It reads sexp and recursively rewrite it as follows:
;;   ... ::?= expr ...
;;     => ... (debug-print expr) ...
;; Here `debug-print' is a macro, which does the above frustrating idiom.
;; (needs initialization.) For who kwons Gauche note that it is not implemented by
;; reader macro. So one have to use some settings to inform emacs that the expression
;; needs preprocessed.
;;
;; Initialization and configuration: To use the above feature, write as follows
;; in your .emacs.d/init.el (after setting of load-path):
;;   (require 'debug-print)
;;   (debug-print-init)
;;   (define-key global-map (kbd "C-x C-e") 'debug-print-eval-last-sexp)
;; debug-print.el use some variables:
;;   `debug-print-symbol'
;;   `debug-print-buffer-name'
;;   `debug-print-width'
;; (See definitions below.) You have to set these before calling of `debug-print-init'.
;;
;; Example:
;; Code:
;;   (debug-print-init)
;;   (eval-with-debug-print
;;    (defun fact (n)
;;      (if (zerop n)
;;          1
;;          (* n ::?= (fact (- n 1))))))
;;   (fact 5)
;; Result: <buffer *debug-print*>
;;   ::?="fact"::(fact (- n 1))
;;   ::?="fact"::(fact (- n 1))
;;   ::?="fact"::(fact (- n 1))
;;   ::?="fact"::(fact (- n 1))
;;   ::?="fact"::(fact (- n 1))
;;   ::?-    1
;;   ::?-    1
;;   ::?-    2
;;   ::?-    6
;;   ::?-    24
;; For more detail, see debug-print-test.el .

;;; Code:


;; move to keu
(defmacro keu:with-advice (on-or-off func class advice &rest body)
  "[internal] Evaluate BODY with ADVICE enabled/disabled.
Note that there is a bug that it cannot restore the state of ADVICE.
Any ideas?"
  `(progn
     ,(pcase on-or-off
        (`'on `(ad-enable-advice ,func ,class ,advice))
        (`'off `(ad-disable-advice ,func ,class ,advice))
        (_ (error "the first argument must be the symol 'on or 'off")))
     (ad-activate ,func)
     ,@body
     ,(pcase on-or-off
        (`'on `(ad-disable-advice ,func ,class ,advice))
        (`'off `(ad-enable-advice ,func ,class ,advice))
        (_ (error "the first argument must be the symol 'on or 'off")))
     (ad-activate ,func)))
(put 'keu:with-advice 'lisp-indent-function 4)



(require 'cl-lib)



;;; configuration

(defvar debug-print-symbol ::?=)
(defvar debug-print-buffer-name "*debug-print*")
(defvar debug-print-width 30)



;;; core

(defmacro debug-print (expr &optional f-name)
  "[internal] Evaluate EXPR, display and return the result. The results are
displayed in the buffer with buffer name `debug-print-buffer-name'. The
optional argument F-NAME indicate in what function EXPR is."
  `(with-current-buffer debug-print-buffer
     (progn
       (goto-char (point-max))
       (insert (format debug-print-format-for-::?= ,(or f-name "") "" ',expr))
       (let ((value ,expr))
         (progn
           (insert (format debug-print-format-for-::?- value))
           value)))))

(defun debug-print:code-walk (action f-name sexp)
  "[internal] If ACTION is \'replace, replace the symbol `debug-print-symbol'
 (default is ::?=) followed by EXPR in SEXP with (debug-print EXPR). If
ACTION is \'remove, it only removes ::?= in SEXP. If possible it detect
in what function EXPR is, and inform `debug-print'."
  (pcase sexp
    (`()
     '())
    ;; bugs here
    (`(defun ,name ,args . ,rest)
     `(defun ,name ,args ,@(debug-print:code-walk action (symbol-name name) rest)))
    (`(defalias ',name . ,rest)
     `(defalias ',name ,@(debug-print:code-walk action (symbol-name name) rest)))
    (`(,(pred (eq debug-print-symbol)) ,x . ,expr)
     (pcase action
       (`replace
        `((debug-print ,(debug-print:code-walk action f-name x) ,f-name)
          ,@(debug-print:code-walk action f-name expr)))
       (`remove
        `(,x ,@(debug-print:code-walk action f-name expr)))))
    (`(,x . ,expr)
     `(,(debug-print:code-walk action f-name x) ,@(debug-print:code-walk action f-name expr)))
    (x
     x)))

(defmacro eval-with-debug-print (expr)
  "Evaluate EXPR with debug print. See aslo `debug-print:code-walk'"
  (debug-print:code-walk 'replace nil (macroexpand-all expr)))
(defmacro eval-without-debug-print (expr)
  (debug-print:code-walk 'remove nil (macroexpand-all expr)))



;;; interface

(defun debug-print-eval-last-sexp ()
  "Evaluate last sexp with debug print. See aslo `debug-print:code-walk'"
  (interactive)
  (keu:with-advice 'on 'preceding-sexp 'after 'debug-print-hijack-emacs-ad
    (call-interactively 'eval-last-sexp)))

(defadvice preceding-sexp (after debug-print-hijack-emacs-ad)
  "Enclose sexp with `eval-with-debug-print'"
  (setq ad-return-value `(eval-with-debug-print ,ad-return-value)))

(defun debug-print-init ()
  "Initialize some variables for `debug-print'. Note that custamizable variables
have to be set before calling of this funciton."
  (interactive)
  (progn
    (setq debug-print-format-for-::?=
          (concat "::?=\"%s\":%s:%-" (int-to-string debug-print-width) "s\n"))
    (setq debug-print-format-for-::?-
          (concat "::?-    %-" (int-to-string debug-print-width) "s\n"))
    (setq debug-print-buffer (get-buffer-create debug-print-buffer-name))))



(provide 'debug-print)
;;; debug-print.el ends here
