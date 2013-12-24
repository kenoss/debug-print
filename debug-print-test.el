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
