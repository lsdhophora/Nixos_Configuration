;; test-5.el --- Filename rules and .prob round trip
;; The scratch dir comes from CPH_TEST_DIR (see run-tests.sh).

(defvar cph-test-repo
  (expand-file-name ".." (file-name-directory (or load-file-name default-directory))))
(add-to-list 'load-path cph-test-repo)
(require 'cph)

(defvar cph-test-dir (or (getenv "CPH_TEST_DIR") "/tmp/cph-test"))
(defvar test-failures 0)
(defun assert-t (label cond)
  (if cond (princ (format "PASS: %s\n" label))
    (setq test-failures (1+ test-failures))
    (princ (format "FAIL: %s\n" label))))

;; --- unit: short names (Codeforces only) ---
(assert-t "cf contest" (string= (cph--short-name '(("url" . "https://codeforces.com/contest/1234/problem/A"))) "1234A"))
(assert-t "cf gym" (string= (cph--short-name '(("url" . "https://codeforces.com/gym/1001/problem/B2"))) "1001B2"))
(assert-t "cf problemset" (string= (cph--short-name '(("url" . "https://codeforces.com/problemset/problem/4/A"))) "4A"))
(assert-t "generic slug"
          (string= (cph--short-name '(("url" . "https://example.com/x") ("name" . "A. Weird Name!")))
                   "a_weird_name_"))
(assert-t "no name slug" (string= (cph--short-name nil) "problem"))

;; --- unit: language selection ---
(assert-t "default language is cpp" (string= (cph--choose-language) "cpp"))
(let ((cph-default-language "rs"))
  (assert-t "default language override"
            (string= (cph--choose-language) "rs")))
(assert-t "extension lookup cpp" (string= (cph--language-for-src "a.cpp") "cpp"))
(assert-t "extension lookup rs" (string= (cph--language-for-src "a.rs") "rs"))
(assert-t "unknown extension nil" (null (cph--language-for-src "a.txt")))

;; --- unit: debug compile (lldb) ---
(let* ((src (expand-file-name "debug.cpp" cph-test-dir)))
  (with-temp-file src (insert "int main(){return 0;}\n"))
  (pcase (cph--compile src "cpp" t)
    (`(,cmd . ,cleanup)
     (assert-t "debug compile ok" (file-exists-p (car cmd)))
     (funcall cleanup)
     (assert-t "debug binary cleaned" (not (file-exists-p (car cmd)))))
    (_ (assert-t "debug compile ok" nil))))
(assert-t "no debugger for js"
          (null (cph--compile (expand-file-name "a.js" cph-test-dir) "js" t)))

;; --- unit: .prob round trip ---
(let* ((src (expand-file-name "roundtrip/X.cpp" cph-test-dir))
       (problem '(("name" . "X") ("url" . "https://codeforces.com/problemset/problem/1/X")
                  ("tests" . ((("input" . "1") ("output" . "2") ("id" . 7)))))))
  (cph--save-problem src problem)
  (let ((back (with-temp-buffer
                (setq buffer-file-name src)
                (cph--problem-for-buffer))))
    (assert-t "round trip name" (string= (cph--get "name" back) "X"))
    (assert-t "round trip tests" (= (length (cph--get "tests" back)) 1))
    (assert-t "round trip id" (= (cph--get "id" (car (cph--get "tests" back))) 7))))

(princ (format "TOTAL FAILURES: %d\n" test-failures))
(kill-emacs (if (> test-failures 0) 1 0))
