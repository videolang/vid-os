#lang racket/gui

(require video/base
         video/render
         video/player
         images/icons/control)

(define screen-width 1920)
(define screen-height 1080)

(define recordings-folder (build-path (find-system-path 'home-dir) "recordings"))
(make-directory* recordings-folder)

(define view-width 960)
(define view-height 540)

(define normal-font
  (let ([n normal-control-font])
    (make-object font%
      (* 4 (send n get-size))
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
(define camera-render-settings
  (make-render-settings #:destination (path->string (build-path recordings-folder
                                                                (format "camera-~a"
                                                                        (current-seconds))))
                        #:format 'mp4
                        #:split-av #t
                        #:width 1920
                        #:height 1080))

(define presenter-render-settings
  (make-render-settings #:destination (path->string (build-path recordings-folder
                                                                (format "presenter-~a"
                                                                        (current-seconds))))
                        #:format 'mp4
                        #:split-av #t
                        #:width 1920
                        #:height 1080))

(define record-label
  (record-icon #:color "red"
               #:height 50))
(define stop-label
  (stop-icon #:color "gray"
             #:height 50))

(define vid-gui%
  (class frame%
    (super-new)

    (define (stop-filming)
      (send camera-vps stop)
      (send presenter-vps stop))
    (define menu-bar (new menu-bar% [parent this]))
    (define config-menu (new menu% [parent menu-bar]
                             [label "Configure"]))
    (new menu-item% [parent config-menu]
         [label "Saved Files"]
         [callback (λ (t e) (void))])
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
                            [font normal-font]))
    ;; Video player servers:
    (define camera-vps (new video-player-server%
                            [video (color "black")]
                            [canvas camera-screen]))
    (define presenter-vps (new video-player-server%
                               [video (color "black")]
                               [canvas presenter-screen]))
    (send camera-vps record camera-render-settings)
    (send presenter-vps record presenter-render-settings)
    (send camera-vps play)
    (send presenter-vps play)))

(module+ main
  (define window (new vid-gui%
                      [label "VidOS"]))
  (send window fullscreen #t)
  (send window show #t))
