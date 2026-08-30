;; Loaded before package.el can initialize, so the ELPA package manager
;; never loads alongside straight-free (Nix-provided) packages.
(setq package-enable-at-startup nil)

;; --- startup speed ---
;; Defer the GC while init loads packages (they allocate a lot), and
;; skip file-name handlers (nothing at init time needs .gz/tar/TRAMP
;; handling).  Both are restored once startup finishes.
(setq gc-cons-threshold (* 128 1024 1024)) ; 128 MiB during init
(setq gc-cons-percentage 0.6)
(setq inhibit-message t) ; silence echo-area writes while loading
(defvar my/init-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024))
            (setq gc-cons-percentage 0.1)
            (setq inhibit-message nil)
            (setq file-name-handler-alist my/init-file-name-handler-alist)))

(setq initial-frame-alist
      '((width . 84) (height . 32)))
