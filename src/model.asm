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
LIST_COL        = 60
LIST_Y0         = 12
LIST_ROWS       = 11
PROP_Y0         = 120
PROP_ROWS       = 8
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
        jsr doc_default
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
; per ortho view: zoom (pixels a unit), the world point at its centre (across, up)
vw_default:     .dint FX(5), FX(0), FX(16), FX(5), FX(0), FX(0), FX(5), FX(16), FX(0)

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
+       rts
_down:
        lda ev_y
        cmp #10
        bcs +
        jsr gui_menu                    ; the menu bar
        pha
        jsr redraw_all
        pla
        jmp model_cmd
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
+       jmp prop_click
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
+       cmp #K_DEL
        bne +
        lda #CMD_DELETE
        jmp model_cmd
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
+       rts

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
        jmp redraw_all
+       lda ms_dview
        sta ms_maxview
        jmp redraw_all
_pick:
        jsr world_all                   ; every object's place
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
        jsr obj_origin                  ; pk_w = its origin, in the world
        jsr pk_try
        inc pk_i
        bra _obj
_lights:
        lda #0
        sta pk_j
-       lda pk_j
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
        sta pk_w,x
        iny
        inx
        cpx #12
        bne -
        lda pk_j
        ora #$40
        sta pk_i
        jsr pk_try
        inc pk_j
        bra --
_cam:
        #VMOV doc_cam_loc, pk_w
        lda #$80
        sta pk_i
        jsr pk_try
        lda pk_best
        cmp #$ff
        beq +
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
+       jmp redraw_all

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
        lda ms_drag
        cmp #$ff
        bne +
        rts
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
        ldx ms_drag
        lda vw_ha,x
        asl
        asl
        tay
        jsr _add_a
        ldx ms_drag
        lda vw_va,x
        asl
        asl
        tay
        jsr _add_b
        lda ev_x
        sta ms_dx
        lda ev_x+1
        sta ms_dx+1
        lda ev_y
        sta ms_dy
        jsr draw_views
        jmp draw_props
_add_a: ; the position's part at Y += dr_a (unrolled: a compare would break the carry)
        clc
        .for si = 0, si < 4, si += 1
        lda (lp),y
        adc dr_a+si
        sta (lp),y
        iny
        .next
        rts
_add_b:
        clc
        .for si = 0, si < 4, si += 1
        lda (lp),y
        adc dr_b+si
        sta (lp),y
        iny
        .next
        rts
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
        sec
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

        .include "model2.asm"
        .include "model3.asm"
