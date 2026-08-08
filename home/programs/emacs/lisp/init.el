;;; init.el -- Main Emacs configuration -*- lexical-binding: t -*-
(setq package-enable-at-startup nil)
(require 'straight)
(straight-use-package-mode +1)

(setq custom-file "~/.config/emacs/custom.el")
(when (file-exists-p custom-file)
  (load custom-file :noerror))

(add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))
(autoload 'audio-trimmer "audio-trimmer" "Audio trimmer with ffplay backend." t)
(require 'nmcli-wifi nil t)


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
(load-theme 'modus-vivendi)

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
  :ensure t
  :config
  (setq eglot-sync-connect 5)
  (setq eglot-autoshutdown t)
  (setq corfu-auto-delay 0.2))

(use-package corfu
  :ensure t
  :config
  (setq corfu-auto t)
  (setq corfu-auto-delay 0.2)
  (setq corfu-auto-prefix 1))

(use-package corfu-terminal
  :ensure t
  :config
  (unless (display-graphic-p)
    (corfu-terminal-mode 1)))

(use-package nix-mode
  :ensure t
  :hook
  (nix-mode . eglot-ensure)
  (nix-mode . corfu-mode)
  (before-save . (lambda () (when (eq major-mode 'nix-mode) (eglot-format-buffer))))
  :config
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nixd" "--inlay-hints=false")))
  (setq eglot-nix-server-path "nixd"
        eglot-nix-formatting-command ["nixfmt"]
        eglot-nix-nixpkgs-expr "import <nixpkgs> { }"
        eglot-nix-nixos-options-expr
        "(builtins.getFlake \"/home/lophophora/.config/nixos\").nixosConfigurations.flowerpot.options"))

(use-package magit
  :ensure t
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
  :ensure t
  :config
  (direnv-mode))

(use-package dashboard
  :ensure t
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
  :ensure t
  :defer t
  :hook (LaTeX-mode . (lambda ()
                        (TeX-engine-set 'luatex)
                        (TeX-PDF-mode 1)
                        (reftex-mode 1)))
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
  :ensure t
  :custom
  (nerd-icons-font-family "Hack Nerd Font"))

(eval-after-load 'nov
  '(load "~/.config/emacs/lisp/nov-config" nil t))

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


 (use-package kkp
   :straight (:host github :repo "benotn/kkp" :branch "master")
   :hook (tty-setup . global-kkp-mode))

;; hydra removed

(when (file-exists-p "~/.config/eca/deepseek-key")
  (setenv "DEEPSEEK_API_KEY"
          (with-temp-buffer
            (insert-file-contents "~/.config/eca/deepseek-key")
            (string-trim (buffer-string)))))

(use-package eca
  :bind
  (("C-c e" . eca)
   :map eca-chat-mode-map
   ("C-c ." . eca-transient-menu))
  :custom
  (eca-custom-command '("eca" "server"))
  (eca-completion-idle-delay 0.2)
  (eca-chat-window-side 'right)
  (eca-chat-window-width 56)
  (eca-chat-auto-add-cursor t)
  (eca-chat-auto-add-repomap t)
  :config
  (add-hook 'prog-mode-hook #'eca-completion-mode))

;; --- competitive programming: oj.el + quickrun ---
;; oj test requires the `oj` CLI from online-judge-tools (system package).
;; Packages live in site-lisp/ (cloned locally, no straight needed).
(add-to-list 'load-path (expand-file-name "site-lisp/oj" user-emacs-directory))
(require 'quickrun)
(require 'oj)
(setq oj-command-name "oj")
(setq oj-test-args '("--print-memory"))
(setq oj-compiler-c "clang")

;; oj-test with # comment lines stripped from stdin (oj layer filter).
;; Uses `compile' (non-interactive) so the zsh precmd OSC title sequence
;; and shell prompt never pollute the output.
(defun oj-test ()
  "Run `oj test' on the current buffer via `compile', filtering # lines."
  (interactive)
  (let* ((alist (quickrun--command-info
                 (quickrun--command-key (buffer-file-name))))
         (spec (mapcar (lambda (elm)
                         `(,(string-to-char (substring (car elm) 1)) . ,(cdr elm)))
                       (quickrun--template-argument alist (buffer-file-name))))
         (exec (or (alist-get :exec alist)
                   (alist-get :exec quickrun--default-tmpl-alist))))
    (when (consp exec)
      (let* ((compile-cmds
              (mapcar (lambda (arg) (format-spec arg spec))
                      (nreverse (cdr (reverse exec)))))
             (run-cmd (format-spec (car (last exec)) spec))
             (oj-cmd
              (concat
               "oj test"
               (when oj-test-args
                 (format " %s" (mapconcat #'identity oj-test-args " ")))
               " -c 'sh -c \"grep -v \\\"^#\\\" | " run-cmd "\"'"))
             (script (mapconcat #'identity
                                (append compile-cmds (list oj-cmd))
                                " && ")))
        (compile (concat "cd " (shell-quote-argument (expand-file-name default-directory))
                         " && " script))))))

;; C++: use clang++ for quickrun, clangd via eglot for LSP
(add-hook 'c++-mode-hook
          (lambda ()
            (setq-local quickrun-command-key "c++/clang++")
            (eglot-ensure)))
