;;; audio-trimmer.el -- Audio trimming major mode with ffplay backend

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
  "Convert SECONDS to mm:ss.s format."
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
      (setq audio-trimmer-position (min audio-trimmer-duration
                                        (+ audio-trimmer-position 0.05)))
      (audio-trimmer--redraw)
      (when (and audio-trimmer-in-preview
                 audio-trimmer-trim-end
                 (>= audio-trimmer-position audio-trimmer-trim-end))
        (audio-trimmer--stop-player)
        (message "Preview ended at trim point: %s"
                 (audio-trimmer--format-time audio-trimmer-position))))))

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
            (if (and audio-trimmer-trim-start audio-trimmer-trim-end
                     (> audio-trimmer-trim-end audio-trimmer-trim-start))
                (insert (format "%s \342\206\222 %s (%.1fs)"
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
  "Seek to position in SECONDS."
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
        (message "Previewing from %s"
                 (audio-trimmer--format-time audio-trimmer-trim-start)))
    (message "No trim start set!")))

(defun audio-trimmer--trim ()
  "Execute trim with ffmpeg."
  (interactive)
  (if (or (null audio-trimmer-trim-end) (null audio-trimmer-trim-start)
          (<= audio-trimmer-trim-end audio-trimmer-trim-start))
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
      (insert " SPC=play/pause j=jump \342\206\220\342\206\222=\302\2615s \342\206\221\342\206\223=\302\26130s\n")
      (insert " s=start e=end p=preview t=trim q=quit\n")
      (audio-trimmer-mode))
    (switch-to-buffer buf)
    (message "Audio Trimmer ready")))

(provide 'audio-trimmer)
