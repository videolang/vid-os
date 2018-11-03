#lang racket/gui

(require video/base
         video/render
         video/player
         images/icons/control)

(define screen-width 1920)
(define screen-height 1080)

(define default-cam-in "/dev/video0")
(define default-pres-in "/dev/video1")
(define default-mic-in "/dev/audio")

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
    (init camera presenter mic)
    (define camera-dev camera)
    (define pres-dev presenter)
    (define mic-dev mic)
    (define/public (get-dev)
      (values camera-dev pres-dev mic-dev))
    (define camera-field (new text-field% [parent this]
                              [label "Camera"]
                              [text camera-dev]))
    (define pres-field (new text-field% [parent this]
                            [label "Presenter"]
                            [text pres-dev]))
    (define mic-field (new text-field% [parent this]
                           [label "Mic"]
                           [text mic-dev]))
    (define conf-row (new horizontal-pane% [parent this]))
    (new button% [parent conf-row]
         [label "OK"]
         [callback
          (λ (b e)
            (set! camera-dev (send camera-field get-value))
            (set! pres-dev (send pres-field get-value))
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

    (define camera-dev default-cam-in)
    (define pres-dev default-pres-in)
    (define mic-dev default-mic-in)

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
                                    [camera camera-dev]
                                    [presenter pres-dev]
                                    [mic mic-dev]))
                     (send conf show #t)
                     (define-values (c p m) (send conf get-dev))
                     (set! camera-dev c)
                     (set! pres-dev p)
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
                            [video (color "black")]
                            [canvas camera-screen]))
    (define presenter-vps (new video-player-server%
                               [video (color "black")]
                               [canvas presenter-screen]))
    (define mic-vps (new video-player-server%
                         [video (color "black")]))
    (send mic-vps render-video #f)
    (send camera-vps play)
    (send presenter-vps play)
    (send mic-vps play)

    (define/public (stop-vps)
      (send camera-vps stop)
      (send presenter-vps stop)
      (send mic-vps stop))

    (define/public (play-vps)
      (send camera-vps play)
      (send presenter-vps play)
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
