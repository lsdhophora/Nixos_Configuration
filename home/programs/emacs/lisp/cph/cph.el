;;; cph.el --- Competitive programming helper for Emacs (Codeforces) -*- lexical-binding: t; -*-

;; Copyright (C) 2026 FeiHsueh

;; Author: FeiHsueh
;; Keywords: tools, languages
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; A minimal clone of the "Competitive Programming Helper" (CPH)
;; VSCode extension for Emacs, for Codeforces only.
;;
;; The companion userscript `cph.user.js` (same directory) parses a
;; Codeforces problem page and POSTs the problem JSON to this server.
;; The server listens on 127.0.0.1:27121, the same port and the same
;; problem schema (competitive-companion) as the VSCode CPH plugin.
;;
;; This file does two things only:
;;
;;   1. Download: write the solution file, save the sample tests as
;;      .prob metadata, open the file and the judge buffer.
;;   2. Run: compile the solution once, run each sample, compare with
;;      CPH semantics, show PASS/FAIL and a line diff.
;;   3. Debug: start lldb on the testcase at point (requires lldb).
;;
;; There is no submit flow and no ONLINE_JUDGE handling.
;;
;; Usage:
;;
;;   M-x cph-server-start    start the problem-fetch server
;;   M-x cph-enable          start the server
;;   M-x cph-mode            enable the solution-buffer minor mode
;;
;; In the judge buffer (*cph-judge*):
;;   g    run all testcases
;;   p    run the testcase at point
;;   d    debug the testcase at point (lldb)
;;   k    stop the running testcases
;;   s    open the solution file
;;   q    quit the window
;;
;; In a solution buffer (cph-mode):
;;   C-c C-r   run all testcases of the problem
;;   C-c C-j   show the judge buffer
;;   C-c C-s   start the server
;;   C-c C-k   stop the running testcases

;;; Code:

(require 'cl-lib)
(require 'json)

(defgroup cph nil
  "Competitive programming helper for Emacs (Codeforces)."
  :group 'tools
  :prefix "cph-")

(defcustom cph-port 27121
  "TCP port of the problem-fetch HTTP server.
The same default as CPH, so the userscript needs no configuration."
  :type 'integer
  :group 'cph)

(defcustom cph-host "127.0.0.1"
  "Interface the problem-fetch server listens on."
  :type 'string
  :group 'cph)

(defcustom cph-default-language "cpp"
  "Language for new solution files (a key of `cph-languages').
nil means: infer from the current buffer, else use cpp."
  :type '(choice (const :tag "cpp" "cpp") (const :tag "Infer" nil) string)
  :group 'cph)

(defcustom cph-save-location ""
  "Directory for new solution files and .prob metadata.
Empty means: use the directory of the file in the selected window,
else `default-directory'.  The .prob file then sits in a `.cph'
subdirectory next to the solution file."
  :type 'string
  :group 'cph)

(defcustom cph-template-file nil
  "Template file for new solution files.
The literal text `$CURSOR_PLACEHOLDER' (if present) is removed and the
cursor is placed there."
  :type '(choice (const :tag "None" nil) file)
  :group 'cph)

(defcustom cph-timeout 3000
  "Kill a testcase run after this many milliseconds."
  :type 'integer
  :group 'cph)

(defcustom cph-show-judge-after-fetch t
  "Pop up the judge buffer when a problem arrives."
  :type 'boolean
  :group 'cph)

(defcustom cph-keep-binaries nil
  "Keep compiled binaries after a test run (debugging aid)."
  :type 'boolean
  :group 'cph)

(defvar cph-languages
  '(("c"   . (:compiler "clang"   :args ("-std=c11" "-O2" "-Wall")   :skip-compile nil))
    ("cpp" . (:compiler "clang++" :args ("-std=c++17" "-O2" "-Wall") :skip-compile nil))
    ("cc"  . (:compiler "clang++" :args ("-std=c++17" "-O2" "-Wall") :skip-compile nil))
    ("cxx" . (:compiler "clang++" :args ("-std=c++17" "-O2" "-Wall") :skip-compile nil))
    ("rs"  . (:compiler "rustc"   :args ("-O")                        :skip-compile nil))
    ("js"  . (:compiler "node"    :args nil                           :skip-compile t)))
  "Languages: extension -> (:compiler :args :skip-compile).
Compilers must be on PATH.")

;; ---------------------------------------------------------------------------
;; State

(defvar cph--server-process nil
  "The problem-fetch server process, or nil.")
(defvar cph--judge-buffer nil
  "The judge buffer, or nil.")
(defvar cph--running-procs nil
  "Processes of currently running testcases.")
(defvar cph--id-counter 0
  "Counter for testcase ids.")

(defvar-local cph--problem nil
  "Problem alist for the current judge buffer.")
(defvar-local cph--results nil
  "Alist mapping testcase id -> result plist.")
(defvar-local cph--tc-header-lines nil
  "Alist mapping header line number -> testcase id.")
(defvar-local cph--running nil
  "Non-nil while a run-all is in progress.")
(defvar-local cph--stopped nil
  "Non-nil when the user stopped a run-all.")
(defvar-local cph--last-compile-error nil
  "Compiler stderr of the last failed compilation.")

;; ---------------------------------------------------------------------------
;; Logging and JSON helpers

(defun cph--log (format-string &rest args)
  "Log to *Messages* with a CPH prefix."
  (apply #'message (concat "[cph] " format-string) args))

(defun cph--json-read (string)
  "Read STRING as JSON into an alist with string keys."
  (condition-case nil
      (let ((json-object-type 'alist)
            (json-key-type 'string)
            (json-array-type 'list))
        (json-read-from-string string))
    (error nil)))

(defun cph--new-id ()
  "Return a fresh numeric testcase id."
  (cl-incf cph--id-counter))

(defun cph--get (key alist)
  "Return the value of KEY in ALIST, comparing keys with `equal'."
  (let ((cell (assoc key alist)))
    (and cell (cdr cell))))

(defun cph--put (alist key value)
  "Return ALIST with KEY set to VALUE, mutating in place."
  (let ((cell (assoc key alist)))
    (if cell
        (setcdr cell value)
      (push (cons key value) alist)))
  alist)

;; ---------------------------------------------------------------------------
;; HTTP server (mirrors the CPH companion server on port 27121)

(defun cph--http-parse (text)
  "Parse TEXT as an HTTP/1.x request.
Return (METHOD PATH HEADERS BODY).  Return nil while the request is
still incomplete."
  (let* ((sep (string-search "\r\n\r\n" text))
         (head (if sep (substring text 0 sep) text))
         (lines (split-string head "\r\n" t))
         (parts (and lines (split-string (car lines) " " t)))
         (headers nil))
    (dolist (line (cdr lines))
      (when (string-match "^\\([^:]+\\):[ \t]*\\(.*\\)$" line)
        (push (cons (downcase (match-string 1 line))
                    (match-string 2 line))
              headers)))
    (let* ((cl-str (cdr (assoc "content-length" headers)))
           (cl (and cl-str (string-to-number cl-str)))
           (complete (and sep (if cl
                                  (>= (length text) (+ sep 4 cl))
                                t))))
      (when complete
        (list (and parts (upcase (nth 0 parts)))
              (and parts (nth 1 parts))
              headers
              (if cl (substring text (+ sep 4) (+ sep 4 cl)) ""))))))

(defun cph-server-start ()
  "Start the problem-fetch HTTP server on `cph-port'."
  (interactive)
  (when (process-live-p cph--server-process)
    (user-error "CPH server is already running"))
  (condition-case err
      (setq cph--server-process
            (make-network-process
             :name "cph-server" :server t
             :host cph-host :service cph-port :family 'ipv4
             :filter #'cph--server-accept
             :sentinel #'cph--server-sentinel
             :noquery t))
    (error (user-error "Cannot listen on %s:%s: %s" cph-host cph-port err)))
  (cph--log "problem server listening on http://%s:%s" cph-host cph-port))

(defun cph-server-stop ()
  "Stop the problem-fetch HTTP server."
  (interactive)
  (when (process-live-p cph--server-process)
    (delete-process cph--server-process)
    (setq cph--server-process nil)
    (cph--log "problem server stopped")))

(defun cph--server-sentinel (_proc _msg)
  "Ignore server process status changes.")

(defun cph--server-accept (client data)
  "Attach the request handler to the newly accepted CLIENT."
  (set-process-buffer client (generate-new-buffer " *cph-http*"))
  (set-process-filter client #'cph--request-filter)
  (set-process-sentinel client #'cph--request-sentinel)
  (set-process-coding-system client 'utf-8 'utf-8)
  (cph--request-filter client data))

(defun cph--request-sentinel (proc _msg)
  "Clean up the request buffer when the connection closes."
  (when (buffer-live-p (process-buffer proc))
    (kill-buffer (process-buffer proc))))

(defun cph--request-filter (proc data)
  "Accumulate DATA for PROC and handle the request once complete."
  (let ((buf (process-buffer proc)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (goto-char (point-max))
        (insert data))
      (let ((req (with-current-buffer buf
                   (cph--http-parse (buffer-string)))))
        (when req
          (condition-case err
              (cph--handle-request proc req)
            (error (cph--log "request failed: %S" err)
                   (cph--close-connection proc))))))))

(defun cph--handle-request (proc req)
  "Handle one parsed HTTP request REQ from PROC.
The request body is the problem JSON from the userscript."
  (let* ((body (nth 3 req))
         (problem (and body (> (length body) 0)
                       (cph--json-read body))))
    (if (not problem)
        (progn
          (cph--log "bad problem JSON from companion")
          (cph--respond proc 400))
      (condition-case err
          (progn
            (cph--handle-problem problem)
            (cph--respond proc 200))
        (error (cph--log "problem handling failed: %S" err)
               (cph--respond proc 400)))))
  (cph--close-connection proc))

(defun cph--respond (proc status)
  "Write an HTTP response with STATUS to PROC."
  (let* ((body (if (= status 200) "{\"status\":\"ok\"}" "{\"status\":\"error\"}"))
         (status-text (if (= status 200) "200 OK" "400 Bad Request"))
         (text (concat "HTTP/1.1 " status-text "\r\n"
                       "Content-Type: application/json\r\n"
                       "Access-Control-Allow-Origin: *\r\n"
                       "Content-Length: "
                       (number-to-string (string-bytes body))
                       "\r\nConnection: close\r\n\r\n"
                       body)))
    (condition-case nil
        (process-send-string proc text)
      (error nil))))

(defun cph--close-connection (proc)
  "Close PROC after the response has been flushed."
  (run-at-time 0.5 nil
               (lambda ()
                 (when (process-live-p proc)
                   (delete-process proc)))))

;; ---------------------------------------------------------------------------
;; Problem handling

(defun cph--active-file-dir ()
  "Return the directory of the file in the selected window, or nil."
  (condition-case nil
      (let* ((win (selected-window))
             (buf (and (window-live-p win) (window-buffer win)))
             (file (and buf (buffer-file-name buf))))
        (and file (file-name-directory file)))
    (error nil)))

(defun cph--solution-dir ()
  "Directory where new solution files are created."
  (if (and cph-save-location (not (string-empty-p cph-save-location)))
      (expand-file-name cph-save-location)
    (or (cph--active-file-dir) default-directory)))

(defun cph--slugify (s)
  "Turn a problem name into a filesystem-safe slug."
  (replace-regexp-in-string
   "[^[:alnum:]_]+" "_"
   (downcase (or s "problem"))))

(defun cph--short-name (problem)
  "Return the short problem name for the filename, mirroring CPH.
Codeforces: contest code plus problem letter, for example 1234A."
  (let ((url (or (cph--get "url" problem) "")))
    (cond
     ((string-match "/\\(?:contest\\|gym\\)/\\([0-9]+\\)/problem/\\([A-Za-z0-9]+\\)" url)
      (concat (match-string 1 url) (match-string 2 url)))
     ((string-match "/problemset/problem/\\([0-9]+\\)/\\([A-Za-z0-9]+\\)" url)
      (concat (match-string 1 url) (match-string 2 url)))
     (t (cph--slugify (cph--get "name" problem))))))

(defun cph--language-for-src (src)
  "Return the language key for SRC from its extension."
  (let ((ext (file-name-extension src)))
    (and ext (member ext (mapcar #'car cph-languages)) ext)))

(defun cph--choose-language ()
  "Choose the language for a new problem.
Preference order: `cph-default-language', then the current buffer
file extension, then cpp."
  (or cph-default-language
      (and (buffer-file-name)
           (cph--language-for-src (buffer-file-name)))
      "cpp"))

(defun cph--write-template (src)
  "Create SRC from `cph-template-file', or empty when no template."
  (if (and cph-template-file (file-exists-p cph-template-file))
      (with-temp-file src
        (insert-file-contents cph-template-file))
    (with-temp-file src)))

(defun cph--goto-placeholder ()
  "Move point to `$CURSOR_PLACEHOLDER', removing the marker."
  (goto-char (point-min))
  (when (search-forward "$CURSOR_PLACEHOLDER" nil t)
    (delete-char -19))) ; "$CURSOR_PLACEHOLDER" is 19 characters

(defun cph--problem-file (src)
  "Return the .prob metadata path for the solution file SRC.
Mirrors CPH: .cph/.<basename>_<md5-of-path>.prob"
  (let* ((base (file-name-nondirectory src))
         (dir (file-name-directory src))
         (save (if (string-empty-p cph-save-location)
                   (expand-file-name ".cph" dir)
                 cph-save-location)))
    (expand-file-name
     (format ".%s_%s.prob" base (md5 (expand-file-name src)))
     save)))

(defun cph--save-problem (src problem)
  "Persist PROBLEM to the .prob file next to SRC."
  (let ((f (cph--problem-file src)))
    (make-directory (file-name-directory f) t)
    (with-temp-file f (insert (json-encode problem)))))

(defun cph--problem-for-buffer ()
  "Load the problem associated with the current buffer's file."
  (let ((src (buffer-file-name)))
    (when src
      (let ((f (cph--problem-file src)))
        (and (file-exists-p f)
             (cph--json-read (with-temp-buffer
                               (insert-file-contents f)
                               (buffer-string))))))))

(defun cph--handle-problem (problem)
  "Handle a problem JSON alist from the companion server."
  (let* ((lang (cph--choose-language))
         (name (cph--get "name" problem))
         (dir (cph--solution-dir))
         (src (expand-file-name (concat (cph--short-name problem) "." lang)
                                dir)))
    (setq problem (cph--put problem "tests"
                            (mapcar (lambda (tc)
                                      (cons (cons "id" (cph--new-id)) tc))
                                    (cph--get "tests" problem))))
    (setq problem (cph--put problem "srcPath" src))
    (let ((created (not (file-exists-p src))))
      (when created (cph--write-template src))
      (cph--save-problem src problem)
      (find-file src)
      (when created (cph--goto-placeholder))
      (cph-mode 1)
      (cph--log "fetched problem: %s -> %s (%d tests)"
                name src (length (cph--get "tests" problem)))
      (cph--show-judge problem))))

;; ---------------------------------------------------------------------------
;; Compilation and execution

(defun cph--compile (src lang &optional debug)
  "Compile SRC for LANG.  Return (COMMAND . CLEANUP) or nil on failure.
When DEBUG is non-nil, drop the optimization flag and add debug info
(-g).  Interpreted languages return nil when DEBUG is non-nil."
  (let ((entry (cdr (assoc lang cph-languages))))
    (if (not entry)
        (progn (cph--log "no compiler configured for %s" lang) nil)
      (let ((compiler (plist-get entry :compiler))
            (skip (plist-get entry :skip-compile)))
        (if skip
            (if debug
                (progn (cph--log "no debugger for %s" lang) nil)
              (cons (list compiler src) #'ignore))
          (let* ((args0 (plist-get entry :args))
                 (args (if debug
                           (append (cl-remove-if
                                    (lambda (a) (string-match-p "^-O[0-9a-z]*$" a))
                                    args0)
                                   '("-g"))
                         args0))
                 (bin (make-temp-name
                       (expand-file-name "cph-bin-" temporary-file-directory)))
                 (buf (generate-new-buffer " *cph-compile*"))
                 (err "")
                 (code 1))
            (unwind-protect
                (setq code (apply #'call-process compiler nil buf nil
                                  (append args (list src "-o" bin))))
              (setq err (with-current-buffer buf (buffer-string)))
              (kill-buffer buf))
            (if (zerop code)
                (progn
                  (setq cph--last-compile-error nil)
                  (cons (list bin)
                        (lambda () (unless cph-keep-binaries
                                     (delete-file bin)))))
              (setq cph--last-compile-error
                    (format "%s failed:\n%s" compiler err))
              nil)))))))

(defun cph--exec (cmd input callback)
  "Run CMD with INPUT on stdin; call CALLBACK with a result plist.
Result keys: :stdout :stderr :code :signal :time :timed-out."
  (let* ((out-buf (generate-new-buffer " *cph-run-out*"))
         (err-buf (generate-new-buffer " *cph-run-err*"))
         (err-proc (make-pipe-process :name "cph-run-err"
                                      :buffer err-buf :noquery t
                                      :coding 'utf-8))
         (timed-out nil)
         (start (float-time))
         (proc (make-process :name "cph-run" :command cmd
                             :connection-type 'pipe :noquery t
                             :coding 'utf-8 :buffer out-buf
                             :stderr err-proc))
         (timer (run-at-time (/ (max cph-timeout 1) 1000.0) nil
                             (lambda ()
                               (when (process-live-p proc)
                                 (setq timed-out t)
                                 (signal-process proc 'SIGKILL))))))
    (push proc cph--running-procs)
    (condition-case nil
        (progn (process-send-string proc input)
               (process-send-eof proc))
      (error nil))
    (set-process-sentinel
     proc
     (lambda (p _event)
       (when (memq (process-status p) '(exit signal failed))
         (cancel-timer timer)
         (setq cph--running-procs (delq p cph--running-procs))
         (let* ((status (process-status p))
                (result
                 (list :stdout (with-current-buffer out-buf (buffer-string))
                       :stderr (with-current-buffer err-buf (buffer-string))
                       :code (if (eq status 'failed) 127
                               (process-exit-status p))
                       :signal (and (eq status 'signal)
                                    (format "signal %d"
                                            (process-exit-status p)))
                       :time (round (* 1000 (- (float-time) start)))
                       :timed-out timed-out)))
           (kill-buffer out-buf)
           (kill-buffer err-buf)
           (funcall callback result)))))))

;; ---------------------------------------------------------------------------
;; Comparison and diff (mirror CPH semantics)

(defun cph--normalize (s)
  "Normalize line endings for comparison."
  (replace-regexp-in-string "\r\n" "\n" (or s "")))

(defun cph--trimmed-lines (s)
  "Split S into lines the way CPH does: trim whole, then split."
  (split-string (string-trim (cph--normalize s)) "\n"))

(defun cph--correct-p (expected received)
  "Compare EXPECTED and RECEIVED with CPH semantics."
  (let ((e (cph--trimmed-lines expected))
        (r (cph--trimmed-lines received)))
    (and (= (length e) (length r))
         (cl-loop for a in e for b in r
                  always (string= (string-trim a) (string-trim b))))))

(defun cph--lcs-diff (e r)
  "Return an LCS line diff of E and R as (status . line) items.
Status is match, extra, or missing."
  (let* ((n (length e)) (m (length r))
         (dp (make-vector (1+ n) nil)))
    (dotimes (i (1+ n))
      (aset dp i (make-vector (1+ m) 0)))
    (dotimes (i n)
      (dotimes (j m)
        (aset (aref dp (1+ i)) (1+ j)
              (if (string= (nth i e) (nth j r))
                  (1+ (aref (aref dp i) j))
                (max (aref (aref dp i) (1+ j))
                     (aref (aref dp (1+ i)) j))))))
    (let ((out nil) (i n) (j m))
      (while (and (> i 0) (> j 0))
        (if (string= (nth (1- i) e) (nth (1- j) r))
            (progn (push (cons "match" (nth (1- j) r)) out)
                   (cl-decf i) (cl-decf j))
          (if (>= (aref (aref dp i) (1- j))
                  (aref (aref dp (1- i)) j))
              (progn (push (cons "extra" (nth (1- j) r)) out)
                     (cl-decf j))
            (progn (push (cons "missing" (nth (1- i) e)) out)
                   (cl-decf i)))))
      (while (> j 0)
        (push (cons "extra" (nth (1- j) r)) out) (cl-decf j))
      (while (> i 0)
        (push (cons "missing" (nth (1- i) e)) out) (cl-decf i))
      out)))

(defun cph--diff-lines (expected received)
  "Return the line diff of EXPECTED vs RECEIVED."
  (cph--lcs-diff (cph--trimmed-lines expected)
                 (cph--trimmed-lines received)))

(defun cph--finalize-result (raw expected)
  "Turn an execution result plist RAW into a judged result.
A test fails on timeout, signal, non-zero exit, non-empty stderr, or
wrong output."
  (let ((pass (and (not (plist-get raw :timed-out))
                   (not (plist-get raw :signal))
                   (zerop (or (plist-get raw :code) -1))
                   (string-empty-p (plist-get raw :stderr))
                   (cph--correct-p expected (plist-get raw :stdout)))))
    (list :status 'done :pass pass
          :stdout (plist-get raw :stdout)
          :stderr (plist-get raw :stderr)
          :time (plist-get raw :time)
          :timed-out (plist-get raw :timed-out)
          :signal (plist-get raw :signal)
          :code (plist-get raw :code)
          :diff (cph--diff-lines expected (plist-get raw :stdout)))))

;; ---------------------------------------------------------------------------
;; Judge buffer

(defun cph--make-judge-buffer ()
  "Create the judge buffer if needed and return it."
  (unless (buffer-live-p cph--judge-buffer)
    (setq cph--judge-buffer (get-buffer-create "*cph-judge*"))
    (with-current-buffer cph--judge-buffer
      (cph-judge-mode)))
  cph--judge-buffer)

(defun cph--set-result (id result)
  "Store RESULT for testcase ID in the judge buffer."
  (setq cph--results (cph--put cph--results id result)))

(defun cph--tc-number (tc)
  "Return the 1-based display number of TC."
  (1+ (cl-position tc (cph--get "tests" cph--problem))))

(defun cph--result-label (res)
  "Return a status label for result plist RES."
  (pcase (and res (plist-get res :status))
    ('running "(running)")
    ('done (if (plist-get res :pass) "[PASS]" "[FAIL]"))
    (_ "-")))

(defun cph--insert-lines (prefix s)
  "Insert S indented with PREFIX, one line at a time."
  (dolist (l (split-string (cph--normalize s) "\n"))
    (insert (format "%s%s\n" prefix l))))

(defun cph--insert-diff (diff)
  "Insert a human-readable summary of DIFF."
  (let ((extra (cl-count-if (lambda (x) (string= (car x) "extra")) diff))
        (missing (cl-count-if (lambda (x) (string= (car x) "missing")) diff)))
    (insert (format "  Diff: %d extra line(s), %d missing line(s)\n"
                    extra missing))
    (when (> extra 0)
      (insert "    extra:\n")
      (dolist (x (cl-remove-if-not (lambda (x) (string= (car x) "extra")) diff))
        (insert (format "      + %s\n" (cdr x)))))
    (when (> missing 0)
      (insert "    missing:\n")
      (dolist (x (cl-remove-if-not (lambda (x) (string= (car x) "missing")) diff))
        (insert (format "      - %s\n" (cdr x)))))))

(defun cph--insert-testcase (tc num)
  "Insert the section for testcase TC numbered NUM."
  (let* ((id (cph--get "id" tc))
         (res (cdr (assoc id cph--results)))
         (header-line (line-number-at-pos (point))))
    (push (cons header-line id) cph--tc-header-lines)
    (insert (format "Test %d %s\n" num (cph--result-label res)))
    (insert "  Input:\n")
    (cph--insert-lines "    " (cph--get "input" tc))
    (insert "  Expected:\n")
    (cph--insert-lines "    " (cph--get "output" tc))
    (when res
      (if (eq (plist-get res :status) 'running)
          (insert "  Running...\n")
        (insert (format "  Received (%s):\n"
                        (if (plist-get res :timed-out)
                            (format "TIMED OUT after %d ms"
                                    (plist-get res :time))
                          (format "%d ms" (plist-get res :time)))))
        (cph--insert-lines "    " (plist-get res :stdout))
        (when (and (plist-get res :stderr)
                   (not (string-empty-p (plist-get res :stderr))))
          (insert "  stderr:\n")
          (cph--insert-lines "    " (plist-get res :stderr)))
        (when (plist-get res :diff)
          (cph--insert-diff (plist-get res :diff)))))
    (insert "\n")))

(defun cph--render-judge ()
  "Rebuild the judge buffer contents from the current state."
  (cph--make-judge-buffer)
  (with-current-buffer cph--judge-buffer
    (let ((inhibit-read-only t))
      (erase-buffer)
      (setq cph--tc-header-lines nil)
      (when cph--problem
        (insert (format "%s\n" (cph--get "name" cph--problem)))
        (insert (format "  %s | %s\n"
                        (cph--get "group" cph--problem)
                        (cph--get "url" cph--problem)))
        (insert (format "  Time %s ms | Memory %s MB\n"
                        (or (cph--get "timeLimit" cph--problem) "?")
                        (or (cph--get "memoryLimit" cph--problem) "?")))
        (insert (format "  server: %s\n\n"
                        (if (process-live-p cph--server-process)
                            (format "%s:%s" cph-host cph-port)
                          "stopped")))
        (when cph--last-compile-error
          (insert (format "  Compile error:\n%s\n\n" cph--last-compile-error)))
        (insert "  g run all | p run at point | d debug at point | k stop | s source | q quit\n\n")
        (let ((num 0))
          (dolist (tc (cph--get "tests" cph--problem))
            (cl-incf num)
            (cph--insert-testcase tc num))))
      (goto-char (point-min)))
    (set-buffer-modified-p nil)))

(defun cph--show-judge (problem)
  "Display the judge buffer for PROBLEM."
  (cph--make-judge-buffer)
  (with-current-buffer cph--judge-buffer
    (setq cph--problem problem
          cph--results nil
          cph--tc-header-lines nil)
    (cph--render-judge))
  (when cph-show-judge-after-fetch
    (unless noninteractive
      (display-buffer cph--judge-buffer
                      '(display-buffer-reuse-window
                        display-buffer-pop-up-window))))
  cph--judge-buffer)

(defun cph-show-judge ()
  "Show the judge buffer for the current buffer's problem."
  (interactive)
  (let ((problem (or cph--problem (cph--problem-for-buffer))))
    (unless problem (user-error "No CPH problem associated with this buffer"))
    (cph--show-judge problem)))

;; ---------------------------------------------------------------------------
;; Test running

(defun cph--tc-at-point ()
  "Return the testcase id of the test header at or above point."
  (let ((line (line-number-at-pos (point))))
    (cdr (cl-some (lambda (entry)
                    (when (>= line (car entry)) entry))
                  cph--tc-header-lines))))

(defun cph-run-all ()
  "Run all testcases of the problem for the current solution buffer."
  (interactive)
  (let ((problem (cph--problem-for-buffer)))
    (unless problem (user-error "No CPH problem associated with this buffer"))
    (cph--show-judge problem)
    (with-current-buffer cph--judge-buffer
      (cph-run-all-in-judge))))

(defun cph-run-all-in-judge ()
  "Compile once and run all testcases in the judge buffer."
  (interactive)
  (unless cph--problem (user-error "No problem in the judge buffer"))
  (save-some-buffers t)
  (let* ((src (cph--get "srcPath" cph--problem))
         (lang (cph--language-for-src src)))
    (setq cph--stopped nil cph--results nil cph--running t
          cph--last-compile-error nil)
    (cph--render-judge)
    (pcase (cph--compile src lang)
      (`(,cmd . ,cleanup)
       (cph--run-tests-seq cmd cleanup (cph--get "tests" cph--problem) 0))
      (_ (setq cph--running nil)
         (cph--render-judge)))))

(defun cph--run-tests-seq (cmd cleanup tests i)
  "Run TESTS sequentially with CMD, cleanup once at the end."
  (if (>= i (length tests))
      (progn
        (funcall cleanup)
        (setq cph--running nil)
        (cph--render-judge))
    (when (and cph--running (not cph--stopped))
      (let ((tc (nth i tests)))
        (cph--exec cmd (cph--get "input" tc)
                   (lambda (r)
                     (with-current-buffer cph--judge-buffer
                       (cph--set-result (cph--get "id" tc)
                                        (cph--finalize-result
                                         r (cph--get "output" tc)))
                       (cph--render-judge)
                       (cph--run-tests-seq cmd cleanup tests (1+ i)))))))))

(defun cph-run-testcase-at-point ()
  "Compile and run the testcase at point."
  (interactive)
  (let* ((id (cph--tc-at-point))
         (tc (and id (cl-find id (cph--get "tests" cph--problem)
                              :key (lambda (x) (cph--get "id" x))))))
    (unless tc (user-error "No testcase at point"))
    (save-some-buffers t)
    (let* ((src (cph--get "srcPath" cph--problem))
           (lang (cph--language-for-src src)))
      (setq cph--last-compile-error nil)
      (pcase (cph--compile src lang)
        (`(,cmd . ,cleanup)
         (cph--set-result id (list :status 'running))
         (cph--render-judge)
         (cph--exec cmd (cph--get "input" tc)
                    (lambda (r)
                      (funcall cleanup)
                      (with-current-buffer cph--judge-buffer
                        (cph--set-result id
                                         (cph--finalize-result
                                          r (cph--get "output" tc)))
                        (cph--render-judge)))))
        (_ (cph--render-judge))))))

;; ---------------------------------------------------------------------------
;; Debugging (lldb)

(defun cph--write-input-file (input)
  "Write INPUT to a temp file and return the file name."
  (let ((f (make-temp-file "cph-input-")))
    (with-temp-file f (insert input))
    f))

(defun cph-debug-testcase-at-point ()
  "Compile with debug info and start lldb on the testcase at point.
The testcase input is redirected from a temp file.  The lldb session
runs in a term buffer named *cph-lldb*.  A breakpoint at main stops
right after the launch; then set your own breakpoints and step."
  (interactive)
  (let* ((id (cph--tc-at-point))
         (tc (and id (cl-find id (cph--get "tests" cph--problem)
                              :key (lambda (x) (cph--get "id" x))))))
    (unless tc (user-error "No testcase at point"))
    (save-some-buffers t)
    (let* ((src (cph--get "srcPath" cph--problem))
           (lang (cph--language-for-src src)))
      (setq cph--last-compile-error nil)
      (pcase (cph--compile src lang t)
        (`(,cmd . ,_cleanup)
         ;; Keep the binary: lldb runs it for the whole session.  The
         ;; temp files live in /tmp and disappear on reboot.
         (let* ((lldb (executable-find "lldb"))
                (input-file (cph--write-input-file (cph--get "input" tc)))
                (bin (car cmd))
                (args (list "-o" "breakpoint set --name main"
                            "-o" (format "process launch -i %s" input-file)
                            "--" bin))
                (launch (mapconcat #'shell-quote-argument
                                   (cons lldb args) " ")))
           (unless lldb (user-error "lldb is not installed"))
           (when (get-buffer "*cph-lldb*")
             (kill-buffer "*cph-lldb*"))
           (require 'term)
           (ansi-term launch "*cph-lldb*")
           (cph--log "lldb started on %s (input %s)" bin input-file)))
        (_ (cph--render-judge))))))

(defun cph-stop ()
  "Stop all running testcases."
  (interactive)
  (setq cph--stopped t cph--running nil)
  (dolist (p cph--running-procs)
    (when (process-live-p p) (signal-process p 'SIGKILL)))
  (setq cph--running-procs nil)
  (cph--render-judge))

(defun cph-show-source ()
  "Open the solution file of the problem in the judge buffer."
  (interactive)
  (when-let ((src (cph--get "srcPath" cph--problem)))
    (find-file src)))

;; ---------------------------------------------------------------------------
;; Modes

(defvar-keymap cph-judge-mode-map
  "g" #'cph-run-all-in-judge
  "p" #'cph-run-testcase-at-point
  "RET" #'cph-run-testcase-at-point
  "d" #'cph-debug-testcase-at-point
  "k" #'cph-stop
  "s" #'cph-show-source
  "q" #'quit-window)

(define-derived-mode cph-judge-mode special-mode "CPH-Judge"
  "Major mode for the CPH judge buffer."
  (setq buffer-read-only t))

(defvar-keymap cph-mode-map
  "C-c C-r" #'cph-run-all
  "C-c C-j" #'cph-show-judge
  "C-c C-s" #'cph-server-start
  "C-c C-k" #'cph-stop)

(define-minor-mode cph-mode
  "Minor mode for competitive programming solution files."
  :lighter " CPH"
  :keymap cph-mode-map)

(defun cph-enable ()
  "Start the problem server."
  (interactive)
  (cph-server-start))

(provide 'cph)
;;; cph.el ends here
