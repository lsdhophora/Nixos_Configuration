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

;; Frame font pinned as an explicit frame parameter (family + size),
;; so every frame -- including the initial one -- is created with the
;; right size instead of depending on default-face realization timing
;; (pgtk can transiently drop the face's :height under fontconfig load,
;; falling back to the ~10pt default).
(setq default-frame-alist
      '((font . "IBM Plex Mono-14")))
(setq initial-frame-alist
      ;; 14pt font + 1.25x Wayland scaling: 32 rows overflow the 1080p
      ;; screen, so start with 28 rows (same text capacity as 32 rows
      ;; at the old 12pt).
      (append
       '((font . "IBM Plex Mono-14")
         (width . 84) (height . 28))
       default-frame-alist))
