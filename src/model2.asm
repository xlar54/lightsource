;=======================================================================================
; model2.asm - the modeller's drawing: world transforms, wireframes, the views
;=======================================================================================

; redraw_all: the whole screen (after a picture had it). redraw_work: the views, the list,
; the properties and the status line, which each fill their own area: the screen isn't
; cleared and the menu bar stays as it is.
redraw_all:
        lda #GC_BG
        sta f640_fill
        lda #0
        jsr f640_clear
        jsr gui_menubar
redraw_work:
        jsr draw_views
        jsr draw_list
        #FAR OVL_PANEL, draw_props
        lda ms_msg
        ldx ms_msg+1
        jmp gui_status

draw_views:
        jsr views_layout
        jsr world_all
        jsr cam_setup
        lda #0
        sta dv_v
-       ldx dv_v
        lda vw_on,x
        beq +
        jsr draw_view
+       inc dv_v
        lda dv_v
        cmp #4
        bne -
        jmp d6_clip_all

; view dv_v: its frame, background, axes, objects, lights, camera, name
draw_view:
        jsr d6_clip_all
        ldx dv_v
        jsr vw_rect                     ; d6_x .. d6_y1 = the view
        lda #GC_FRAME
        sta d6_col
        jsr d6_frame
        jsr vw_inner                    ; inside the frame: the clip, and the background
        lda #GC_BG
        jsr gui_fill
        jsr vw_clip
        lda dv_v
        jsr project_setup
        ; axes through the origin (ortho views): the across axis and the up axis
        lda dv_v
        cmp #3
        beq _objs
        jsr view_grid
        lda #GC_PANEL
        sta d6_col
        #VMOV q_z3, sg_wa
        #VMOV q_z3, sg_wb
        ldx dv_v
        lda vw_ha,x
        jsr _axis
        ldx dv_v
        lda vw_va,x
        jsr _axis
_objs:
        lda #0
        sta dv_i
_o:
        lda dv_i
        cmp doc_nobj
        beq _lights
        jsr draw_obj
        inc dv_i
        bra _o
_lights:
        lda #0
        sta dv_i
_l:
        lda dv_i
        cmp doc_nlight
        beq _cam
        tax
        lda dlight_lo,x
        sta lp
        lda dlight_hi,x
        sta lp+1
        ldy #DL_POS
        ldx #0
-       lda (lp),y
        sta pj_w,x
        iny
        inx
        cpx #12
        bne -
        lda #GC_ORANGE
        sta d6_col
        lda dv_i
        ora #$40
        cmp ms_sel
        bne +
        lda #GC_YELLOW
        sta d6_col
+
        jsr mark_cross
        jsr spot_draw
        inc dv_i
        bra _l
_cam:
        lda dv_v                        ; the camera: a cross, and a line to where it looks
        cmp #3
        beq _name
        lda #GC_GREEN
        ldx ms_sel
        cpx #$80
        bne +
        lda #GC_YELLOW
+       sta d6_col
        #VMOV doc_cam_loc, pj_w
        jsr mark_cross
        #VMOV doc_cam_loc, sg_wa
        #VMOV doc_cam_look, sg_wb
        jsr seg_world
_name:
        jsr d6_clip_all
        ldx dv_v
        lda vw_x0l,x
        sta tmp0
        lda vw_x0h,x
        lsr
        lda tmp0
        ror
        lsr
        lsr
        clc
        adc #1
        sta d6_tc
        lda vw_y0,x
        clc
        adc #2
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_FRAME
        sta d6_col
        lda #$ff
        sta d6_bg
        lda dv_v
        asl
        tax
        lda vw_names,x
        pha
        lda vw_names+1,x
        tax
        pla
        jmp d6_text
_axis:  ; a line along world axis A, -100 .. 100
        asl
        asl
        tax
        lda #0
        sta sg_wa,x
        sta sg_wa+1,x
        sta sg_wb,x
        sta sg_wb+1,x
        lda #<-100
        sta sg_wa+2,x
        lda #>-100
        sta sg_wa+3,x
        lda #100
        sta sg_wb+2,x
        lda #0
        sta sg_wb+3,x
        jsr seg_world
        #VMOV q_z3, sg_wa
        #VMOV q_z3, sg_wb
        rts
q_z3:           .dint 0, 0, 0

;---------------------------------------------------------------------------------------
; spot_draw: light dv_i, if it's a spotlight: a cross at its aim point, a line to it, and
; its cone out to there (falloff): a ring of 16 segments round the aim point, square to
; the axis, and four lines from the light to the ring. Drawn through wcur, a frame with
; x and y across the axis, z along it (light -> aim) and its origin at the aim point.
;---------------------------------------------------------------------------------------
spot_draw:
        ldx dv_i
        lda dlight_lo,x
        sta lp
        lda dlight_hi,x
        sta lp+1
        ldy #DL_SPOT
        lda (lp),y
        and #1
        bne +
_r:     rts
+       ldy #DL_POS                     ; its position, aim point and falloff
        ldx #0
-       lda (lp),y
        sta sd_p,x
        iny
        inx
        cpx #12
        bne -
        ldy #DL_AIM
        ldx #0
-       lda (lp),y
        sta sd_a,x
        iny
        inx
        cpx #12
        bne -
        ldy #DL_FALL
        ldx #0
-       lda (lp),y
        sta sd_t,x
        iny
        inx
        cpx #4
        bne -
        #VMOV sd_a, pj_w                ; the aim point: a cross, and the axis
        jsr mark_cross
        #VMOV sd_p, sg_wa
        #VMOV sd_a, sg_wb
        jsr seg_world
        #VSUB sd_a, sd_p, sd_w          ; w = the axis, its length L
        #DOT sd_w, sd_w, tq
        jsr fsqrt
        stq sd_l
        #LDIMM FX(0.05), tq
        #BLTQ sd_l, tq, _r              ; (it aims at itself, or nearly)
        .for si = 0, si < 3, si += 1
        #FDIV sd_w+si*4, sd_l, sd_w+si*4
        .next
        ; u across it: y x w = (wz, 0, -wx), or when w is nearly upright x x w = (0, -wz, wy)
        #ABSQ sd_w+4, tq
        #LDIMM FX(0.9), tv3m
        #BLTQ tq, tv3m, _y
        #MOVQ q_zero, sd_u
        #NEGQ sd_w+8, sd_u+4
        #MOVQ sd_w+4, sd_u+8
        bra _un
_y:     #MOVQ sd_w+8, sd_u
        #MOVQ q_zero, sd_u+4
        #NEGQ sd_w, sd_u+8
_un:    #DOT sd_u, sd_u, tq
        jsr fsqrt
        stq tq
        .for si = 0, si < 3, si += 1
        #FDIV sd_u+si*4, tq, sd_u+si*4
        .next
        ; v = w x u
        .for si = 0, si < 3, si += 1    ; v_i = w_j u_k - w_k u_j (j, k the next two)
        #FMUL sd_w+((si+1)%3)*4, sd_u+((si+2)%3)*4, tq
        #FMUL sd_w+((si+2)%3)*4, sd_u+((si+1)%3)*4, tv3m
        #SUBQ tq, tv3m, sd_v+si*4
        .next
        .for si = 0, si < 3, si += 1    ; wcur: row i = (u_i, v_i, w_i), then the aim point
        #MOVQ sd_u+si*4, wcur+si*12
        #MOVQ sd_v+si*4, wcur+si*12+4
        #MOVQ sd_w+si*4, wcur+si*12+8
        #MOVQ sd_a+si*4, wcur+36+si*4
        .next
        ; the ring's radius: L tan(falloff), falloff kept to 1 .. 80 degrees
        #LDIMM FX(1), tq
        #BLEQ tq, sd_t, +
        #MOVQ tq, sd_t
+       #LDIMM FX(80), tq
        #BLEQ sd_t, tq, +
        #MOVQ tq, sd_t
+       #MOVQ sd_t, fs_a
        jsr fsin_deg
        stq sd_r
        #MOVQ sd_t, fs_a
        jsr fcos_deg
        stq tq
        #FDIV sd_r, tq, sd_r
        #FMUL sd_r, sd_l, sd_r
        lda #0                          ; the ring (x-y: across the axis)
        sta ci_plane
        #MOVQ sd_r, ci_rr
        jsr circle_r
        lda #0                          ; the four edges, from the light: (0, 0, -L)
        sta sd_k
_e:     #MOVQ q_zero, sg_a
        #MOVQ q_zero, sg_a+4
        #NEGQ sd_l, sg_a+8
        #VMOV q_z3, sg_b
        #MOVQ sd_r, tq                  ; edge k: +-r along x (k = 0, 1) or y (2, 3)
        lda sd_k                        ; (after the MOVQs: ldq loads X and Y too)
        and #1
        beq +
        #NEGQ sd_r, tq
+       lda sd_k
        and #2
        asl
        tay                             ; (Y = 0 or 4: the coordinate)
        ldx #0
-       lda tq,x
        sta sg_b,y
        iny
        inx
        cpx #4
        bne -
        jsr seg_local
        inc sd_k
        lda sd_k
        cmp #4
        bne _e
        rts
sd_p:           .fill 12                ; the light,
sd_a:           .fill 12                ; its aim point,
sd_w:           .fill 12                ; the frame
sd_u:           .fill 12
sd_v:           .fill 12
sd_l:           .dword 0                ; the axis's length
sd_t:           .dword 0                ; the falloff angle
sd_r:           .dword 0                ; the ring's radius
sd_k:           .byte 0

; d6_x .. d6_y1 = view X; vw_inner shrinks it by one; vw_clip clips to it
vw_rect:
        lda vw_x0l,x
        sta d6_x
        lda vw_x0h,x
        sta d6_x+1
        lda vw_x1l,x
        sta d6_x1
        lda vw_x1h,x
        sta d6_x1+1
        lda vw_y0,x
        sta d6_y
        lda vw_y1,x
        sta d6_y1
        lda #0
        sta d6_y+1
        sta d6_y1+1
        rts
vw_inner:
        inc d6_x
        bne +
        inc d6_x+1
+       inc d6_y
        lda d6_x1
        bne +
        dec d6_x1+1
+       dec d6_x1
        dec d6_y1
        rts
vw_clip:
        lda d6_x
        sta d6_cx0
        lda d6_x+1
        sta d6_cx0+1
        lda d6_x1
        sta d6_cx1
        lda d6_x1+1
        sta d6_cx1+1
        lda d6_y
        sta d6_cy0
        lda #0
        sta d6_cy0+1
        sta d6_cy1+1
        lda d6_y1
        sta d6_cy1
        rts

; a small + at the world point pj_w
mark_cross:
        jsr project
        bcc +
        .for si in [(-3, 0, 3, 0), (0, -2, 0, 2)]
        clc
        lda pj_sx
        adc #<(si[0] & $ffff)
        sta d6_x
        lda pj_sx+1
        adc #>(si[0] & $ffff)
        sta d6_x+1
        clc
        lda pj_sx
        adc #<(si[2] & $ffff)
        sta d6_x1
        lda pj_sx+1
        adc #>(si[2] & $ffff)
        sta d6_x1+1
        clc
        lda pj_sy
        adc #<(si[1] & $ffff)
        sta d6_y
        lda pj_sy+1
        adc #>(si[1] & $ffff)
        sta d6_y+1
        clc
        lda pj_sy
        adc #<(si[3] & $ffff)
        sta d6_y1
        lda pj_sy+1
        adc #>(si[3] & $ffff)
        sta d6_y1+1
        jsr d6_line
        .next
+       rts

;---------------------------------------------------------------------------------------
; world transforms: wm (48 bytes an object: A rows, t) and sel (1 if drawn as selected)
;---------------------------------------------------------------------------------------
world_all:
        lda #0
        sta wa_i
        lda #$ff
        sta wa_seld                     ; the depth below which things are selected
        sta wa_hd                       ; and hidden
_o:
        lda wa_i
        cmp doc_nobj
        bne +
        rts
+       tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        sta wa_d
        ; selection: this one, or inside a selected group
        lda wa_seld
        cmp #$ff
        beq _notin
        lda wa_seld                     ; deeper than the selected group: inside it
        cmp wa_d
        bcs _notin
        lda #1
        bra _flag
_notin:
        lda #$ff
        sta wa_seld
        lda wa_i
        cmp ms_sel
        bne +
        lda wa_d
        sta wa_seld
        lda #1
        bra _flag
+       lda #0
_flag:  ldx wa_i
        sta sel_flag,x
        ; hidden: by its own box, or inside a hidden group
        lda wa_hd
        cmp #$ff
        beq _hown
        cmp wa_d
        bcs _hleft                      ; (not deeper: out of that group)
        lda #1
        bra _hput
_hleft: lda #$ff
        sta wa_hd
_hown:  ldy #O_FLAGS
        lda (op),y
        and #OF_HIDE
        beq _hput
        lda wa_d
        sta wa_hd
        lda #1
_hput:  ldx wa_i
        sta hid_flag,x
        ; L = rotations of (scale I), t = pos
        jsr local_matrix
        ; W = P L, P = the parent's (wstk at depth - 1), or L at depth 0
        lda wa_d
        beq _top
        dec a
        jsr wstk_ptr                    ; pa = the parent's
        jsr mat_mul                     ; mm_r = (pa) * lm
        bra _keep
_top:
        ldx #47
-       lda lm,x
        sta mm_r,x
        dex
        bpl -
_keep:
        lda wa_d                        ; this one's, for its children
        jsr wstk_ptr
        ldy #47
-       lda mm_r,y
        sta (pa),y
        dey
        bpl -
        lda wa_i                        ; and its own
        jsr wm_ptr
        ldy #47
-       lda mm_r,y
        sta (pa),y
        dey
        bpl -
        inc wa_i
        jmp _o

; pa = wstk + 48 A / wm + 48 A
wstk_ptr:
        tax
        lda wstk_lo,x
        sta pa
        lda wstk_hi,x
        sta pa+1
        rts
wm_ptr:
        tax
        lda wm_lo,x
        sta pa
        lda wm_hi,x
        sta pa+1
        rts
wstk_lo:        .byte <(wstk + range(10) * 48)
wstk_hi:        .byte >(wstk + range(10) * 48)
wm_lo:          .byte <(wm + range(DOC_MAXOBJ) * 48)
wm_hi:          .byte >(wm + range(DOC_MAXOBJ) * 48)

; lm = the object at op: A = Rz Ry Rx s, t = pos
local_matrix:
        ldx #47
        lda #0
-       sta lm,x
        dex
        bpl -
        ldy #O_SCALE
        ldx #0
-       lda (op),y
        sta lm,x                        ; A[0][0]
        sta lm+16,x                     ; A[1][1]
        sta lm+32,x                     ; A[2][2]
        iny
        inx
        cpx #4
        bne -
        ldy #O_POS
        ldx #0
-       lda (op),y
        sta lm+36,x
        iny
        inx
        cpx #12
        bne -
        lda #0
        sta lr_ax
_ax:
        lda lr_ax                       ; the angle about this axis
        asl
        asl
        clc
        adc #O_ROT
        tay
        ldx #0
-       lda (op),y
        sta fs_a,x
        sta lr_ang,x
        iny
        inx
        cpx #4
        bne -
        #BEQZ lr_ang, _next
        jsr fcos_deg
        stq lr_c
        #MOVQ lr_ang, fs_a
        jsr fsin_deg
        stq lr_s
        ; rows a, b of A: u' = c u -/+ s v ...
        ldx lr_ax
        lda lr_ra,x
        sta lr_a
        lda lr_rb,x
        sta lr_b
        lda #0
        sta lr_j
-       jsr lr_pair
        inc lr_j
        lda lr_j
        cmp #3
        bne -
_next:
        inc lr_ax
        lda lr_ax
        cmp #3
        bne _ax
        rts
lr_ra:          .byte 1, 0, 0
lr_rb:          .byte 2, 2, 1
lr_minus:       .byte 1, 0, 1

; one column (lr_j) of rows lr_a, lr_b of lm
lr_pair:
        lda lr_a
        jsr _el
        sta lr_u
        lda lr_b
        jsr _el
        sta lr_v
        ldx lr_u
        ldy #0
-       lda lm,x
        sta lr_x,y
        inx
        iny
        cpy #4
        bne -
        ldx lr_v
        ldy #0
-       lda lm,x
        sta lr_y,y
        inx
        iny
        cpy #4
        bne -
        ldx lr_ax
        lda lr_minus,x
        beq _plus
        #FMUL lr_c, lr_x, tq            ; u' = c u - s v; v' = s u + c v
        #FMUL lr_s, lr_y, tv3m
        #SUBQ tq, tv3m, lr_x2
        #FMUL lr_s, lr_x, tq
        #FMUL lr_c, lr_y, tv3m
        #ADDQ tq, tv3m, lr_y2
        bra _put
_plus:  #FMUL lr_c, lr_x, tq            ; u' = c u + s v; v' = c v - s u
        #FMUL lr_s, lr_y, tv3m
        #ADDQ tq, tv3m, lr_x2
        #FMUL lr_c, lr_y, tq
        #FMUL lr_s, lr_x, tv3m
        #SUBQ tq, tv3m, lr_y2
_put:
        ldx lr_u
        ldy #0
-       lda lr_x2,y
        sta lm,x
        inx
        iny
        cpy #4
        bne -
        ldx lr_v
        ldy #0
-       lda lr_y2,y
        sta lm,x
        inx
        iny
        cpy #4
        bne -
        rts
_el:    ; 12 row + 4 lr_j
        sta tmp0
        asl
        clc
        adc tmp0
        asl
        asl
        sta tmp0
        lda lr_j
        asl
        asl
        clc
        adc tmp0
        rts

; mm_r = P L, P at (pa), L = lm: A = P.A L.A, t = P.A L.t + P.t
mat_mul:
        ldy #47
-       lda (pa),y
        sta mm_p,y
        dey
        bpl -
        .for si = 0, si < 3, si += 1
        #MOVQ lm+si*4, mm_c
        #MOVQ lm+12+si*4, mm_c+4
        #MOVQ lm+24+si*4, mm_c+8
        .for sj = 0, sj < 3, sj += 1
        #DOT mm_p+sj*12, mm_c, mm_r+sj*12+si*4
        .next
        .next
        .for sj = 0, sj < 3, sj += 1
        #DOT mm_p+sj*12, lm+36, tq
        #ADDQ tq, mm_p+36+sj*4, mm_r+36+sj*4
        .next
        rts

; pk_w = object pk_i's origin in the world (its wm's t)
obj_origin:
        lda pk_i
        jsr wm_ptr
        ldy #36
        ldx #0
-       lda (pa),y
        sta pk_w,x
        iny
        inx
        cpx #12
        bne -
        rts

;---------------------------------------------------------------------------------------
; wireframes. A segment in the object's own coordinates: sg_a -> sg_b (through wcur, the
; object's world transform), or in the world: sg_wa -> sg_wb.
;---------------------------------------------------------------------------------------
draw_obj:
        ldx dv_i
        lda hid_flag,x                  ; hidden: not drawn
        beq +
        rts
+       lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_TYPE
        lda (op),y
        cmp #OT_GROUP
        bcc +
        rts                             ; groups are their parts
+       sta do_t
        lda dv_i                        ; wcur = its transform
        jsr wm_ptr
        ldy #47
-       lda (pa),y
        sta wcur,y
        dey
        bpl -
        lda #GC_WIRE
        ldx dv_i
        ldy sel_flag,x
        beq +
        lda #GC_YELLOW
+       sta d6_col
        ldy #O_P                        ; p0, p1, p2
        ldx #0
-       lda (op),y
        sta do_p,x
        iny
        inx
        cpx #12
        bne -
        lda do_t
        asl
        tax
        jmp (_t,x)
_t:     .word wf_sphere, wf_box, wf_cyl, wf_cone, wf_plane, wf_prism, wf_lathe

; a prism: its outline at y = -h/2 and +h/2, and an edge up from each corner. Selected
; (and in an ortho view): a handle on each corner (filled: the one picked)
wf_prism:
        ldx dv_i
        jsr pp_setup
        #NEGQ ci_hh, ci_h
        lda #0
        sta wp_k
_e:
        lda wp_k
        jsr pt_get_a
        ldx wp_k
        inx
        cpx wp_n
        bne +
        ldx #0
+       txa
        jsr pt_get_b
        #MOVQ ci_h, sg_a+4
        #MOVQ ci_h, sg_b+4
        jsr seg_local
        #MOVQ ci_hh, sg_a+4
        #MOVQ ci_hh, sg_b+4
        jsr seg_local
        #VMOV sg_a, sg_b
        #MOVQ ci_h, sg_b+4
        jsr seg_local
        inc wp_k
        lda wp_k
        cmp wp_n
        bne _e
; the selected prism's or lathe's corners: handles (not in the camera view)
wf_handles:
        lda dv_i
        cmp ms_sel
        bne _r
        lda dv_v
        cmp #3
        beq _r
        lda #0
        sta wp_k
_h:
        lda wp_k
        jsr pt_world
        #VMOV pk_w, pj_w
        jsr project
        bcc _hn
        sec
        lda pj_sx
        sbc #2
        sta d6_x
        lda pj_sx+1
        sbc #0
        sta d6_x+1
        clc
        lda pj_sx
        adc #2
        sta d6_x1
        lda pj_sx+1
        adc #0
        sta d6_x1+1
        sec
        lda pj_sy
        sbc #2
        sta d6_y
        lda pj_sy+1
        sbc #0
        sta d6_y+1
        clc
        lda pj_sy
        adc #2
        sta d6_y1
        lda pj_sy+1
        adc #0
        sta d6_y1+1
        jsr pt_valid
        bcc _frame
        lda ms_pt
        cmp wp_k
        bne _frame
        lda #GC_YELLOW
        jsr gui_fill
        bra _hn
_frame:
        lda #GC_CYAN
        sta d6_col
        jsr d6_frame
_hn:
        inc wp_k
        lda wp_k
        cmp wp_n
        bne _h
_r:     rts

; a sphere: three great circles
wf_sphere:
        #MOVQ do_p, ci_r1
        #MOVQ do_p, ci_r2
        lda #0
        sta ci_h
        sta ci_h+1
        sta ci_h+2
        sta ci_h+3
        .for si = 0, si < 3, si += 1
        lda #si
        sta ci_plane
        jsr circle
        .next
        rts

; a box: 12 edges between its corners (+- half sizes)
wf_box:
        .for si = 0, si < 3, si += 1
        ldq do_p+si*4
        #ASRQ_Q
        stq bx_h+si*4
        #NEGQ bx_h+si*4, bx_l+si*4
        .next
        .for se in [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]
        lda #se[0]
        ldx #0
        jsr bx_corner
        lda #se[1]
        ldx #1
        jsr bx_corner
        jsr seg_local
        .next
        rts
; corner A (bit 0 x, bit 1 y, bit 2 z: set = +half) into sg_a (X = 0) or sg_b (X = 1)
bx_corner:
        sta tmp0
        cpx #0
        bne _b
        .for si = 0, si < 3, si += 1
        lsr tmp0
        bcc +
        #MOVQ bx_h+si*4, sg_a+si*4
        bra ++
+       #MOVQ bx_l+si*4, sg_a+si*4
+
        .next
        rts
_b:
        .for si = 0, si < 3, si += 1
        lsr tmp0
        bcc +
        #MOVQ bx_h+si*4, sg_b+si*4
        bra ++
+       #MOVQ bx_l+si*4, sg_b+si*4
+
        .next
        rts

; a cylinder (r = p0, height p1) or cone (r1 = p0, r2 = p1, height p2): two rings, 4 sides
wf_cyl:
        #MOVQ do_p, ci_r1
        #MOVQ do_p, ci_r2
        #MOVQ do_p+4, ci_hh
        bra wf_rings
wf_cone:
        #MOVQ do_p, ci_r1
        #MOVQ do_p+4, ci_r2
        #MOVQ do_p+8, ci_hh
wf_rings:
        ldq ci_hh                       ; rings at y = -h/2 (r1) and +h/2 (r2)
        #ASRQ_Q
        stq ci_hh
        lda #1
        sta ci_plane
        #NEGQ ci_hh, ci_h
        #MOVQ ci_r1, ci_rr
        jsr circle_r
        #MOVQ ci_hh, ci_h
        #MOVQ ci_r2, ci_rr
        jsr circle_r
        .for si = 0, si < 4, si += 1    ; the sides, at 0, 90, 180, 270 degrees
        #FMUL ci_r1, ci_cos+si*16, sg_a
        #NEGQ ci_hh, sg_a+4
        #FMUL ci_r1, ci_cos+((si*4+4)%16)*4, sg_a+8
        #FMUL ci_r2, ci_cos+si*16, sg_b
        #MOVQ ci_hh, sg_b+4
        #FMUL ci_r2, ci_cos+((si*4+4)%16)*4, sg_b+8
        jsr seg_local
        .next
        rts

; a plane: a grid of 5 x 5 lines, 5 units apart, in y = 0
wf_plane:
        .for si = -2, si <= 2, si += 1
        #LDIMM FX(si * 5), sg_a
        #LDIMM 0, sg_a+4
        #LDIMM FX(-10), sg_a+8
        #LDIMM FX(si * 5), sg_b
        #LDIMM 0, sg_b+4
        #LDIMM FX(10), sg_b+8
        jsr seg_local
        #LDIMM FX(-10), sg_a
        #LDIMM 0, sg_a+4
        #LDIMM FX(si * 5), sg_a+8
        #LDIMM FX(10), sg_b
        #LDIMM 0, sg_b+4
        #LDIMM FX(si * 5), sg_b+8
        jsr seg_local
        .next
        rts

; a lathe: a ring at each point of its profile, and lines up its sides at 0, 90, 180
; and 270 degrees from each point to the next
wf_lathe:
        ldx dv_i
        jsr pp_setup
        lda #1
        sta ci_plane
        lda #0
        sta wp_k
_p:
        lda wp_k                        ; the ring: radius x, at height z
        jsr pt_get_a
        #MOVQ sg_a+8, ci_h
        #MOVQ sg_a, ci_rr
        #BEQZ ci_rr, +
        jsr circle_r
+       lda wp_k                        ; the sides, to the next point
        inc a
        cmp wp_n
        beq _h
        jsr pt_get_b
        lda wp_k
        jsr pt_get_a
        #MOVQ sg_a+8, sg_a+4            ; (r, h) -> (r, h, 0)
        #MOVQ sg_b+8, sg_b+4
        #MOVQ q_zero, sg_a+8
        #MOVQ q_zero, sg_b+8
        jsr seg_local
        #MOVQ sg_a, sg_a+8              ; (0, h, r)
        #MOVQ sg_b, sg_b+8
        #MOVQ q_zero, sg_a
        #MOVQ q_zero, sg_b
        jsr seg_local
        #NEGQ sg_a+8, sg_a              ; (-r, h, 0)
        #NEGQ sg_b+8, sg_b
        #MOVQ q_zero, sg_a+8
        #MOVQ q_zero, sg_b+8
        jsr seg_local
        #MOVQ sg_a, sg_a+8              ; (0, h, -r)
        #MOVQ sg_b, sg_b+8
        #MOVQ q_zero, sg_a
        #MOVQ q_zero, sg_b
        jsr seg_local
        inc wp_k
        bra _p
_h:     jmp wf_handles

; a circle of 16 segments, radius ci_r1, in plane ci_plane (0: x-y, 1: x-z at y = ci_h,
; 2: y-z)
circle:
        #MOVQ ci_r1, ci_rr
circle_r:
        lda #0
        sta ci_k
        jsr ci_point                    ; the first point (each one is projected once)
        #VMOV sg_b, xf_in
        jsr sg_proj
_s:
        inc ci_k
        jsr ci_point
        jsr seg_next
        lda ci_k
        cmp #16
        bne _s
        rts
; point ci_k (mod 16) -> sg_b
ci_point:
        lda ci_k
        and #15
        asl
        asl
        tax
        ldy #0
-       lda ci_cos,x                    ; cos
        sta ci_ca,y
        inx
        iny
        cpy #4
        bne -
        lda ci_k                        ; sin = cos(k - 4)
        sec
        sbc #4
        and #15
        asl
        asl
        tax
        ldy #0
-       lda ci_cos,x
        sta ci_sa,y
        inx
        iny
        cpy #4
        bne -
        #FMUL ci_rr, ci_ca, ci_u
        #FMUL ci_rr, ci_sa, ci_v
        lda ci_plane
        bne +
        #MOVQ ci_u, sg_b                ; x-y
        #MOVQ ci_v, sg_b+4
        #MOVQ q_zero, sg_b+8
        rts
+       cmp #1
        bne +
        #MOVQ ci_u, sg_b                ; x-z, at y = ci_h
        #MOVQ ci_h, sg_b+4
        #MOVQ ci_v, sg_b+8
        rts
+       #MOVQ q_zero, sg_b              ; y-z
        #MOVQ ci_u, sg_b+4
        #MOVQ ci_v, sg_b+8
        rts
ci_cos:
        .for si = 0, si < 16, si += 1
        .dint FX(cos(rad(si * 22.5)))
        .next

; the object-space segment sg_a -> sg_b, through wcur
seg_local:
        #VMOV sg_a, xf_in
        jsr sg_proj
; seg_next: on from the last point projected (sg_proj) to sg_b: a polyline projects each
; point once
seg_next:
        lda sg_ok
        sta sg_oka
        #MOVQ sg_px, ln_x0
        #MOVQ sg_py, ln_y0
        #VMOV sg_b, xf_in
        jsr sg_proj
        lda sg_ok
        and sg_oka
        beq _r
        #MOVQ sg_px, ln_x1
        #MOVQ sg_py, ln_y1
        jmp clip_line
_r:     rts
; xf_in through wcur, projected: sg_px, sg_py (16.16 pixels); sg_ok = 1 if it can be seen
sg_proj:
        jsr xf_point
        #VMOV xf_out, pj_w
        jsr project
        lda #0
        rol
        sta sg_ok
        #MOVQ pj_fx, sg_px
        #MOVQ pj_fy, sg_py
        rts
; the world segment sg_wa -> sg_wb in the current view
seg_world:
        #VMOV sg_wa, pj_w
        jsr project
        bcc _r
        #MOVQ pj_fx, ln_x0
        #MOVQ pj_fy, ln_y0
        #VMOV sg_wb, pj_w
        jsr project
        bcc _r
        #MOVQ pj_fx, ln_x1
        #MOVQ pj_fy, ln_y1
        jmp clip_line
_r:     rts

; xf_out = wcur.A xf_in + wcur.t, but for coordinate xf_skip (project_setup: the one a flat
; view doesn't show; $ff: none)
xf_point:
        .for si = 0, si < 3, si += 1
        lda xf_skip
        cmp #si
        beq +
        #DOT wcur+si*12, xf_in, tq
        #ADDQ tq, wcur+36+si*4, xf_out+si*4
+
        .next
        rts

;---------------------------------------------------------------------------------------
; projection: project_setup A = the view; project pj_w -> pj_fx, pj_fy (16.16 screen
; pixels) and pj_sx, pj_sy (words); carry clear if it can't be seen (behind the camera)
;---------------------------------------------------------------------------------------
project_setup:
        sta pj_v
        tax
        lda #0
        sta pj_cx
        sta pj_cx+1
        lda vw_cxl,x
        sta pj_cx+2
        lda vw_cxh,x
        sta pj_cx+3
        lda #0
        sta pj_cy
        sta pj_cy+1
        sta pj_cy+3
        lda vw_cy,x
        sta pj_cy+2
        ldy #$ff
        sty xf_skip
        cpx #3
        beq +
        lda vw_ha,x
        sta pj_ha
        lda vw_va,x
        sta pj_va
        lda #3                          ; xf_point skips the third coordinate
        sec
        sbc pj_ha
        sbc pj_va
        sta xf_skip
        txa
        jsr vw_zoom
        #MOVQ tq, pj_zx
        #FMUL tq, q_aspect, pj_zy
        lda pj_v                        ; the centre: ms_view + 12 v + 4, + 8
        asl
        clc
        adc pj_v
        asl
        asl
        tax
        ldy #0
-       lda ms_view+4,x
        sta pj_ca,y
        lda ms_view+8,x
        sta pj_cb,y
        inx
        iny
        cpy #4
        bne -
+       rts

project:
        lda pj_v
        cmp #3
        beq _persp
        ; across: cx + (w[ha] - ca) zoom; up: cy - (w[va] - cb) zoom 8/15
        lda pj_ha
        asl
        asl
        tax
        ldy #0
-       lda pj_w,x
        sta pj_t,y
        inx
        iny
        cpy #4
        bne -
        #SUBQ pj_t, pj_ca, pj_t
        #FMUL pj_t, pj_zx, pj_t
        #ADDQ pj_cx, pj_t, pj_fx
        lda pj_va
        asl
        asl
        tax
        ldy #0
-       lda pj_w,x
        sta pj_t,y
        inx
        iny
        cpy #4
        bne -
        #SUBQ pj_t, pj_cb, pj_t
        #FMUL pj_t, pj_zy, pj_t
        #SUBQ pj_cy, pj_t, pj_fy
        bra _ints
_persp:
        #VSUB pj_w, doc_cam_loc, pj_c
        #DOT pj_c, cm_f, pj_zc
        #LDIMM FX(0.1), tq              ; in front of the camera?
        #BLTQ pj_zc, tq, _no
        #DOT pj_c, cm_r, pj_t
        #FDIV pj_t, pj_zc, pj_t
        #FMUL pj_t, cm_k, pj_t
        #ADDQ pj_cx, pj_t, pj_fx
        #DOT pj_c, cm_u, pj_t
        #FDIV pj_t, pj_zc, pj_t
        #FMUL pj_t, cm_ky, pj_t
        #SUBQ pj_cy, pj_t, pj_fy
_ints:
        lda pj_fx+2
        sta pj_sx
        lda pj_fx+3
        sta pj_sx+1
        lda pj_fy+2
        sta pj_sy
        lda pj_fy+3
        sta pj_sy+1
        sec
        rts
_no:    clc
        rts

; the camera's frame for the perspective view: f, r, u, and the scale k (pixels at 1 unit
; away): 120 / tan(angle / 2), ky = k 8/15
cam_setup:
        #VSUB doc_cam_look, doc_cam_loc, cn_a
        jsr cn_norm
        #VMOV cn_r, cm_f
        ; r = y x f = (f.z, 0, -f.x)
        #MOVQ cm_f+8, cn_a
        #MOVQ q_zero, cn_a+4
        #NEGQ cm_f, cn_a+8
        jsr cn_norm
        #VMOV cn_r, cm_r
        ; u = f x r
        #FMUL cm_f+4, cm_r+8, tq
        #FMUL cm_f+8, cm_r+4, tv3m
        #SUBQ tq, tv3m, cm_u
        #FMUL cm_f+8, cm_r, tq
        #FMUL cm_f, cm_r+8, tv3m
        #SUBQ tq, tv3m, cm_u+4
        #FMUL cm_f, cm_r+4, tq
        #FMUL cm_f+4, cm_r, tv3m
        #SUBQ tq, tv3m, cm_u+8
        ldq doc_cam_angle
        #ASRQ_Q
        stq fs_a
        stq cm_half
        jsr fsin_deg
        stq cm_sin
        #MOVQ cm_half, fs_a
        jsr fcos_deg
        stq tq
        #BEQZ cm_sin, +
        #FDIV tq, cm_sin, tq            ; 1 / tan = cos / sin
        sec                             ; times half the camera view's width
        lda vw_x1l+3
        sbc vw_x0l+3
        sta tv3m+2
        lda vw_x1h+3
        sbc vw_x0h+3
        sta tv3m+3
        lda #0
        sta tv3m
        sta tv3m+1
        ldq tv3m
        #LSRQ_Q
        stq tv3m
        #FMUL tq, tv3m, cm_k
        #FMUL cm_k, q_aspect, cm_ky
+       rts
; cn_r = cn_a normalised (unchanged if zero)
cn_norm:
        #VMOV cn_a, cn_r
        #DOT cn_a, cn_a, tq
        #BEQZ tq, +
        ldq tq
        jsr fsqrt
        stq cn_l
        #FDIV cn_a, cn_l, cn_r
        #FDIV cn_a+4, cn_l, cn_r+4
        #FDIV cn_a+8, cn_l, cn_r+8
+       rts

;---------------------------------------------------------------------------------------
; clip_line: ln_x0, ln_y0 - ln_x1, ln_y1 (16.16 pixels) to the clip rectangle
; (Cohen-Sutherland), then d6_line
;---------------------------------------------------------------------------------------
clip_line:
        jsr cl_ints                     ; both ends inside (their whole pixels)? draw it
        ldx #0
        jsr d6_inside
        bcc +
        ldx #4
        jsr d6_inside
        bcc +
        jmp d6_line_in
+       lda #0
        sta cl_n
_loop:
        inc cl_n
        lda cl_n
        cmp #6
        bcs _out                        ; (can't settle: skip it)
        #MOVQ ln_x0, cl_x
        #MOVQ ln_y0, cl_y
        jsr cl_code
        sta cl_c0
        #MOVQ ln_x1, cl_x
        #MOVQ ln_y1, cl_y
        jsr cl_code
        sta cl_c1
        ora cl_c0
        beq _draw                       ; both inside
        lda cl_c0
        and cl_c1
        bne _out                        ; both off one side
        lda cl_c0                       ; move an outside end to the edge
        bne +
        jsr cl_swap                     ; (so that end 0 is the outside one)
        lda cl_c0
+       sta cl_c
        ; dx = x1 - x0, dy = y1 - y0
        #SUBQ ln_x1, ln_x0, cl_dx
        #SUBQ ln_y1, ln_y0, cl_dy
        lda cl_c
        and #CL_TOP | CL_BOTTOM
        beq _lr
        and #CL_TOP
        beq +
        #MOVQ cl_ty, cl_e               ; y = top edge
        bra ++
+       #MOVQ cl_by, cl_e
+       ; x0 += dx (e - y0) / dy, y0 = e
        #SUBQ cl_e, ln_y0, tq
        #BEQZ cl_dy, _out
        #FDIV tq, cl_dy, tq
        #FMUL cl_dx, tq, tq
        #ADDQ ln_x0, tq, ln_x0
        #MOVQ cl_e, ln_y0
        jmp _loop
_lr:
        lda cl_c
        and #CL_LEFT
        beq +
        #MOVQ cl_lx, cl_e
        bra ++
+       #MOVQ cl_rx, cl_e
+       #SUBQ cl_e, ln_x0, tq           ; y0 += dy (e - x0) / dx, x0 = e
        #BEQZ cl_dx, _out
        #FDIV tq, cl_dx, tq
        #FMUL cl_dy, tq, tq
        #ADDQ ln_y0, tq, ln_y0
        #MOVQ cl_e, ln_x0
        jmp _loop
_out:   rts
_draw:
        jsr cl_ints
        jmp d6_line
; the ends' whole pixels -> d6_x, d6_y, d6_x1, d6_y1
cl_ints:
        lda ln_x0+2
        sta d6_x
        lda ln_x0+3
        sta d6_x+1
        lda ln_y0+2
        sta d6_y
        lda ln_y0+3
        sta d6_y+1
        lda ln_x1+2
        sta d6_x1
        lda ln_x1+3
        sta d6_x1+1
        lda ln_y1+2
        sta d6_y1
        lda ln_y1+3
        sta d6_y1+1
        rts
CL_LEFT         = 1
CL_RIGHT        = 2
CL_TOP          = 4
CL_BOTTOM       = 8
; A = the outcode of (cl_x, cl_y) against the clip rectangle (as 16.16 edges)
cl_code:
        lda #0
        sta cl_k
        lda #0                          ; the edges: lx = cx0, rx = cx1 + 0.99, ty, by
        sta cl_lx
        sta cl_lx+1
        sta cl_ty
        sta cl_ty+1
        lda #$ff
        sta cl_rx
        sta cl_rx+1
        sta cl_by
        sta cl_by+1
        lda d6_cx0
        sta cl_lx+2
        lda d6_cx0+1
        sta cl_lx+3
        lda d6_cx1
        sta cl_rx+2
        lda d6_cx1+1
        sta cl_rx+3
        lda d6_cy0
        sta cl_ty+2
        lda d6_cy0+1
        sta cl_ty+3
        lda d6_cy1
        sta cl_by+2
        lda d6_cy1+1
        sta cl_by+3
        #BLTQ cl_x, cl_lx, _l
        #BGTQ cl_x, cl_rx, _r
        bra _y
_l:     lda #CL_LEFT
        sta cl_k
        bra _y
_r:     lda #CL_RIGHT
        sta cl_k
_y:     #BLTQ cl_y, cl_ty, _t
        #BGTQ cl_y, cl_by, _b
        lda cl_k
        rts
_t:     lda cl_k
        ora #CL_TOP
        rts
_b:     lda cl_k
        ora #CL_BOTTOM
        rts
cl_swap:
        #MOVQ ln_x0, tq
        #MOVQ ln_x1, ln_x0
        #MOVQ tq, ln_x1
        #MOVQ ln_y0, tq
        #MOVQ ln_y1, ln_y0
        #MOVQ tq, ln_y1
        lda cl_c0
        ldx cl_c1
        sta cl_c1
        stx cl_c0
        rts

;---------------------------------------------------------------------------------------
; the grid (View, Grid) in a flat view, under everything else: lines at the multiples of a
; spacing, the smallest of 0.25, 0.5, 1, 2, 5 .. 100 units that is GR_MINPX pixels or more
; apart across. Called by draw_view once project_setup and the clip are done.
;---------------------------------------------------------------------------------------
GR_MINPX        = 12
GR_N            = 9
view_grid:
        lda ms_grid
        beq _r
        lda #0
_pick:  sta gr_k                        ; spacing gr_k: s, 1 / s
        tax
        ldy #0
-       lda gr_steps,x
        sta gr_s,y
        lda gr_inv,x
        sta gr_i,y
        inx
        iny
        cpy #4
        bne -
        #FMUL gr_s, pj_zx, gr_d         ; pixels apart across (the zoom is positive)
        lda gr_d+3
        bne _found
        lda gr_d+2
        cmp #GR_MINPX
        bcs _found
        lda gr_k
        clc
        adc #4
        cmp #GR_N * 4
        bne _pick
_r:     rts                             ; (zoomed too far out: no grid)
_found:
        lda #GC_GRID
        sta d6_col
        lda #0                          ; lines down the view, at x = cx + (w - ca) zx
        sta gr_up
        #MOVQ pj_ca, gr_a
        #MOVQ pj_zx, gr_z
        #MOVQ pj_cx, gr_c
        ldx #d6_cx0 - d6_cx0
        jsr _dir
        inc gr_up                       ; lines across, at y = cy - (w - cb) zy
        #MOVQ pj_cb, gr_a
        #MOVQ pj_zy, gr_z
        #MOVQ pj_cy, gr_c
        ldx #d6_cy0 - d6_cx0
_dir:   ; the edges: gr_lo, gr_hi = d6_cx0 / d6_cx1 or d6_cy0 / d6_cy1
        lda d6_cx0,x
        sta gr_lo
        lda d6_cx0+1,x
        sta gr_lo+1
        lda d6_cx1,x
        sta gr_hi
        lda d6_cx1+1,x
        sta gr_hi+1
        #FMUL gr_s, gr_z, gr_d          ; pixels apart
        #FMUL gr_a, gr_i, tq            ; the multiple of s nearest the centre: round(a / s) s
        clc
        lda tq+1
        adc #$80
        lda tq+2
        adc #0
        sta tq+2
        lda tq+3
        adc #0
        sta tq+3
        lda #0
        sta tq
        sta tq+1
        #FMUL tq, gr_s, tq
        #SUBQ tq, gr_a, tq              ; its line: c +- (w0 - a) z
        #FMUL tq, gr_z, tq
        lda gr_up
        beq +
        #NEGQ tq, tq
+       #ADDQ gr_c, tq, gr_p
        #MOVQ gr_p, gr_q
_fwd:   jsr _line                       ; that one and those after it, to the far edge
        jsr _past_hi
        bmi _back
        #ADDQ gr_p, gr_d, gr_p
        bra _fwd
_back:  #MOVQ gr_q, gr_p                ; those before it, to the near edge
_bk:    #SUBQ gr_p, gr_d, gr_p
        lda gr_p+2                      ; p < lo: done
        cmp gr_lo
        lda gr_p+3
        sbc gr_lo+1
        bmi _r
        jsr _line
        bra _bk
_past_hi:                               ; N set if p > hi
        lda gr_hi
        cmp gr_p+2
        lda gr_hi+1
        sbc gr_p+3
        rts
_line:  ; a line at p (if it's inside)
        lda gr_p+2
        cmp gr_lo
        lda gr_p+3
        sbc gr_lo+1
        bmi _no
        jsr _past_hi
        bmi _no
        lda gr_up
        bne _across
        lda gr_p+2                      ; down: x = p, the clip's top to bottom
        sta d6_x
        lda gr_p+3
        sta d6_x+1
        lda d6_cy0
        sta d6_y
        lda d6_cy0+1
        sta d6_y+1
        lda d6_cy1
        sta d6_y1
        lda d6_cy1+1
        sta d6_y1+1
        jmp d6_vline
_across:
        lda gr_p+2                      ; across: y = p, the clip's left to right
        sta d6_y
        lda gr_p+3
        sta d6_y+1
        lda d6_cx0
        sta d6_x
        lda d6_cx0+1
        sta d6_x+1
        lda d6_cx1
        sta d6_x1
        lda d6_cx1+1
        sta d6_x1+1
        jmp d6_hline
_no:    rts
gr_steps:       .dint FX(0.25), FX(0.5), FX(1), FX(2), FX(5), FX(10), FX(20), FX(50), FX(100)
gr_inv:         .dint FX(4), FX(2), FX(1), FX(0.5), FX(0.2), FX(0.1), FX(0.05), FX(0.02), FX(0.01)
        .cerror gr_inv - gr_steps != GR_N * 4, "the grid's spacings"
gr_k:           .byte 0
gr_up:          .byte 0                 ; 0: lines down the view, 1: across it
gr_lo:          .word 0                 ; the clip's edges along the lines' spacing
gr_hi:          .word 0
gr_s:           .dword 0
gr_i:           .dword 0
gr_d:           .dword 0
gr_a:           .dword 0
gr_z:           .dword 0
gr_c:           .dword 0
gr_p:           .dword 0
gr_q:           .dword 0
