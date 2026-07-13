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

(use-package hydra
  :ensure t)

(defhydra hydra-window (:color teal :hint nil)
  "
  ^Window^           ^Navigation^
 ══════════════════════════════════
  _0_ delete          _h_←  _j_↓  _k_↑  _l_→
  _v_ split vert      _H_⟺  _J_⇣  _K_⇡  _L_⟹
  _x_ split horiz
  _=_ balance         _q_ quit
"
  ("0" delete-window)
  ("v" split-window-right)
  ("x" split-window-below)
  ("=" balance-windows)
  ("h" windmove-left)
  ("j" windmove-down)
  ("k" windmove-up)
  ("l" windmove-right)
  ("H" enlarge-window-horizontally)
  ("J" enlarge-window)
  ("K" shrink-window)
  ("L" shrink-window-horizontally)
  ("q" nil :color blue))

(defhydra hydra-move (:color red :hint nil)
  "
  ^Move^
 ═══════════════════════
  _j_↓  _k_↑  _h_←  _l_→
  _w_ word  _b_ back-word
  _t_ bol   _e_ eol   _n_ next  _p_ prev
  _g_ top  _G_ bottom
  _q_ quit
"
  ("j" next-line)
  ("k" previous-line)
  ("h" backward-char)
  ("l" forward-char)
  ("w" forward-word)
  ("b" backward-word)
  ("t" beginning-of-line)
  ("e" move-end-of-line)
  ("n" scroll-up-command)
  ("p" scroll-down-command)
  ("g" beginning-of-buffer)
  ("G" end-of-buffer)
  ("q" nil :color blue))

(global-set-key (kbd "C-c w") #'hydra-window/body)
(global-set-key (kbd "C-c m") #'hydra-move/body)
