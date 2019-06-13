#lang racket/gui

(require video/base
         video/render
         video/player
         (prefix-in core: video/core)
         images/icons/control)

(define screen-width 1920)
(define screen-height 1080)

(define default-cam-vid "/dev/video0")
(define default-cam-aud "CL1")
(define default-pres-vid "/dev/video3")
(define default-pres-aud "CL2")
(define default-mic "")

(define recordings-folder (build-path (find-system-path 'home-dir) "recordings"))
(make-directory* recordings-folder)

(define view-width 960)
(define view-height 540)

(define normal-font
  (let ([n normal-control-font])
    (make-object font%
      (* 8 (send n get-size))
      (send n get-face)
      (send n get-family)
      (send n get-style)
      (send n get-weight)
      (send n get-underlined)
      (send n get-smoothing)
      (send n get-size-in-pixels)
      (send n get-hinting))))

(define large-font
  (let ([n normal-control-font])
    (make-object font%
      (* 8 (send n get-size))
      (send n get-face)
      (send n get-family)
      (send n get-style)
      (send n get-weight)
      (send n get-underlined)
      (send n get-smoothing)
      (send n get-size-in-pixels)
      (send n get-hinting))))

(define marks-file (build-path recordings-folder "marks.txt"))

(define (camera-render-settings)
  (make-render-settings #:destination (path->string (build-path recordings-folder
                                                                (format "camera-~a"
                                                                        (current-seconds))))
                        #:format 'mp4
                        #:split-av #t
                        #:width 1920
                        #:height 1080))

(define (presenter-render-settings)
  (make-render-settings #:destination (path->string (build-path recordings-folder
                                                                (format "presenter-~a"
                                                                        (current-seconds))))
                        #:format 'mp4
                        #:split-av #t
                        #:width 1920
                        #:height 1080))
(define (mic-render-settings)
  (make-render-settings #:destination (path->string (build-path recordings-folder
                                                                (format "mic-~a"
                                                                        (current-seconds))))
                        #:format 'mp4
                        #:split-av #t
                        #:width 1920
                        #:height 1080))

(define record-label
  (record-icon #:color "red"
               #:height 200))
(define stop-label
  (stop-icon #:color "gray"
             #:height 200))

(define config-dirs%
  (class dialog%
    (super-new)
    (init camera-vid camera-aud
          presenter-vid presenter-aud
          mic)
    (define camera-vid-dev camera-vid)
    (define camera-aud-dev camera-aud)
    (define pres-vid-dev presenter-vid)
    (define pres-aud-dev presenter-aud)
    (define mic-dev mic)
    (define/public (get-dev)
      (values camera-vid-dev camera-aud-dev
              pres-vid-dev pres-aud-dev
              mic-dev))
    (define camera-vid-field (new text-field% [parent this]
                              [label "Camera Video"]
                              [text camera-vid-dev]))
    (define camera-aud-field (new text-field% [parent this]
                                  [label "Camera Audio"]
                                  [text camera-aud-dev]))
    (define pres-vid-field (new text-field% [parent this]
                                [label "Presenter Video"]
                                [text pres-vid-dev]))
    (define pres-aud-field (new text-field% [parent this]
                                [label "Presenter Audio"]
                                [text pres-aud-dev]))
    (define mic-field (new text-field% [parent this]
                           [label "Mic"]
                           [text mic-dev]))
    (define conf-row (new horizontal-pane% [parent this]))
    (new button% [parent conf-row]
         [label "OK"]
         [callback
          (λ (b e)
            (set! camera-vid-dev (send camera-vid-field get-value))
            (set! camera-aud-dev (send camera-aud-field get-value))
            (set! pres-vid-dev (send pres-vid-field get-value))
            (set! pres-aud-dev (send pres-aud-field get-value))
            (set! mic-dev (send mic-field get-value))
            (send this show #f))])
    (new button% [parent conf-row]
         [label "Cancel"]
         [callback
          (λ (b e)
            (send this show #f))])))
    
(define vid-gui%
  (class frame%
    (super-new)
    (define recording? #f)
    (define recording-lock (make-semaphore 1))

    (define camera-vid-dev default-cam-vid)
    (define camera-aud-dev default-cam-aud)
    (define pres-vid-dev default-pres-vid)
    (define pres-aud-dev default-pres-aud)
    (define mic-dev default-mic)

    (define (stop-filming)
      (send camera-vps stop)
      (send presenter-vps stop))
    (define menu-bar (new menu-bar% [parent this]))
    (define config-menu (new menu% [parent menu-bar]
                             [label "Configure"]))
    (new menu-item% [parent config-menu]
         [label "Configure Inputs"]
         [callback (λ (t e)
                     (define conf (new config-dirs% [parent this]
                                    [label "Configure"]
                                    [camera-vid camera-vid-dev]
                                    [camera-aud camera-aud-dev]
                                    [presenter-vid pres-vid-dev]
                                    [presenter-aud pres-aud-dev]
                                    [mic mic-dev]))
                     (send conf show #t)
                     (define-values (cv ca pv pa m) (send conf get-dev))
                     (set! camera-vid-dev cv)
                     (set! camera-aud-dev ca)
                     (set! pres-vid-dev pv)
                     (set! camera-aud-dev pa)
                     (set! mic-dev m))])
    (new menu-item% [parent config-menu]
         [label "Saved Files"]
         [callback (λ (t e)
                     (system* (find-executable-path "xdg-open")
                              recordings-folder))])
    (new menu-item% [parent config-menu]
         [label "Remove Marks"]
         [callback (λ (t e)
                     (delete-directory/files marks-file
                                             #:must-exist #f))])
    (new menu-item% [parent config-menu]
         [label "Exit"]
         [callback
          (λ (t e)
            (stop-filming)
            (send this show #f))])
    (new menu-item% [parent config-menu]
         [label "Shut Down"]
         [callback
          (λ (t e)
            (stop-filming)
            (send this show #f)
            (system* (find-executable-path "halt")))])
    
    (define screen-row (new horizontal-pane% [parent this]))
    (define camera-screen (new video-canvas% [parent screen-row]
                               [width view-width]
                               [height view-height]))
    (define presenter-screen (new video-canvas% [parent screen-row]
                                  [width view-width]
                                  [height view-height]))
    (define audio-row (new horizontal-pane% [parent this]))
    (define camera-audio (new gauge% [parent audio-row]
                              [label ""]
                              [range 100]
                              [min-width view-width]
                              [stretchable-width #f]))
    (define presenter-audio (new gauge% [parent audio-row]
                                 [label ""]
                                 [range 100]
                                 [min-width view-width]
                                 [stretchable-width #f]))
    (define time-row (new horizontal-pane% [parent this]))
    (define time (new message% [parent time-row]
                      [label "0:0:0"]
                      [font large-font]))
    (define control-row (new horizontal-pane% [parent this]))
    (define mark-button (new button% [parent control-row]
                             [label "MARK"]
                             [font normal-font]
                             [callback
                              (λ (b e)
                                (with-output-to-file marks-file
                                  #:exists 'append
                                  (λ ()
                                    (displayln (current-seconds)))))]))
    (define rec-button (new button% [parent control-row]
                            [label record-label]
                            [font normal-font]
                            [callback
                             (λ (b e)
                               (call-with-semaphore/enable-break
                                recording-lock
                                (λ ()
                                  (set! recording? (not recording?))
                                  (stop-vps)
                                  (cond [recording?
                                         (send b set-label stop-label)
                                         (send recording-timer start (* 1000 60 5) #f)
                                         (send camera-vps record (camera-render-settings))
                                         (send presenter-vps record (presenter-render-settings))
                                         (send mic-vps record (mic-render-settings))]
                                        [else
                                         (send b set-label record-label)
                                         (send recording-timer stop)
                                         (send camera-vps record #f)
                                         (send presenter-vps record #f)
                                         (send mic-vps record #f)])
                                  (play-vps))))]))
    ;; Video player servers:
    (define camera-vps (new video-player-server%
                            [video (blank)]
                            [canvas camera-screen]))
    (define presenter-vps (new video-player-server%
                               [video (blank)]
                               [canvas presenter-screen]))
    (define mic-vps (new video-player-server%
                         [video (color "black")]))
    (send mic-vps render-video #f)
    (play-vps)

    (define/public (stop-vps)
      (send camera-vps stop)
      (send presenter-vps stop)
      (send mic-vps stop))

    (define/public (play-vps)
      (send camera-vps set-video
            (if (file-exists? camera-vid-dev)
                (core:make-input-device #:video camera-vid-dev
                                        #:audio camera-aud-dev)
                (color "blue")))
      (send camera-vps play)
      (send presenter-vps set-video
            (if (file-exists? pres-vid-dev)
                (core:make-input-device #:video pres-vid-dev
                                        #:audio pres-aud-dev)
                (color "blue")))
      (send presenter-vps play)
      (send mic-vps set-video
            (if (file-exists? mic-dev)
                (core:make-input-device #:video mic-dev
                                        #:audio mic-dev)
                (color "blue")))
      (send mic-vps play))

    (define recording-timer
      (new timer% [notify-callback
                   (λ ()
                     (call-with-semaphore/enable-break
                      recording-lock
                      (λ ()
                        (stop-vps)
                        (send camera-vps record (camera-render-settings))
                        (send presenter-vps record (presenter-render-settings))
                        (send mic-vps record (mic-render-settings))
                        (play-vps))))]))))

(module+ main
  (define window (new vid-gui%
                      [label "VidOS"]))
  (send window fullscreen #t)
  (send window show #t))
