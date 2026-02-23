{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    extraPackages =
      epkgs: with epkgs; [
        direnv
        auctex
        nix-mode
        magit
        nov
        vterm
        nerd-icons
        dashboard
        trashed
      ];
    extraConfig = ''
      ;; -*- lexical-binding: t -*-
      (setq custom-file "~/.config/emacs/custom.el")
      (when (file-exists-p custom-file)
       (load custom-file :noerror))

      (add-hook 'after-init-hook
          (lambda ()
            (when (display-graphic-p)
              (load-theme 'modus-vivendi t))))

      (add-to-list 'initial-frame-alist '(width . 72))
      (add-to-list 'initial-frame-alist '(height . 32))

      (setq nobreak-char-display nil)
      (set-face-attribute 'default nil :height 120)
      (set-face-attribute 'default nil :font "IBM Plex Mono")
      (set-fontset-font t 'han "Noto Sans CJK SC" nil 'prepend)
      (set-fontset-font t 'cjk-misc "Noto Sans CJK SC" nil 'prepend)

      (tool-bar-mode -1)
      (scroll-bar-mode -1)
      (menu-bar-mode -1)

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
       (nix-mode . corfu-mode) ;; So that envrc mode will work
       (before-save . (lambda () (when (eq major-mode 'nix-mode) (eglot-format-buffer))))
       :config
       (add-to-list 'eglot-server-programs
                    '(nix-mode . ("nixd" "--inlay-hints=false")))
       (setq eglot-nix-server-path "nixd"
             eglot-nix-formatting-command ["nixfmt"]
             eglot-nix-nixpkgs-expr "import <nixpkgs> { }"
             eglot-nix-nixos-options-expr "(builtins.getFlake \"/home/nb/nixos\").nixosConfigurations.mnd.options"
             eglot-nix-home-manager-options-expr "(builtins.getFlake \"/home/nb/nixos\").homeConfigurations.\"nb@mnd\".options"))

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
        (setq dashboard-agenda-prefix-format " %i %s ")
        (setq dashboard-items '((agenda . 50)))
        (setq dashboard-item-names '(("Agenda for today:" . "My Agenda")
                                     ("Agenda for the coming week:" . "My Agenda")))
        (setq dashboard-filter-agenda-entry 'dashboard-no-filter-agenda)
        (setq org-directory "~/.config/emacs")
        (setq org-agenda-files '("~/.config/emacs/agenda.org"))
        (setq org-default-notes-file "~/.config/emacs/agenda.org")
        (setq org-log-done 'time)
        (setq org-todo-keywords
              '((sequence "TODO(t)" "IN-PROGRESS(p)" "|" "DONE(d)")))
        (setq org-todo-keyword-faces
              '(("TODO" . (:foreground "red" :weight bold))
                ("IN-PROGRESS" . (:foreground "red" :weight bold))
                ("DONE" . (:foreground "forest green" :weight bold)))))
        :custom-face
        ((dashboard-items-face ((t (:height 1.0)))))

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
                              (TeX-source-correlate-mode 1)
                              (reftex-mode 1)))
        :custom
        (TeX-auto-save t)
        (TeX-parse-self t)
        (TeX-master nil)
        (TeX-source-correlate-method 'synctex)
        (TeX-view-program-selection '((output-pdf "Papers")))
        (TeX-view-program-list
        '(("Papers" "Papers ./%o")))

        :config
        (require 'tex)
        (setf (alist-get "latexmk" TeX-command-list nil nil #'equal)
              '("latexmk"
                "latexmk -pdf -pdflatex=lualatex -synctex=1 -shell-escape %s"
                TeX-run-command nil t
                :help "Run latexmk with LuaLaTeX + SyncTeX"))
        (setq TeX-file-line-error t)
        (setq TeX-source-correlate-start-server t))

        (use-package nov
          :ensure t
          :mode ("\\.epub\\'" . nov-mode)
          :config
          (setq nov-text-width t)
          (setq visual-fill-column-center-text t)
          (add-hook 'nov-mode-hook 'visual-line-mode)
          (add-hook 'nov-mode-hook (lambda () (setq truncate-lines nil)))

          (defun my-nov-font-setup ()
            (face-remap-add-relative 'variable-pitch
                                      :family "IBM Plex Sans"
                                      :height 1.0)
            (setq-local text-quote-style 'straight)
            (setq-local line-spacing 0.1)
            (setq-local word-wrap nil)
            (setq-local word-wrap-by-category t))
          (add-hook 'nov-mode-hook #'my-nov-font-setup)

          (defcustom nov-header-line-format-no-chapter "%t"
            "Header line format when chapter part is hidden."
            :type 'string
            :group 'nov)

          (defvar-local nov-hide-chapter-part nil)

          (defun nov-toggle-chapter-display ()
            "Toggle display of chapter part in header line and save state."
            (interactive)
            (setq nov-hide-chapter-part (not nov-hide-chapter-part))
            (let ((identifier (cdr (assq 'identifier nov-metadata)))
                  (index nov-documents-index))
              (nov-save-place identifier index (point)))
            (nov-render-document)
            (message "Chapter display %s" (if nov-hide-chapter-part "disabled" "enabled")))

          (defun my-nov-render-title-advice (orig-func dom)
            (let ((nov-header-line-format
                   (if nov-hide-chapter-part
                       nov-header-line-format-no-chapter
                     nov-header-line-format)))
              (funcall orig-func dom)))
          (advice-add 'nov-render-title :around #'my-nov-render-title-advice)

          (defun nov-save-place-with-state (identifier index point)
            (when nov-save-place-file
              (let* ((place `(,identifier (index . ,index)
                                          (point . ,point)
                                          (hide-chapter . ,nov-hide-chapter-part)))
                     (places (cons place (assq-delete-all identifier (nov-saved-places))))
                     print-level
                     print-length)
                (with-temp-file nov-save-place-file
                  (insert (prin1-to-string places))))))
          (advice-add 'nov-save-place :override #'nov-save-place-with-state)

          (defun nov-restore-display-state ()
            "Restore the chapter display state from saved place data."
            (when (and nov-metadata nov-documents)
              (let* ((identifier (cdr (assq 'identifier nov-metadata)))
                     (place (nov-saved-place identifier)))
                (when place
                  (setq nov-hide-chapter-part (cdr (assq 'hide-chapter place))))
                (let ((current-path (cdr (aref nov-documents nov-documents-index))))
                  (when current-path
                    (let* ((html (nov-slurp current-path))
                           (dom (with-temp-buffer
                                  (insert html)
                                  (libxml-parse-html-region (point-min) (point-max))))
                           (title-node (esxml-query "title" dom)))
                      (when title-node
                        (nov-render-title title-node))))))))
          (add-hook 'nov-mode-hook #'nov-restore-display-state)

          (defun nov-next-document-last-chapter-guard (orig-func &optional count)
            "Advice: do nothing if already on the last chapter."
            (let ((target (+ nov-documents-index (or count 1))))
              (if (>= target (length nov-documents))
                  (message "Already at the last chapter.")
                (funcall orig-func (or count 1)))))
          (advice-add 'nov-next-document :around #'nov-next-document-last-chapter-guard))

         (use-package nerd-icons
           :ensure t
           :custom
         (nerd-icons-font-family "Hack Nerd Font"))
    '';
  };

  home.file.".config/emacs/init.el".text = "";
  home.file.".config/emacs/early-init.el".text = ''
    (add-to-list 'initial-frame-alist '(width . 100))
    (add-to-list 'initial-frame-alist '(height . 32))
  '';
  home.file.".local/share/applications/emacsclient-mail.desktop".text = "";
  home.file.".local/share/applications/emacs-mail.desktop".text = "";
  home.file.".local/share/applications/emacsclient.desktop".text = "";

  home.packages = with pkgs; [
    vips
    nerd-fonts.hack
    epub-thumbnailer
  ];
}
