;=======================================================================================
; modelpanel.asm - overlay 6: the properties panel (what is selected, as fields to click
; and type into). Overlay 4 and the resident part reach it through ovl_far (#FAR
; OVL_PANEL, ...), and it reaches overlay 4 the same way: it must not call or read
; overlay 4's labels directly (private/tools/ovl_check.py checks).
;=======================================================================================

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
        #FAR OVL_MODEL, pt_valid  ; the corner picked: its two numbers (a copy in
        bcc _r                          ; pt_cur: prop_click puts it back)
        #FAR OVL_MODEL, pt_load
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
        #PF 5, PCOL_B, PK_VAL, pl_lpy, 4
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
        #PF 1, PCOL_B, PK_VAL, pl_lr, DL_COL
        #PF 2, PCOL_B, PK_VAL, pl_lg, DL_COL+4
        #PF 3, PCOL_B, PK_VAL, pl_lb, DL_COL+8
        #PF 4, PCOL_A, PK_BIT, pl_nosh, DL_FLAGS
        #PF 5, PCOL_A, PK_BIT, pl_spot, DL_SPOT
        ldy #DL_SPOT                    ; a spotlight: where it aims, its cone
        lda (lp),y
        and #1
        beq +
        #PF 6, PCOL_A, PK_VAL, pl_ax, DL_AIM
        #PF 7, PCOL_A, PK_VAL, pl_ay, DL_AIM+4
        #PF 8, PCOL_A, PK_VAL, pl_az, DL_AIM+8
        #PF 6, PCOL_B, PK_VAL, pl_rad, DL_RAD
        #PF 7, PCOL_B, PK_VAL, pl_fal, DL_FALL
        #PF 8, PCOL_B, PK_VAL, pl_tgt, DL_TIGHT
+       rts
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
        #PF 7, PCOL_A, PK_VAL, pl_r2c, DM_COL2
        #PF 7, PCOL_B, PK_VAL, pl_g2, DM_COL2+4
        #PF 8, PCOL_A, PK_VAL, pl_b2, DM_COL2+8
        rts


; the labels; a number's has its help line's number before it (modelhelp.asm)
pl_name:        .null "Name "
pl_mat:         .null "Mat "
pl_nosh:        .null "No shadow"
pl_chk:         .null "Chk"
pl_spot:        .null "Spot"
        .byte (hp_ax - OVL_END) >> 6
pl_ax:          .null "AX"
        .byte (hp_ay - OVL_END) >> 6
pl_ay:          .null "AY"
        .byte (hp_az - OVL_END) >> 6
pl_az:          .null "AZ"
        .byte (hp_rad - OVL_END) >> 6
pl_rad:         .null "Rad"
        .byte (hp_fal - OVL_END) >> 6
pl_fal:         .null "Fal"
        .byte (hp_tgt - OVL_END) >> 6
pl_tgt:         .null "Tgt"
        .byte (hp_px - OVL_END) >> 6
pl_px:          .null "X"
        .byte (hp_py - OVL_END) >> 6
pl_py:          .null "Y"
        .byte (hp_pz - OVL_END) >> 6
pl_pz:          .null "Z"
        .byte (hp_rx - OVL_END) >> 6
pl_rx:          .null "RX"
        .byte (hp_ry - OVL_END) >> 6
pl_ry:          .null "RY"
        .byte (hp_rz - OVL_END) >> 6
pl_rz:          .null "RZ"
        .byte (hp_s - OVL_END) >> 6
pl_s:           .null "S"
        .byte (hp_r - OVL_END) >> 6
pl_r:           .null "R"
        .byte (hp_r1 - OVL_END) >> 6
pl_r1:          .null "R1"
        .byte (hp_r2 - OVL_END) >> 6
pl_r2:          .null "R2"
        .byte (hp_r2c - OVL_END) >> 6
pl_r2c:         .null "R2"
        .byte (hp_g2 - OVL_END) >> 6
pl_g2:          .null "G2"
        .byte (hp_b2 - OVL_END) >> 6
pl_b2:          .null "B2"
        .byte (hp_h - OVL_END) >> 6
pl_h:           .null "H"
        .byte (hp_sx - OVL_END) >> 6
pl_sx:          .null "SX"
        .byte (hp_sy - OVL_END) >> 6
pl_sy:          .null "SY"
        .byte (hp_sz - OVL_END) >> 6
pl_sz:          .null "SZ"
        .byte (hp_cx - OVL_END) >> 6
pl_cx:          .null "CX"
        .byte (hp_cz - OVL_END) >> 6
pl_cz:          .null "CZ"
        .byte (hp_lpy - OVL_END) >> 6
pl_lpy:         .null "Y"
        .byte (hp_lr - OVL_END) >> 6
pl_lr:          .null "R"
        .byte (hp_lg - OVL_END) >> 6
pl_lg:          .null "G"
        .byte (hp_lb - OVL_END) >> 6
pl_lb:          .null "B"
        .byte (hp_cr - OVL_END) >> 6
pl_cr:          .null "R"
        .byte (hp_cg - OVL_END) >> 6
pl_cg:          .null "G"
        .byte (hp_cb - OVL_END) >> 6
pl_cb:          .null "B"
        .byte (hp_lx - OVL_END) >> 6
pl_lx:          .null "LX"
        .byte (hp_ly - OVL_END) >> 6
pl_ly:          .null "LY"
        .byte (hp_lz - OVL_END) >> 6
pl_lz:          .null "LZ"
        .byte (hp_ang - OVL_END) >> 6
pl_ang:         .null "Ang"
        .byte (hp_bgr - OVL_END) >> 6
pl_bgr:         .null "BgR"
        .byte (hp_bgg - OVL_END) >> 6
pl_bgg:         .null "BgG"
        .byte (hp_bgb - OVL_END) >> 6
pl_bgb:         .null "BgB"
        .byte (hp_trc - OVL_END) >> 6
pl_trace:       .null "Trace"
        .byte (hp_dif - OVL_END) >> 6
pl_dif:         .null "Dif"
        .byte (hp_pho - OVL_END) >> 6
pl_pho:         .null "Pho"
        .byte (hp_psz - OVL_END) >> 6
pl_psz:         .null "Siz"
        .byte (hp_amb - OVL_END) >> 6
pl_amb:         .null "Amb"
        .byte (hp_ref - OVL_END) >> 6
pl_ref:         .null "Ref"
        .byte (hp_trn - OVL_END) >> 6
pl_trn:         .null "Trn"
        .byte (hp_ior - OVL_END) >> 6
pl_ior:         .null "IOR"
        .byte (hp_csz - OVL_END) >> 6
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
        #FAR OVL_MODEL, u_save
        ldy #0                          ; the next material (or none)
        lda (lp),y
        clc
        adc #1
        cmp doc_nmat
        beq _setm
        bcc _setm
        lda #0
_setm:  sta (lp),y
        #FAR OVL_MODEL, redraw_work
        rts
_edit:
        cmp #PK_BIT
        bne +
        #FAR OVL_MODEL, u_save
        ldy #0
        lda (lp),y
        eor #1
        sta (lp),y
        #FAR OVL_MODEL, redraw_work
        rts
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
        #FAR OVL_MODEL, u_save
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
_done:  #FAR OVL_MODEL, redraw_work
        rts
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
+       ldx pc_f                        ; the prompt: what the field means
        jsr help_prompt
        jsr gui_edit
        bcs _esc                        ; (ESC: the status line is back as it was)
        jsr gui_num
        bcc +
        lda #<st_notnum
        ldx #>st_notnum
        sta ms_msg
        stx ms_msg+1
        #FAR OVL_MODEL, redraw_work
        rts
+       #FAR OVL_MODEL, u_save
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
        #FAR OVL_MODEL, redraw_work
        rts
+       ldy #0
-       lda gf_v,y
        sta (lp),y
        iny
        cpy #4
        bne -
        #FAR OVL_MODEL, pt_valid  ; (a corner's x or z went into pt_cur: back to
        bcc +                           ;  the pool; the same value if it was another)
        #FAR OVL_MODEL, pt_store
+       #FAR OVL_MODEL, redraw_work
        rts
_esc:   rts
st_pname:       .null "Name: "
st_notnum:      .null "That isn't a number"


;---------------------------------------------------------------------------------------
; fatan2 (model4.asm kp_atan calls it): at_r = atan2(at_y, at_x) in degrees (16.16, -180 .. 180), by halving 0 .. 90 on
; sin and cos (20 steps: within 0.0001 degrees)
;---------------------------------------------------------------------------------------
fatan2:
        #ABSQ at_y, at_ay
        #ABSQ at_x, at_ax
        lda at_ay
        ora at_ay+1
        ora at_ay+2
        ora at_ay+3
        ora at_ax
        ora at_ax+1
        ora at_ax+2
        ora at_ax+3
        bne +
        #MOVQ q_zero, at_r
        rts
+       #MOVQ q_zero, at_lo
        #LDIMM 90 * ONE, at_hi
        lda #20
        sta at_k
_step:  #ADDQ at_lo, at_hi, at_m        ; m = (lo + hi) / 2: sin m |x| - cos m |y|
        #ASRQ_Q
        stq at_m
        stq fs_a
        jsr fsin_deg
        stq at_s
        #MOVQ at_m, fs_a
        jsr fcos_deg
        stq at_c
        #FMUL at_s, at_ax, at_s
        #FMUL at_c, at_ay, at_c
        #SUBQ at_s, at_c, tq
        bit tq+3
        bmi _lo
        #MOVQ at_m, at_hi
        bra _n
_lo:    #MOVQ at_m, at_lo
_n:     dec at_k
        bne _step
        #ADDQ at_lo, at_hi, tq
        #ASRQ_Q
        stq tq
        bit at_x+3                      ; x < 0: 180 - t
        bpl +
        #LDIMM 180 * ONE, at_m
        #SUBQ at_m, tq, tq
+       bit at_y+3                      ; y < 0: -t
        bpl +
        #NEGQ tq, tq
+       #MOVQ tq, at_r
        rts

at_ax:          .dword 0
at_ay:          .dword 0
at_lo:          .dword 0
at_hi:          .dword 0
at_m:           .dword 0
at_s:           .dword 0
at_c:           .dword 0
at_k:           .byte 0

;---------------------------------------------------------------------------------------
; Indent and Outdent keep the object where it is (cmd_depth): kp_before, with the object in
; A, keeps its world transform and its parent's; kp_after (the depths changed) works out
; its position, turn and scale in the new parent's frame. Its parts follow it (theirs are
; relative to it). Matrices are wm's: rows of A at 12 r, t at 36; A = R s (uniform s).
;   position  p_j = (col_j(P) . (t_O - t_P)) / (col_j(P) . col_j(P))
;   scale     the old one times |old parent| / |new parent|
;   turn      unchanged when both parents turn alike; else from N = P^T O (its scale
;             doesn't matter: A = Rz Ry Rx s, so RX = atan2(N21, N22), RY = atan2(-N20,
;             sqrt(N00^2 + N10^2)), RZ = atan2(N10, N00))
;---------------------------------------------------------------------------------------
kp_before:                              ; (world_all done: wm is up to date)
        sta kp_i
        jsr kp_wm
        ldy #47
-       lda (pa),y
        sta kp_o,y
        dey
        bpl -
        jsr kp_frame                    ; the parent's (kp_p), kept as kp_q
        ldx #47
-       lda kp_p,x
        sta kp_q,x
        dex
        bpl -
        rts

kp_after:
        jsr kp_frame                    ; the new parent's
        ldx kp_i
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ; the position: p_j = col_j . v / col_j . col_j
        #VSUB kp_o+36, kp_p+36, kp_v
        lda #0
        sta kp_j
_pos:   jsr kp_pcol                     ; kp_c = column j of P
        jsr kp_c2d
        jsr kp_dot
        stq kp_t2
        #VMOV kp_v, kp_d
        jsr kp_dot
        stq tq
        #FDIV tq, kp_t2, tq
        lda kp_j
        clc
        adc #O_POS
        tay
        jsr kp_store
        jsr kp_jnext
        bne _pos
        ; the two parents' sizes: |col 0|
        lda #<kp_q
        ldx #>kp_q
        jsr kp_len
        stq kp_sq
        lda #<kp_p
        ldx #>kp_p
        jsr kp_len
        stq kp_sp
        ; do they turn alike? (each entry over its size, within 1/256)
        lda #0
        sta kp_k
_alike: ldx kp_k                        ; (the Q macros change X: kp_k counts)
        ldy #0
-       lda kp_q,x
        sta kp_t,y
        lda kp_p,x
        sta kp_t2,y
        inx
        iny
        cpy #4
        bne -
        #FDIV kp_t, kp_sq, kp_t
        #FDIV kp_t2, kp_sp, kp_t2
        #SUBQ kp_t, kp_t2, kp_t
        #ABSQ kp_t, kp_t
        #LDIMM ONE / 256, tq
        #BLTQ kp_t, tq, +
        jmp _turn
+       lda kp_k
        clc
        adc #4
        sta kp_k
        cmp #36
        bne _alike
        ; alike: the angles stay; the scale times |old| / |new| (if they differ)
        #SUBQ kp_sq, kp_sp, tq
        #BEQZ tq, _done
        ldy #O_SCALE
        jsr kp_load
        #FMUL kp_t, kp_sq, kp_t
        #FDIV kp_t, kp_sp, tq
        ldy #O_SCALE
        jsr kp_round
_done:  rts
_turn:  ; N = P^T O: N[i][j] = col_i(P) . col_j(O) (at kp_n + 12 i + 4 j)
        lda #0
        sta kp_j
_ni:    lda #0
        sta kp_k
_nj:    jsr kp_pcol                     ; column i of P
        jsr kp_c2d
        lda #<kp_o                      ; column j of O
        ldx #>kp_o
        ldy kp_k
        jsr kp_colof
        jsr kp_dot
        stq kp_t
        lda kp_j                        ; 12 i + 4 j = 3 (4 i) + 4 j
        asl
        clc
        adc kp_j
        adc kp_k
        tax
        ldy #0
-       lda kp_t,y
        sta kp_n,x
        inx
        iny
        cpy #4
        bne -
        lda kp_k
        clc
        adc #4
        sta kp_k
        cmp #12
        bne _nj
        jsr kp_jnext
        bne _ni
        ; RY = atan2(-N20, sqrt(N00^2 + N10^2))
        #FMUL kp_n, kp_n, tq
        #FMUL kp_n+12, kp_n+12, kp_t
        #ADDQ tq, kp_t, tq
        jsr fsqrt
        stq at_x
        #NEGQ kp_n+24, at_y
        jsr kp_atan
        ldy #O_ROT + 4
        jsr kp_round
        #LDIMM 64, tq                   ; (straight up or down: RZ 0, RX from the rest)
        #BLTQ at_x, tq, _gimbal
        #MOVQ kp_n+28, at_y             ; RX = atan2(N21, N22)
        #MOVQ kp_n+32, at_x
        jsr kp_atan
        ldy #O_ROT
        jsr kp_round
        #MOVQ kp_n+12, at_y             ; RZ = atan2(N10, N00)
        #MOVQ kp_n, at_x
        jsr kp_atan
        ldy #O_ROT + 8
        jsr kp_round
        bra _scale
_gimbal:
        #NEGQ kp_n+20, at_y             ; RX = atan2(-N12, N11)
        #MOVQ kp_n+16, at_x
        jsr kp_atan
        ldy #O_ROT
        jsr kp_round
        #MOVQ q_zero, tq
        ldy #O_ROT + 8
        jsr kp_round
_scale: lda #<kp_o                      ; the scale: |O| / |new parent|
        ldx #>kp_o
        jsr kp_len
        stq kp_t
        #FDIV kp_t, kp_sp, tq
        ldy #O_SCALE
        jmp kp_round

; kp_c = column kp_j / 4 of kp_p; kp_colof: of the matrix at A/X, column Y / 4
kp_pcol:
        lda #<kp_p
        ldx #>kp_p
        ldy kp_j
kp_colof:
        sty kp_t
        clc
        adc kp_t
        sta _s+1
        txa
        adc #0
        sta _s+2
        ldx #11
-       ldy kp_offs,x
_s:     lda $ffff,y                     ; (self-modified)
        sta kp_c,x
        dex
        bpl -
        rts
kp_offs:        .byte 0, 1, 2, 3, 12, 13, 14, 15, 24, 25, 26, 27
kp_c2d:
        ldx #11
-       lda kp_c,x
        sta kp_d,x
        dex
        bpl -
        rts
; Q = kp_c . kp_d
kp_dot:
        #DOT kp_c, kp_d, tq
        rts
; kp_j += 4; Z set at 12
kp_jnext:
        lda kp_j
        clc
        adc #4
        sta kp_j
        cmp #12
        rts
; kp_p = the world transform of object kp_i's parent (the nearest one before it a level
; up), or the identity at the top level
kp_frame:
        ldx #47
        lda #0
-       sta kp_p,x
        dex
        bpl -
        lda #1
        sta kp_p+2
        sta kp_p+16+2
        sta kp_p+32+2
        ldx kp_i
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        beq _r
        sec
        sbc #1
        sta kp_t
-       dex
        bmi _r
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        lda (op),y
        cmp kp_t
        bne -
        txa
        jsr kp_wm
        ldy #47
-       lda (pa),y
        sta kp_p,y
        dey
        bpl -
_r:     rts

; Q = atan2(at_y, at_x) (degrees): overlay 6's fatan2 (at_x, at_y, at_r are resident)
kp_atan:
        jsr fatan2
        ldq at_r
        rts

; Q = |column 0| of the matrix at A/X
kp_len:
        ldy #0
        jsr kp_colof
        jsr kp_c2d
        jsr kp_dot
        jmp fsqrt
; kp_round: tq to the nearest 1/256 (angles and scales come back whole, not 29.99997),
; then kp_store
kp_round:
        lda tq
        clc
        adc #$80
        bcc +
        inc tq+1
        bne +
        inw tq+2
+       lda #0
        sta tq
; tq -> the object's dword at Y; kp_t <- it
kp_store:
        ldx #0
-       lda tq,x
        sta (op),y
        iny
        inx
        cpx #4
        bne -
        rts
kp_load:
        ldx #0
-       lda (op),y
        sta kp_t,x
        iny
        inx
        cpx #4
        bne -
        rts

kp_i:           .byte 0
kp_k:           .byte 0
kp_j:           .byte 0
kp_o:           .fill 48                ; the object's world transform (before)
kp_q:           .fill 48                ; its old parent's
kp_p:           .fill 48                ; its new parent's
kp_n:           .fill 36
kp_v:           .fill 12
kp_c:           .fill 12
kp_d:           .fill 36
kp_t:           .dword 0
kp_t2:          .dword 0
kp_sq:          .dword 0
kp_sp:          .dword 0

; pa = object A's world transform in wm (model3.asm: the modeller's buffers at $0800)
KP_WM           = $0800 + 48 * 10
kp_wm:
        tax
        lda kp_wml,x
        sta pa
        lda kp_wmh,x
        sta pa+1
        rts
kp_wml:         .byte <(KP_WM + range(DOC_MAXOBJ) * 48)
kp_wmh:         .byte >(KP_WM + range(DOC_MAXOBJ) * 48)

; help_prompt: X = a property field (prop_click) -> A/X = what it means (its help line,
; modelhelp.asm, copied from this overlay's file in attic: the line's number is the byte before the
; field's label)
HP_ATTIC        = OVL_ATTIC + OVL_PANEL * $10000 + (OVL_END - OVL_BASE)
help_prompt:
        sec
        lda pf_lbl_lo,x
        sbc #1
        sta txt_ptr
        lda pf_lbl_hi,x
        sbc #0
        sta txt_ptr+1
        ldy #0
        lda (txt_ptr),y                 ; n: the line at HP_ATTIC + 64 n
        tay
        lsr
        lsr
        clc
        adc #>HP_ATTIC
        sta dmaj_src+1
        tya
        and #3
        lsr
        ror
        ror
        sta dmaj_src                    ; (HP_ATTIC is page aligned)
        lda #(HP_ATTIC >> 16) & $0f
        sta dmaj_src_bank
        lda #HP_ATTIC >> 20
        sta dmaj_src_mb
        lda #<hp_buf
        sta dmaj_dst
        lda #>hp_buf
        sta dmaj_dst+1
        lda #0
        sta dmaj_dst_bank
        sta dmaj_dst_mb
        sta dmaj_count+1
        lda #64
        sta dmaj_count
        lda #DMACMD_COPY
        sta dmaj_cmd
        jsr dma_go
        lda #<hp_buf
        ldx #>hp_buf
        rts
        .cerror (HP_ATTIC & $ff) != 0, "HP_ATTIC must be page aligned"
hp_buf:         .fill 64

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
