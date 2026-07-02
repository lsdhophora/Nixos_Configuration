;;; init.el -- Main Emacs configuration -*- lexical-binding: t -*-

(unless (display-graphic-p)
  (define-key key-translation-map (kbd "ESC <up>") (kbd "M-<up>"))
  (define-key key-translation-map (kbd "ESC <down>") (kbd "M-<down>")))

(setq custom-file "~/.config/emacs/custom.el")
(when (file-exists-p custom-file)
  (load custom-file :noerror))

(add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))
(autoload 'audio-trimmer "audio-trimmer" "Audio trimmer with ffplay backend." t)


(setq nobreak-char-display nil)
(set-face-attribute 'default nil :height 120)
(set-face-attribute 'default nil :font "IBM Plex Mono")
(set-fontset-font t 'han "Noto Sans CJK SC" nil 'prepend)
(set-fontset-font t 'cjk-misc "Noto Sans CJK SC" nil 'prepend)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(setq use-file-dialog nil)
(load-theme 'modus-vivendi)

(defun my/prevent-empty-tooltip (str &rest _)
  (string-blank-p str))
(advice-add #'x-show-tip :before-until #'my/prevent-empty-tooltip)

(advice-add 'tab-bar--load-buttons :around
            (lambda (orig)
              (cl-letf (((symbol-function 'display-images-p) (lambda () nil)))
                (funcall orig))))

(setq shell-file-name (executable-find "bash"))
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

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

(use-package meow
  :ensure t
  :config
  (defun meow-setup ()
    (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
    (meow-motion-define-key
     '("j" . meow-next)
     '("k" . meow-prev)
     '("<escape>" . ignore))
    (meow-leader-define-key
     '("1" . meow-digit-argument)
     '("2" . meow-digit-argument)
     '("3" . meow-digit-argument)
     '("4" . meow-digit-argument)
     '("5" . meow-digit-argument)
     '("6" . meow-digit-argument)
     '("7" . meow-digit-argument)
     '("8" . meow-digit-argument)
     '("9" . meow-digit-argument)
     '("0" . meow-digit-argument)
     '("/" . meow-keypad-describe-key)
     '("?" . meow-cheatsheet))
    (meow-normal-define-key
     '("0" . meow-expand-0)
     '("9" . meow-expand-9)
     '("8" . meow-expand-8)
     '("7" . meow-expand-7)
     '("6" . meow-expand-6)
     '("5" . meow-expand-5)
     '("4" . meow-expand-4)
     '("3" . meow-expand-3)
     '("2" . meow-expand-2)
     '("1" . meow-expand-1)
     '("-" . negative-argument)
     '(";" . meow-reverse)
     '("," . meow-inner-of-thing)
     '("." . meow-bounds-of-thing)
     '("[" . meow-beginning-of-thing)
     '("]" . meow-end-of-thing)
     '("a" . meow-append)
     '("A" . meow-open-below)
     '("b" . meow-back-word)
     '("B" . meow-back-symbol)
     '("c" . meow-change)
     '("d" . meow-delete)
     '("D" . meow-backward-delete)
     '("e" . meow-next-word)
     '("E" . meow-next-symbol)
     '("f" . meow-find)
     '("g" . meow-cancel-selection)
     '("G" . meow-grab)
     '("h" . meow-left)
     '("H" . meow-left-expand)
     '("i" . meow-insert)
     '("I" . meow-open-above)
     '("j" . meow-next)
     '("J" . meow-next-expand)
     '("k" . meow-prev)
     '("K" . meow-prev-expand)
     '("l" . meow-right)
     '("L" . meow-right-expand)
     '("m" . meow-join)
     '("n" . meow-search)
     '("o" . meow-block)
     '("O" . meow-to-block)
     '("p" . meow-yank)
     '("q" . meow-quit)
     '("Q" . meow-goto-line)
     '("r" . meow-replace)
     '("R" . meow-swap-grab)
     '("s" . meow-kill)
     '("t" . meow-till)
     '("u" . meow-undo)
     '("U" . meow-undo-in-selection)
     '("v" . meow-visit)
     '("w" . meow-mark-word)
     '("W" . meow-mark-symbol)
     '("x" . meow-line)
     '("X" . meow-goto-line)
     '("y" . meow-save)
     '("Y" . meow-sync-grab)
     '("z" . meow-pop-selection)
     '("'" . repeat)
     '("<escape>" . ignore)))
  (meow-setup)
  (meow-global-mode 1)
  (add-hook 'magit-mode-hook #'meow-motion-mode))
