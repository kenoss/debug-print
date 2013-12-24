(require 'debug-print)


(debug-print:code-walk 'replace nil '())
(debug-print:code-walk 'replace nil '(a b c d))
(debug-print:code-walk 'replace nil '(func ::?= a))
(debug-print:code-walk 'replace nil '(func ::?= a b))
(debug-print:code-walk 'remove nil '(func ::?= a b))
(debug-print:code-walk 'replace nil
                       (macroexpand-all
                        '(defun fact (n)
                           (if (zerop n)
                               1
                               (* n ::?= (fact (- n 1)))))))
; => (defalias 'fact
;      #'(lambda
;          (n)
;          (if
;              (zerop n)
;              1
;              (* n
;                 (debug-print
;                  (fact
;                   (- n 1))
;                  "fact")))))


(debug-print-init)
(eval-with-debug-print
 (defun fact (n)
   (if (zerop n)
       1
       (* n ::?= (fact (- n 1))))))
(fact 5)















;; (defun eval-last-sexp-with-debug-print ()
;;   (interactive)
;;   (keu:dynamic-flet
;;       ((preceding-sexp (&rest rest)
;;          `(eval-with-debug-print ,(apply 'preceding-sexp rest))))
;;     (eval-last-sexp)))

; oh...
; it fails since preceding-sexp is advized.
; use dynamic-wind and advice.



;; Common Lisp sublis
;; sublis can be treat slicing?
;; my-lexical-let
;; keu:define-parameters
;; (setq my-var%hoge 1)
