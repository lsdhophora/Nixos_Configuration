;;; init.el -- Main Emacs configuration -*- lexical-binding: t -*-
(setq package-enable-at-startup nil)

(setq custom-file "~/.config/emacs/custom.el")
(when (file-exists-p custom-file)
  (load custom-file :noerror))

(setq nobreak-char-display nil)
(set-face-attribute 'default nil :height 120)
(set-face-attribute 'default nil :font "IBM Plex Mono")
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
  :config
  (setq eglot-sync-connect 5)
  (setq eglot-autoshutdown t)
  ;; --- clangd LSP (clang-tools, system package) ---
  ;; The global default C++ standard is pinned in
  ;; ~/.config/clangd/config.yaml (managed by home/misc/clangd.nix);
  ;; drop a .clangd file next to a source tree to override it.
  (add-to-list 'eglot-server-programs '(c-mode . ("clangd" "--header-insertion=never")))
  (add-to-list 'eglot-server-programs '(c++-mode . ("clangd" "--header-insertion=never")))
  (add-hook 'c-mode-hook #'eglot-ensure)
  (add-hook 'c++-mode-hook #'eglot-ensure)
  (add-hook 'c-mode-hook #'corfu-mode)
  (add-hook 'c++-mode-hook #'corfu-mode)
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
  ;; :demand t: this Nix-provided Emacs never activates package autoloads
  ;; (package-enable-at-startup nil, no package-initialize), so the deferred
  ;; .nix auto-mode-alist autoload never registers.  Load eagerly so
  ;; nix-mode.el registers ".nix" itself (nix-mode.el has the
  ;; (add-to-list 'auto-mode-alist ...) in its body).
  :demand t
  :hook
  (nix-mode . eglot-ensure)
  (nix-mode . corfu-mode)
  (before-save . (lambda () (when (eq major-mode 'nix-mode) (eglot-format-buffer))))
  :config
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nixd" "--inlay-hints=false"))))

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

(use-package dashboard
  :config
  (dashboard-setup-startup-hook)
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

(use-package nerd-icons
  :custom
  (nerd-icons-font-family "Hack Nerd Font"))

(require 'emms-setup)
(emms-all)
(emms-default-players)
(setq emms-player-list '(emms-player-mpv))
(setq emms-player-mpv-command-name "mpv")
(setq emms-source-file-default-directory "~/Music/")

(require 'emms-info-native)
(setq emms-info-functions '(emms-info-native))

(setq emms-track-description-function
      (lambda (track)
        (or (emms-track-get track 'info-title)
            (file-name-sans-extension
             (file-name-nondirectory (emms-track-get track 'name))))))

;; --- competitive programming: cph.el (companion: lisp/cph/cph.user.js) ---
;; cph.el is symlinked into ~/.config/emacs/cph by files.nix
;; (mkOutOfStoreSymlink), so repo edits apply without rebuild.
(add-to-list 'load-path (expand-file-name "cph" user-emacs-directory))
(require 'cph)
(setq cph-default-language "cpp")
(setq cph-naming-style (quote title))
(setq cph-timeout 3000)
;; Start the problem-fetch server.  Ignore failure: the port may already
;; be taken by another Emacs instance.
(ignore-errors (cph-enable))
