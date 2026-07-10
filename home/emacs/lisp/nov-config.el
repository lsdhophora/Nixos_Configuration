;;; nov-config.el -- Nov EPUB reader customizations

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
             print-level print-length)
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
  (advice-add 'nov-next-document :around #'nov-next-document-last-chapter-guard)

  (defun nov-occur (regexp)
    "Search EPUB content with `occur'.
Searches all chapters and shows clickable results."
    (interactive "sNov occur (regexp): ")
    (when (string-empty-p regexp)
      (user-error "No search query"))
    (let ((nov-buffer (current-buffer))
          (title-map (make-hash-table :test 'equal))
          (results nil))
      (let ((toc-dir (file-name-directory
                      (cdr (aref nov-documents 0)))))
        (dolist (entry (nov-imenu-create-index))
          (let* ((file (nth 1 entry))
                 (title (nth 0 entry))
                 (abs-path (expand-file-name file toc-dir)))
            (when (and title file
                       (not (string-empty-p title)))
              (dotimes (i (length nov-documents))
                (when (string= abs-path (cdr (aref nov-documents i)))
                  (puthash i title title-map)))))))
      (dotimes (i (length nov-documents))
        (let* ((path (cdr (aref nov-documents i)))
               (html (nov-slurp path)))
          (when html
            (with-temp-buffer
              (insert html)
              (let ((dom (libxml-parse-html-region
                          (point-min) (point-max))))
                (let ((title (gethash i title-map
                                      (file-name-nondirectory path))))
                  (erase-buffer)
                  (let ((shr-width nil))
                    (shr-insert-document dom))
                  (goto-char (point-min))
                  (while (re-search-forward regexp nil t)
                    (let ((line (line-number-at-pos))
                          (matched (match-string-no-properties 0))
                          (full-line (string-trim
                                      (buffer-substring
                                       (line-beginning-position)
                                       (line-end-position)))))
                      (push (list i title line matched full-line)
                            results)))))))))
      (if (null results)
          (message "No matches for regexp \"%s\"" regexp)
        (pop-to-buffer (get-buffer-create "*Nov Occur*"))
        (setq buffer-read-only nil)
        (erase-buffer)
        (let ((seen (make-hash-table :test 'equal))
              (uniq-results nil))
          (dolist (r (nreverse results))
            (let ((key (cons (nth 0 r) (nth 2 r))))
              (unless (gethash key seen)
                (puthash key t seen)
                (push r uniq-results))))
          (let ((count (length uniq-results)))
            (insert (format "%d match%s for \"%s\":\n\n"
                            count (if (= count 1) "" "es") regexp))
            (dolist (r (nreverse uniq-results))
              (let* ((doc-index (nth 0 r))
                     (title (nth 1 r))
                     (line (nth 2 r))
                     (matched (nth 3 r))
                     (full-line (nth 4 r))
                     (p (point)))
                (insert (format "%s:%d: %s\n" title line full-line))
                (add-text-properties
                 p (1- (point))
                 (list 'mouse-face 'highlight
                       'help-echo (format "Jump to %s:L%d" title line)
                       'nov-doc-index doc-index
                       'nov-occur-line line
                       'nov-matched matched
                       'nov-full-line full-line
                       'nov-buffer nov-buffer)))))
          (nov-occur-mode)
          (setq buffer-read-only t)
          (goto-char (point-min)))))

  (defun nov-occur-follow ()
    (interactive)
    (let ((doc-index (get-text-property (point) 'nov-doc-index))
          (matched (get-text-property (point) 'nov-matched))
          (full-line (get-text-property (point) 'nov-full-line))
          (line (get-text-property (point) 'nov-occur-line))
          (buf (get-text-property (point) 'nov-buffer)))
      (when (and doc-index matched buf
                 (buffer-live-p buf))
        (let ((cur (current-buffer)))
          (pop-to-buffer buf)
          (nov-goto-document doc-index)
          (goto-char (point-min))
          (cond ((and full-line
                      (search-forward full-line nil t))
                 (goto-char (match-beginning 0)))
                ((search-forward matched nil t)
                 (goto-char (match-beginning 0)))
                 (t (forward-line (1- line)))))))))

)

(define-derived-mode nov-occur-mode special-mode "Nov-Occur"
  "Major mode for nov-occur results."
  (define-key nov-occur-mode-map (kbd "RET") #'nov-occur-follow)
  (define-key nov-occur-mode-map (kbd "<mouse-1>") #'nov-occur-follow)
  (define-key nov-occur-mode-map (kbd "q") #'quit-window))

(defun my/nov-open-image-at-point ()
  "Open image at point with swayimg, showing only that single image."
  (interactive)
  (let ((file (get-text-property (point) 'nov-image-file)))
    (if (and file (file-exists-p file))
        (start-process "swayimg" nil "swayimg"
                       "--config=list.all=no"
                       file)
      (message "No image at point"))))

(with-eval-after-load 'nov
  (define-key nov-mode-map (kbd "C-c C-o") #'my/nov-open-image-at-point))

(defun my/nov-record-image-path (orig-fun path &optional alt)
  (let ((start (point)))
    (funcall orig-fun path alt)
    (add-text-properties start (point)
                         `(nov-image-file ,path
                           help-echo ,(format "Image: %s (C-c C-o to open)" path)))))

(with-eval-after-load 'nov
  (advice-add 'nov-insert-image :around #'my/nov-record-image-path))

(provide 'nov-config)
