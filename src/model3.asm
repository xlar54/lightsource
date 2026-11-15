;=======================================================================================
; model3.asm - the modeller's panels and commands: the object list, the properties, the
; menus and what they do; the overlay's variables
;=======================================================================================

CMD_NEW         = 1
CMD_OPEN        = 2
CMD_SAVE        = 3
CMD_SAVEAS      = 4
CMD_EXPORT      = 5
CMD_RENDER      = 6
CMD_PREVIEW     = 7
CMD_EXIT        = 8
CMD_DELETE      = 10
CMD_DUP         = 11
CMD_UP          = 12
CMD_DOWN        = 13
CMD_INDENT      = 14
CMD_OUTDENT     = 15
CMD_WORLD       = 16
CMD_UNDO        = 17
CMD_REDO        = 18
SEL_WORLD       = $81                   ; ms_sel: the world settings ($80: the camera)
CMD_ADDLIGHT    = 19
CMD_ADD         = 20                    ; + OT_* (20-29)
CMD_MATNEXT     = 31
CMD_MATPREV     = 32
CMD_MATNEW      = 33
CMD_MATEDIT     = 34
CMD_ZOOMIN      = 40
CMD_ZOOMOUT     = 41
CMD_VRESET      = 42
CMD_LOCATE      = 43
CMD_AIM         = 44                    ; the camera (modelres.asm cam_cmd)
CMD_CAMFRONT    = 45
CMD_CAMTOP      = 46
CMD_CAMSIDE     = 47
CMD_SNAP        = 48                    ; (also cam_cmd)

type_names:     .word tn0, tn1, tn2, tn3, tn4, tn5, tn5b, tn6, tn7, tn8, tn9
tn0:    .null "Sphere"
tn1:    .null "Box"
tn2:    .null "Cylinder"
tn3:    .null "Cone"
tn4:    .null "Plane"
tn5:    .null "Prism"
tn5b:   .null "Lathe"
tn6:    .null "Union"
tn7:    .null "Merge"
tn8:    .null "Intersection"
tn9:    .null "Difference"

;=======================================================================================
; the object list: objects (indented by depth), lights, the camera
;=======================================================================================
list_count:                             ; A = entries
        clc
        lda doc_nobj
        adc doc_nlight
        adc #2                          ; (the camera, the world)
        rts
; A = the selection's entry, or $ff. The entries: the world, the objects, the lights, the
; camera.
sel_entry:
        lda ms_sel
        cmp #SEL_WORLD
        bne +
        lda #0
        rts
+       cmp #$80
        bne +
        sec                             ; the camera: 1 + objects + lights
        lda doc_nobj
        adc doc_nlight
        rts
+       bcs _none
        cmp #$40
        bcc +
        and #$3f
        clc
        adc doc_nobj
+       inc a
        rts
_none:  lda #$ff
        rts

draw_list:
        jsr d6_clip_all
        #GXY LIST_X, 10, 639, 117
        lda #GC_PANEL
        jsr gui_fill
        ; a new selection: into view
        lda ms_sel
        cmp ms_lsel
        beq _clamp
        sta ms_lsel
        jsr sel_entry
        cmp #$ff
        beq _clamp
        cmp ms_lscroll
        bcs +
        sta ms_lscroll
        bra _clamp
+       sec
        sbc #LIST_ROWS - 1
        bcc _clamp
        cmp ms_lscroll
        bcc _clamp
        sta ms_lscroll
_clamp: ; no further down than a full page
        jsr list_count
        sec
        sbc #LIST_ROWS
        bcs +
        lda #0
+       cmp ms_lscroll
        bcs _draw
        sta ms_lscroll
_draw:
        lda #0
        sta dl_r
_row:
        clc
        lda dl_r
        adc ms_lscroll
        sta dl_e
        jsr list_count
        cmp dl_e
        bcc _done
        beq _done
        lda dl_r                        ; y = LIST_Y0 + 9 r
        asl
        asl
        asl
        clc
        adc dl_r
        adc #LIST_Y0
        sta dl_y
        ; the selected row's background
        jsr sel_entry
        cmp dl_e
        bne +
        lda dl_y
        sec
        sbc #1
        sta d6_y
        lda #0
        sta d6_y+1
        sta d6_y1+1
        lda dl_y
        clc
        adc #7
        sta d6_y1
        lda #<LIST_X
        sta d6_x
        lda #>LIST_X
        sta d6_x+1
        lda #<639
        sta d6_x1
        lda #>639
        sta d6_x1+1
        lda #GC_SEL
        jsr gui_fill
+       lda dl_y
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_WHITE
        sta d6_col
        lda #$ff
        sta d6_bg
        lda #LIST_COL
        sta d6_tc
        lda dl_e                        ; entry 0: the world; then objects from 0
        bne +
        jmp _world
+       dec a
        sta dl_e
        cmp doc_nobj
        bcs _nobj
        tax                             ; an object: its box, indent, name
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        jsr vis_box
        ldx dl_e                        ; (grey if hidden, by itself or a group)
        lda hid_flag,x
        beq +
        lda #GC_LIGHT
        sta d6_col
+       ldy #O_DEPTH
        lda (op),y
        clc
        adc d6_tc
        sta d6_tc
        clc
        lda op
        adc #O_NAME
        tay
        lda op+1
        adc #0
        tax
        tya
        jsr d6_text
        bra _next
_nobj:
        sec
        sbc doc_nobj
        cmp doc_nlight
        bcs _cam
        pha
        lda #GC_ORANGE
        sta d6_col
        lda #<st_light
        ldx #>st_light
        jsr d6_text
        pla                             ; its number, 1 - 16
        inc a
        cmp #10
        bcc +
        sbc #10                         ; (carry set)
        pha
        lda #'1'
        jsr d6_char
        pla
+       ora #'0'
        jsr d6_char
        bra _next
_cam:
        lda #GC_GREEN
        sta d6_col
        lda #<st_camera
        ldx #>st_camera
        jsr d6_text
        bra _next
_world:
        lda #GC_CYAN
        sta d6_col
        lda #<st_world
        ldx #>st_world
        jsr d6_text
_next:
        inc dl_r
        lda dl_r
        cmp #LIST_ROWS
        beq _done
        jmp _row
_done:
        ; the scroll bar: a track, and a thumb for the rows shown
        #GXY SB_X0, SB_Y0, SB_X0 + 6, SB_Y0 + SB_H - 1
        lda #GC_DARK
        jsr gui_fill
        jsr sb_thumb
        lda sb_top
        sta d6_y
        lda sb_bot
        sta d6_y1
        lda #<(SB_X0 + 1)
        sta d6_x
        lda #<(SB_X0 + 5)
        sta d6_x1
        lda #GC_LIGHT
        jmp gui_fill

SB_X0           = 632                   ; the scroll bar: x 632-638, y 11-116
SB_Y0           = 11
SB_H            = 106
; sb_top / sb_bot = the thumb's first and last y
sb_thumb:
        lda ms_lscroll
        jsr sb_pos
        sta sb_top
        clc
        lda ms_lscroll
        adc #LIST_ROWS
        sta tmp0
        jsr list_count
        sta tmp1
        lda tmp0
        cmp tmp1
        bcs _all                        ; (all of the rest is shown)
        jsr sb_pos
        bra +
_all:   lda #SB_Y0 + SB_H
+       dec a
        sta sb_bot
        rts
; A = SB_Y0 + entry A * SB_H / entries
sb_pos:
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        lda #SB_H
        sta MULTINB
        lda MULTOUT                     ; (at most 106 * 51)
        ldx MULTOUT+1
        sta MULTINA
        stx MULTINA+1
        jsr list_count
        sta MULTINB
-       bit DIVBUSY
        bmi -
        lda DIVOUT+4
        clc
        adc #SB_Y0
        rts

; a click on the scroll bar: above the thumb a page up, below it a page down, on it a
; drag (sb_drag_move)
sb_click:
        jsr sb_thumb
        lda ev_y
        cmp sb_top
        bcs +
        sec                             ; a page up
        lda ms_lscroll
        sbc #LIST_ROWS - 1
        bcs ++
        lda #0
        bra ++
+       lda sb_bot
        cmp ev_y
        bcs _grab
        clc                             ; a page down (draw_list keeps it in range)
        lda ms_lscroll
        adc #LIST_ROWS - 1
+       sta ms_lscroll
        jmp draw_list
_grab:  sec
        lda ev_y
        sbc sb_top
        sta sb_grab
        lda #1
        sta sb_drag
        rts
; the pointer moved while dragging the thumb: scroll to match
sb_drag_move:
        sec
        lda ev_y
        sbc sb_grab
        bcc _top
        sec
        sbc #SB_Y0
        bcc _top
        sta MULTINA                     ; entry = (y - y0) * entries / SB_H
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        jsr list_count
        sta MULTINB
        lda MULTOUT
        ldx MULTOUT+1
        sta MULTINA
        stx MULTINA+1
        lda #SB_H
        sta MULTINB
-       bit DIVBUSY
        bmi -
        lda DIVOUT+4
        bra +
_top:   lda #0
+       cmp ms_lscroll
        beq +
        sta ms_lscroll
        jmp draw_list
+       rts
; the visible box of the object at op, at the left of row dl_y: filled = shown in the
; views. (d6_y, the colours and d6_tc are set again for the text after it.)
vis_box:
        lda #<LIST_X
        sta d6_x
        lda #>LIST_X
        sta d6_x+1
        lda #<(LIST_X + 6)
        sta d6_x1
        lda #>(LIST_X + 6)
        sta d6_x1+1
        lda dl_y
        sta d6_y
        clc
        adc #6
        sta d6_y1
        lda #0
        sta d6_y+1
        sta d6_y1+1
        lda #GC_LIGHT
        sta d6_col
        jsr d6_frame
        ldy #O_FLAGS
        lda (op),y
        and #OF_HIDE
        bne +
        lda #<(LIST_X + 2)
        sta d6_x
        lda #<(LIST_X + 4)
        sta d6_x1
        inc d6_y
        inc d6_y
        dec d6_y1
        dec d6_y1
        lda #GC_GREEN
        jsr gui_fill
+       lda dl_y
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_WHITE
        sta d6_col
        lda #$ff
        sta d6_bg
        rts
st_world:       .null "World"
st_light:       .null "Light "
st_camera:      .null "Camera"

list_click:
        lda ev_x+1                      ; the scroll bar?
        cmp #>(SB_X0 - 1)
        bcc +
        lda ev_x
        cmp #<(SB_X0 - 1)
        bcc +
        jmp sb_click
+       lda ev_y
        sec
        sbc #LIST_Y0 - 1
        bcc _r
        ldx #0
-       cmp #9
        bcc +
        sbc #9
        inx
        bra -
+       cpx #LIST_ROWS
        bcs _r
        txa
        clc
        adc ms_lscroll
        sta dl_e
        jsr list_count
        cmp dl_e
        bcc _r
        beq _r
        lda dl_e                        ; entry 0: the world
        bne +
        lda #SEL_WORLD
        bra _set
+       dec dl_e                        ; (then objects from 0)
        lda dl_e                        ; an object's box: shown / hidden
        cmp doc_nobj
        bcs _ent
        lda ev_x+1
        cmp #>(LIST_X + 9)
        bne _ent
        lda ev_x
        cmp #<(LIST_X + 9)
        bcs _ent
        ldx dl_e
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        jsr u_save
        ldx dl_e
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_FLAGS
        lda (op),y
        eor #OF_HIDE
        sta (op),y
        jmp redraw_work
_ent:   lda dl_e                        ; the entry -> the selection
        cmp doc_nobj
        bcc _set
        sec
        sbc doc_nobj
        cmp doc_nlight
        bcs +
        ora #$40
        bra _set
+       sbc doc_nlight                  ; (carry set) 0 the camera, 1 the world
        ora #$80
_set:   sta ms_sel
        lda #$ff
        sta ms_ptobj
        lda #<st_hello
        ldx #>st_hello
        sta ms_msg
        stx ms_msg+1
        jmp redraw_work
_r:     rts

;=======================================================================================
; the properties: a list of fields for what's selected (props_build), drawn two to a row
;=======================================================================================
PK_VAL          = 0                     ; a number (16.16)
PK_NAME         = 1                     ; a name (11 characters)
PK_MAT          = 2                     ; the object's material: a click takes the next
PK_WORD         = 3                     ; a whole number (a word)
PK_BIT          = 4                     ; bit 0 of a byte: a click flips it
PK_TEXT         = 5                     ; just text
PK_BYTE         = 6                     ; a whole number (a byte)

; gf_v = the word (or byte: kind A = PK_BYTE) at lp, as a whole number
pk_getw:
        tax
        lda #0
        sta gf_v
        sta gf_v+1
        sta gf_v+3
        ldy #0
        lda (lp),y
        sta gf_v+2
        cpx #PK_BYTE
        beq +
        iny
        lda (lp),y
        sta gf_v+3
+       rts

; PF row, column, kind, label, offset from lp
PF .macro row, col, kind, label, off
        ldx pf_n
        lda #\row
        sta pf_row,x
        lda #\col
        sta pf_col,x
        lda #\kind
        sta pf_kind,x
        lda #<\label
        sta pf_lbl_lo,x
        lda #>\label
        sta pf_lbl_hi,x
        clc
        lda lp
        adc #<(\off)
        sta pf_adr_lo,x
        lda lp+1
        adc #>(\off)
        sta pf_adr_hi,x
        inc pf_n
.endmacro

props_build:
        lda #0
        sta pf_n
        lda ms_sel
        cmp #$ff
        bne +
        rts
+       cmp #$c0
        bcc +
        jmp pb_material
+       cmp #$80
        bne +
        jmp pb_camera
+       cmp #SEL_WORLD
        bne +
        jmp pb_world
+       cmp #$40
        bcc +
        jmp pb_light
+       tax                             ; an object
        lda obj_lo,x
        sta lp
        lda obj_hi,x
        sta lp+1
        #PF 0, PCOL_A, PK_NAME, pl_name, O_NAME
        #PF 1, PCOL_A, PK_VAL, pl_px, O_POS
        #PF 2, PCOL_A, PK_VAL, pl_py, O_POS+4
        #PF 3, PCOL_A, PK_VAL, pl_pz, O_POS+8
        #PF 1, PCOL_B, PK_VAL, pl_rx, O_ROT
        #PF 2, PCOL_B, PK_VAL, pl_ry, O_ROT+4
        #PF 3, PCOL_B, PK_VAL, pl_rz, O_ROT+8
        #PF 4, PCOL_A, PK_VAL, pl_s, O_SCALE
        #PF 6, PCOL_A, PK_MAT, pl_mat, O_MAT
        #PF 7, PCOL_A, PK_BIT, pl_nosh, O_FLAGS
        ldy #O_TYPE
        lda (lp),y
        cmp #OT_SPHERE
        bne +
        #PF 4, PCOL_B, PK_VAL, pl_r, O_P
        rts
+       cmp #OT_BOX
        bne +
        #PF 4, PCOL_B, PK_VAL, pl_sx, O_P
        #PF 5, PCOL_A, PK_VAL, pl_sy, O_P+4
        #PF 5, PCOL_B, PK_VAL, pl_sz, O_P+8
        rts
+       cmp #OT_CYL
        bne +
        #PF 4, PCOL_B, PK_VAL, pl_r, O_P
        #PF 5, PCOL_A, PK_VAL, pl_h, O_P+4
        rts
+       cmp #OT_CONE
        bne +
        #PF 4, PCOL_B, PK_VAL, pl_r1, O_P
        #PF 5, PCOL_A, PK_VAL, pl_r2, O_P+4
        #PF 5, PCOL_B, PK_VAL, pl_h, O_P+8
        rts
+       cmp #OT_LATHE
        beq _corner
        cmp #OT_PRISM
        bne _r
        #PF 4, PCOL_B, PK_VAL, pl_h, O_P
_corner:
        jsr pt_valid                    ; the corner picked: its two numbers (a copy in
        bcc _r                          ; pt_cur: prop_click puts it back)
        jsr pt_load
        ldy #O_TYPE                     ; (txt_ptr: the object, from pt_valid)
        lda (txt_ptr),y
        ldx #<pt_cur
        stx lp
        ldx #>pt_cur
        stx lp+1
        cmp #OT_LATHE
        beq _lathe
        #PF 5, PCOL_A, PK_VAL, pl_cx, 0
        #PF 5, PCOL_B, PK_VAL, pl_cz, 4
_r:     rts
_lathe: #PF 5, PCOL_A, PK_VAL, pl_r, 0  ; a lathe's: radius, height
        #PF 5, PCOL_B, PK_VAL, pl_py, 4
        rts
pb_light:
        and #$3f
        tax
        lda dlight_lo,x
        sta lp
        lda dlight_hi,x
        sta lp+1
        #PF 1, PCOL_A, PK_VAL, pl_px, DL_POS
        #PF 2, PCOL_A, PK_VAL, pl_py, DL_POS+4
        #PF 3, PCOL_A, PK_VAL, pl_pz, DL_POS+8
        #PF 1, PCOL_B, PK_VAL, pl_cr, DL_COL
        #PF 2, PCOL_B, PK_VAL, pl_cg, DL_COL+4
        #PF 3, PCOL_B, PK_VAL, pl_cb, DL_COL+8
        #PF 4, PCOL_A, PK_BIT, pl_nosh, DL_FLAGS
        rts
pb_camera:
        lda #<doc_cam_loc
        sta lp
        lda #>doc_cam_loc
        sta lp+1
        #PF 1, PCOL_A, PK_VAL, pl_px, 0
        #PF 2, PCOL_A, PK_VAL, pl_py, 4
        #PF 3, PCOL_A, PK_VAL, pl_pz, 8
        #PF 1, PCOL_B, PK_VAL, pl_lx, 12
        #PF 2, PCOL_B, PK_VAL, pl_ly, 16
        #PF 3, PCOL_B, PK_VAL, pl_lz, 20
        #PF 4, PCOL_A, PK_VAL, pl_ang, 24
        rts
pb_world:
        lda #<doc_bg
        sta lp
        lda #>doc_bg
        sta lp+1
        #PF 1, PCOL_A, PK_VAL, pl_bgr, 0
        #PF 2, PCOL_A, PK_VAL, pl_bgg, 4
        #PF 3, PCOL_A, PK_VAL, pl_bgb, 8
        #PF 1, PCOL_B, PK_BYTE, pl_trace, doc_maxtrace - doc_bg
        rts
pb_material:
        and #$3f
        tax
        lda dmat_lo,x
        sta lp
        lda dmat_hi,x
        sta lp+1
        #PF 0, PCOL_A, PK_NAME, pl_name, DM_NAME
        #PF 1, PCOL_A, PK_VAL, pl_cr, DM_COL
        #PF 2, PCOL_A, PK_VAL, pl_cg, DM_COL+4
        #PF 3, PCOL_A, PK_VAL, pl_cb, DM_COL+8
        #PF 1, PCOL_B, PK_VAL, pl_dif, DM_DIFF
        #PF 2, PCOL_B, PK_VAL, pl_pho, DM_PHONG
        #PF 3, PCOL_B, PK_WORD, pl_psz, DM_PSIZE
        #PF 4, PCOL_A, PK_VAL, pl_amb, DM_AMB
        #PF 4, PCOL_B, PK_VAL, pl_ref, DM_REFL
        #PF 5, PCOL_A, PK_VAL, pl_trn, DM_TRANS
        #PF 5, PCOL_B, PK_VAL, pl_ior, DM_IOR
        #PF 6, PCOL_B, PK_VAL, pl_csz, DM_CSCALE  ; (before the toggle: it takes the rest)
        #PF 6, PCOL_A, PK_BIT, pl_chk, DM_FLAGS
        #PF 7, PCOL_A, PK_VAL, pl_r2, DM_COL2
        #PF 7, PCOL_B, PK_VAL, pl_g2, DM_COL2+4
        #PF 8, PCOL_A, PK_VAL, pl_b2, DM_COL2+8
        rts


pl_name:        .null "Name "
pl_px:          .null "X"
pl_py:          .null "Y"
pl_pz:          .null "Z"
pl_rx:          .null "RX"
pl_ry:          .null "RY"
pl_rz:          .null "RZ"
pl_s:           .null "S"
pl_r:           .null "R"
pl_r1:          .null "R1"
pl_r2:          .null "R2"
pl_g2:          .null "G2"
pl_b2:          .null "B2"
pl_h:           .null "H"
pl_sx:          .null "SX"
pl_sy:          .null "SY"
pl_sz:          .null "SZ"
pl_cx:          .null "CX"
pl_cz:          .null "CZ"
pl_mat:         .null "Mat "
pl_cr:          .null "R"
pl_cg:          .null "G"
pl_cb:          .null "B"
pl_lx:          .null "LX"
pl_ly:          .null "LY"
pl_lz:          .null "LZ"
pl_ang:         .null "Ang"
pl_bgr:         .null "BgR"
pl_bgg:         .null "BgG"
pl_bgb:         .null "BgB"
pl_trace:       .null "Trace"
pl_nosh:        .null "No shadow"
pl_dif:         .null "Dif"
pl_pho:         .null "Pho"
pl_psz:         .null "Siz"
pl_amb:         .null "Amb"
pl_ref:         .null "Ref"
pl_trn:         .null "Trn"
pl_ior:         .null "IOR"
pl_chk:         .null "Chk"
pl_csz:         .null "Sq"

draw_props:
        jsr d6_clip_all
        #GXY LIST_X, 118, 639, 189
        lda #GC_DARK
        jsr gui_fill
        jsr props_build
        ; a heading: what it is
        lda #GC_LIGHT
        sta d6_col
        lda #$ff
        sta d6_bg
        jsr props_title
        lda #0
        sta dp_i
_f:
        lda dp_i
        cmp pf_n
        bne +
        rts
+       tax
        lda pf_row,x                    ; y = PROP_Y0 + 8 row
        asl
        asl
        asl
        clc
        adc #PROP_Y0
        sta d6_y
        lda #0
        sta d6_y+1
        lda pf_col,x
        sta d6_tc
        lda pf_lbl_lo,x
        sta dp_p
        lda pf_lbl_hi,x
        sta dp_p+1
        lda #GC_LIGHT
        sta d6_col
        lda dp_p
        ldx dp_p+1
        jsr d6_text
        ldx dp_i
        lda pf_adr_lo,x
        sta lp
        lda pf_adr_hi,x
        sta lp+1
        lda #GC_WHITE
        sta d6_col
        lda pf_kind,x
        jsr pf_value_text               ; A/X = the value as text
        jsr d6_text
        inc dp_i
        bra _f

; the heading on the properties panel's first row (row 0 is the name: the heading goes
; on the status of ... ) - here: the type, at the right of row 7
props_title:
        rts

; the field (lp, kind A) as text -> A/X
pf_value_text:
        cmp #PK_NAME
        bne +
        lda lp
        ldx lp+1
        rts
+       cmp #PK_MAT
        bne +
        ldy #0
        lda (lp),y
        bne _mat
        lda #<st_none
        ldx #>st_none
        rts
_mat:   tax
        dex
        clc
        lda dmat_lo,x
        adc #DM_NAME
        pha
        lda dmat_hi,x
        adc #0
        tax
        pla
        rts
+       cmp #PK_BIT
        bne +
        ldy #0
        lda (lp),y
        and #1
        beq _off
        lda #<st_on
        ldx #>st_on
        rts
_off:   lda #<st_off
        ldx #>st_off
        rts
+       cmp #PK_WORD                    ; a word or a byte, shown as a number
        beq +
        cmp #PK_BYTE
        bne ++
+       jsr pk_getw
        lda #0
        jsr gui_fmt
        bra _str
+       ldy #0                          ; a 16.16 number, 2 decimals
-       lda (lp),y
        sta gf_v,y
        iny
        cpy #4
        bne -
        lda #2
        jsr gui_fmt
_str:   ; " " + the number (right after the label)
        ldx #0
        lda #' '
        sta pv_text
-       lda gf_str,x
        sta pv_text+1,x
        beq +
        inx
        bra -
+       lda #<pv_text
        ldx #>pv_text
        rts
st_none:        .null "(none)"
st_on:          .null " yes"
st_off:         .null " no"

prop_click:
        lda ev_y                        ; the row
        sec
        sbc #PROP_Y0
        bcc _r
        lsr
        lsr
        lsr
        sta pc_row
        lda ev_x+1                      ; the column: A (60-69) or B (70-79)
        sta tmp0
        lda ev_x
        lsr tmp0
        ror
        lsr tmp0
        ror
        lsr tmp0
        ror
        ldx #PCOL_A
        cmp #PCOL_B
        bcc +
        ldx #PCOL_B
+       stx pc_col
        jsr props_build
        ldx #0
_f:     cpx pf_n
        beq _r
        lda pf_row,x
        cmp pc_row
        bne _n
        lda pf_kind,x                   ; names and materials take the whole row
        cmp #PK_NAME
        beq _hit
        cmp #PK_MAT
        beq _hit
        cmp #PK_BIT
        beq _hit
        lda pf_col,x
        cmp pc_col
        beq _hit
_n:     inx
        bra _f
_r:     rts
_hit:
        stx pc_f
        lda pf_adr_lo,x
        sta lp
        lda pf_adr_hi,x
        sta lp+1
        lda pf_kind,x
        cmp #PK_MAT
        bne _edit
        jsr u_save
        ldy #0                          ; the next material (or none)
        lda (lp),y
        clc
        adc #1
        cmp doc_nmat
        beq _setm
        bcc _setm
        lda #0
_setm:  sta (lp),y
        jmp redraw_work
_edit:
        cmp #PK_BIT
        bne +
        jsr u_save
        ldy #0
        lda (lp),y
        eor #1
        sta (lp),y
        jmp redraw_work
+       cmp #PK_NAME
        bne _num
        ldy #0                          ; a name: edit it
-       lda (lp),y
        sta ge_buf,y
        beq +
        iny
        cpy #11
        bne -
        lda #0
        sta ge_buf,y
+       lda #<st_pname
        ldx #>st_pname
        jsr gui_edit
        bcs _esc                        ; (ESC: the status line is back as it was)
        jsr u_save
        ldx pc_f
        lda pf_adr_lo,x
        sta lp
        lda pf_adr_hi,x
        sta lp+1
        ldy #0
-       lda ge_buf,y
        sta (lp),y
        beq _done
        iny
        cpy #11
        bne -
        lda #0
        sta (lp),y
_done:  jmp redraw_work
_num:
        ; a number: start from its value
        cmp #PK_WORD
        beq +
        cmp #PK_BYTE
        bne ++
+       jsr pk_getw
        bra ++
+       ldy #0
-       lda (lp),y
        sta gf_v,y
        iny
        cpy #4
        bne -
+       lda #$84
        jsr gui_fmt
        ldx #0
-       lda gf_str,x
        sta ge_buf,x
        beq +
        inx
        bra -
+       ldx pc_f                        ; the prompt: its label and " = "
        lda pf_lbl_lo,x
        sta txt_ptr
        lda pf_lbl_hi,x
        sta txt_ptr+1
        ldy #0
-       lda (txt_ptr),y
        sta pc_prompt,y
        beq +
        iny
        bra -
+       ldx #0
-       lda st_eq,x
        sta pc_prompt,y
        beq +
        iny
        inx
        bra -
+       lda #<pc_prompt
        ldx #>pc_prompt
        jsr gui_edit
        bcs _esc                        ; (ESC: the status line is back as it was)
        jsr gui_num
        bcc +
        lda #<st_notnum
        ldx #>st_notnum
        sta ms_msg
        stx ms_msg+1
        jmp redraw_work
+       jsr u_save
        ldx pc_f
        lda pf_adr_lo,x
        sta lp
        lda pf_adr_hi,x
        sta lp+1
        lda pf_kind,x
        cmp #PK_BYTE
        beq _wb
        cmp #PK_WORD
        bne +
        ldy #1                          ; a word: the whole part
        lda gf_v+3
        sta (lp),y
_wb:    ldy #0                          ; (a byte: its low part)
        lda gf_v+2
        sta (lp),y
        jmp redraw_work
+       ldy #0
-       lda gf_v,y
        sta (lp),y
        iny
        cpy #4
        bne -
        jsr pt_valid                    ; (a corner's x or z went into pt_cur: back to
        bcc +                           ;  the pool; the same value if it was another)
        jsr pt_store
+       jmp redraw_work
_esc:   rts
st_pname:       .null "Name: "
st_eq:          .null " = "
st_notnum:      .null "That isn't a number"

;=======================================================================================
; commands
;=======================================================================================
model_cmd:
        sta mc_cmd
        cmp #0
        bne +
        rts
+       jsr cmd_changes                 ; a change to the document: undo can go back
        bcc +
        jsr u_save
+       lda mc_cmd
        cmp #CMD_UNDO
        bne +
        jmp cmd_undo
+       cmp #CMD_REDO
        bne +
        jmp cmd_redo
+       cmp #CMD_NEW
        bne +
        jsr model_reset
        jmp _msg_redraw
+       cmp #CMD_ADDLIGHT
        bne +
        jmp cmd_addlight
+       cmp #CMD_ADD
        bcc +
        cmp #CMD_ADD + OT_DIFF + 1
        bcs +
        jmp cmd_add
+       cmp #CMD_DELETE
        bne +
        jmp cmd_delete
+       cmp #CMD_DUP
        bne +
        jmp cmd_dup
+       cmp #CMD_UP
        bne +
        jmp cmd_up
+       cmp #CMD_DOWN
        bne +
        jmp cmd_down
+       cmp #CMD_INDENT
        bne +
        lda #1
        jmp cmd_depth
+       cmp #CMD_OUTDENT
        bne +
        lda #$ff
        jmp cmd_depth
+       cmp #CMD_MATNEXT
        bne +
        lda #1
        jmp cmd_mat
+       cmp #CMD_MATPREV
        bne +
        lda #$ff
        jmp cmd_mat
+       cmp #CMD_MATNEW
        bne +
        jmp cmd_matnew
+       cmp #CMD_MATEDIT
        bne +
        jmp cmd_matedit
+       cmp #CMD_ZOOMIN
        bne +
        lda #<FX(1.5)
        ldx #>FX(1.5)
        ldy #`FX(1.5)
        jmp cmd_zoom
+       cmp #CMD_ZOOMOUT
        bne +
        lda #<FX(1 / 1.5)
        ldx #>FX(1 / 1.5)
        ldy #`FX(1 / 1.5)
        jmp cmd_zoom
+       cmp #CMD_VRESET
        bne +
        jsr views_reset
        jmp redraw_work
+       cmp #CMD_LOCATE
        bne +
        jmp cmd_locate
+       cmp #CMD_AIM
        bcc +
        jmp cam_cmd
+       cmp #CMD_EXIT
        bne +
        jmp cmd_exit
+       cmp #CMD_WORLD                  ; the world's settings in the panel
        bne +
        lda #SEL_WORLD
        sta ms_sel
        jmp redraw_work
+       ; files and renders: resident code (other overlays)
        lda mc_cmd
        jsr do_command                  ; -> A/X = a message
        sta ms_msg
        stx ms_msg+1
        jsr open_check
        lda ms_msg
        ldx ms_msg+1
        cmp #<dc_cancel                 ; cancelled: nothing changed but the status line
        bne +
        cpx #>dc_cancel
        bne +
        jmp gui_status
+       jsr gui_on                      ; (a render or a file: the whole screen)
        jmp redraw_all
_msg_redraw:
        lda #<st_hello
        ldx #>st_hello
        sta ms_msg
        stx ms_msg+1
        jmp redraw_work

; carry set if command mc_cmd changes the document (u_save first): New, Open, Delete ..
; Outdent, the Add commands, and the material ones but Edit
cmd_changes:
        lda mc_cmd
        cmp #CMD_NEW
        beq _yes
        cmp #CMD_OPEN
        beq _yes
        cmp #CMD_DELETE
        bcc _no
        cmp #CMD_WORLD                  ; 10 - 15
        bcc _yes
        cmp #CMD_ADDLIGHT
        bcc _no                         ; (World, Undo, Redo)
        cmp #CMD_MATEDIT                ; 19 - 32
        bcc _yes
        cmp #CMD_SNAP                   ; (Snap changes nothing in the document)
        beq _no
        cmp #CMD_AIM                    ; the camera's
        bcs _yes
_no:    clc
        rts
_yes:   sec
        rts
; after do_command: an Open that didn't open anything takes its u_save back
open_check:
        lda mc_cmd
        cmp #CMD_OPEN
        bne +
        lda ms_msg
        cmp #<dc_opened
        bne _back
        lda ms_msg+1
        cmp #>dc_opened
        beq +
_back:  jmp u_unsave
+       rts

; a message A/X, then everything again
say:
        sta ms_msg
        stx ms_msg+1
        jmp redraw_work

; Exit: back to BASIC, once Y is typed (the document isn't saved: nothing keeps track
; of changes)
cmd_exit:
        lda #0
        sta ge_buf
        lda #<st_exitq
        ldx #>st_exitq
        jsr gui_edit
        bcs _no
        lda ge_buf
        and #$df
        cmp #'Y'
        bne _no
        jsr gui_off
        jmp kst_to_basic
_no:    lda #<dc_cancel
        ldx #>dc_cancel
        sta ms_msg
        stx ms_msg+1
        jmp gui_status
st_exitq:       .null "Leave for BASIC? Anything not saved is lost. Y to leave: "

; pk_w = the selection's place in the world; carry clear if there's none
sel_world:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _nobj
        jsr world_all                   ; an object: its world origin
        lda ms_sel
        sta pk_i
        jsr obj_origin
        sec
        rts
_nobj:  cmp #SEL_WORLD
        beq _none
        cmp #$c0                        ; (a material, or nothing)
        bcs _none
        jsr sel_pos_ptr                 ; a light or the camera: its position
        ldy #11
-       lda (lp),y
        sta pk_w,y
        dey
        bpl -
        sec
        rts
_none:  clc
        rts

; Locate: the top, front and side views centred on the selection (its place in the
; world), at the zoom they have
cmd_locate:
        jsr sel_world
        bcc _none
_centre:
        ldx #0                          ; view v: centre = (w[across], w[up])
-       stx dv_v
        txa
        asl
        adc dv_v
        asl
        asl
        sta tmp0                        ; 12 v
        lda vw_ha,x
        jsr _part
        clc
        lda tmp0
        adc #4
        tay
        jsr _put
        ldx dv_v
        lda vw_va,x
        jsr _part
        clc
        lda tmp0
        adc #8
        tay
        jsr _put
        ldx dv_v
        inx
        cpx #3
        bne -
        jmp redraw_work
_none:  lda #<st_nothing
        ldx #>st_nothing
        jmp say
_part:  ; tv3m = w[axis A]
        asl
        asl
        tax
        ldy #0
-       lda pk_w,x
        sta tv3m,y
        inx
        iny
        cpy #4
        bne -
        rts
_put:   ; ms_view + Y = tv3m
        ldx #0
-       lda tv3m,x
        sta ms_view,y
        iny
        inx
        cpx #4
        bne -
        rts
st_nothing:     .null "Select something to locate"

cmd_zoom:        sta cz_f
        stx cz_f+1
        sty cz_f+2
        lda #0
        sta cz_f+3
        .for si = 0, si < 3, si += 1
        #FMUL ms_view+si*12, cz_f, ms_view+si*12
        .next
        jmp redraw_work

;---------------------------------------------------------------------------------------
; the outline: subtrees, inserting and removing records
;---------------------------------------------------------------------------------------
; A = object -> A = the first object after its subtree
sub_end:
        sta se_i
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        sta se_d
        ldx se_i
-       inx
        cpx doc_nobj
        bcs +
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        lda (op),y
        cmp se_d
        beq +
        bcs -
+       txa
        rts

; make room for A records at object ob_at (shifting the rest up)
obj_open:
        sta oo_n
        clc
        lda doc_nobj
        adc oo_n
        cmp #DOC_MAXOBJ + 1
        bcc +
        sec                             ; no room
        rts
+       lda doc_nobj
        sta oo_i
-       lda oo_i                        ; from the end: record i -> i + n
        cmp ob_at
        beq +
        dec oo_i
        lda oo_i
        tax
        clc
        adc oo_n
        tay
        jsr obj_copy
        bra -
+       clc
        lda doc_nobj
        adc oo_n
        sta doc_nobj
        clc
        rts
; remove oo_n records at ob_at
obj_close:
        lda ob_at
        sta oo_i
-       clc
        lda oo_i
        adc oo_n
        cmp doc_nobj
        bcs +
        tax
        ldy oo_i
        jsr obj_copy
        inc oo_i
        bra -
+       sec
        lda doc_nobj
        sbc oo_n
        sta doc_nobj
        rts
; record X -> record Y
obj_copy:
        lda obj_lo,x
        sta pa
        lda obj_hi,x
        sta pa+1
        lda obj_lo,y
        sta op
        lda obj_hi,y
        sta op+1
        ldy #OBJ_SIZE - 1
-       lda (pa),y
        sta (op),y
        dey
        bpl -
        rts

; Add: a primitive or a group. A primitive goes after the selected object's subtree, at
; its depth (inside it, if it's a group); a group takes the selected object into itself.
cmd_add:
        sec
        lda mc_cmd
        sbc #CMD_ADD
        sta ca_t
        cmp #OT_PRISM                   ; a prism or lathe needs room in the corner pool
        beq +
        cmp #OT_LATHE
        bne ++
+       jsr pool_count
        cmp #DOC_POOL - NEW_LPTS + 1
        bcc +
        lda #<st_pfull
        ldx #>st_pfull
        jmp say
+       lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _end                        ; nothing (or no object) selected: at the end, depth 0
        sta ca_s
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        sta ca_d
        lda ca_t
        cmp #OT_GROUP
        bcs _group
        ldy #O_TYPE
        lda (op),y
        cmp #OT_GROUP
        bcc +
        inc ca_d                        ; into the selected group
+       lda ca_s
        jsr sub_end
        sta ob_at
        bra _put
_end:
        lda doc_nobj
        sta ob_at
        lda #0
        sta ca_d
        bra _put
_group:
        lda ca_s                        ; the group before the selected subtree, which goes
        sta ob_at                       ; one deeper
        jsr sub_end
        sta ca_e
        lda #1
        jsr obj_open
        bcs _full
        inc ca_e
        ldx ob_at
-       inx
        cpx ca_e
        bcs +
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        inc a
        sta (op),y
        bra -
+       bra _fill
_put:
        lda #1
        jsr obj_open
        bcs _full
_fill:
        ldx ob_at                       ; the new record
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #OBJ_SIZE - 1
        lda #0
-       sta (op),y
        dey
        bpl -
        ldy #O_TYPE
        lda ca_t
        sta (op),y
        ldy #O_DEPTH
        lda ca_d
        sta (op),y
        ldy #O_MAT                      ; the first material, if there is one
        lda doc_nmat
        beq +
        lda #1
        sta (op),y
+       lda ca_t                        ; its name: the type's
        asl
        tax
        lda type_names,x
        sta txt_ptr
        lda type_names+1,x
        sta txt_ptr+1
        ldy #0
-       lda (txt_ptr),y
        phy
        pha
        tya
        clc
        adc #O_NAME
        tay
        pla
        sta (op),y
        ply
        cmp #0
        beq +
        iny
        cpy #11
        bne -
+       ldy #O_SCALE+2                  ; scale 1, at the origin, sizes 1 / 2
        lda #1
        sta (op),y
        lda ca_t                        ; a group round the selection: where that was, and
        cmp #OT_GROUP                   ; that at its origin, so that nothing moves
        bcc +
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs +
        ldx ob_at
        lda obj_lo+1,x
        sta pa
        lda obj_hi+1,x
        sta pa+1
        ldy #O_POS+11
-       lda (pa),y
        sta (op),y
        lda #0
        sta (pa),y
        dey
        cpy #O_POS-1
        bne -
+       lda ca_t
        asl
        asl
        tax
        ldy #O_P+2
        lda add_sizes,x
        sta (op),y
        ldy #O_P+6
        lda add_sizes+1,x
        sta (op),y
        ldy #O_P+10
        lda add_sizes+2,x
        sta (op),y
        ldx #0                          ; a prism or lathe: its corners at the pool's end
        lda ca_t
        cmp #OT_PRISM
        beq +
        ldx #1
        cmp #OT_LATHE
        bne ++
+       stx ca_k
        jsr pool_count
        ldy #O_PFIRST
        sta (op),y
        iny
        ldx ca_k
        lda new_n,x
        sta (op),y
        lda new_lo,x
        sta px_b0
        lda new_hi,x
        sta px_b0+1
        lda new_n,x
        tax
        dey
        lda (op),y
        jsr pool_put_b
+       lda ob_at
        sta ms_sel
        lda #<st_added
        ldx #>st_added
        jmp say
_full:
        lda #<st_full
        ldx #>st_full
        jmp say
; p0, p1, p2 (whole numbers) for each type
add_sizes:      .byte 1, 0, 0, 0,  2, 2, 2, 0,  1, 2, 0, 0,  1, 0, 2, 0,  0, 0, 0, 0
                .byte 1, 0, 0, 0,  0, 0, 0, 0
                .byte 0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0
; a new prism's outline: a house, 5 corners (x, z); a new lathe's profile: a pawn, 7
; points (radius, height)
new_outline:    .dint FX(-1), FX(-1), FX(1), FX(-1), FX(1), FX(0.5), FX(0), FX(1.4), FX(-1), FX(0.5)
new_profile:    .dint FX(1), FX(0), FX(1), FX(0.25), FX(0.45), FX(0.6), FX(0.3), FX(1.5)
                .dint FX(0.65), FX(1.7), FX(0.55), FX(2.2), FX(0), FX(2.7)
NEW_LPTS        = 7
new_n:          .byte 5, NEW_LPTS
new_lo:         .byte <new_outline, <new_profile
new_hi:         .byte >new_outline, >new_profile
st_added:       .null "Added: give it a place in the views or the panel"
st_full:        .null "No room for more (64 objects)"

cmd_addlight:
        lda doc_nlight
        cmp #DOC_MAXLIGHT
        bcs _full
        tax
        inc doc_nlight
        lda dlight_lo,x
        sta op
        lda dlight_hi,x
        sta op+1
        ldy #DLIGHT_SIZE - 1
-       lda new_light,y
        sta (op),y
        dey
        bpl -
        txa
        ora #$40
        sta ms_sel
        lda #<st_added
        ldx #>st_added
        jmp say
_full:  lda #<st_lfull
        ldx #>st_lfull
        jmp say
st_lfull:       .null "No room for more lights (16)"
new_light:      #DLIT (10, 20, -10), (1, 1, 1), 0

cmd_delete:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _light
        sta ob_at
        jsr sub_end
        sta ca_e
        sec
        sbc ob_at
        sta oo_n
        lda ob_at                       ; its prisms' corners leave the pool
        sta ca_k
-       ldx ca_k
        cpx ca_e
        beq +
        jsr po_obj
        bne _np
        ldy #O_PN
        lda (txt_ptr),y
        tax
        ldy #O_PFIRST
        lda (txt_ptr),y
        jsr pool_close
_np:    inc ca_k
        bra -
+       jsr obj_close
        lda #$ff
        sta ms_sel
        lda #<st_deleted
        ldx #>st_deleted
        jmp say
_light:
        cmp #$40
        bcc _r
        cmp #$80
        bcs _r
        and #$3f
        sta oo_i
-       lda oo_i                        ; the lights after it move down
        clc
        adc #1
        cmp doc_nlight
        bcs +
        tax
        lda dlight_lo,x
        sta pa
        lda dlight_hi,x
        sta pa+1
        ldx oo_i
        lda dlight_lo,x
        sta op
        lda dlight_hi,x
        sta op+1
        ldy #DLIGHT_SIZE - 1
-       lda (pa),y
        sta (op),y
        dey
        bpl -
        inc oo_i
        bra --
+       dec doc_nlight
        lda #$ff
        sta ms_sel
        lda #<st_deleted
        ldx #>st_deleted
        jmp say
_r:     rts
st_deleted:     .null "Deleted"

cmd_dup:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _r
        sta ca_s
        jsr sub_end
        sta ob_at
        sec
        sbc ca_s
        sta ca_n
        lda #0                          ; room in the pool for its prisms' corners
        sta ca_t
        ldx ca_s
-       jsr _isprism
        bne +
        clc
        ldy #O_PN
        lda (op),y
        adc ca_t
        sta ca_t
        bcs _pfull
+       inx
        cpx ob_at
        bne -
        jsr pool_count
        sta ca_e                        ; (the copies' corners go from here)
        clc
        adc ca_t
        bcs _pfull                      ; (DOC_POOL is 255: a carry is too many)
        lda ca_n
        jsr obj_open                    ; (A = how many)
        bcs _full
        lda #0
        sta ca_k
-       clc
        lda ca_s
        adc ca_k
        tax
        clc
        lda ob_at
        adc ca_k
        tay
        jsr obj_copy
        inc ca_k
        lda ca_k
        cmp ca_n
        bne -
        lda #0                          ; the copied prisms: their corners copied to the
        sta ca_k                        ; pool's end
_corners:
        clc
        lda ob_at
        adc ca_k
        tax
        jsr _isprism
        bne _nc
        ldy #O_PN
        lda (op),y
        tax
        ldy #O_PFIRST
        lda (op),y
        jsr pool_get
        ldy #O_PFIRST
        lda ca_e
        sta (op),y
        ldy #O_PN
        lda (op),y
        tax
        clc
        adc ca_e
        pha
        lda ca_e
        jsr pool_put
        pla
        sta ca_e
_nc:    inc ca_k
        lda ca_k
        cmp ca_n
        bne _corners
        lda ob_at
        sta ms_sel
        lda #<st_dup
        ldx #>st_dup
        jmp say
_full:  lda #<st_full
        ldx #>st_full
        jmp say
_pfull: lda #<st_pfull
        ldx #>st_pfull
        jmp say
_r:     rts
_isprism: ; op = object X; Z set if it's a prism
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_TYPE                     ; (or a lathe: corners too)
        lda (op),y
        cmp #OT_PRISM
        beq +
        cmp #OT_LATHE
+       rts
st_dup:         .null "Duplicated"

; Move up / down: an object with no children swaps with its neighbour of the same depth
cmd_up:
        lda ms_sel
        beq _r
        cmp #DOC_MAXOBJ
        bcs _r
        sta ca_s
        sec
        sbc #1
        sta ca_e
        jmp swap_sel
_r:     rts
cmd_down:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _r
        sta ca_s
        clc
        adc #1
        cmp doc_nobj
        bcs _r
        sta ca_e
        jmp swap_sel
_r:     rts
; swap objects ca_s and ca_e (if neither is a group and they're at the same depth)
swap_sel:
        lda #0
        sta ca_t
        ldx ca_s
        jsr _info
        sta ca_d
        ldx ca_e
        jsr _info
        cmp ca_d
        bne _no
        lda ca_t
        bne _no
        ldx ca_s                        ; ca_s -> spare (record DOC_MAXOBJ - 1 is ...):
        lda obj_lo,x                    ; swap through the copy buffer
        sta pa
        lda obj_hi,x
        sta pa+1
        ldy #OBJ_SIZE - 1
-       lda (pa),y
        sta sw_buf,y
        dey
        bpl -
        ldx ca_e
        ldy ca_s
        jsr obj_copy
        ldx ca_e
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #OBJ_SIZE - 1
-       lda sw_buf,y
        sta (op),y
        dey
        bpl -
        lda ca_e
        sta ms_sel
        jmp redraw_work
_no:    lda #<st_cantmove
        ldx #>st_cantmove
        jmp say
_info:  ; A = depth of X; ca_t |= 1 if it's a group
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_TYPE
        lda (op),y
        cmp #OT_GROUP
        lda #0
        rol
        ora ca_t
        sta ca_t
        ldy #O_DEPTH
        lda (op),y
        rts
st_cantmove:    .null "Only an object with no parts moves past one at its depth"

; Indent (A = 1) / Outdent (A = $ff): the selected subtree one deeper / shallower
cmd_depth:
        sta cd_dir
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _r
        sta ca_s
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        sta ca_d
        lda cd_dir
        bmi _out
        ; deeper: only if the object before it is a group at this depth (or deeper inside one)
        lda ca_s
        beq _no
        ldx ca_s
        dex
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        sta ca_e
        ldy #O_TYPE
        lda (op),y
        cmp #OT_GROUP
        lda ca_e
        adc #0                          ; (+1 if a group)
        cmp ca_d
        beq _no
        bcc _no
        bra _go
_out:
        lda ca_d
        beq _no
_go:
        lda ca_s
        jsr sub_end
        sta ca_e
        ldx ca_s
-       lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        clc
        lda (op),y
        adc cd_dir
        sta (op),y
        inx
        cpx ca_e
        bne -
        jmp redraw_work
_no:    lda #<st_cantdepth
        ldx #>st_cantdepth
        jmp say
_r:     rts
st_cantdepth:   .null "It can only go into a group just above it, or out of one"


;=======================================================================================
; the overlay's variables
;=======================================================================================
op              = pb                    ; an object record (base page)
pv_text:        .fill 20
pf_n:           .byte 0
pf_row:         .fill 16
pf_col:         .fill 16
pf_kind:        .fill 16
pf_lbl_lo:      .fill 16
pf_lbl_hi:      .fill 16
pf_adr_lo:      .fill 16
pf_adr_hi:      .fill 16
dp_i:           .byte 0
dp_p:           .word 0
pc_row:         .byte 0
pc_col:         .byte 0
pc_f:           .byte 0
pc_prompt:      .fill 16
dl_r:           .byte 0
dl_e:           .byte 0
dl_y:           .byte 0
mc_cmd:         .byte 0
cz_f:           .dword 0
se_i:           .byte 0
se_d:           .byte 0
oo_n:           .byte 0
oo_i:           .byte 0
ob_at:          .byte 0
ca_t:           .byte 0
ca_s:           .byte 0
ca_d:           .byte 0
ca_e:           .byte 0
ca_n:           .byte 0
ca_k:           .byte 0
cd_dir:         .byte 0
sw_buf:         .fill OBJ_SIZE
pk_best:        .byte 0
pk_bd:          .byte 0
pk_i:           .byte 0
pk_j:           .byte 0
pk_w:           .fill 12
dr_a:           .dword 0
dr_b:           .dword 0
tv3m:           .dword 0
dv_v:           .byte 0
dv_i:           .byte 0
wa_i:           .byte 0
wa_d:           .byte 0
wa_seld:        .byte 0
sel_flag:       .fill DOC_MAXOBJ
hid_flag:       .fill DOC_MAXOBJ        ; 1: not in the views (its box, or a group's)
wa_hd:          .byte 0
lm:             .fill 48
mm_p:           .fill 48
mm_c:           .fill 12
mm_r:           .fill 48
wcur:           .fill 48
        .virtual $0800                  ; (the parser's work area: free while the modeller
wstk:           .fill 48 * 10           ;  runs. world_all fills these on every redraw)
wm:             .fill 48 * DOC_MAXOBJ
        .cerror * > $1600, "the modeller's buffers run into kstream's"
        .endv
dr_moved:       .byte 0                 ; 1 once a drag has moved (undo kept)
sb_drag:        .byte 0                 ; 1: the scroll bar's thumb is being dragged
sb_grab:        .byte 0                 ; where on the thumb it was taken
sb_top:         .byte 0
sb_bot:         .byte 0
wp_k:           .byte 0
pp_lathe:       .byte 0                 ; pp_setup: 1 for a lathe, 0 a prism
pt_cur:         .fill 8                 ; the picked corner (x, z), from the pool
wp_n:           .byte 0
dl_v:           .fill 12
lr_ax:          .byte 0
lr_a:           .byte 0
lr_b:           .byte 0
lr_j:           .byte 0
lr_u:           .byte 0
lr_v:           .byte 0
lr_ang:         .dword 0
lr_c:           .dword 0
lr_s:           .dword 0
lr_x:           .dword 0
lr_y:           .dword 0
lr_x2:          .dword 0
lr_y2:          .dword 0
do_t:           .byte 0
do_p:           .fill 12
bx_h:           .fill 12
bx_l:           .fill 12
ci_r1:          .dword 0
ci_r2:          .dword 0
ci_rr:          .dword 0
ci_h:           .dword 0
ci_hh:          .dword 0
ci_plane:       .byte 0
ci_k:           .byte 0
ci_ca:          .dword 0
ci_sa:          .dword 0
ci_u:           .dword 0
ci_v:           .dword 0
sg_a:           .fill 12
sg_b:           .fill 12
sg_wa:          .fill 12
sg_wb:          .fill 12
xf_in:          .fill 12
xf_out:         .fill 12
pj_v:           .byte 0
pj_ha:          .byte 0
pj_va:          .byte 0
pj_w:           .fill 12
pj_t:           .dword 0
pj_c:           .fill 12
pj_zc:          .dword 0
pj_zx:          .dword 0
pj_zy:          .dword 0
pj_ca:          .dword 0
pj_cb:          .dword 0
pj_cx:          .dword 0
pj_cy:          .dword 0
pj_fx:          .dword 0
pj_fy:          .dword 0
pj_sx:          .word 0
pj_sy:          .word 0
cm_f:           .fill 12
cm_r:           .fill 12
cm_u:           .fill 12
cm_k:           .dword 0
cm_ky:          .dword 0
cm_half:        .dword 0
cm_sin:         .dword 0
cn_a:           .fill 12
cn_r:           .fill 12
cn_l:           .dword 0
ln_x0:          .dword 0
ln_y0:          .dword 0
ln_x1:          .dword 0
ln_y1:          .dword 0
cl_n:           .byte 0
cl_c0:          .byte 0
cl_c1:          .byte 0
cl_c:           .byte 0
cl_k:           .byte 0
cl_x:           .dword 0
cl_y:           .dword 0
cl_dx:          .dword 0
cl_dy:          .dword 0
cl_e:           .dword 0
cl_lx:          .dword 0
cl_rx:          .dword 0
cl_ty:          .dword 0
cl_by:          .dword 0
