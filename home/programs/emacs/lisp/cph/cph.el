;;; cph.el --- Competitive programming helper for Emacs -*- lexical-binding: t; -*-

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
;;   3. Debug: start a GUD lldb session on the testcase at point.
;;      GUD is Emacs's own debugger interface; this needs Emacs 30
;;      (built-in GUD lldb support) and lldb on PATH.
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
;;   d    debug the testcase at point (lldb through GUD)
;;   k    stop the running testcases
;;   s    open the solution file
;;   q    quit the window
;;
;; Debugging opens a GUD lldb session (not an ansi-term).  The usual
;; GUD keys apply in the *gud-* buffer: C-c C-n next, C-c C-s step,
;; C-c C-r continue, C-c C-b breakpoint, C-c C-p print expression.
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
  "Competitive programming helper for Emacs."
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
(defvar cph--debug-process nil
  "Process of the current GUD lldb debug session, or nil.")
(defvar cph--id-counter 0
  "Counter for testcase ids.")

(defvar-local cph--problem nil
  "Problem record (`cph-problem') of the current judge buffer.")
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

;; ---------------------------------------------------------------------------
;; Problem model (native records)
;;
;; The companion wire format and the .prob metadata are JSON with
;; string keys.  cph decodes JSON into the records below once, at the
;; boundary, so the rest of the code reads native accessors instead of
;; magic strings.

(cl-defstruct (cph-problem (:constructor cph--problem-new)
                           (:copier nil))
  "A problem sent by the companion, decoded from JSON."
  name group url time-limit memory-limit tests src-path)

(cl-defstruct (cph-test (:constructor cph--test-new)
                        (:copier nil))
  "One sample testcase of a problem."
  id input output)

(defun cph--json-field (json key)
  "Value of KEY in the string-keyed JSON alist JSON."
  (cdr (assoc key json)))

(defun cph--problem-from-json (json)
  "Decode the string-keyed JSON alist JSON into a `cph-problem'."
  (cph--problem-new
   :name (cph--json-field json "name")
   :group (cph--json-field json "group")
   :url (cph--json-field json "url")
   :time-limit (cph--json-field json "timeLimit")
   :memory-limit (cph--json-field json "memoryLimit")
   :src-path (cph--json-field json "srcPath")
   :tests (mapcar #'cph--test-from-json (cph--json-field json "tests"))))

(defun cph--test-from-json (json)
  "Decode the string-keyed JSON alist JSON into a `cph-test'."
  (cph--test-new :id (cph--json-field json "id")
                 :input (cph--json-field json "input")
                 :output (cph--json-field json "output")))

(defun cph--problem-to-json (problem)
  "Encode PROBLEM as a string-keyed JSON alist.
Keeps the competitive-companion key names, so the .prob metadata
stays compatible with the original CPH layout."
  (delq nil
        (list (and (cph-problem-name problem)
                   (cons "name" (cph-problem-name problem)))
              (and (cph-problem-group problem)
                   (cons "group" (cph-problem-group problem)))
              (and (cph-problem-url problem)
                   (cons "url" (cph-problem-url problem)))
              (and (cph-problem-time-limit problem)
                   (cons "timeLimit" (cph-problem-time-limit problem)))
              (and (cph-problem-memory-limit problem)
                   (cons "memoryLimit" (cph-problem-memory-limit problem)))
              (and (cph-problem-src-path problem)
                   (cons "srcPath" (cph-problem-src-path problem)))
              (cons "tests"
                    (mapcar #'cph--test-to-json
                            (cph-problem-tests problem))))))

(defun cph--test-to-json (test)
  "Encode TEST as a string-keyed JSON alist."
  (list (cons "id" (cph-test-id test))
        (cons "input" (cph-test-input test))
        (cons "output" (cph-test-output test))))

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
  (let ((url (or (cph-problem-url problem) "")))
    (cond
     ((string-match "/\\(?:contest\\|gym\\)/\\([0-9]+\\)/problem/\\([A-Za-z0-9]+\\)" url)
      (concat (match-string 1 url) (match-string 2 url)))
     ((string-match "/problemset/problem/\\([0-9]+\\)/\\([A-Za-z0-9]+\\)" url)
      (concat (match-string 1 url) (match-string 2 url)))
     (t (cph--slugify (cph-problem-name problem))))))

(defun cph--contest-parts (url)
  "Return (CONTEST-ID . INDEX) parsed from a Codeforces problem URL.
For https://codeforces.com/contest/677/problem/A this is the pair
of strings (\"677\" . \"A\"); gym links follow the same rule.
Return nil when URL has no contest-shaped path."
  (cond
   ((string-match
     "/\\(?:contest\\|gym\\)/\\([0-9]+\\)/problem/\\([A-Za-z0-9]+\\)" url)
    (cons (match-string 1 url) (match-string 2 url)))
   ((string-match "/problemset/problem/\\([0-9]+\\)/\\([A-Za-z0-9]+\\)" url)
    (cons (match-string 1 url) (match-string 2 url)))
   (t nil)))

(defun cph--div-token (group)
  "Compact division tag of contest GROUP, or nil.
Examples: Codeforces Round 355 (Div. 2) -> D2;
EPIC ... (Div. 1 + Div. 2) -> D1+2;
Codeforces Beta Round 4 (Div. 2 Only) -> D2.
nil when GROUP names no division (gym, mirrors)."
  (when (and group (string-match "Div\\.[^)]*" group))
    (let ((s (match-string 0 group)))
      (setq s (replace-regexp-in-string "[^0-9+]" "" s))
      (and (not (string-empty-p s)) (concat "D" s)))))

(defun cph--problem-id (url group)
  "Problem identifier used as the solution folder name.
Format: CF<contest>[-D<div>]-<index>, for example CF677-D2-A.
The -D<div> part is omitted when GROUP names no division."
  (let ((parts (cph--contest-parts url)))
    (when parts
      (let ((contest (car parts))
            (index (cdr parts))
            (div (cph--div-token group)))
        (format "CF%s%s-%s"
                contest (if div (concat "-" div) "") index)))))

(defun cph--title-stem (problem)
  "Problem title without the leading index.
A. Vanya and Fence -> Vanya and Fence (the index letter already
lives in the folder id)."
  (replace-regexp-in-string
   "^[A-Za-z][0-9]*\\.[ \t]*" ""
   (string-trim (or (cph-problem-name problem) ""))))

(defun cph--file-stem (title)
  "Make TITLE safe as one file name component."
  (let ((s (replace-regexp-in-string "[/\\\\]" "-" title)))
    (setq s (replace-regexp-in-string "[\000-\037\177]" "" s))
    (setq s (string-trim s))
    (replace-regexp-in-string "[. ]+\\'" "" s)))

(defun cph--solution-path (problem lang)
  "Absolute path of the new solution file for PROBLEM.
Layout: <solution-dir>/CF<contest>[-D<div>]-<index>/<Title>.<lang>,
for example .../CF677-D2-A/Vanya and Fence.cpp.  The directory is
created on demand by the caller.  Problems without a contest-shaped
URL fall back to the flat name <short>.<lang>."
  (let* ((base (cph--solution-dir))
         (url (or (cph-problem-url problem) ""))
         (id (cph--problem-id url (cph-problem-group problem))))
    (if id
        (let* ((title (cph--file-stem (cph--title-stem problem)))
               (stem (if (string-empty-p title)
                         (cph--short-name problem)
                       title))
               (dir (expand-file-name id base)))
          (expand-file-name (concat stem "." lang) dir))
      (expand-file-name (concat (cph--short-name problem) "." lang)
                        base))))
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
Mirrors CPH: .cph/.<basename>_<md5-of-path>.prob next to SRC.  Each
solution lives in its own folder, so its metadata stays in that
folder's .cph directory regardless of `cph-save-location'."
  (expand-file-name
   (format ".%s_%s.prob" (file-name-nondirectory src)
           (md5 (expand-file-name src)))
   (expand-file-name ".cph" (file-name-directory src))))

(defun cph--save-problem (src problem)
  "Persist the `cph-problem' PROBLEM to the .prob file next to SRC."
  (let ((f (cph--problem-file src)))
    (make-directory (file-name-directory f) t)
    (with-temp-file f
      (insert (json-encode (cph--problem-to-json problem))))))

(defun cph--problem-for-buffer ()
  "Load the `cph-problem' associated with the current buffer's file."
  (let ((src (buffer-file-name)))
    (when src
      (let ((f (cph--problem-file src)))
        (and (file-exists-p f)
             (cph--problem-from-json
              (cph--json-read (with-temp-buffer
                                (insert-file-contents f)
                                (buffer-string)))))))))

(defun cph--handle-problem (problem)
  "Handle a problem JSON alist from the companion server."
  (setq problem (cph--problem-from-json problem))
  (let* ((lang (cph--choose-language))
         (name (cph-problem-name problem))
         (src (cph--solution-path problem lang)))
    (setf (cph-problem-tests problem)
          (mapcar (lambda (tc)
                    (cph--test-new :id (cph--new-id)
                                   :input (cph-test-input tc)
                                   :output (cph-test-output tc)))
                  (cph-problem-tests problem)))
    (setf (cph-problem-src-path problem) src)
    (let ((created (not (file-exists-p src))))
      (when created
        (make-directory (file-name-directory src) t)
        (cph--write-template src))
      (cph--save-problem src problem)
      (find-file src)
      (when created (cph--goto-placeholder))
      (cph-mode 1)
      (cph--log "fetched problem: %s -> %s (%d tests)"
                name src (length (cph-problem-tests problem)))
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
  "Return an LCS line diff of E and R as (STATUS . line) items.
STATUS is the keyword :match, :extra, or :missing."
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
            (progn (push (cons :match (nth (1- j) r)) out)
                   (cl-decf i) (cl-decf j))
          (if (>= (aref (aref dp i) (1- j))
                  (aref (aref dp (1- i)) j))
              (progn (push (cons :extra (nth (1- j) r)) out)
                     (cl-decf j))
            (progn (push (cons :missing (nth (1- i) e)) out)
                   (cl-decf i)))))
      (while (> j 0)
        (push (cons :extra (nth (1- j) r)) out) (cl-decf j))
      (while (> i 0)
        (push (cons :missing (nth (1- i) e)) out) (cl-decf i))
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
  (let ((cell (assoc id cph--results)))
    (if cell
        (setcdr cell result)
      (push (cons id result) cph--results))))

(defun cph--tc-number (tc)
  "Return the 1-based display number of TC."
  (1+ (cl-position tc (cph-problem-tests cph--problem))))

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
  (let ((extra (cl-count-if (lambda (x) (eq (car x) :extra)) diff))
        (missing (cl-count-if (lambda (x) (eq (car x) :missing)) diff)))
    (insert (format "  Diff: %d extra line(s), %d missing line(s)\n"
                    extra missing))
    (when (> extra 0)
      (insert "    extra:\n")
      (dolist (x (cl-remove-if-not (lambda (x) (eq (car x) :extra)) diff))
        (insert (format "      + %s\n" (cdr x)))))
    (when (> missing 0)
      (insert "    missing:\n")
      (dolist (x (cl-remove-if-not (lambda (x) (eq (car x) :missing)) diff))
        (insert (format "      - %s\n" (cdr x)))))))

(defun cph--insert-testcase (tc num)
  "Insert the section for testcase TC numbered NUM."
  (let* ((id (cph-test-id tc))
         (res (cdr (assoc id cph--results)))
         (header-line (line-number-at-pos (point))))
    (push (cons header-line id) cph--tc-header-lines)
    (insert (format "Test %d %s\n" num (cph--result-label res)))
    (insert "  Input:\n")
    (cph--insert-lines "    " (cph-test-input tc))
    (insert "  Expected:\n")
    (cph--insert-lines "    " (cph-test-output tc))
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
        (insert (format "%s\n" (cph-problem-name cph--problem)))
        (insert (format "  %s | %s\n"
                        (cph-problem-group cph--problem)
                        (cph-problem-url cph--problem)))
        (insert (format "  Time %s ms | Memory %s MB\n"
                        (or (cph-problem-time-limit cph--problem) "?")
                        (or (cph-problem-memory-limit cph--problem) "?")))
        (insert (format "  server: %s\n\n"
                        (if (process-live-p cph--server-process)
                            (format "%s:%s" cph-host cph-port)
                          "stopped")))
        (when cph--last-compile-error
          (insert (format "  Compile error:\n%s\n\n" cph--last-compile-error)))
        (insert "  g run all | p run at point | d debug at point (GUD) | k stop | s source | q quit\n\n")
        (let ((num 0))
          (dolist (tc (cph-problem-tests cph--problem))
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
  (let* ((src (cph-problem-src-path cph--problem))
         (lang (cph--language-for-src src)))
    (setq cph--stopped nil cph--results nil cph--running t
          cph--last-compile-error nil)
    (cph--render-judge)
    (pcase (cph--compile src lang)
      (`(,cmd . ,cleanup)
       (cph--run-tests-seq cmd cleanup
                           (cph-problem-tests cph--problem) 0))
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
        (cph--exec cmd (cph-test-input tc)
                   (lambda (r)
                     (with-current-buffer cph--judge-buffer
                       (cph--set-result (cph-test-id tc)
                                        (cph--finalize-result
                                         r (cph-test-output tc)))
                       (cph--render-judge)
                       (cph--run-tests-seq cmd cleanup tests (1+ i)))))))))

(defun cph-run-testcase-at-point ()
  "Compile and run the testcase at point."
  (interactive)
  (let* ((id (cph--tc-at-point))
         (tc (and id (cl-find id (cph-problem-tests cph--problem)
                              :key #'cph-test-id))))
    (unless tc (user-error "No testcase at point"))
    (save-some-buffers t)
    (let* ((src (cph-problem-src-path cph--problem))
           (lang (cph--language-for-src src)))
      (setq cph--last-compile-error nil)
      (pcase (cph--compile src lang)
        (`(,cmd . ,cleanup)
         (cph--set-result id (list :status 'running))
         (cph--render-judge)
         (cph--exec cmd (cph-test-input tc)
                    (lambda (r)
                      (funcall cleanup)
                      (with-current-buffer cph--judge-buffer
                        (cph--set-result id
                                         (cph--finalize-result
                                          r (cph-test-output tc)))
                        (cph--render-judge)))))
        (_ (cph--render-judge))))))

;; ---------------------------------------------------------------------------
;; Debugging (lldb through GUD, Emacs's own debugger interface)

(defun cph--write-input-file (input)
  "Write INPUT to a temp file and return the file name."
  (let ((f (make-temp-file "cph-input-")))
    (with-temp-file f (insert input))
    f))

(defun cph--lldb-session-cleanup (proc bin input-file)
  "Delete the temp files of a finished GUD session.
PROC is the lldb process; BIN and INPUT-FILE are the temp files.
Keep BIN when `cph-keep-binaries' is non-nil."
  (when (eq proc cph--debug-process)
    (setq cph--debug-process nil))
  (ignore-errors
    (unless cph-keep-binaries (delete-file bin))
    (delete-file input-file)))

(defun cph--lldb-track-process (proc bin input-file)
  "Clean up BIN and INPUT-FILE when the lldb process PROC exits.
The sentinel that GUD installed keeps running; this one only adds
the temp-file cleanup after it."
  (if (not (process-live-p proc))
      ;; The process died before we could arm the cleanup.
      (cph--lldb-session-cleanup proc bin input-file)
    (let ((old-sentinel (process-sentinel proc)))
      (set-process-sentinel
       proc
       (lambda (p event)
         (when old-sentinel (funcall old-sentinel p event))
         (when (not (process-live-p p))
           (cph--lldb-session-cleanup p bin input-file)))))))

(defun cph--lldb-start (bin input-file)
  "Start a GUD lldb session for BIN with INPUT-FILE on stdin.
Return the lldb process.  The session breaks at main and launches
the program, so the debugger stops at main, ready for stepping.
On failure, delete the temp files and signal a user-error."
  (require 'gud)
  (unless (fboundp 'lldb)
    (user-error "CPH lldb debugging needs Emacs 30 (built-in GUD lldb)"))
  (unless (executable-find "lldb")
    (user-error "lldb is not installed"))
  (let (proc)
    (condition-case err
        (progn
          (lldb (format "%s %s" (executable-find "lldb")
                        (shell-quote-argument bin)))
          (setq proc (get-buffer-process (current-buffer)))
          (unless proc (error "GUD failed to start lldb"))
          ;; These commands queue behind GUD's own lldb initialization,
          ;; which installs the frame format used to track source lines.
          (process-send-string proc "breakpoint set --name main\n")
          (process-send-string
           proc (format "settings set target.input-path %s\n"
                        (shell-quote-argument input-file)))
          (process-send-string proc "process launch\n"))
      (error
       (when (and proc (process-live-p proc))
         (delete-process proc))
       (unless cph-keep-binaries (ignore-errors (delete-file bin)))
       (ignore-errors (delete-file input-file))
       (user-error "lldb session failed to start: %s"
                   (error-message-string err))))
    (cph--lldb-track-process proc bin input-file)
    proc))

(defun cph--lldb-kill-session ()
  "Stop the current CPH GUD debug session, if any."
  (let ((proc (and (process-live-p cph--debug-process)
                   cph--debug-process)))
    (when proc
      (let ((buf (process-buffer proc)))
        (delete-process proc)
        (when (and buf (buffer-live-p buf))
          (kill-buffer buf))))))

(defun cph-debug-testcase-at-point ()
  "Debug the testcase at point with lldb inside GUD.
Compile the solution with debug info and start a GUD lldb session on
the binary.  The session breaks at main, redirects the testcase input
from a temp file, and stops there, ready for your breakpoints and
stepping.

GUD is Emacs's own debugger interface, not a terminal: the source
file opens with the current line marked, and the GUD keys (C-c C-n
next, C-c C-s step, C-c C-r continue, C-c C-b set breakpoint, C-c C-p
print expression) drive the session from the *gud-* buffer.  The
binary and the input file are deleted when the session ends; set
`cph-keep-binaries' to keep the binary."
  (interactive)
  (let* ((id (cph--tc-at-point))
         (tc (and id (cl-find id (cph-problem-tests cph--problem)
                              :key #'cph-test-id))))
    (unless tc (user-error "No testcase at point"))
    (save-some-buffers t)
    (let* ((src (cph-problem-src-path cph--problem))
           (lang (cph--language-for-src src)))
      (setq cph--last-compile-error nil)
      (pcase (cph--compile src lang t)
        (`(,cmd . ,_cleanup)
         (let ((bin (car cmd)))
           ;; Replace any previous CPH debug session first; the lldb
           ;; process owns the binary for its whole lifetime.
           (cph--lldb-kill-session)
           ;; Compute the testcase number here: the GUD session below
           ;; switches the current buffer away from the judge buffer.
           (let* ((num (cph--tc-number tc))
                  (input-file
                   (cph--write-input-file (cph-test-input tc)))
                  (proc (cph--lldb-start bin input-file)))
             (setq cph--debug-process proc)
             (cph--log "lldb (GUD) debug session on %s, testcase %d, input %s"
                       (file-name-nondirectory bin) num input-file))))
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
  (when-let ((src (cph-problem-src-path cph--problem)))
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
