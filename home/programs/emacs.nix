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

      (add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))
      (autoload 'audio-trimmer "audio-trimmer" "Audio trimmer with ffplay backend." t)

      (add-hook 'after-init-hook
          (lambda ()
            (when (display-graphic-p)
              (load-theme 'modus-vivendi t))))

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
       (nix-mode . corfu-mode)
       (before-save . (lambda () (when (eq major-mode 'nix-mode) (eglot-format-buffer))))
       :config
       (add-to-list 'eglot-server-programs
                    '(nix-mode . ("nixd" "--inlay-hints=false")))
       (setq eglot-nix-server-path "nixd"
             eglot-nix-formatting-command ["nixfmt"]
             eglot-nix-nixpkgs-expr "import <nixpkgs> { }"
             eglot-nix-nixos-options-expr "(builtins.getFlake \"/home/lophophora/.config/nixos\").nixosConfigurations.flowerpot.options"))

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
                "latexmk -pdf -pdflatex="lualatex -synctex=0 %O %S" -shell-escape %s"
                TeX-run-command nil t
                :help "Run latexmk with LuaLaTeX"))
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
    (setq initial-frame-alist
      '((top . 1) (left . 1) (width . 80) (height . 32)))
  '';
  home.file.".local/share/applications/emacsclient-mail.desktop".text = "";
  home.file.".local/share/applications/emacs-mail.desktop".text = "";
  home.file.".local/share/applications/emacsclient.desktop".text = "";

  home.packages = with pkgs; [
    vips
    nerd-fonts.hack
    epub-thumbnailer
  ];

  home.file.".config/emacs/site-lisp/audio-trimmer.el".text = ''
    (defvar audio-trimmer-file nil)
    (defvar audio-trimmer-duration 0.0)
    (defvar audio-trimmer-position 0.0)
    (defvar audio-trimmer-is-playing nil)
    (defvar audio-trimmer-player-process nil)
    (defvar audio-trimmer-timer nil)
    (defvar audio-trimmer-buffer nil)
    (defvar audio-trimmer-trim-start nil)
    (defvar audio-trimmer-trim-end nil)
    (defvar audio-trimmer-in-preview nil)

    (defun audio-trimmer--format-time (seconds)
      "Convert seconds to mm:ss.s format."
      (if (null seconds)
          "00:00.0"
        (let* ((s (mod seconds 60))
               (m (floor (/ seconds 60))))
          (format "%02d:%04.1f" m s))))

    (defun audio-trimmer--get-duration (file)
      "Get audio duration using ffprobe."
      (with-temp-buffer
        (call-process "ffprobe" nil t nil
                      "-v" "quiet" "-show_entries" "format=duration"
                      "-of" "default=noprint_wrappers=1:nokey=1"
                      (expand-file-name file))
        (let ((dur (string-to-number (string-trim (buffer-string)))))
          (if (> dur 0) dur 0.0))))

    (defun audio-trimmer--current-position ()
      "Get current playback position."
      (min audio-trimmer-duration audio-trimmer-position))

    (defun audio-trimmer--start-player ()
      "Start ffplay from current position."
      (when (and audio-trimmer-player-process (process-live-p audio-trimmer-player-process))
        (delete-process audio-trimmer-player-process))
      (setq audio-trimmer-player-process
            (start-process "audio-trimmer-player" nil
                           "ffplay" "-nodisp" "-autoexit" "-loglevel" "quiet"
                           "-ss" (format "%.3f" audio-trimmer-position)
                           audio-trimmer-file))
      (set-process-sentinel audio-trimmer-player-process #'audio-trimmer--player-sentinel)
      (setq audio-trimmer-is-playing t)
      (setq audio-trimmer-timer (run-with-timer 0.05 0.05 #'audio-trimmer--update-position)))

    (defun audio-trimmer--player-sentinel (proc event)
      "Handle ffplay process exit."
      (when (string-match "finished\\|exited\\|killed" event)
        (setq audio-trimmer-is-playing nil)
        (when audio-trimmer-timer
          (cancel-timer audio-trimmer-timer)
          (setq audio-trimmer-timer nil))
        (when (equal (process-status proc) 'exit)
          (setq audio-trimmer-position audio-trimmer-duration))
        (audio-trimmer--redraw)))

    (defun audio-trimmer--stop-player ()
      "Stop ffplay and update position."
      (when (and audio-trimmer-player-process (process-live-p audio-trimmer-player-process))
        (delete-process audio-trimmer-player-process))
      (setq audio-trimmer-is-playing nil
            audio-trimmer-in-preview nil)
      (when audio-trimmer-timer
        (cancel-timer audio-trimmer-timer)
        (setq audio-trimmer-timer nil)))

    (defun audio-trimmer--update-position ()
      "Update position while playing."
      (when audio-trimmer-is-playing
        (when (and audio-trimmer-player-process (process-live-p audio-trimmer-player-process))
          (setq audio-trimmer-position (min audio-trimmer-duration (+ audio-trimmer-position 0.05)))
          (audio-trimmer--redraw)
          (when (and audio-trimmer-in-preview
                     audio-trimmer-trim-end
                     (>= audio-trimmer-position audio-trimmer-trim-end))
            (audio-trimmer--stop-player)
            (message "Preview ended at trim point: %s" (audio-trimmer--format-time audio-trimmer-position))))))

    (defun audio-trimmer--redraw ()
      "Update display."
      (when (buffer-live-p audio-trimmer-buffer)
        (with-current-buffer audio-trimmer-buffer
          (let ((inhibit-read-only t)
                (pos (audio-trimmer--current-position)))
            (save-excursion
              (goto-char (point-min))
              (when (search-forward "Position: " nil t)
                (delete-region (point) (line-end-position))
                (insert (format "%s / %s%s"
                                (audio-trimmer--format-time pos)
                                (audio-trimmer--format-time audio-trimmer-duration)
                                (if audio-trimmer-is-playing " [PLAYING]" ""))))
              (when (search-forward "Trim: " nil t)
                (delete-region (point) (line-end-position))
                (if (and audio-trimmer-trim-start audio-trimmer-trim-end (> audio-trimmer-trim-end audio-trimmer-trim-start))
                    (insert (format "%s → %s (%.1fs)"
                                    (audio-trimmer--format-time audio-trimmer-trim-start)
                                    (audio-trimmer--format-time audio-trimmer-trim-end)
                                    (- audio-trimmer-trim-end audio-trimmer-trim-start)))
                  (insert "(not set)"))))))))

    (defun audio-trimmer--play ()
      "Toggle play/pause."
      (interactive)
      (if audio-trimmer-is-playing
          (progn
            (audio-trimmer--stop-player)
            (message "Paused at %s" (audio-trimmer--format-time audio-trimmer-position)))
        (if (>= audio-trimmer-position audio-trimmer-duration)
            (setq audio-trimmer-position 0.0))
        (audio-trimmer--start-player)
        (message "Playing from %s" (audio-trimmer--format-time audio-trimmer-position))))

    (defun audio-trimmer--seek (seconds)
      "Seek to position in seconds."
      (interactive "nSeek to seconds: ")
      (let ((was-playing audio-trimmer-is-playing))
        (when was-playing (audio-trimmer--stop-player))
        (setq audio-trimmer-position (max 0 (min audio-trimmer-duration seconds)))
        (audio-trimmer--redraw)
        (when was-playing (audio-trimmer--start-player))
        (message "Seeked to %s" (audio-trimmer--format-time audio-trimmer-position))))

    (defun audio-trimmer--seek-relative (delta)
      "Seek forward/backward by DELTA seconds."
      (interactive)
      (audio-trimmer--seek (+ audio-trimmer-position delta)))

    (defun audio-trimmer--set-start ()
      "Set trim start to current position."
      (interactive)
      (setq audio-trimmer-trim-start audio-trimmer-position)
      (message "Start set to %s" (audio-trimmer--format-time audio-trimmer-trim-start))
      (audio-trimmer--redraw))

    (defun audio-trimmer--set-end ()
      "Set trim end to current position."
      (interactive)
      (setq audio-trimmer-trim-end audio-trimmer-position)
      (message "End set to %s" (audio-trimmer--format-time audio-trimmer-trim-end))
      (audio-trimmer--redraw))

    (defun audio-trimmer--preview ()
      "Preview trim segment."
      (interactive)
      (if audio-trimmer-trim-start
          (let ((was-playing audio-trimmer-is-playing))
            (when was-playing (audio-trimmer--stop-player))
            (setq audio-trimmer-position audio-trimmer-trim-start
                  audio-trimmer-in-preview t)
            (audio-trimmer--redraw)
            (audio-trimmer--start-player)
            (message "Previewing from %s" (audio-trimmer--format-time audio-trimmer-trim-start)))
        (message "No trim start set!")))

    (defun audio-trimmer--trim ()
      "Execute trim with ffmpeg."
      (interactive)
      (if (or (null audio-trimmer-trim-end) (null audio-trimmer-trim-start) (<= audio-trimmer-trim-end audio-trimmer-trim-start))
          (message "Please set valid start and end times first!")
        (let* ((out (concat (file-name-sans-extension audio-trimmer-file)
                            "_trimmed."
                            (file-name-extension audio-trimmer-file)))
               (dur (- audio-trimmer-trim-end audio-trimmer-trim-start)))
          (call-process "ffmpeg" nil nil nil
                        "-ss" (format "%.3f" audio-trimmer-trim-start)
                        "-i" audio-trimmer-file
                        "-t" (format "%.3f" dur)
                        "-c" "copy" "-y" out)
          (message "Trim completed! -> %s" out))))

    (defun audio-trimmer--quit ()
      "Cleanup and quit."
      (interactive)
      (audio-trimmer--stop-player)
      (kill-buffer audio-trimmer-buffer))

    (define-derived-mode audio-trimmer-mode special-mode "Audio-Trimmer"
      "Major mode for trimming audio (ffplay backend)."
      (setq buffer-read-only t)
      (local-set-key " " #'audio-trimmer--play)
      (local-set-key "j" #'audio-trimmer--seek)
      (local-set-key (kbd "<left>") (lambda () (interactive) (audio-trimmer--seek-relative -5.0)))
      (local-set-key (kbd "<right>") (lambda () (interactive) (audio-trimmer--seek-relative 5.0)))
      (local-set-key (kbd "<up>") (lambda () (interactive) (audio-trimmer--seek-relative -30.0)))
      (local-set-key (kbd "<down>") (lambda () (interactive) (audio-trimmer--seek-relative 30.0)))
      (local-set-key "s" #'audio-trimmer--set-start)
      (local-set-key "e" #'audio-trimmer--set-end)
      (local-set-key "p" #'audio-trimmer--preview)
      (local-set-key "t" #'audio-trimmer--trim)
      (local-set-key "q" #'audio-trimmer--quit))

    (defun audio-trimmer--audio-p (file)
      "Check if FILE is an audio file by extension."
      (let ((ext (downcase (or (file-name-extension file) ""))))
        (member ext '("mp3" "wav" "flac" "ogg" "m4a" "aac" "wma" "opus" "ape" "aiff" "au" "ra" "mid" "midi"))))

    (defun audio-trimmer (file)
      "Open the audio trimmer (ffplay backend)."
      (interactive "fSelect audio file: ")
      (when (file-directory-p file)
        (error "Directories are not supported: %s" file))
      (unless (audio-trimmer--audio-p file)
        (error "Not an audio file: %s" file))
      (let ((buf (get-buffer-create "*audio-trimmer*"))
            (dur (audio-trimmer--get-duration file)))
        (setq audio-trimmer-file (expand-file-name file)
              audio-trimmer-duration dur
              audio-trimmer-position 0.0
              audio-trimmer-is-playing nil
              audio-trimmer-player-process nil
              audio-trimmer-timer nil
              audio-trimmer-trim-start nil
              audio-trimmer-trim-end nil
              audio-trimmer-in-preview nil
              audio-trimmer-buffer buf)
        (with-current-buffer buf
          (setq buffer-read-only nil)
          (erase-buffer)
          (insert (format "File: %s\n" (file-name-nondirectory file)))
          (insert (format "Duration: %s\n\n" (audio-trimmer--format-time dur)))
          (insert (format "Position: %s / %s\n"
                          (audio-trimmer--format-time 0.0)
                          (audio-trimmer--format-time dur)))
          (insert "Trim: (not set)\n\n")
          (insert "Controls:\n")
          (insert "  SPC=play/pause  j=jump  ←→=±5s  ↑↓=±30s\n")
          (insert "  s=start  e=end  p=preview  t=trim  q=quit\n")
          (audio-trimmer-mode))
        (switch-to-buffer buf)
        (message "Audio Trimmer ready")))

    (provide 'audio-trimmer)
  '';
}
