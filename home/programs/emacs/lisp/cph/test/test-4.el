;; test-4.el --- Judge integration: compile once, run all, compare, timeout
;; Scratch dir comes from CPH_TEST_DIR (see run-tests.sh).

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

(setq cph-default-language "cpp" cph-show-judge-after-fetch nil)
(setq default-directory (expand-file-name "judge" cph-test-dir))
(make-directory default-directory t)
(setq cph-timeout 3000)

(defun wait-idle (secs)
  (let ((deadline (+ (float-time) secs)))
    (while (and (< (float-time) deadline)
                (with-current-buffer cph--judge-buffer cph--running))
      (accept-process-output nil 0.2))))

(defun run-all-and-get-results ()
  (with-current-buffer cph--judge-buffer (cph-run-all-in-judge))
  (wait-idle 30)
  (with-current-buffer cph--judge-buffer
    (mapcar #'cdr cph--results)))

(defun write-src (src &rest text)
  "Replace SRC on disk, avoiding supersession checks on visited buffers."
  (when (get-file-buffer src)
    (kill-buffer (get-file-buffer src)))
  (with-temp-file src (insert (apply #'concat text))))

;; --- unit: comparison semantics (CPH parity) ---
(assert-t "exact match" (cph--correct-p "4\n" "4\n"))
(assert-t "trimmed match" (cph--correct-p "4" "  4  \n"))
(assert-t "crlf match" (cph--correct-p "a\r\nb\r\n" "a\nb"))
(assert-t "mismatch" (not (cph--correct-p "4\n" "5\n")))
(assert-t "line count differs" (not (cph--correct-p "1\n2\n" "1\n2\n3\n")))
(assert-t "empty passes" (cph--correct-p "" ""))

;; --- fetch the CF problem ---
(let* ((body (with-temp-buffer
               (insert-file-contents (expand-file-name "problem.json" cph-test-dir))
               (buffer-string)))
       (problem (cph--json-read body)))
  (cph--handle-problem problem))

(let ((src (expand-file-name "4A.cpp" default-directory)))

  ;; 1) wrong solution: everything fails
  (write-src src "int main(){return 0;}\n")
  (let ((res (run-all-and-get-results)))
    (assert-t "2 results" (= (length res) 2))
    (assert-t "wrong solution: both fail"
              (and (not (plist-get (nth 0 res) :pass))
                   (not (plist-get (nth 1 res) :pass))))
    (assert-t "wrong solution: diff present"
              (> (length (plist-get (nth 0 res) :diff)) 0)))

  ;; 2) correct solution: both pass
  (write-src src
             "#include <bits/stdc++.h>\n"
             "using namespace std;\n"
             "int main(){\n"
             "long long n,m,a; cin>>n>>m>>a;\n"
             "cout<<((n+a-1)/a)*((m+a-1)/a)<<endl;\n"
             "}\n")
  (let ((res (run-all-and-get-results)))
    (assert-t "correct solution: both pass"
              (and (plist-get (nth 0 res) :pass)
                   (plist-get (nth 1 res) :pass)))
    (assert-t "timing recorded"
              (and (integerp (plist-get (nth 0 res) :time))
                   (> (plist-get (nth 0 res) :time) 0))))

  ;; 3) timeout: infinite loop gets killed
  (write-src src "int main(){while(1){}}\n")
  (let ((res (run-all-and-get-results)))
    (assert-t "timeout detected"
              (and (plist-get (nth 0 res) :timed-out)
                   (not (plist-get (nth 0 res) :pass)))))

  ;; 4) a compile error is shown, and the next run clears it again
  (write-src src "int main( { syntax error here }\n")
  (let ((res (run-all-and-get-results)))
    (assert-t "compile error: no results" (null res))
    (assert-t "compile error shown"
              (with-current-buffer cph--judge-buffer
                (string-match-p "Compile error" (buffer-string)))))
  (write-src src
             "#include <bits/stdc++.h>\n"
             "using namespace std;\n"
             "int main(){\n"
             "long long n,m,a; cin>>n>>m>>a;\n"
             "cout<<((n+a-1)/a)*((m+a-1)/a)<<endl;\n"
             "}\n")
  (let ((res (run-all-and-get-results)))
    (assert-t "fixed solution passes again"
              (and (= (length res) 2)
                   (plist-get (nth 0 res) :pass)
                   (plist-get (nth 1 res) :pass)))
    (assert-t "stale compile error cleared"
              (not (with-current-buffer cph--judge-buffer
                     (string-match-p "Compile error" (buffer-string)))))))

(princ (format "TOTAL FAILURES: %d\n" test-failures))
(kill-emacs (if (> test-failures 0) 1 0))
