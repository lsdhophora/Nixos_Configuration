;; test-5.el --- Submit-state protocol + filename rules + .prob round trip
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

;; --- unit: short names (CPH parity) ---
(assert-t "cf contest" (string= (cph--short-name '(("url" . "https://codeforces.com/contest/1234/problem/A"))) "1234A"))
(assert-t "cf gym" (string= (cph--short-name '(("url" . "https://codeforces.com/gym/1001/problem/B2"))) "1001B2"))
(assert-t "cf problemset" (string= (cph--short-name '(("url" . "https://codeforces.com/problemset/problem/4/A"))) "4A"))
(assert-t "atcoder" (string= (cph--short-name '(("url" . "https://atcoder.jp/contests/abc123/tasks/abc123_a"))) "abc123a"))
(assert-t "luogu" (string= (cph--short-name '(("url" . "https://www.luogu.com.cn/problem/P1001"))) "P1001"))
(assert-t "libreoj" (string= (cph--short-name '(("url" . "https://loj.ac/p/1000"))) "1000"))
(assert-t "libreoj legacy" (string= (cph--short-name '(("url" . "https://loj.ac/problem/1"))) "1"))
(assert-t "generic slug"
          (string= (cph--short-name '(("url" . "https://example.com/x") ("name" . "A. Weird Name!")))
                   "a_weird_name_"))

;; --- unit: title naming (cph-naming-style 'title) ---
(assert-t "atcoder title" (string= (cph--title-name '(("name" . "ABC087B - Coins"))) "Coins"))
(assert-t "cf title" (string= (cph--title-name '(("name" . "A. Theatre Square"))) "Theatre_Square"))
(assert-t "luogu title" (string= (cph--title-name '(("name" . "P1001 A+B Problem"))) "P1001_A_B_Problem"))
(assert-t "no prefix title" (string= (cph--title-name '(("name" . "Plain Title"))) "Plain_Title"))
(let ((cph-naming-style 'title))
  (assert-t "title style file name"
            (string= (cph--problem-file-name '(("url" . "https://atcoder.jp/contests/abs/tasks/abc087_b")
                                               ("name" . "ABC087B - Coins"))
                                              "cpp")
                     "Coins.cpp"))
  (assert-t "title style keeps case"
            (string= (cph--problem-file-name '(("name" . "Placing Marbles")) "cpp")
                     "Placing_Marbles.cpp")))

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

;; --- integration: cph-submit protocol ---
(setq cph--submit-state (list :empty t))
(let ((resp-buf (generate-new-buffer " *resp*")))
  (cph-server-start)
  (accept-process-output nil 0.3)

  ;; 1) idle: GET with cph-submit header -> {"empty":true}
  (let ((c1 (make-network-process :name "cph-test-client"
                                  :host "127.0.0.1" :service cph-port
                                  :noquery t :buffer resp-buf)))
    (process-send-string
     c1 "GET / HTTP/1.1\r\nHost: x\r\ncph-submit: true\r\nConnection: close\r\n\r\n")
    (let ((deadline (+ (float-time) 3)))
      (while (and (< (float-time) deadline)
                  (not (string-match-p "\"empty\":true"
                                       (with-current-buffer resp-buf (buffer-string)))))
        (accept-process-output nil 0.2)))
    (assert-t "idle response has empty:true"
              (string-match-p "\"empty\":true"
                              (with-current-buffer resp-buf (buffer-string))))
    (delete-process c1))

  ;; 2) store a submit state, poll again
  (setq cph--submit-state
        (list :empty nil :url "https://codeforces.com/problemset/problem/1/X"
              :problemName "1X" :sourceCode "int main(){}" :languageId 54))
  (let ((c2 (make-network-process :name "cph-test-client2"
                                  :host "127.0.0.1" :service cph-port
                                  :noquery t :buffer resp-buf)))
    (process-send-string
     c2 "GET / HTTP/1.1\r\nHost: x\r\ncph-submit: true\r\nConnection: close\r\n\r\n")
    (let ((deadline (+ (float-time) 3)))
      (while (and (< (float-time) deadline)
                  (not (string-match-p "int main"
                                       (with-current-buffer resp-buf (buffer-string)))))
        (accept-process-output nil 0.2)))
    (let ((resp (with-current-buffer resp-buf (buffer-string))))
      (assert-t "submit response has sourceCode" (string-match-p "int main" resp))
      (assert-t "submit response has languageId 54"
                (string-match-p "\"languageId\":54" resp))
      (assert-t "submit response has empty:false"
                (string-match-p "\"empty\":false" resp)))
    (delete-process c2))

  ;; 3) state must have been drained by the poll
  (assert-t "state drained after poll" (plist-get cph--submit-state :empty))
  (cph-server-stop))

(princ (format "TOTAL FAILURES: %d\n" test-failures))
(kill-emacs (if (> test-failures 0) 1 0))
