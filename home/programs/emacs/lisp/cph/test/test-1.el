;; test-1.el --- Server accepts a problem POST end-to-end (self-contained)
;; Scratch dir comes from CPH_TEST_DIR (see run-tests.sh).

(defvar cph-test-repo
  (expand-file-name ".." (file-name-directory (or load-file-name default-directory))))
(add-to-list 'load-path cph-test-repo)
(require 'cph)

;; The test server binds an ephemeral port (see run-tests.sh): the
;; developer's Emacs may already hold the CPH default port 27121.
(when-let ((port (getenv "CPH_TEST_PORT")))
  (setq cph-port (string-to-number port)))

(defvar cph-test-dir (or (getenv "CPH_TEST_DIR") "/tmp/cph-test"))
(defvar test-failures 0)
(defun assert-t (label cond)
  (if cond (princ (format "PASS: %s\n" label))
    (setq test-failures (1+ test-failures))
    (princ (format "FAIL: %s\n" label))))

(setq cph-default-language "cpp"
      cph-show-judge-after-fetch nil
      default-directory cph-test-dir)

(defun cph-http-request (method body &optional extra-headers)
  "Send an HTTP request to the local server, return the raw response."
  (let* ((buf (generate-new-buffer " *http-resp*"))
         (client (make-network-process :name "cph-test-client"
                                       :host "127.0.0.1" :service cph-port
                                       :noquery t :buffer buf))
         (head (concat method " / HTTP/1.1\r\nHost: 127.0.0.1\r\n"
                       (or extra-headers "")
                       (when body
                         (concat "Content-Type: application/json\r\n"
                                 "Content-Length: "
                                 (number-to-string (string-bytes body)) "\r\n"))
                       "\r\n")))
    (process-send-string client (concat head (or body "")))
    (let ((deadline (+ (float-time) 5)) resp)
      (while (and (< (float-time) deadline)
                  (not (string-match-p "\"empty\""
                                       (setq resp (with-current-buffer buf
                                                    (buffer-string))))))
        (accept-process-output nil 0.2))
      (delete-process client)
      resp)))

;; --- start server, send a problem, verify everything ---
(cph-server-start)
(let* ((body (with-temp-buffer
               (insert-file-contents (expand-file-name "problem.json" cph-test-dir))
               (buffer-string)))
       (resp (cph-http-request "POST" body))
       (src (expand-file-name "4A.cpp" cph-test-dir))
       (prob-file (cph--problem-file src)))
  (assert-t "HTTP response ok" (string-match-p "\"empty\":true" resp))
  (assert-t "solution file created" (file-exists-p src))
  (assert-t "prob file created" (file-exists-p prob-file))
  (assert-t "prob has tests"
            (string-match-p "\"input\":\"6 6 4" (with-temp-buffer
                                                  (insert-file-contents prob-file)
                                                  (buffer-string))))
  (assert-t "judge buffer shows problem"
            (with-current-buffer (cph--make-judge-buffer)
              (string-match-p "A\\. Theatre Square" (buffer-string)))))

;; --- cph-submit poll: GET with header returns drained state ---
(let ((resp (cph-http-request "GET" nil "cph-submit: true\r\n")))
  (assert-t "submit poll returns empty" (string-match-p "\"empty\":true" resp)))

(cph-server-stop)
(princ (format "TOTAL FAILURES: %d\n" test-failures))
(kill-emacs (if (> test-failures 0) 1 0))
