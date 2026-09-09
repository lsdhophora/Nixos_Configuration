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
(defun prob (json) "Build a `cph-problem' from a JSON-style alist for these tests."
  (cph--problem-from-json json))
(assert-t "cf contest"
          (string= (cph--short-name (prob '(("url" . "https://codeforces.com/contest/1234/problem/A")))) "1234A"))
(assert-t "cf gym"
          (string= (cph--short-name (prob '(("url" . "https://codeforces.com/gym/1001/problem/B2")))) "1001B2"))
(assert-t "cf problemset"
          (string= (cph--short-name (prob '(("url" . "https://codeforces.com/problemset/problem/4/A")))) "4A"))
(assert-t "generic slug"
          (string= (cph--short-name (prob '(("url" . "https://example.com/x")
                                            ("name" . "A. Weird Name!"))))
                   "a_weird_name_"))
(assert-t "no name slug" (string= (cph--short-name (prob '())) "problem"))

;; --- unit: solution naming (CF<contest>[-D<div>]-<index>/<Title>.<lang>) ---
(assert-t "title stem A."
          (string= (cph--title-stem (prob '(("name" . "A. Vanya and Fence"))))
                   "Vanya and Fence"))
(assert-t "title stem D1"
          (string= (cph--title-stem (prob '(("name" . "D1. Mocha and Diana (Easy Version)"))))
                   "Mocha and Diana (Easy Version)"))
(assert-t "title stem A1"
          (string= (cph--title-stem (prob '(("name" . "A1. Balanced Shuffle (Easy)"))))
                   "Balanced Shuffle (Easy)"))
(assert-t "title stem without index"
          (string= (cph--title-stem (prob '(("name" . "Plain Title"))))
                   "Plain Title"))
(assert-t "div token D2"
          (string= (cph--div-token "Codeforces Round 355 (Div. 2)") "D2"))
(assert-t "div token D1"
          (string= (cph--div-token "Codeforces Round 873 (Div. 1)") "D1"))
(assert-t "div token D3"
          (string= (cph--div-token "Codeforces Round 826 (Div. 3)") "D3"))
(assert-t "div token D1+2"
          (string= (cph--div-token "EPIC Institute of Technology Round Summer 2024 (Div. 1 + Div. 2)")
                   "D1+2"))
(assert-t "div token Beta Only"
          (string= (cph--div-token "Codeforces Beta Round 4 (Div. 2 Only)") "D2"))
(assert-t "div token Rated for"
          (string= (cph--div-token "Educational Codeforces Round 171 (Rated for Div. 2)")
                   "D2"))
(assert-t "div token none"
          (null (cph--div-token "2019-2020 ICPC Southwestern European Regional Programming Contest (SWERC 2019-20)")))
(assert-t "problem id Div2"
          (string= (cph--problem-id "https://codeforces.com/contest/677/problem/A"
                                    "Codeforces Round 355 (Div. 2)")
                   "CF677-D2-A"))
(assert-t "problem id problemset"
          (string= (cph--problem-id "https://codeforces.com/problemset/problem/4/A" "Codeforces")
                   "CF4-A"))
(assert-t "problem id gym"
          (string= (cph--problem-id "https://codeforces.com/gym/102501/problem/A" "SWERC 2019-20")
                   "CF102501-A"))
(assert-t "problem id version index"
          (string= (cph--problem-id "https://codeforces.com/contest/1559/problem/D2"
                                    "Codeforces Round 738 (Div. 2)")
                   "CF1559-D2-D2"))
(assert-t "file stem keeps spaces"
          (string= (cph--file-stem "Vanya and Fence") "Vanya and Fence"))
(assert-t "file stem sanitizes separators"
          (string= (cph--file-stem "A. X / Y\\ Z!")
                   "A. X - Y- Z!"))
(assert-t "file stem trims trailing dots"
          (string= (cph--file-stem "Weird. ") "Weird"))
(let* ((problem (prob '(("name" . "A. Vanya and Fence")
                         ("url" . "https://codeforces.com/contest/677/problem/A")
                         ("group" . "Codeforces Round 355 (Div. 2)"))))
       (path (cph--solution-path problem "cpp")))
  (assert-t "solution path file"
            (string= (file-name-nondirectory path) "Vanya and Fence.cpp"))
  (assert-t "solution path folder"
            (string= (file-name-directory path)
                     (file-name-as-directory
                      (expand-file-name "CF677-D2-A" (cph--solution-dir))))))
(assert-t "fallback path without contest url"
          (string= (file-name-nondirectory
                    (cph--solution-path
                     (prob '(("name" . "X") ("url" . "https://example.com/x")))
                     "cpp"))
                   "x.cpp"))

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
       (problem (prob '(("name" . "X")
                        ("url" . "https://codeforces.com/problemset/problem/1/X")
                        ("tests" . (( ("input" . "1") ("output" . "2")
                                      ("id" . 7))))))))
  (cph--save-problem src problem)
  (let ((back (with-temp-buffer
                (setq buffer-file-name src)
                (cph--problem-for-buffer))))
    (assert-t "round trip name" (string= (cph-problem-name back) "X"))
    (assert-t "round trip tests"
              (= (length (cph-problem-tests back)) 1))
    (assert-t "round trip id"
              (= (cph-test-id (car (cph-problem-tests back))) 7))))

(princ (format "TOTAL FAILURES: %d\n" test-failures))
(kill-emacs (if (> test-failures 0) 1 0))
