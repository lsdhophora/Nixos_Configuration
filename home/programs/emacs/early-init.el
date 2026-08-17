;; Loaded before package.el can initialize, so the ELPA package manager
;; never loads alongside straight-free (Nix-provided) packages.
(setq package-enable-at-startup nil)

(setq initial-frame-alist
      '((width . 84) (height . 32)))
