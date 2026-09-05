;;; init.el -- Main Emacs configuration -*- lexical-binding: t -*-
(setq package-enable-at-startup nil)

(setq custom-file "~/.config/emacs/custom.el")
(when (file-exists-p custom-file)
  (load custom-file :noerror))

(setq nobreak-char-display nil)
;; Font family and size in one call, so the size is not reset when the
;; family is applied.
(set-face-attribute 'default nil :font "IBM Plex Mono" :height 140)
(set-fontset-font t 'han "Noto Sans CJK SC" nil 'prepend)
(set-fontset-font t 'cjk-misc "Noto Sans CJK SC" nil 'prepend)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(when (not (display-graphic-p))
  (require 'term/xterm nil t)
  (setq xterm-set-window-title t)
  (xterm--init-frame-title))
(setq use-file-dialog nil)
(setq initial-major-mode 'org-mode)
(setq initial-scratch-message nil)
(load-theme 'modus-operandi)

(defun on-after-init ()
  (unless (display-graphic-p (selected-frame))
    (set-face-background 'default "unspecified-bg" (selected-frame))
    (set-face-background 'header-line "#7a358f" (selected-frame))))

(add-hook 'window-setup-hook 'on-after-init)

(defun my/prevent-empty-tooltip (str &rest _)
  (string-blank-p str))
(advice-add #'x-show-tip :before-until #'my/prevent-empty-tooltip)

(advice-add 'tab-bar--load-buttons :around
            (lambda (orig)
              (cl-letf (((symbol-function 'display-images-p) (lambda () nil)))
                (funcall orig))))

(use-package eglot
  ;; :defer t: `eglot-ensure' is autoloaded by Emacs core, so the hooks
  ;; below start eglot on the first C/C++/LaTeX buffer without loading
  ;; it at startup.  The :config runs when that first connection loads
  ;; it, before the server program is chosen.
  :defer t
  :hook
  (c-mode . eglot-ensure)
  (c++-mode . eglot-ensure)
  (c-mode . corfu-mode)
  (c++-mode . corfu-mode)
  :config
  (setq eglot-sync-connect 5)
  (setq eglot-autoshutdown t)
  ;; --- clangd LSP (clang-tools, system package) ---
  ;; The global default C++ standard is pinned in
  ;; ~/.config/clangd/config.yaml (managed by home/misc/clangd.nix);
  ;; drop a .clangd file next to a source tree to override it.
  (add-to-list 'eglot-server-programs '(c-mode . ("clangd" "--header-insertion=never")))
  (add-to-list 'eglot-server-programs '(c++-mode . ("clangd" "--header-insertion=never")))
  ;; --- texlab LSP (latex, system package) ---
  (add-to-list 'eglot-server-programs '(latex-mode . ("texlab")))
  (add-to-list 'eglot-server-programs '(LaTeX-mode . ("texlab"))))

(use-package corfu
  :config
  (setq corfu-auto t)
  (setq corfu-auto-delay 0.2)
  (setq corfu-auto-prefix 1))

;; Forward declarations keep the byte compiler silent when it compiles
;; init.el and its deferred lambdas.
(defvar corfu-terminal-mode)
(declare-function corfu-terminal-mode "corfu-terminal")
(with-eval-after-load 'corfu-terminal
  (unless (display-graphic-p)
    (corfu-terminal-mode 1)))

(use-package nix-mode
  ;; Deferred: Nix-provided packages never activate their autoloads
  ;; (package-enable-at-startup nil, no package-initialize), so the .nix
  ;; auto-mode-alist association is registered by hand below and
  ;; nix-mode.el loads on the first .nix file instead of at startup.
  :defer t
  :init
  (autoload 'nix-mode "nix-mode" nil t)
  (add-to-list 'auto-mode-alist '("\\.nix\\'" . nix-mode))
  :hook
  (nix-mode . eglot-ensure)
  (nix-mode . corfu-mode)
  (before-save . (lambda () (when (eq major-mode 'nix-mode) (eglot-format-buffer))))
  :config
  ;; eglot may still be deferred when nix-mode loads; register the nixd
  ;; server the moment eglot does load.
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(nix-mode . ("nixd" "--inlay-hints=false")))))

(use-package rust-ts-mode
  ;; Deferred: rust-ts-mode is built into Emacs.  Unlike C/C++/LaTeX,
  ;; it does NOT register .rs in auto-mode-alist itself, so the mapping
  ;; is added by hand here (:init runs when init.el loads).  The rust
  ;; tree-sitter grammar, rust-analyzer and rustfmt come from the nix
  ;; profile (home/packages.nix + files.nix).
  :defer t
  :init
  (add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
  :hook
  (rust-ts-mode . eglot-ensure)
  (rust-ts-mode . corfu-mode)
  (before-save . (lambda () (when (eq major-mode 'rust-ts-mode) (eglot-format-buffer))))
  :config
  ;; rust-analyzer formats through rustfmt; eglot may still be deferred
  ;; when rust-ts-mode loads, so register the server once eglot loads.
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '(rust-ts-mode . ("rust-analyzer")))

    ;; rust-analyzer has no cargo-less folder mode: with a folder root
    ;; and no Cargo.toml it reports "Failed to discover workspace" and
    ;; serves nothing.  The supported standalone path is LSP detached
    ;; files: the client starts the server without workspace folders
    ;; and lists the file in the `detachedFiles' initialization option.
    ;; Eglot always sends a workspace folder, so these advices emulate
    ;; detached mode when the rust buffer has no cargo project above
    ;; it.  Real cargo projects keep the normal path.
    (defun my/rust-cargo-root ()
      "Return the nearest dir with Cargo.toml or rust-project.json."
      (or (locate-dominating-file default-directory "Cargo.toml")
          (locate-dominating-file default-directory "rust-project.json")))

    (defun my/rust-standalone-p ()
      "Non-nil for a rust buffer outside any cargo project."
      (and (buffer-file-name)
           (derived-mode-p 'rust-ts-mode)
           (not (my/rust-cargo-root))))

    (defun my/eglot-workspace-folders (folders &rest _)
      "Adapt the workspace folders for rust buffers.
Standalone rust buffers (CPH solution files, no cargo project above)
get no folder, which makes rust-analyzer use detached-file mode.
Rust buffers inside a cargo project get the cargo root as their
folder, even when eglot's project root is a parent git root."
      (cond
       ((my/rust-standalone-p) [])
       ((and (derived-mode-p 'rust-ts-mode)
             (buffer-file-name)
             (my/rust-cargo-root))
        (let ((dir (my/rust-cargo-root)))
          (vector (list :uri (eglot-path-to-uri dir)
                        :name (file-name-nondirectory
                               (directory-file-name dir))))))
       (t folders)))
    (advice-add 'eglot-workspace-folders :filter-return
                #'my/eglot-workspace-folders)

    (defun my/eglot-initialization-options (fn server)
      "List the current file as a detached file for standalone rust."
      (let ((base (funcall fn server)))
        (if (my/rust-standalone-p)
            (let ((f (buffer-file-name)))
              (when f
                ;; Marker for the noise filter (kept on the server, not
                ;; in the options we send to rust-analyzer).
                (setf (eglot--saved-initargs server)
                      (plist-put (eglot--saved-initargs server)
                                 :my-standalone-rust t))
                ;; eglot--{} is a hash table (jsonrpc keys must be
                ;; strings); a per-server :initializationOptions entry
                ;; is a plist (keyword keys are fine there).
                (if (hash-table-p base)
                    (puthash "detachedFiles" (vector f) base)
                  (plist-put base :detachedFiles (vector f))))
              base)
          base)))
    (advice-add 'eglot-initialization-options :around
                #'my/eglot-initialization-options)

    (defun my/rust-server-standalone-p (server)
      "Non-nil when SERVER serves a rust project without cargo."
      (let ((root (ignore-errors (project-root (eglot--project server)))))
        (and root
             (not (locate-dominating-file root "Cargo.toml"))
             (not (locate-dominating-file root "rust-project.json")))))

    ;; Standalone rust-analyzer still tries `cargo check' once at
    ;; startup (no manifest: two warnings) and its folder-mode errors
    ;; are meaningless in detached mode.  Hide those specific messages
    ;; for servers we started as standalone rust, so detached rust
    ;; buffers do not spam *Messages*.
    (defun my/eglot-hide-rust-noise (fn server method &rest params)
      "Suppress known rust-analyzer noise for standalone rust servers."
      (let* ((msg (and (stringp (plist-get params :message))
                       (plist-get params :message)))
             (noise (and msg
                         (string-match-p
                          "Failed to discover workspace\\|Failed to load workspaces\\|Cargo watcher failed"
                          msg)))
             (standalone (or (plist-get (ignore-errors
                                          (eglot--saved-initargs server))
                                        :my-standalone-rust)
                             (my/rust-server-standalone-p server)))
             ;; After eglot-shutdown the server's project is gone, so a
             ;; late duplicate may not be tagged as standalone.  Drop
             ;; those warning-level (type 2) duplicates too; real
             ;; error-level (type 1) reports stay visible.
             (warn-only (eq (plist-get params :type) 2)))
        (if (and (eq method 'window/showMessage)
                 noise
                 (or standalone warn-only))
            nil
          (apply fn server method params))))
    (advice-add 'eglot-handle-notification :around
                #'my/eglot-hide-rust-noise)))

(use-package magit
  :bind (("C-x g" . magit-status))
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1))
(add-hook 'python-mode-hook
          (lambda ()
            (direnv-update-environment)
            (when (executable-find "pylsp")
              (eglot-ensure)
              (corfu-mode 1))))

(use-package direnv
  :config
  (direnv-mode))

;; --- dashboard ---
;; Deferred: dashboard.el only needs to render at the startup hooks,
;; which run after init.el.  Register the same hooks that
;; `dashboard-setup-startup-hook' would register (package autoloads are
;; never activated in this Nix setup, so declare the autoloads by hand).
(autoload 'dashboard-initialize "dashboard")
(autoload 'dashboard-insert-startupify-lists "dashboard")
(autoload 'dashboard-resize-on-hook "dashboard")
(when (< (length command-line-args) 2)
  (add-hook 'after-init-hook #'dashboard-insert-startupify-lists)
  (add-hook 'emacs-startup-hook #'dashboard-initialize)
  (add-hook 'window-size-change-functions #'dashboard-resize-on-hook 100)
  (add-hook 'window-setup-hook #'dashboard-resize-on-hook))
(use-package dashboard
  :defer t
  :config
  (setq dashboard-startup-banner 2)
  (setq dashboard-center-content t)
  (setq dashboard-vertically-center-content t)
  (setq dashboard-display-icons-p nil)
  (setq dashboard-init-info (lambda () ""))
  (setq dashboard-set-footer nil)
  (setq dashboard-show-shortcuts nil)
  (setq dashboard-set-navigator nil)
  (setq dashboard-items '())
  :custom-face
  (dashboard-items-face ((t :height 1.0))))

(defun my/disable-text-scale-commands-in-dashboard ()
  "Disable all text scaling commands in dashboard buffer only, completely silent."
  (when (eq major-mode 'dashboard-mode)
    (dolist (cmd '(text-scale-increase
                   text-scale-decrease
                   text-scale-adjust
                   text-scale-set
                   text-scale-mode-step
                   text-scale-pinch))
      (when (fboundp cmd)
        (local-set-key (vector 'remap cmd) #'ignore)))))
(add-hook 'dashboard-mode-hook #'my/disable-text-scale-commands-in-dashboard)

(use-package auctex
  ;; :demand t: same autoload caveat as nix-mode above; .tex files would
  ;; otherwise stay in the built-in latex-mode.
  :demand t
  :hook (LaTeX-mode . (lambda ()
                        (TeX-engine-set 'luatex)
                        (TeX-PDF-mode 1)
                        (reftex-mode 1)
                        ;; texlab for LSP completion/diagnostics
                        (when (executable-find "texlab")
                          (eglot-ensure))))
  :custom
  (TeX-auto-save t)
  (TeX-parse-self t)
  (TeX-master nil)
  (TeX-view-program-selection '((output-pdf "Papers")))
  (TeX-view-program-list
   '(("Papers" "papers ./%o")))
  :config
  (require 'tex)
  (setf (alist-get "latexmk" TeX-command-list nil nil #'equal)
        '("latexmk"
          "latexmk -pdf -pdflatex=\"lualatex -synctex=0 %O %S\" -shell-escape %s"
          TeX-run-command nil t
          :help "Run latexmk with LuaLaTeX"))
  (setq TeX-file-line-error t)
  (setq TeX-source-correlate-start-server t))

;; --- nerd-icons ---
;; Deferred: nerd-icons is only needed when icons are rendered, never
;; at startup.  The autoloads file keeps every M-x nerd-icons-* command
;; available without loading the package.
(load "nerd-icons-autoloads" nil t)
(use-package nerd-icons
  :defer t
  :custom
  (nerd-icons-font-family "Hack Nerd Font"))

;; --- emms (music player) ---
;; Deferred: Nix packages never activate their autoloads, so load
;; emms-autoloads.el explicitly to keep every M-x emms-* command
;; available; the player and info backends then load on the first emms
;; command instead of at startup.  Loads only what mpv needs (emms-all
;; would pull in every player and info backend).
(load "emms-autoloads" nil t)
(use-package emms
  :defer t
  :config
  (require 'emms-player-mpv)
  (require 'emms-info-native)
  (setq emms-player-list '(emms-player-mpv))
  (setq emms-player-mpv-command-name "mpv")
  (setq emms-source-file-default-directory "~/Music/")
  (setq emms-info-functions '(emms-info-native))
  (setq emms-track-description-function
        (lambda (track)
          (or (emms-track-get track 'info-title)
              (file-name-sans-extension
               (file-name-nondirectory (emms-track-get track 'name)))))))

;; --- competitive programming: cph.el (companion: lisp/cph/cph.user.js) ---
;; cph.el is symlinked into ~/.config/emacs/cph by files.nix
;; (mkOutOfStoreSymlink), so repo edits apply without rebuild.
(add-to-list 'load-path (expand-file-name "cph" user-emacs-directory))
(require 'cph)
(setq cph-default-language "cpp")
;; LibreOJ problems are solved in Rust, other sites keep the C++
;; default.  Match on the URL, first rule wins.
(setq cph-site-languages '(("loj\\.ac" . "rs")))
(setq cph-naming-style (quote title))
(setq cph-timeout 3000)
;; Start the problem-fetch server.  Ignore failure: the port may already
;; be taken by another Emacs instance.
(ignore-errors (cph-enable))
