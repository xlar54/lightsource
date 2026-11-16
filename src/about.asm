;=======================================================================================
; about.asm - Help, About: a box in the middle of the screen with the version and the
; build date. A click or a key closes it, and what was under it comes back (gui_save
; slot 0, as the menus and the Open dialog use). Overlay 6; called with #FAR.
;=======================================================================================

AB_X0           = 160                   ; the box: 40 columns, from column 20
AB_X1           = 479
AB_Y0           = 44
AB_Y1           = 151
AB_COL          = 22                    ; the text's column

about_box:
        jsr d6_clip_all
        #GXY AB_X0, AB_Y0, AB_X1, AB_Y1
        ldx #0
        jsr gui_save
        #GXY AB_X0, AB_Y0, AB_X1, AB_Y1
        lda #GC_PANEL
        jsr gui_fill
        #GXY AB_X0, AB_Y0, AB_X1, AB_Y0 + 10
        lda #GC_BAR
        jsr gui_fill
        #GXY AB_X0, AB_Y0, AB_X1, AB_Y1
        lda #GC_LIGHT
        sta d6_col
        jsr d6_frame
        #GTEXT AB_COL - 1, AB_Y0 + 2, GC_WHITE, $ff, ab_title
        #GTEXT AB_COL, AB_Y0 + 18, GC_YELLOW, $ff, ab_name
        #GTEXT AB_COL, AB_Y0 + 28, GC_LIGHT, $ff, ab_built
        #GTEXT AB_COL, AB_Y0 + 44, GC_WHITE, $ff, ab_l1
        #GTEXT AB_COL, AB_Y0 + 53, GC_WHITE, $ff, ab_l2
        #GTEXT AB_COL, AB_Y0 + 62, GC_WHITE, $ff, ab_l3
        #GTEXT AB_COL, AB_Y0 + 76, GC_LIGHT, $ff, ab_l4
        #GTEXT AB_COL, AB_Y0 + 94, GC_CYAN, $ff, ab_close
_wait:  jsr wait_frame                  ; a key, or a click (its release is taken here too,
        jsr gui_poll                    ; so the views don't see it)
        lda ev_type
        cmp #EV_KEY
        beq _close
        cmp #EV_DOWN
        beq _up
        cmp #EV_RDOWN
        bne _wait
        bra _close
_up:    jsr wait_frame
        jsr gui_poll
        lda ev_type
        cmp #EV_UP
        bne _up
_close: ldx #0
        jmp gui_restore

ab_title:       .null "About Lightsource"
ab_name:        .null "Lightsource ", LS_VERSION
ab_built:       .null "Built ", LS_BUILT
ab_l1:          .null "A 3D modeller and ray tracer for"
ab_l2:          .null "the MEGA65, with scenes in a subset"
ab_l3:          .null "of POV-Ray's scene language."
ab_l4:          .null "Shadows, mirrors and glass"
ab_close:       .null "Click or press a key to close"
