;=======================================================================================
; model.asm - overlay 4: the modeller. Four views (top, front, side: orthographic; the
; camera's, in perspective), the object list and the properties panel, menus, selecting,
; dragging and typing values. The document is resident (doc.asm), and so is the state that
; has to survive an overlay swap (ms_*, in modelst.asm).
;
;   model_main     run the modeller (doesn't return; renders go through resident code)
;
; Screen: menu bar y 0-9; views 2 x 2 in x 0-479, y 10-189; the list (x 480-639, y 10-117)
; and the properties (y 118-189); the status line y 190-199.
;=======================================================================================

LIST_X          = 480
LIST_COL        = 61                    ; (the visible boxes are left of it)
LIST_Y0         = 12
LIST_ROWS       = 11
PROP_Y0         = 118                   ; rows 8 pixels apart: 9 of them, to y 189
PROP_ROWS       = 9
PCOL_A          = 60
PCOL_B          = 70

; the views: x0, y0, x1, y1, kind (0 top, 1 front, 2 side, 3 camera)
; the four views' places (views_layout copies them into vw_*, or gives one view the
; whole area when ms_maxview says so)
vd_x0:          .word 0, 240, 0, 240
vd_x1:          .word 239, 479, 239, 479
vd_y0:          .byte 10, 10, 100, 100
vd_y1:          .byte 99, 99, 189, 189
vw_x0l:         .fill 4
vw_x0h:         .fill 4
vw_x1l:         .fill 4
vw_x1h:         .fill 4
vw_y0:          .fill 4
vw_y1:          .fill 4
vw_cxl:         .fill 4                 ; centres
vw_cxh:         .fill 4
vw_cy:          .fill 4
vw_on:          .fill 4                 ; drawn (all four, or the one made large)

views_layout:
        ldx #0
_v:
        lda ms_maxview
        cmp #$ff
        beq _small
        stx tmp0
        cmp tmp0
        beq _large
        lda #0                          ; another view is large: this one is hidden
        sta vw_on,x
        bra _next
_large:
        lda #1
        sta vw_on,x
        lda #<0
        sta vw_x0l,x
        lda #>0
        sta vw_x0h,x
        lda #<479
        sta vw_x1l,x
        lda #>479
        sta vw_x1h,x
        lda #10
        sta vw_y0,x
        lda #189
        sta vw_y1,x
        bra _centre
_small:
        lda #1
        sta vw_on,x
        txa
        asl
        tay
        lda vd_x0,y
        sta vw_x0l,x
        lda vd_x0+1,y
        sta vw_x0h,x
        lda vd_x1,y
        sta vw_x1l,x
        lda vd_x1+1,y
        sta vw_x1h,x
        lda vd_y0,x
        sta vw_y0,x
        lda vd_y1,x
        sta vw_y1,x
_centre:
        clc                             ; centre = (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2
        lda vw_x0l,x
        adc vw_x1l,x
        sta tmp0
        lda vw_x0h,x
        adc vw_x1h,x
        sta tmp1
        inc tmp0
        bne +
        inc tmp1
+       lsr tmp1
        ror tmp0
        lda tmp0
        sta vw_cxl,x
        lda tmp1
        sta vw_cxh,x
        clc
        lda vw_y0,x
        adc vw_y1,x
        ror                             ; (the carry is the 9th bit)
        sta vw_cy,x
_next:
        inx
        cpx #4
        bne _v
        rts
vw_ha:          .byte 0, 0, 2               ; the world axis across each view
vw_va:          .byte 2, 1, 1               ; and up
vw_names:       .word vn_top, vn_front, vn_side, vn_cam
vn_top:         .null "Top"
vn_front:       .null "Front"
vn_side:        .null "Side"
vn_cam:         .null "Camera"

model_main:
        lda ms_inited
        bne +
        jsr model_reset
+       jsr gui_on
        lda #<st_hello
        ldx #>st_hello
        sta ms_msg
        stx ms_msg+1
        jsr redraw_all
        lda #5                          ; (tests: the modeller is up)
        sta done
_loop:
        jsr wait_frame
        .if DBG_BENCH
        lda dbg_bench                   ; (tests: 1 = time 16 redraw_work, 2 = 16 draw_views)
        beq _nob
        lda ticks
        sta dbg_btime
        lda ticks+1
        sta dbg_btime+1
        lda #16
        sta dbg_bn
-       lda dbg_bench
        cmp #1
        bne +
        jsr redraw_work
        bra ++
+       jsr world_all
        jsr draw_views
+       dec dbg_bn
        bne -
        sec
        lda ticks
        sbc dbg_btime
        sta dbg_btime
        lda ticks+1
        sbc dbg_btime+1
        sta dbg_btime+1
        lda #0
        sta dbg_bench
_nob:
        .endif
        jsr gui_poll
        lda ev_type
        beq _loop
        jsr model_event
        bra _loop
st_hello:       .null "renderer65 modeller - File: Render to see the scene"

; a new document and views
model_reset:
        lda #1
        sta ms_inited
        jsr doc_new                     ; (resident: it is in overlay 5)
        lda #$ff
        sta ms_sel
        jmp views_reset
views_reset:
        ldx #(3 * 12) - 1
-       lda vw_default,x
        sta ms_view,x
        dex
        bpl -
        lda #0
        sta ms_lscroll
        rts
; per ortho view: zoom (pixels a unit), the world point at its centre (across, up): the
; origin, where Add puts things
vw_default:     .dint FX(10), FX(0), FX(0), FX(10), FX(0), FX(0), FX(10), FX(0), FX(0)

;=======================================================================================
; events
;=======================================================================================
model_event:
        lda ev_type
        cmp #EV_KEY
        bne +
        jmp model_key
+       cmp #EV_DOWN
        beq _down
        cmp #EV_MOVE
        bne +
        jmp model_drag
+       cmp #EV_UP
        bne +
        lda #$ff
        sta ms_drag
        lda #0
        sta sb_drag
        sta ms_orbit
        sta ms_aim
+       rts
_down:
        lda #0
        sta dr_moved
        lda ev_y
        cmp #10
        bcs +
        jsr gui_menu                    ; the menu bar (it puts back what it covered;
        jmp model_cmd                   ; commands redraw what they change)
+       cmp #190
        bcc +
        rts
+       lda ev_x+1                      ; the panel?
        cmp #>LIST_X
        bcc _view
        bne +
        lda ev_x
        cmp #<LIST_X
        bcc _view
+       lda ev_y
        cmp #118
        bcs +
        jmp list_click
+       #FAR OVL_PANEL, prop_click
        rts
_view:
        jmp view_click

; keys: + - zoom, DEL delete, r render, p preview, s save
model_key:
        lda ev_key
        cmp #'+'
        bne +
        lda #CMD_ZOOMIN
        jmp model_cmd
+       cmp #'-'
        bne +
        lda #CMD_ZOOMOUT
        jmp model_cmd
+       cmp #K_DEL                      ; (a prism's corner, if one is picked)
        bne +
        jsr pt_valid
        bcc _del
        jmp pt_delete
_del:   lda #CMD_DELETE
        jmp model_cmd
+       cmp #'i'
        beq _ins
        cmp #K_INST
        bne +
_ins:   jsr pt_valid
        bcc _r
        jmp pt_insert
+       cmp #'r'
        bne +
        lda #CMD_RENDER
        jmp model_cmd
+       cmp #'p'
        bne +
        lda #CMD_PREVIEW
        jmp model_cmd
+       cmp #'s'
        bne +
        lda #CMD_SAVE
        jmp model_cmd
+       cmp #'l'
        bne +
        lda #CMD_LOCATE
        jmp model_cmd
+       cmp #'a'
        bne +
        lda #CMD_AIM
        jmp model_cmd
+       cmp #'g'
        bne +
        lda #CMD_SNAP
        jmp model_cmd
+       cmp #'u'
        beq _undo
        cmp #$1a
        bne +
_undo:  lda #CMD_UNDO
        jmp model_cmd
+       cmp #'y'
        beq _redo
        cmp #$19
        bne _r
_redo:  lda #CMD_REDO
        jmp model_cmd
_r:     rts

;---------------------------------------------------------------------------------------
; the views: picking and dragging
;---------------------------------------------------------------------------------------
; A = the view at ev_x, ev_y -> carry set if one
view_at:
        ldx #0
-       lda vw_on,x
        beq _no
        lda ev_y
        cmp vw_y0,x
        bcc _no
        lda vw_y1,x
        cmp ev_y
        bcc _no
        lda ev_x
        cmp vw_x0l,x
        lda ev_x+1
        sbc vw_x0h,x
        bcc _no
        lda vw_x1l,x
        cmp ev_x
        lda vw_x1h,x
        sbc ev_x+1
        bcc _no
        txa
        sec
        rts
_no:    inx
        cpx #4
        bne -
        clc
        rts

view_click:
        jsr view_at
        bcs +
        rts
+       sta ms_dview
        ; on its name (the top-left corner): make it large, or the four again
        tax
        lda vw_y0,x
        clc
        adc #11
        cmp ev_y
        bcc _pick
        sec
        lda ev_x
        sbc vw_x0l,x
        sta tmp0
        lda ev_x+1
        sbc vw_x0h,x
        bne _pick
        lda tmp0
        cmp #56
        bcs _pick
        lda ms_maxview
        cmp #$ff
        beq +
        lda #$ff                        ; large: back to four
        sta ms_maxview
        jmp redraw_work
+       lda ms_dview
        sta ms_maxview
        jmp redraw_work
_pick:
        jsr world_all                   ; every object's place
        jsr pt_pick                     ; a corner of the selected prism?
        bcc +
        jmp redraw_work
+       lda #0                          ; (a click anywhere else lets go of the corner)
        sta ms_dpt
        lda #$ff
        sta ms_ptobj
        ; the nearest thing within 10 pixels of the click: objects' origins, lights, camera
        lda #$ff
        sta pk_best
        lda #100
        sta pk_bd
        lda #0
        sta pk_i
_obj:
        lda pk_i
        cmp doc_nobj
        beq _lights
        tax                             ; (not the hidden ones)
        lda hid_flag,x
        bne +
        jsr obj_origin                  ; pk_w = its origin, in the world
        jsr pk_try
+       inc pk_i
        bra _obj
_lights:
        lda #0
        sta pk_j
_lnext: lda pk_j
        cmp doc_nlight
        beq _cam
        jsr _lp
        ldy #DL_POS
        ldx #0
-       lda (lp),y
        sta pk_w,x
        iny
        inx
        cpx #12
        bne -
        lda pk_j
        ora #$40
        sta pk_i
        jsr pk_try
        jsr _lp
        ldy #DL_SPOT                    ; a spotlight's aim point: $60 + the light
        lda (lp),y
        and #1
        beq +
        ldy #DL_AIM + 11
        ldx #11
-       lda (lp),y
        sta pk_w,x
        dey
        dex
        bpl -
        lda pk_j
        ora #$60
        sta pk_i
        jsr pk_try
+       inc pk_j
        bra _lnext
_lp:    ldx pk_j                        ; lp = light pk_j
        lda dlight_lo,x
        sta lp
        lda dlight_hi,x
        sta lp+1
        rts
_cam:
        #VMOV doc_cam_loc, pk_w
        lda #$80
        sta pk_i
        jsr pk_try
        lda ms_aimfor                   ; View, Aim light: this click says where
        cmp #$ff
        beq +
        jmp aim_pick
+       lda pk_best
        cmp #$ff
        bne _picked
        lda ms_dview                    ; nothing, in the camera view: turn the camera
        cmp #3
        bne +
        jmp cam_orbit_start
_picked:
        ldx #0                          ; a spotlight's aim point: the light, its aim dragged
        cmp #$60
        bcc +
        cmp #$70
        bcs +
        and #$4f
        inx
+       stx ms_aim
        sta ms_sel
        lda ms_dview                    ; drag it from here (not in the camera view)
        cmp #3
        beq +
        sta ms_drag
        lda ev_x
        sta ms_dx
        lda ev_x+1
        sta ms_dx+1
        lda ev_y
        sta ms_dy
+       jmp redraw_work

; View, Aim light: the click picked pk_best; light ms_aimfor ($40 + n) becomes a spotlight
; aimed at its place (an object's origin, a light, the camera)
aim_pick:
        lda ms_aimfor
        sta ap_l
        sta ms_sel                      ; the light stays selected
        lda #$ff                        ; (one click only)
        sta ms_aimfor
        ldx pk_best
        cpx #$ff
        beq _none
        cpx ms_sel                      ; (not itself)
        beq _none
        cpx #$60                        ; (nor an aim point)
        bcc +
        cpx #$70
        bcc _none
+       stx ms_sel
        jsr sel_world                   ; pk_w = its place
        lda ap_l
        sta ms_sel
        bcc _none
        jsr u_save
        lda ms_sel
        and #$3f
        tax
        lda dlight_lo,x
        sta lp
        lda dlight_hi,x
        sta lp+1
        ldy #DL_AIM + 11
        ldx #11
-       lda pk_w,x
        sta (lp),y
        dey
        dex
        bpl -
        ldy #DL_SPOT
        lda #1
        sta (lp),y
        lda #<st_aimedl
        ldx #>st_aimedl
        jmp say
_none:  lda #<st_noaiml
        ldx #>st_noaiml
        jmp say
st_aimedl:      .null "The spotlight aims at it"
st_noaiml:      .null "Aim light: nothing there, nothing changed"
ap_l:           .byte 0

; pk_w (world) seen in view ms_dview: if it's nearer the click than pk_bd, pk_i is it
pk_try:
        lda ms_dview
        jsr project_setup
        #VMOV pk_w, pj_w
        jsr project
        bcc _r
        sec                             ; distance: max(|dx|, |dy|)
        lda pj_sx
        sbc ev_x
        sta tmp0
        lda pj_sx+1
        sbc ev_x+1
        jsr _abs16
        sta tmp1
        sec
        lda pj_sy
        sbc ev_y
        sta tmp0
        lda pj_sy+1
        sbc #0
        jsr _abs16
        cmp tmp1
        bcs +
        lda tmp1
+       cmp #10
        bcs _r
        cmp pk_bd
        bcs _r
        sta pk_bd
        lda pk_i
        sta pk_best
_r:     rts
_abs16: ; A:tmp0 = a 16-bit difference -> A = min(255, |it|)
        bpl +
        eor #$ff
        pha
        lda tmp0
        eor #$ff
        clc
        adc #1
        sta tmp0
        pla
        adc #0
+       bne +
        lda tmp0
        rts
+       lda #255
        rts

; dragging: the selection moves with the pointer, in the view's plane
model_drag:
        lda sb_drag                     ; the list's scroll bar
        beq +
        jmp sb_drag_move
+       lda ms_orbit                    ; turning the camera
        beq +
        jmp cam_orbit_move
+       lda ms_drag
        cmp #$ff
        bne +
        rts
+       lda ms_dpt                      ; the selection itself (resident: modelres.asm)
        bne +
        jmp drag_obj
+       lda dr_moved                    ; a prism's corner: its first move keeps an undo
        bne +
        inc dr_moved
        jsr u_save
+       jsr sel_pos_ptr                 ; lp = the selection's position (bank 0), or none
        bcs +
        rts
+       ldx ms_drag
        ; d across = (x - dx) / zoom, d up = -(y - dy) / (zoom * 8/15)
        sec
        lda ev_x
        sbc ms_dx
        sta dr_a+2
        lda ev_x+1
        sbc ms_dx+1
        sta dr_a+3
        lda #0
        sta dr_a
        sta dr_a+1
        sec
        lda ms_dy
        sbc ev_y
        sta dr_b+2
        lda #0
        sbc #0
        sta dr_b+3
        lda #0
        sta dr_b
        sta dr_b+1
        lda ms_drag
        jsr vw_zoom                     ; tq = zoom
        #FDIV dr_a, tq, dr_a
        #FMUL tq, q_aspect, tv3m
        #FDIV dr_b, tv3m, dr_b
        jmp pt_drag
q_aspect:       .dint FX(8.0 / 15.0)

; lp = the position of the selection; carry clear if nothing is selected
sel_pos_ptr:
        lda ms_sel
        cmp #$ff
        beq _no
        cmp #$80
        bne +
        lda #<doc_cam_loc
        sta lp
        lda #>doc_cam_loc
        sta lp+1
        sec
        rts
+       cmp #$40
        bcc +
        and #$3f
        tax
        lda dlight_lo,x
        sta lp
        lda dlight_hi,x
        sta lp+1
        lda ms_aim                      ; (its aim point, while that's being dragged)
        beq _lt
        clc
        lda lp
        adc #DL_AIM
        sta lp
        bcc _lt
        inc lp+1
_lt:    sec
        rts
+       tax
        clc
        lda obj_lo,x
        adc #O_POS
        sta lp
        lda obj_hi,x
        adc #0
        sta lp+1
        sec
        rts
_no:    clc
        rts

; tq = view A's zoom
vw_zoom:
        sta tmp0
        asl
        adc tmp0
        asl
        asl                             ; 12 A
        tax
        ldy #0
-       lda ms_view,x
        sta tq,y
        inx
        iny
        cpy #4
        bne -
        rts

;---------------------------------------------------------------------------------------
; prisms: corners. The selected prism's corners have handles in the ortho views (at its
; top); one can be picked (ms_pt, while ms_ptobj = ms_sel), dragged, and have a corner
; added after it or be removed.
;---------------------------------------------------------------------------------------
; carry set if a corner of the selection is picked (txt_ptr = the object)
pt_valid:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _no
        cmp ms_ptobj
        bne _no
        tax
        jsr po_obj
        bne _no
        ldy #O_PN
        lda ms_pt
        cmp (txt_ptr),y
        bcs _no
        sec
        rts
_no:    clc
        rts

; pt_cur = the picked corner (pt_valid first: txt_ptr), from the pool; pt_store puts it
; back. A = its place in the pool, for both.
pt_load:
        jsr pt_place
        jmp pool_get_b
pt_store:
        jsr pt_place
        jmp pool_put_b
pt_place:
        lda #<pt_cur
        sta px_b0
        lda #>pt_cur
        sta px_b0+1
        ldy #O_PFIRST
        lda (txt_ptr),y
        clc
        adc ms_pt
        ldx #1
        rts

; the prism at op (object X): wcur = its world transform, ci_hh = half its height, wp_n =
; its corners, pt_buf = them
pp_setup:
        txa
        jsr wm_ptr
        ldy #47
-       lda (pa),y
        sta wcur,y
        dey
        bpl -
        ldy #O_P
        ldx #0
-       lda (op),y
        sta ci_hh,x
        iny
        inx
        cpx #4
        bne -
        ldq ci_hh
        #ASRQ_Q
        stq ci_hh
        ldy #O_TYPE                     ; pp_lathe: 1 for a lathe
        lda (op),y
        sec
        sbc #OT_PRISM
        sta pp_lathe
        ldy #O_PN
        lda (op),y
        sta wp_n
        tax
        ldy #O_PFIRST
        lda (op),y
        jmp pool_get

; corner A of pt_buf -> sg_a / sg_b (x and z; y untouched)
pt_get_a:
        asl
        asl
        asl
        tax
        ldy #0
-       lda pt_buf,x
        sta sg_a,y
        lda pt_buf+4,x
        sta sg_a+8,y
        inx
        iny
        cpy #4
        bne -
        rts
pt_get_b:
        asl
        asl
        asl
        tax
        ldy #0
-       lda pt_buf,x
        sta sg_b,y
        lda pt_buf+4,x
        sta sg_b+8,y
        inx
        iny
        cpy #4
        bne -
        rts
; pk_w = corner A in the world: a prism's at its top (y = ci_hh), a lathe's (radius,
; height) at (r, h, 0)
pt_world:
        jsr pt_get_a
        lda pp_lathe
        beq +
        #MOVQ sg_a+8, sg_a+4
        #MOVQ q_zero, sg_a+8
        bra ++
+       #MOVQ ci_hh, sg_a+4
+
        lda #$ff                        ; (all three coordinates)
        sta xf_skip
        #VMOV sg_a, xf_in
        jsr xf_point
        #VMOV xf_out, pk_w
        rts

; a click near a corner of the selected prism (not in the camera view): pick it and drag
; it. Carry set if so.
pt_pick:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _no
        lda ms_dview
        cmp #3
        beq _no
        ldx ms_sel
        lda hid_flag,x                  ; (hidden: no handles to pick)
        bne _no
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_TYPE
        lda (op),y
        cmp #OT_PRISM
        beq +
        cmp #OT_LATHE
        bne _no
+       jsr pp_setup
        lda #$ff
        sta pk_best
        lda #6                          ; (within 5 pixels)
        sta pk_bd
        lda #0
        sta wp_k
-       lda wp_k
        jsr pt_world
        lda wp_k
        sta pk_i
        jsr pk_try
        inc wp_k
        lda wp_k
        cmp wp_n
        bne -
        lda pk_best
        cmp #$ff
        beq _no
        sta ms_pt
        lda ms_sel
        sta ms_ptobj
        lda #1
        sta ms_dpt
        lda ms_dview
        sta ms_drag
        lda ev_x
        sta ms_dx
        lda ev_x+1
        sta ms_dx+1
        lda ev_y
        sta ms_dy
        lda #<st_corner
        ldx #>st_corner
        sta ms_msg
        stx ms_msg+1
        sec
        rts
_no:    clc
        rts
st_corner:      .null "A corner: drag it. I adds one after it, DEL removes it"

; drag the picked corner by (dr_a across, dr_b up) in view ms_drag: the move in the world,
; taken into the prism's own x and z (its transform is a rotation times a scale, so
; along column j of A the move is (col_j . v) / (col_j . col_j))
pt_drag:
        #VMOV q_z3, dl_v
        ldx ms_drag
        lda vw_ha,x
        asl
        asl
        tax
        ldy #0
-       lda dr_a,y
        sta dl_v,x
        inx
        iny
        cpy #4
        bne -
        ldx ms_drag
        lda vw_va,x
        asl
        asl
        tax
        ldy #0
-       lda dr_b,y
        sta dl_v,x
        inx
        iny
        cpy #4
        bne -
        lda ms_sel
        jsr wm_ptr
        ldy #47
-       lda (pa),y
        sta wcur,y
        dey
        bpl -
        lda #8                          ; a prism's second number is along z, a lathe's
        sta tmp2                        ; along y
        ldx ms_sel
        jsr po_obj
        cmp #OT_LATHE
        bne +
        lda #4
        sta tmp2
+       .for si in [(0, lr_x), (2, lr_y)]
        .if si[0] == 0
        #MOVQ wcur, mm_c
        #MOVQ wcur+12, mm_c+4
        #MOVQ wcur+24, mm_c+8
        .else
        ldx tmp2                        ; column tmp2 / 4 of A
        ldy #0
-       lda wcur,x
        sta mm_c,y
        lda wcur+12,x
        sta mm_c+4,y
        lda wcur+24,x
        sta mm_c+8,y
        inx
        iny
        cpy #4
        bne -
        .endif
        #DOT mm_c, dl_v, tq
        #DOT mm_c, mm_c, tv3m
        #BNEZ tv3m, +
        rts
+       #FDIV tq, tv3m, si[1]
        .next
        jsr pt_valid
        bcc _r
        jsr pt_load
        #ADDQ pt_cur, lr_x, pt_cur
        #ADDQ pt_cur+4, lr_y, pt_cur+4
        jsr pt_store
        lda ev_x
        sta ms_dx
        lda ev_x+1
        sta ms_dx+1
        lda ev_y
        sta ms_dy
        jsr draw_views
        #FAR OVL_PANEL, draw_props
        rts
_r:     rts

; I: a corner after the picked one, half way along the edge to the next
pt_insert:
        jsr u_save                      ; (txt_ptr: pt_valid's, untouched by it)
        ldy #O_PN                       ; (txt_ptr = the object, from pt_valid)
        lda (txt_ptr),y
        sta wp_n
        cmp #DOC_MAXPTS
        bcc +
        lda #<st_pmax
        ldx #>st_pmax
        jmp say
+       tax                             ; all its corners
        ldy #O_PFIRST
        lda (txt_ptr),y
        sta wp_k
        jsr pool_get
        lda ms_pt                       ; this one and the next (mod n): their middle
        jsr pt_get_a
        ldx ms_pt
        inx
        cpx wp_n
        bne +
        ldx #0
+       txa
        jsr pt_get_b
        #ADDQ sg_a, sg_b, tq
        #ASRQ_Q
        stq pt_cur
        #ADDQ sg_a+8, sg_b+8, tq
        #ASRQ_Q
        stq pt_cur+4
        clc                             ; room at first + ms_pt + 1
        lda wp_k
        adc ms_pt
        inc a
        ldx #1
        jsr pool_open
        bcc +
        lda #<st_pfull
        ldx #>st_pfull
        jmp say
+       jsr pt_valid                    ; (txt_ptr again)
        ldy #O_PN
        lda wp_n
        inc a
        sta (txt_ptr),y
        inc ms_pt
        jsr pt_store
        jmp redraw_work
st_pmax:        .null "A prism has 16 corners at most"
st_pmin:        .null "A prism needs 3 corners at least"
st_pfull:       .null "No room for more corners (255 in all)"

; DEL: the picked corner goes
pt_delete:
        jsr u_save
        ldy #O_PN
        lda (txt_ptr),y
        sta wp_n
        cmp #4
        bcs +
        lda #<st_pmin
        ldx #>st_pmin
        jmp say
+       ldy #O_PFIRST
        lda (txt_ptr),y
        clc
        adc ms_pt
        ldx #1
        jsr pool_close
        ldx ms_sel
        jsr po_obj
        ldy #O_PN
        lda wp_n
        dec a
        sta (txt_ptr),y
        cmp ms_pt                       ; it was the last: the one before it now
        bne +
        dec ms_pt
+       jmp redraw_work

        .include "model2.asm"
        .include "model3.asm"
        .include "model4.asm"
