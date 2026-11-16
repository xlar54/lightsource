;=======================================================================================
; matedit.asm - overlay 7: the material editor, a screen of its own. The modeller opens it
; (#FAR OVL_MATED, mat_editor) for material ed_n:
;   - a preview at the left: a ball wearing the material on a checker floor, traced small by
;     the real tracer (modes.asm ed_trace; every 3rd pixel and line of the whole picture),
;     dithered to a 6x6x6 colour cube in palette entries 16..231
;   - the settings at the right, grouped, with swatches for the two colours (entries 232,
;     233). Drag a number left or right to nudge it, or click it to type one; the preview
;     is traced again after each change
;   - presets under the preview (Matte, Plastic, Metal, Mirror, Glass, Glow) set the finish
;     and leave the colours alone
;   - Done (RETURN) keeps the changes, Cancel (ESC) puts the material back as it was
; mat_editor: carry set if cancelled. The material is edited in place, in the document.
;=======================================================================================

EK_VAL          = 0                     ; a 16.16 number
EK_WORD         = 1                     ; a whole number (word)
EK_BIT          = 2                     ; bit 0 of a byte
EK_NAME         = 3                     ; the name
ED_SW1          = 232                   ; the swatches' palette entries
ED_SW2          = 233
ED_BY           = 104                   ; the preset buttons' first row
ED_DY           = 150                   ; Done / Cancel

; the fields: column, y, kind, offset in the record, width (columns), label, prompt; the
; drag step and the limits (16.16)
EF .macro col, y, kind, off, w, label, prompt, step, lo, hi
        .byte \col, \y, \kind, \off, \w
        .word \label, \prompt
        .dint FX(\step), FX(\lo), FX(\hi)
.endmacro
EF_SIZE         = 21
ed_fields:
        #EF 40, 20, EK_NAME, DM_NAME, 14, ef_none, ep_name, 0, 0, 0
        #EF 40, 34, EK_VAL, DM_COL, 10, ef_r, ep_r, 0.01, 0, 1
        #EF 50, 34, EK_VAL, DM_COL+4, 10, ef_g, ep_g, 0.01, 0, 1
        #EF 60, 34, EK_VAL, DM_COL+8, 10, ef_b, ep_b, 0.01, 0, 1
        #EF 40, 46, EK_BIT, DM_FLAGS, 10, ef_none, ep_name, 0, 0, 0
        #EF 50, 46, EK_VAL, DM_CSCALE, 12, ef_sq, ep_sq, 0.05, 0.1, 20
        #EF 40, 58, EK_VAL, DM_COL2, 10, ef_r, ep_r2, 0.01, 0, 1
        #EF 50, 58, EK_VAL, DM_COL2+4, 10, ef_g, ep_g2, 0.01, 0, 1
        #EF 60, 58, EK_VAL, DM_COL2+8, 10, ef_b, ep_b2, 0.01, 0, 1
        #EF 40, 76, EK_VAL, DM_DIFF, 18, ef_dif, ep_dif, 0.01, 0, 1
        #EF 58, 76, EK_VAL, DM_AMB, 18, ef_amb, ep_amb, 0.01, 0, 1
        #EF 40, 88, EK_VAL, DM_PHONG, 18, ef_pho, ep_pho, 0.01, 0, 1
        #EF 58, 88, EK_WORD, DM_PSIZE, 18, ef_siz, ep_siz, 2, 1, 2000
        #EF 40, 106, EK_VAL, DM_REFL, 18, ef_ref, ep_ref, 0.01, 0, 1
        #EF 40, 118, EK_VAL, DM_TRANS, 18, ef_trn, ep_trn, 0.01, 0, 1
        #EF 58, 118, EK_VAL, DM_IOR, 18, ef_ior, ep_ior, 0.01, 1, 3
ed_fields_end:
ED_NF           = (ed_fields_end - ed_fields) / EF_SIZE
        .cerror (ed_fields_end - ed_fields) % EF_SIZE != 0, "EF_SIZE"
EF_COL          = 0
EF_Y            = 1
EF_KIND         = 2
EF_OFF          = 3
EF_W            = 4
EF_LBL          = 5
EF_PR           = 7
EF_STEP         = 9
EF_LO           = 13
EF_HI           = 17
ef_lo:          .byte <(ed_fields + range(ED_NF) * EF_SIZE)
ef_hi:          .byte >(ed_fields + range(ED_NF) * EF_SIZE)

ef_none:        .null ""
ef_r:           .null "R "
ef_g:           .null "G "
ef_b:           .null "B "
ef_sq:          .null "Square "
ef_dif:         .null "Diffuse "
ef_amb:         .null "Ambient "
ef_pho:         .null "Phong "
ef_siz:         .null "Size "
ef_ref:         .null "Reflect "
ef_trn:         .null "Transmit "
ef_ior:         .null "IOR "
ep_name:        .null "Name: "
ep_r:           .null "Red, 0 to 1: "
ep_g:           .null "Green, 0 to 1: "
ep_b:           .null "Blue, 0 to 1: "
ep_r2:          .null "The checker's second colour, red 0 to 1: "
ep_g2:          .null "The checker's second colour, green 0 to 1: "
ep_b2:          .null "The checker's second colour, blue 0 to 1: "
ep_sq:          .null "The checker's square size (1 to 2 for floors): "
ep_dif:         .null "Diffuse: light it scatters, 0 to 1 (0.6 usual): "
ep_amb:         .null "Ambient: light it shows in shadow (0.1 usual): "
ep_pho:         .null "Phong: highlight strength, 0 to 1: "
ep_siz:         .null "Highlight size: bigger is smaller and sharper: "
ep_ref:         .null "Reflection: 0 none, 1 a perfect mirror: "
ep_trn:         .null "Transmit: light let through, 0 to 1 (glass 0.8): "
ep_ior:         .null "IOR: glass 1.5, water 1.33 (1: no bending): "

; the headings, column 30
ed_heads:       .byte 20, 34, 46, 58, 76, 106, 118
ed_head_lo:     .byte <eh_name, <eh_col, <eh_chk, <eh_col2, <eh_fin, <eh_mir, <eh_gls
ed_head_hi:     .byte >eh_name, >eh_col, >eh_chk, >eh_col2, >eh_fin, >eh_mir, >eh_gls
eh_name:        .null "Name"
eh_col:         .null "Colour"
eh_chk:         .null "Checker"
eh_col2:        .null "Colour 2"
eh_fin:         .null "Finish"
eh_mir:         .null "Mirror"
eh_gls:         .null "Glass"

; the presets: phong_size (word), then ambient, diffuse, phong, reflection, transmit, ior
; (DM_PSIZE .. DM_IOR + 3: 26 bytes in the record's order)
EP .macro ps, amb, dif, pho, ref, trn, ior
        .word \ps
        .dint FX(\amb), FX(\dif), FX(\pho), FX(\ref), FX(\trn), FX(\ior)
.endmacro
EP_SIZE         = DM_IOR + 4 - DM_PSIZE
        .cerror EP_SIZE != 26 || DM_AMB != DM_PSIZE + 2, "the presets' layout"
ed_presets:
        #EP 10, 0.1, 0.85, 0, 0, 0, 1          ; Matte
        #EP 60, 0.1, 0.7, 0.6, 0.05, 0, 1      ; Plastic
        #EP 120, 0.08, 0.5, 0.9, 0.4, 0, 1     ; Metal
        #EP 400, 0, 0.05, 1, 0.85, 0, 1        ; Mirror
        #EP 125, 0, 0, 0.9, 0.1, 0.8, 1.5      ; Glass
        #EP 10, 1, 0, 0, 0, 0, 1               ; Glow
ed_pnames_lo:   .byte <epn0, <epn1, <epn2, <epn3, <epn4, <epn5, <epn6, <epn7
ed_pnames_hi:   .byte >epn0, >epn1, >epn2, >epn3, >epn4, >epn5, >epn6, >epn7
epn0:           .null "Matte"
epn1:           .null "Plastic"
epn2:           .null "Metal"
epn3:           .null "Mirror"
epn4:           .null "Glass"
epn5:           .null "Glow"
epn6:           .null "Done"
epn7:           .null "Cancel"
; the 8 buttons: 6 presets (two rows of three), Done, Cancel
ed_bx:          .byte 12, 84, 156, 12, 84, 156, 12, 84
ed_by:          .byte ED_BY, ED_BY, ED_BY, ED_BY + 14, ED_BY + 14, ED_BY + 14, ED_DY, ED_DY

st_edtitle:     .null "Material editor"
st_edhint:      .null "Drag a number left or right, or click it to type. RETURN done, ESC cancel"
st_edtrace:     .null "Tracing the preview..."
st_edbad:       .null "That isn't a number"

;---------------------------------------------------------------------------------------
mat_editor:
        jsr ed_pset                     ; ed_p = the record; a copy to go back to
        ldy #DMAT_SIZE - 1
-       lda (ed_p),y
        sta ed_orig,y
        dey
        bpl -
        jsr ed_palette
        jsr ed_screen
        jsr ed_preview
_loop:
        jsr wait_frame
        jsr gui_poll
        lda ev_type
        cmp #EV_KEY
        bne +
        lda ev_key
        cmp #K_RETURN
        beq ed_done
        cmp #K_ESC
        beq ed_cancel
        bra _loop
+       cmp #EV_DOWN
        bne _loop
        jsr ed_click
        bcs ed_exit
        bra _loop
ed_done:
        clc
        rts
ed_cancel:
        ldy #DMAT_SIZE - 1
-       lda ed_orig,y
        sta (ed_p),y
        dey
        bpl -
        sec
        rts
; (ed_click: carry set = leave, ed_quit: 0 done, 1 cancel)
ed_exit:
        lda ed_quit
        beq ed_done
        bra ed_cancel

; a click: a button, or a field
ed_click:
        ldx #0                          ; the buttons (64 x 11)
_b:     lda ed_by,x
        sec
        sbc #2
        sta tmp0
        lda ev_y
        sec
        sbc tmp0
        bcc _nb
        cmp #11
        bcs _nb
        lda ev_x+1
        bne _nb
        lda ev_x
        sec
        sbc ed_bx,x
        bcc _nb
        cmp #64
        bcs _nb
        cpx #6
        bcs _quit
        jmp ed_preset
_quit:  txa                             ; Done 0, Cancel 1
        sec
        sbc #6
        sta ed_quit
        sec
        rts
_nb:    inx
        cpx #8
        bne _b
        ; a field: its row (y .. y+8) and columns
        lda ev_x+1                      ; the column: x / 8
        sta tmp0
        lda ev_x
        lsr tmp0
        ror
        lsr tmp0
        ror
        lsr tmp0
        ror
        sta ed_c
        ldx #0
_f:     jsr ed_fptr
        ldy #EF_Y
        lda (ed_q),y
        sec
        sbc #1
        sta tmp0
        lda ev_y
        sec
        sbc tmp0
        bcc _nf
        cmp #10
        bcs _nf
        ldy #EF_COL
        lda ed_c
        cmp (ed_q),y
        bcc _nf
        lda (ed_q),y
        ldy #EF_W
        clc
        adc (ed_q),y
        sta tmp0
        lda ed_c
        cmp tmp0
        bcs _nf
        stx ed_f
        jmp ed_field
_nf:    inx
        cpx #ED_NF
        bne _f
        clc
        rts

; ed_q = field X's entry
ed_fptr:
        lda ef_lo,x
        sta ed_q
        lda ef_hi,x
        sta ed_q+1
        rts
; ed_v_p = the field's place in the record (ed_q set)
ed_vptr:
        ldy #EF_OFF
        lda (ed_q),y
        clc
        adc ed_p
        sta ed_vp
        lda ed_p+1
        adc #0
        sta ed_vp+1
        rts

; a preset: the finish (DM_PSIZE .. DM_IOR) from the table
ed_preset:
        txa                             ; X * 26
        asl
        sta tmp0
        asl
        asl
        sta tmp1
        asl
        clc
        adc tmp1
        adc tmp0
        tay
        ldx #0
-       lda ed_presets,y
        sta ed_buf,x
        iny
        inx
        cpx #EP_SIZE
        bne -
        ldy #DM_PSIZE
        ldx #0
-       lda ed_buf,x
        sta (ed_p),y
        iny
        inx
        cpx #EP_SIZE
        bne -
        jsr ed_fields_all
        jsr ed_preview
        clc
        rts

; field ed_f clicked: a toggle flips; a name is typed; a number is dragged, or typed if
; the pointer doesn't move
ed_field:
        ldx ed_f
        jsr ed_fptr
        jsr ed_vptr
        ldy #EF_KIND
        lda (ed_q),y
        cmp #EK_BIT
        bne +
        ldy #0
        lda (ed_vp),y
        eor #1
        sta (ed_vp),y
        ldx ed_f
        jsr ed_field_draw
        jsr ed_preview
        clc
        rts
+       cmp #EK_NAME
        bne +
        jmp ed_name
+       jsr ed_get                      ; ed_v0 = its value (16.16)
        #MOVQ ed_v, ed_v0
        lda ev_x
        sta ed_x0
        lda ev_x+1
        sta ed_x0+1
        lda #0
        sta ed_moved
_drag:  jsr wait_frame
        jsr gui_poll
        lda ev_type
        cmp #EV_UP
        beq _up
        cmp #EV_MOVE
        bne _drag
        jsr ed_dragto
        bra _drag
_up:    jsr ed_dragto                   ; (where the button came up counts too)
        lda ed_moved
        bne +
        ldx ed_f
        jsr ed_fptr
        jsr ed_vptr
        jmp ed_type
+       jsr ed_preview
        clc
        rts

; the pointer at ev_x: once it has moved 2 pixels, the value is v0 + dx * step (kept to
; its limits), stored and shown
ed_dragto:
        sec                             ; dx = x - x0
        lda ev_x
        sbc ed_x0
        sta ed_dx
        lda ev_x+1
        sbc ed_x0+1
        sta ed_dx+1
        lda ed_moved
        bne +
        lda ed_dx+1                     ; (-1 .. 1: not yet)
        cmp #$ff
        beq _neg
        cmp #0
        bne _go
        lda ed_dx
        cmp #2
        bcc _r
        bra _go
_neg:   lda ed_dx
        cmp #$ff
        bcs _r
_go:    inc ed_moved
+       ldx ed_f
        jsr ed_fptr
        jsr ed_vptr
        lda #0
        ldx #0
        ldy ed_dx
        ldz ed_dx+1
        stq fm_a
        ldy #EF_STEP
        jsr ed_qfield
        jsr fmul
        stq tq
        ldz #0
        #ADDQ ed_v0, tq, ed_v
        jsr ed_limit
        jsr ed_put
        ldx ed_f
        jsr ed_field_draw
_r:     rts

; type a number for field ed_f (ed_q, ed_vp set)
ed_type:
        jsr ed_get
        #MOVQ ed_v, gf_v
        lda #$84
        jsr gui_fmt
        ldx #0
-       lda gf_str,x
        sta ge_buf,x
        beq +
        inx
        bra -
+       ldy #EF_PR
        lda (ed_q),y
        pha
        iny
        lda (ed_q),y
        tax
        pla
        jsr gui_edit
        bcs _r
        jsr gui_num
        bcc +
        lda #<st_edbad
        ldx #>st_edbad
        jsr gui_status
        clc
        rts
+       ldx ed_f                        ; (gui_edit used the base page: again)
        jsr ed_fptr
        jsr ed_vptr
        #MOVQ gf_v, ed_v
        jsr ed_limit                    ; (typed values are kept to the limits too: an IOR
        jsr ed_put                      ;  of 0 wouldn't parse)
        ldx ed_f
        jsr ed_field_draw
        jsr ed_preview
_r:     jsr ed_hint
        clc
        rts

; the name, typed
ed_name:
        ldy #0
_in:    lda (ed_vp),y
        sta ge_buf,y
        beq _ask
        iny
        cpy #11
        bne _in
        lda #0
        sta ge_buf,y
_ask:   lda #<ep_name
        ldx #>ep_name
        jsr gui_edit
        bcs _done
        ldx ed_f
        jsr ed_fptr
        jsr ed_vptr
        ldy #0
_out:   lda ge_buf,y
        sta (ed_vp),y
        beq _done
        iny
        cpy #11
        bne _out
        lda #0
        sta (ed_vp),y
_done:  ldx ed_f
        jsr ed_field_draw
        jsr ed_hint
        clc
        rts

; ed_v = the field's value as 16.16 (a word: its whole part)
ed_get:
        ldy #EF_KIND
        lda (ed_q),y
        cmp #EK_WORD
        beq +
        ldy #3
-       lda (ed_vp),y
        sta ed_v,y
        dey
        bpl -
        rts
+       lda #0
        sta ed_v
        sta ed_v+1
        ldy #0
        lda (ed_vp),y
        sta ed_v+2
        iny
        lda (ed_vp),y
        sta ed_v+3
        rts
; ed_v back into the record
ed_put:
        ldy #EF_KIND
        lda (ed_q),y
        cmp #EK_WORD
        beq +
        ldy #3
-       lda ed_v,y
        sta (ed_vp),y
        dey
        bpl -
        rts
+       ldy #0
        lda ed_v+2
        sta (ed_vp),y
        iny
        lda ed_v+3
        sta (ed_vp),y
        rts
; ed_v kept to the field's limits
ed_limit:
        ldy #EF_LO
        jsr ed_qfield
        stq tq
        #BLEQ tq, ed_v, +
        #MOVQ tq, ed_v
+       ldy #EF_HI
        jsr ed_qfield
        stq tq
        #BLEQ ed_v, tq, +
        #MOVQ tq, ed_v
+       rts
; Q = the dword at field entry + Y
ed_qfield:
        lda (ed_q),y
        sta ed_t
        iny
        lda (ed_q),y
        sta ed_t+1
        iny
        lda (ed_q),y
        sta ed_t+2
        iny
        lda (ed_q),y
        sta ed_t+3
        ldq ed_t
        rts

;---------------------------------------------------------------------------------------
; the screen
;---------------------------------------------------------------------------------------
ed_screen:
        jsr d6_clip_all
        #GXY 0, 0, 639, 9               ; the title bar
        lda #GC_BAR
        jsr gui_fill
        #GTEXT 1, 1, GC_YELLOW, $ff, st_edtitle
        #GXY 0, 10, 639, 189
        lda #GC_PANEL
        jsr gui_fill
        #GXY RW_X - 2, RW_Y - 2, RW_X + RW_W + 1, RW_Y + RW_H + 1
        lda #GC_FRAME
        sta d6_col
        jsr d6_frame
        #GXY RW_X - 1, RW_Y - 1, RW_X + RW_W, RW_Y + RW_H
        lda #GC_BLACK
        jsr gui_fill
        ldx #0                          ; the headings
_h:     lda #30
        sta d6_tc
        lda ed_heads,x
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_YELLOW
        sta d6_col
        lda #$ff
        sta d6_bg
        phx
        lda ed_head_lo,x
        pha
        lda ed_head_hi,x
        tax
        pla
        jsr d6_text
        plx
        inx
        cpx #7
        bne _h
        ldx #0                          ; the buttons
_bt:    phx
        lda ed_bx,x
        sta d6_x
        clc
        adc #63
        sta d6_x1
        lda #0
        sta d6_x+1
        sta d6_x1+1
        sta d6_y+1
        sta d6_y1+1
        lda ed_by,x
        sec
        sbc #2
        sta d6_y
        clc
        adc #10
        sta d6_y1
        lda #GC_FRAME
        sta d6_col
        jsr d6_frame
        plx
        phx
        lda ed_bx,x
        lsr
        lsr
        lsr
        inc a
        sta d6_tc
        lda ed_by,x
        sta d6_y
        lda #GC_WHITE
        sta d6_col
        lda ed_pnames_lo,x
        pha
        lda ed_pnames_hi,x
        tax
        pla
        jsr d6_text
        plx
        inx
        cpx #8
        bne _bt
        #GTEXT 1, ED_BY - 12, GC_LIGHT, $ff, st_presets
        #GXY 560, 33, 599, 41           ; the swatches
        lda #ED_SW1
        jsr gui_fill
        #GXY 560, 57, 599, 65
        lda #ED_SW2
        jsr gui_fill
        jsr ed_fields_all
ed_hint:
        lda #<st_edhint
        ldx #>st_edhint
        jmp gui_status
st_presets:     .null "Presets:"

ed_fields_all:
        ldx #0
-       phx
        jsr ed_field_draw
        plx
        inx
        cpx #ED_NF
        bne -
        rts

; field X: its area cleared, its label and value; the swatches' colours
ed_field_draw:
        stx ed_fd
        jsr ed_fptr
        jsr ed_vptr
        ldy #EF_COL                     ; clear it: columns col .. col + w - 1
        lda (ed_q),y
        sta d6_tc
        jsr ed_col8
        sta d6_x
        stx d6_x+1
        ldy #EF_COL
        lda (ed_q),y
        ldy #EF_W
        clc
        adc (ed_q),y
        jsr ed_col8
        sec
        sbc #1
        sta d6_x1
        txa
        sbc #0
        sta d6_x1+1
        ldy #EF_Y
        lda (ed_q),y
        sta d6_y
        clc
        adc #7
        sta d6_y1
        lda #0
        sta d6_y+1
        sta d6_y1+1
        lda #GC_PANEL
        jsr gui_fill
        ldy #EF_Y
        lda (ed_q),y
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_LIGHT
        sta d6_col
        lda #$ff
        sta d6_bg
        ldy #EF_LBL
        lda (ed_q),y
        pha
        iny
        lda (ed_q),y
        tax
        pla
        jsr d6_text
        lda #GC_WHITE
        sta d6_col
        ldy #EF_KIND
        lda (ed_q),y
        cmp #EK_NAME
        bne +
        lda ed_vp
        ldx ed_vp+1
        jmp d6_text
+       cmp #EK_BIT
        bne +
        ldy #0
        lda (ed_vp),y
        and #1
        beq _no
        lda #<st_yes
        ldx #>st_yes
        jmp d6_text
_no:    lda #<st_no
        ldx #>st_no
        jmp d6_text
+       jsr ed_get
        #MOVQ ed_v, gf_v
        ldy #EF_KIND
        lda (ed_q),y
        cmp #EK_WORD
        beq +
        lda #2
        jsr gui_fmt
        bra ++
+       lda #0
        jsr gui_fmt
+       lda #<gf_str
        ldx #>gf_str
        jsr d6_text
        lda ed_fd                       ; a colour: its swatch
        cmp #6
        bcs +
        lda #DM_COL
        ldx #ED_SW1
        jmp ed_swatch
+       cmp #9
        bcs +
        lda #DM_COL2
        ldx #ED_SW2
        jmp ed_swatch
+       rts
st_yes:         .null "yes"
st_no:          .null "no"

; A = a column -> A (low), X (high) = 8 A
ed_col8:
        ldx #0
        stx tmp0
        asl
        rol tmp0
        asl
        rol tmp0
        asl
        rol tmp0
        ldx tmp0
        rts

; palette entry X = the colour at record offset A (each part 0 .. 1 -> 0 .. 255)
ed_swatch:
        stx ed_t+1                      ; the entry
        sta ed_t+2                      ; the part's offset
        ldx #0
_c:     ldy ed_t+2
        iny                             ; byte 3: the whole part's top (sign)
        iny
        iny
        lda (ed_p),y
        bmi _z                          ; below 0: 0
        dey
        ora (ed_p),y                    ; the whole part: 1 or more is 255
        bne _f
        dey
        lda (ed_p),y                    ; else the fraction's top byte
        bra _s
_f:     lda #$ff
        bra _s
_z:     lda #0
_s:     sta tmp0                        ; nibble-swapped
        asl
        asl
        asl
        asl
        sta tmp1
        lda tmp0
        lsr
        lsr
        lsr
        lsr
        ora tmp1
        ldy ed_t+1
        cpx #0
        bne +
        sta $d100,y
        bra _n
+       cpx #1
        bne +
        sta $d200,y
        bra _n
+       sta $d300,y
_n:     clc
        lda ed_t+2
        adc #4
        sta ed_t+2
        inx
        cpx #3
        bne _c
        rts

; palette entries 16..231: the 6x6x6 cube (k * 51 each); the GUI keeps 0..15
ed_palette:
        ldy #16
        lda #0
        sta ed_r
_r:     lda #0
        sta ed_g
_g:     lda #0
        sta ed_b
_b:     ldx ed_r
        lda ed_cube,x
        sta $d100,y
        ldx ed_g
        lda ed_cube,x
        sta $d200,y
        ldx ed_b
        lda ed_cube,x
        sta $d300,y
        iny
        inc ed_b
        lda ed_b
        cmp #6
        bne _b
        inc ed_g
        lda ed_g
        cmp #6
        bne _g
        inc ed_r
        lda ed_r
        cmp #6
        bne _r
        rts
ed_cube:        .for ci = 0, ci < 6, ci += 1    ; k * 51, nibble-swapped
                .byte ((ci * 51) & 15) << 4 | (ci * 51) >> 4
                .next

; trace the preview (the window cleared first)
ed_preview:
        lda #<st_edtrace
        ldx #>st_edtrace
        jsr gui_status
        jsr ed_trace                    ; (resident: overlay 7 is written back and loaded again)
        jsr ed_pset                     ; (the tracer used the base page's pointers)
        jmp ed_hint
; ed_p = material ed_n's record
ed_pset:
        ldx ed_n
        lda dmat_lo,x
        sta ed_p
        lda dmat_hi,x
        sta ed_p+1
        rts

ed_orig:        .fill DMAT_SIZE
ed_buf:         .fill EP_SIZE
ed_v:           .dword 0
ed_v0:          .dword 0
ed_t:           .dword 0
ed_x0:          .word 0
ed_dx:          .word 0
ed_moved:       .byte 0
ed_f:           .byte 0
ed_fd:          .byte 0
ed_c:           .byte 0
ed_quit:        .byte 0
ed_r:           .byte 0
ed_g:           .byte 0
ed_b:           .byte 0
