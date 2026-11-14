;=======================================================================================
; modelst.asm - the modeller's state that must survive an overlay swap (resident)
;=======================================================================================
ms_inited:      .byte 0
ms_ubase:       .byte 0                 ; undo: the oldest snapshot's slot (model4.asm)
ms_ui:          .byte 0                 ; snapshots before the current state
ms_un:          .byte 0                 ; snapshots in all (the ones above ms_ui: redo)
ms_sel:         .byte $ff               ; $00-$1f object, $40+ light, $80 camera, $c0+
                                        ; material (being edited), $ff nothing
ms_view:        .fill 3 * 12            ; ortho views: zoom, centre across, centre up
ms_lscroll:     .byte 0                 ; the list's first row
ms_lsel:        .byte $fe               ; the selection the list last showed (it scrolls to
                                        ; a new one; otherwise it stays where it was put)
ms_maxview:     .byte $ff               ; the view made large, or $ff: all four
ms_drag:        .byte $ff               ; the view being dragged in
ms_dpt:         .byte 0                 ; 1: dragging a prism's corner, not the object
ms_pt:          .byte 0                 ; the prism corner picked (valid while ms_ptobj
ms_ptobj:       .byte $ff               ;  is the selection)
ms_dview:       .byte 0
ms_dx:          .word 0
ms_dy:          .byte 0
ms_orbit:       .byte 0                 ; 1: dragging in the camera view turns the camera
ms_msg:         .word 0                 ; the status line's message
ms_name:        .null "SCENE"           ; the document's name (files: NAME.MDL, .POV, .IFF)
                .fill 9
