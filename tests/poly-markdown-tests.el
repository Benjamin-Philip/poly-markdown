
(require 'markdown-mode)
(require 'poly-markdown)
(require 'polymode-test)
;; ada mode auto loading breaks without this
(require 'speedbar)


;; fixme: add tests when after change spans wrongly temporally cover other spans

(setq python-indent-offset 4
      python-indent-guess-indent-offset nil)

(defun poly-markdown-tests-set-protected (protect)
  (let ((mode (if protect 'poly-head-tail-mode 'host)))
    (oset pm-host/markdown :protect-syntax protect)
    (oset pm-host/markdown :protect-font-lock protect)
    (oset pm-inner/markdown-inline-code :head-mode mode)
    (oset pm-inner/markdown-inline-code :tail-mode mode)
    (oset pm-inner/markdown-fenced-code :head-mode mode)
    (oset pm-inner/markdown-fenced-code :tail-mode mode)))

(ert-deftest poly-markdown/spans-at-borders ()
  (pm-test-run-on-file poly-markdown-mode "markdown.md"
    (pm-map-over-spans
     (lambda ()
       (let* ((sbeg (nth 1 *span*))
              (send (nth 2 *span*))
              (range1 (pm-innermost-range sbeg))
              (range2 (pm-innermost-range send)))
         (should (eq sbeg (car range1)))
         (should (eq send (cdr range1)))
         (unless (eq send (point-max))
           (should (eq send (car range2)))))))))

(ert-deftest poly-markdown/spans-at-narrowed-borders ()
  (pm-test-run-on-file poly-markdown-mode "markdown.md"
    (pm-map-over-spans
     (lambda ()
       (pm-with-narrowed-to-span *span*
         (let* ((range1 (pm-innermost-range (point-min)))
                (range2 (pm-innermost-range (point-max))))
           (should (eq (car range1) (point-min)))
           (should (eq (cdr range1) (point-max)))
           (should (eq (car range2) (point-min)))
           (should (eq (cdr range2) (point-max)))))))))

(ert-deftest poly-markdown/narrowed-spans ()
  (pm-test-run-on-file poly-markdown-mode "markdown.md"
    (narrow-to-region 60 200)
    (let ((span (pm-innermost-span (point-min))))
      (should (eq (car span) nil))
      (should (= (nth 1 span) 60))
      (should (= (nth 2 span) 200)))
    (widen)
    (narrow-to-region 60 500)
    (let ((span (pm-innermost-span (point-min))))
      (should (= (nth 1 span) 60))
      (should (= (nth 2 span) 223)))))

(ert-deftest poly-markdown/spans-at-point-max ()
  (pm-test-run-on-file poly-markdown-mode "markdown.md"
    (goto-char (point-max))
    (pm-switch-to-buffer)

    (let ((span (pm-innermost-span (point-max))))
      (should (eq (car span) nil))
      (should (eq (nth 2 span) (point-max)))
      (delete-region (nth 1 span) (nth 2 span)))

    (let ((span (pm-innermost-span (point-max))))
      (should (eq (car span) 'tail))
      (should (eq (nth 2 span) (point-max)))
      (delete-region (nth 1 span) (nth 2 span)))

    (let ((span (pm-innermost-span (point-max))))
      (should (eq (car span) 'body))
      (should (eq (nth 2 span) (point-max)))
      (delete-region (nth 1 span) (nth 2 span)))

    (let ((span (pm-innermost-span (point-max))))
      (should (eq (car span) 'head))
      (should (eq (nth 2 span) (point-max)))
      (delete-region (nth 1 span) (nth 2 span)))

    (let ((span (pm-innermost-span (point-max))))
      (should (eq (car span) nil))
      (should (eq (nth 2 span) (point-max)))
      (delete-region (nth 1 span) (nth 2 span)))))

(ert-deftest poly-markdown/headings ()
  (poly-markdown-tests-set-protected nil)
  (pm-test-poly-lock poly-markdown-mode "markdown.md"
    ((insert-1 ("^## Intro" beg))
     (insert " ")
     (pm-test-spans)
     (delete-backward-char 1))
    ((delete-2 "^2. Blockquotes")
     (backward-kill-word 1))
    ((insert-new-line-3 ("^3. Two Inline" end))
     (insert "\n")
     (pm-test-spans)
     (delete-backward-char 1))))

(ert-deftest poly-markdown/headings-protected ()
  (poly-markdown-tests-set-protected t)
  (pm-test-poly-lock poly-markdown-mode "markdown.md"
    ((insert-1 ("^## Intro" beg))
     (insert " ")
     (pm-test-spans)
     (delete-backward-char 1))
    ((delete-2 "^2. Blockquotes")
     (backward-kill-word 1))
    ((insert-new-line-3 ("^3. Two Inline" end))
     (insert "\n")
     (pm-test-spans)
     (delete-backward-char 1))))

(ert-deftest poly-markdown/fenced-code ()
  (poly-markdown-tests-set-protected nil)
  (pm-test-poly-lock poly-markdown-mode "markdown.md"
    ((delete-fortran-print (23))
     (forward-word)
     (delete-backward-char 1))
    ((insert-ada-hello (51))
     (insert "\"hello!\"\n")
     (indent-for-tab-command))
    ((insert-lisp-arg "&rest forms")
     (backward-sexp 2)
     (insert "first-arg "))
    ((python-kill-line (130))
     (kill-line 3))
    ((elisp-kill-sexp ("(while (setq retail" beg))
     (kill-sexp))
    ((elisp-kill-defun ("(defun delete-dups" beg))
     (kill-sexp))))

(ert-deftest poly-markdown/fenced-code-protected ()
  (poly-markdown-tests-set-protected t)
  (pm-test-poly-lock poly-markdown-mode "markdown.md"
    ((delete-fortran-print (23))
     (forward-word)
     (delete-backward-char 1))
    ((insert-ada-hello (51))
     (insert "\"hello!\"\n")
     (indent-for-tab-command))
    ((insert-lisp-arg "&rest forms")
     (backward-sexp 2)
     (insert "first-arg "))
    ((python-kill-line (130))
     (kill-line 3))
    ((elisp-kill-sexp ("(while (setq retail" beg))
     (kill-sexp))
    ((elisp-kill-defun ("(defun delete-dups" beg))
     (kill-sexp))))

(ert-deftest poly-markdown/inline-math ()
  (pm-test-run-on-string 'poly-markdown-mode
    "Some text with $\\text{inner math}$, formulas $E=mc^2$
$E=mc^2$, and more formulas $E=mc^2$;
```pascal
Some none-sense (formula $E=mc^2$)
```"
    (switch-to-buffer (current-buffer))
    (goto-char 17)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 35)
    (pm-switch-to-buffer)
    (should (eq major-mode 'markdown-mode))
    (goto-char 47)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 54)
    (pm-switch-to-buffer)
    (should (eq major-mode 'markdown-mode))
    (goto-char 56)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 84)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 91)
    (pm-switch-to-buffer)
    (should (eq major-mode 'markdown-mode))
    (goto-char 127)
    (pm-switch-to-buffer)
    (should (eq major-mode 'pascal-mode))))

(ert-deftest poly-markdown/displayed-math ()
  (pm-test-run-on-string 'poly-markdown-mode
    "Some text with
$$\\text{displayed math}$$, formulas
$$E=mc^2$$
$$E=mc^2$$, and $343 more $$$ formulas $$$ and $3
 $$ E=mc^2 $$;
```pascal
Some none-sense (formula
$$E=mc^2$$ )
```"
    (switch-to-buffer (current-buffer))
    (goto-char 18)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 42)
    (pm-switch-to-buffer)
    (should (eq major-mode 'markdown-mode))
    (goto-char 55)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 64)
    (pm-switch-to-buffer)
    (should-not (eq major-mode 'latex-mode))
    (goto-char 66)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 84)
    (pm-switch-to-buffer)
    (should (eq major-mode 'markdown-mode))
    (goto-char 102)
    (pm-switch-to-buffer)
    (should (eq major-mode 'markdown-mode))
    (goto-char 118)
    (pm-switch-to-buffer)
    (should (eq major-mode 'latex-mode))
    (goto-char 169)
    (pm-switch-to-buffer)
    (should (eq major-mode 'pascal-mode))))

;; this test is useless actually; #163 shows only when `kill-buffer` is called
;; interactively and is not picked up by this test
(ert-deftest poly/markdown/kill-buffer ()
  (pm-test-run-on-file poly-markdown-mode "markdown.md"
    (let ((base-buff (buffer-base-buffer)))
      (re-search-forward "defmacro")
      (pm-switch-to-buffer)
      (let (kill-buffer-query-functions)
        (kill-buffer))
      (should-not (buffer-live-p base-buff)))))