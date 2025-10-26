{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    extraPackages = epkgs: [
      epkgs.pdf-tools
    ];
    extraConfig = ''
            ;; 基本设置
      (setq initial-buffer-choice
            (lambda ()
              (if (or (buffer-file-name)
                      (eq major-mode 'dired-mode))
                  (current-buffer)
                (find-file "~/.config/emacs/dashboard.org"))))

      ;; Load custom file if it exists
      (setq custom-file "~/.config/emacs/custom.el")
      (when (file-exists-p custom-file)
        (load custom-file :noerror))

      ;; Disable auto-save for dashboard.org
      (add-hook 'find-file-hook
                (lambda ()
                  (when (and (buffer-file-name)
                             (string= (buffer-file-name) (expand-file-name "~/.config/emacs/dashboard.org")))
                    (setq-local auto-save-default nil))))

      (add-hook 'after-init-hook
                (lambda ()
                  (when (display-graphic-p)
                    (set-face-attribute 'default nil :height 120) ; 字体大小 12 点
                    ;; 设置中文字符的字体为 Noto Sans CJK SC
                    (set-fontset-font t 'han "Noto Sans CJK SC" nil 'prepend)
                    ;; 设置全角符号的字体为 Noto Sans CJK SC
                    (set-fontset-font t '(#xFF00 . #xFFEF) "Noto Sans CJK SC" nil 'prepend)
                    (load-theme 'modus-vivendi t))))


      ;; 禁用工具栏和滚动条
      (tool-bar-mode -1)
      (scroll-bar-mode -1)

      ;; 设置包源
      (setq package-archives '(("gnu" . "https://mirrors.ustc.edu.cn/elpa/gnu/")
                               ("melpa" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
                               ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")))
      (package-initialize)

      ;; 安装和配置 eglot
      (use-package eglot
        :ensure t
        :config
        (setq eglot-sync-connect 5)
        (setq eglot-autoshutdown t)
        (setq corfu-auto-delay 0.2))

      (use-package corfu
        :ensure t
        :hook ((LaTeX-mode . corfu-mode)
               (nix-mode . corfu-mode))
        :config
        (setq corfu-auto t)           ; Enable auto-completion
        (setq corfu-auto-delay 0.2)
        (setq corfu-auto-prefix 1))

      (use-package tex
        :ensure auctex
        :hook ((LaTeX-mode . corfu-mode)
               (LaTeX-mode . eglot-ensure))
        :config
        (setq TeX-auto-save t)
        (setq TeX-PDF-mode t)
        (setq TeX-command-default "LuaLaTeX")
        (setq-default TeX-engine 'luatex)
        (add-to-list 'TeX-command-list
                     '("LuaLaTeX" "lualatex -synctex=1 -interaction=nonstopmode %s" TeX-run-command nil t :help "Run LuaLaTeX on LaTeX file")
                     t)
        (setq TeX-view-program-selection '((output-pdf "PDF Tools")))
        (setq TeX-view-program-list '(("PDF Tools" TeX-pdf-tools-sync-view)))
        (setq TeX-source-correlate-mode t)
        (setq TeX-source-correlate-start-server t)
        (with-eval-after-load 'pdf-tools
          (pdf-tools-install :no-query)))

      (use-package pdf-tools
        :ensure t
        :mode ("\\.pdf\\'" . pdf-view-mode)
        :config
        (pdf-tools-install))

      ;; 定义 dashboard 文件路径
      (defvar my/dashboard-file (expand-file-name "~/.config/emacs/dashboard.org"))

      ;; 修改 org-open-file 为全屏 dired
      (defun my/org-open-file-dired-full-window (orig-fun path &optional in-emacs line search)
        "在 dashboard 文件中打开目录时全屏显示 dired，其他情况使用默认行为。"
        (if (and (buffer-file-name)
                 (string= (buffer-file-name) my/dashboard-file)
                 (file-directory-p path))
            (progn
              (delete-other-windows)
              (dired path))
          (funcall orig-fun path in-emacs line search)))

      (with-eval-after-load 'org
        (advice-add 'org-open-file :around #'my/org-open-file-dired-full-window))

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

      (use-package nov
        :ensure t
        :mode ("\\.epub\\'" . nov-mode))

      (when (boundp 'native-comp-async-report-warnings)
        (setq native-comp-async-report-warnings '(error)))

      (use-package corfu-terminal
        :ensure t
        :config
        (unless (display-graphic-p)  ; 仅在终端（非图形界面）启用
          (corfu-terminal-mode 1)))

      (defun my-pdf-annot-print-annotation-header-advice (orig-fun a)
        "Advice to remove 'subject' from the annotation header."
        (let ((header
               (cond
                ((eq 'file (pdf-annot-get a 'type))
                 (let ((att (pdf-annot-get-attachment a)))
                   (format "File attachment `%s' of %s"
                           (or (cdr (assq 'filename att)) "unnamed")
                           (if (cdr (assq 'size att))
                               (format "size %s" (file-size-human-readable
                                                  (cdr (assq 'size att))))
                             "unknown size"))))
                (t
                 (format "%s"
                         (mapconcat
                          #'identity
                          (mapcar
                           (lambda (property)
                             (pdf-annot-print-property a property))
                           `(label modified))  ; Exclude subject
                          ";"))))))
          (propertize header 'face 'header-line
                      'intangible t 'read-only t
                      'display (propertize header 'face 'header-line))))

      ;; Remove any existing advice to avoid conflicts
      (advice-remove 'pdf-annot-print-annotation-header 'my-pdf-annot-print-annotation-header-advice)

      ;; Apply the corrected advice
      (advice-add 'pdf-annot-print-annotation-header :around #'my-pdf-annot-print-annotation-header-advice)

      (setq pdf-annot-default-annotation-properties
            '((t (label . "lophophora"))))

    '';
  };
}
