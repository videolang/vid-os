#lang racket/gui

(require video/base
         video/player)

(define view-width 480)
(define view-height 270)

(define vid-gui%
  (class frame%
    (super-new)
    (define menu-bar (new menu-bar% [parent this]))
    (define config-menu (new menu% [parent menu-bar]
                             [label "Configure"]))
    (new menu-item% [parent config-menu]
         [label "Saved Files"]
         [callback (λ (t e) (void))])
    (new menu-item% [parent config-menu]
         [label "Exit"]
         [callback (λ (t e) (send this show #f))])
    
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
                      [label "0:0:0"]))
    (define control-row (new horizontal-pane% [parent this]))
    (define mark-button (new button% [parent control-row]
                             [label "MARK"]))
    (define rec-button (new button% [parent control-row]
                            [label "RECORD"]))
    ;; Video player servers:

    (define camera-vps (new video-player-server%
                            [video (color "black")]
                            [canvas camera-screen]))
    (define presenter-vps (new video-player-server%
                               [video (color "black")]
                               [canvas presenter-screen]))
    (send camera-vps render-audio #f)
    (send camera-vps play)
    (send presenter-vps play)))

(module+ main
  (define window (new vid-gui%
                      [label "VidOS"]))
  (send window fullscreen #t)
  (send window show #t))
