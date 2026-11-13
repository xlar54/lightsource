;=======================================================================================
; modelst.asm - the modeller's state that must survive an overlay swap (resident)
;=======================================================================================
ms_inited:      .byte 0
ms_sel:         .byte $ff               ; $00-$1f object, $40+ light, $80 camera, $c0+
                                        ; material (being edited), $ff nothing
ms_view:        .fill 3 * 12            ; ortho views: zoom, centre across, centre up
ms_lscroll:     .byte 0                 ; the list's first row
ms_maxview:     .byte $ff               ; the view made large, or $ff: all four
ms_drag:        .byte $ff               ; the view being dragged in
ms_dview:       .byte 0
ms_dx:          .word 0
ms_dy:          .byte 0
ms_msg:         .word 0                 ; the status line's message
ms_name:        .null "SCENE"           ; the document's name (files: NAME.MDL, .POV, .IFF)
                .fill 9
