;;; org-noter-media.el --- Module for integrating org-media-note with org-noter  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  c1-g

;; Author: c1-g <char1iegordon@protonmail.com>
;; Keywords: multimedia

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; TODO: Documentation

;;; Code:
(require 'org-media-note)
(require 'org-noter)
(require 'cl-lib)

(defcustom org-noter-media-extensions
  ;; From EMMS package; emms-player-base-format-list
  '("ogg" "mp3" "wav" "mpg" "mpeg" "wmv" "wma" "mov" "avi" "divx"
    "ogm" "ogv" "asf" "mkv" "rm" "rmvb" "mp4" "flac" "vob" "m4a" "ape"
    "flv" "webm" "aif" "opus")
  "All file extensions that mpv can play.")

(defun org-noter-media-check-doc (document-property)
  (when (stringp document-property)
    (cond ((and (string-match org-link-bracket-re document-property)
                (string-match-p (regexp-opt '("video" "audio" "videocite" "audiocite"))
                                document-property))
           (match-string 2 document-property))
          ((or (string-match-p (concat (regexp-opt org-noter-media-extensions) "$") document-property)
               (string-match-p "youtu\\.?be" document-property))
           document-property))))

(add-to-list 'org-noter--check-location-property-hook 'org-noter-media-check-doc)

(defun org-noter-media-open-document (doc-prop)
  (when (org-noter-media-check-doc doc-prop)
    (mpv-start (org-noter-media-check-doc doc-prop))
    (current-buffer)))

(add-to-list 'org-noter-open-document-functions #'org-noter-media-open-document)

(defun org-noter-media--parse-location (s)
  (when (org-noter-media-check-doc s)
    (let* ((s (match-string 1 s))
           (splitted (split-string s "#"))
           (file-path-or-url (nth 0 splitted))
           (timestamps (split-string (nth 1 splitted) "-")))
      (org-timer-hms-to-secs (nth 0 timestamps)))))

(add-to-list 'org-noter--parse-location-property-hook #'org-noter-media--parse-location)

(defun org-noter-media--relative-position-to-view (location view)
  (when (eq (aref view 0) 'timed)
    (setq view (aref view 1))
    (setq location (if (stringp location)
                        (string-to-number location)
                      location))
    (cond ((< location view) 'before)
          ((= location view) 'inside)
          (t 'after))))

(add-to-list 'org-noter--relative-position-to-view-hook #'org-noter-media--relative-position-to-view)

(defun org-noter-media--convert-to-location-cons (location)
  (if (and location (consp location))
      location
    (cons location 0)))

(add-to-list 'org-noter--convert-to-location-cons-hook #'org-noter-media--convert-to-location-cons)

(defun org-noter-media--pretty-print-location (location)
  (org-noter--with-valid-session
   (when (org-noter-media-check-doc (org-noter--session-property-text session)) 
     (let* ((file-path (mpv-get-property "path"))
            (link-type (if (org-media-note-ref-cite-p)
                           (concat (org-media-note--current-media-type)
                                   "cite")
                         (org-media-note--current-media-type)))
            (filename (mpv-get-property "media-title"))
            (duration (org-media-note--get-duration-timestamp))
            (timestamp (org-timer-secs-to-hms location)))
       (if (org-media-note--ab-loop-p)
           ;; ab-loop link
           (let ((time-a (org-media-note--seconds-to-timestamp (mpv-get-property "ab-loop-a")))
                 (time-b (org-media-note--seconds-to-timestamp (mpv-get-property "ab-loop-b"))))
             (format "[[%s:%s#%s-%s][%s]]"
                     link-type
                     (org-media-note--link-base-file file-path)
                     time-a
                     time-b
                     (org-media-note--link-formatter org-media-note-ab-loop-link-format
                                                     `(("filename" . ,filename)
                                                       ("duration" . ,duration)
                                                       ("ab-loop-a" . ,time-a)
                                                       ("ab-loop-b" . ,time-b)
                                                       ("file-path" . ,file-path)))))
         ;; timestamp link
         (format "[[%s:%s#%s][%s]]"
                 link-type
                 (org-media-note--link-base-file file-path)
                 timestamp
                 (org-media-note--link-formatter org-media-note-timestamp-link-format
                                                 `(("filename" . ,filename)
                                                   ("duration" . ,duration)
                                                   ("timestamp" . ,timestamp)
                                                   ("file-path" . ,file-path)))))))))


(add-to-list 'org-noter--pretty-print-location-hook #'org-noter-media--pretty-print-location)

(defun org-noter-media-approx-location (mode &optional precise-info _force-new-ref)
  (org-noter--with-valid-session
   (when (org-noter-media-check-doc (org-noter--session-property-text session))
     (string-to-number (org-media-note--timestamp-to-seconds (org-media-note--get-current-timestamp))))))

(add-hook 'org-noter--doc-approx-location-hook #'org-noter-media-approx-location)

(defun org-noter-media--get-precise-info (major-mode)
  (when (org-noter-media-check-doc major-mode)
    (string-to-number (org-media-note--timestamp-to-seconds (org-media-note--get-current-timestamp)))))

(add-to-list 'org-noter--get-precise-info-hook #'org-noter-media--get-precise-info)

(defun org-noter-media--get-current-view (major-mode)
  (when (org-noter-media-check-doc major-mode)
    (vector 'timed (string-to-number (org-media-note--timestamp-to-seconds (org-media-note--get-current-timestamp))))))

(add-to-list 'org-noter--get-current-view-hook #'org-noter-media--get-current-view)

(defun org-noter-media-setup-handler (major-mode)
  (when (org-noter-media-check-doc major-mode)
    (run-with-idle-timer
     1 t
     (lambda ()
       (org-noter--with-valid-session
        (org-noter--doc-location-change-handler))))
    t))

(add-to-list 'org-noter-set-up-document-hook #'org-noter-media-setup-handler)

(defun org-noter-media--get-sub-text (mode)
  (when (org-noter-media-check-doc mode)
    (condition-case nil
        (mpv-get-property "sub-text")
      (error nil))))

(add-to-list 'org-noter-get-selected-text-hook #'org-noter-media--get-sub-text)

(defun org-noter-media-goto-location (mode location)
  (when (org-noter-media-check-doc mode)
    (org-media-note--seek-position-in-current-media-file location)))

(provide 'org-noter-media)
;;; org-noter-media.el ends here
