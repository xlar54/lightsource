;=======================================================================================
; modelres.asm - modeller parts that live in the resident part, to keep overlay 4 small:
; the menu table and the material commands. They only run while overlay 4 is in (they
; use its variables and routines: say, redraw_work, op, ca_k, cd_dir).
;=======================================================================================

gui_menus:
        .byte 1
        .null "File"
        .byte CMD_NEW
        .null "New"
        .byte CMD_OPEN
        .null "Open..."
        .byte CMD_SAVE
        .null "Save"
        .byte CMD_SAVEAS
        .null "Save as..."
        .byte CMD_EXPORT
        .null "Export POV"
        .byte CMD_PREVIEW
        .null "Preview   P"
        .byte CMD_RENDER
        .null "Render    R"
        .byte CMD_EXIT
        .null "Exit"
        .byte 0
        .byte 7
        .null "Edit"
        .byte CMD_UNDO
        .null "Undo        U"
        .byte CMD_REDO
        .null "Redo        Y"
        .byte CMD_DELETE
        .null "Delete  DEL"
        .byte CMD_DUP
        .null "Duplicate"
        .byte 0
        .byte 13
        .null "Scene"
        .byte CMD_UP
        .null "Move up"
        .byte CMD_DOWN
        .null "Move down"
        .byte CMD_INDENT
        .null "Indent"
        .byte CMD_OUTDENT
        .null "Outdent"
        .byte CMD_WORLD
        .null "World..."
        .byte 0
        .byte 20
        .null "Add"
        .byte CMD_ADD + OT_SPHERE
        .null "Sphere"
        .byte CMD_ADD + OT_BOX
        .null "Box"
        .byte CMD_ADD + OT_CYL
        .null "Cylinder"
        .byte CMD_ADD + OT_CONE
        .null "Cone"
        .byte CMD_ADD + OT_PLANE
        .null "Plane"
        .byte CMD_ADD + OT_PRISM
        .null "Prism"
        .byte CMD_ADD + OT_LATHE
        .null "Lathe"
        .byte CMD_ADDLIGHT
        .null "Light"
        .byte CMD_ADDSPOT
        .null "Spotlight"
        .byte CMD_ADD + OT_UNION
        .null "Union"
        .byte CMD_ADD + OT_MERGE
        .null "Merge"
        .byte CMD_ADD + OT_INTER
        .null "Intersection"
        .byte CMD_ADD + OT_DIFF
        .null "Difference"
        .byte 0
        .byte 25
        .null "Material"
        .byte CMD_MATNEXT
        .null "Next"
        .byte CMD_MATPREV
        .null "Previous"
        .byte CMD_MATNEW
        .null "New (a copy)"
        .byte CMD_MATEDIT
        .null "Edit"
        .byte CMD_MATSAVE
        .null "Save to file..."
        .byte CMD_MATLOAD
        .null "Load from file..."
        .byte 0
        .byte 35
        .null "View"
        .byte CMD_ZOOMIN
        .null "Zoom in     +"
        .byte CMD_ZOOMOUT
        .null "Zoom out    -"
        .byte CMD_LOCATE
        .null "Locate      L"
        .byte CMD_VRESET
        .null "Reset"
        .byte CMD_AIM
        .null "Aim camera  A"
        .byte CMD_AIMLIGHT
        .null "Aim light..."
        .byte CMD_CAMFRONT
        .null "Camera front"
        .byte CMD_CAMTOP
        .null "Camera top"
        .byte CMD_CAMSIDE
        .null "Camera side"
        .byte CMD_SNAP
        .null "Snap        G"
        .byte CMD_GRID
        .null "Grid"
        .byte 0
        .byte 41
        .null "Help"
        .byte CMD_ABOUT
        .null "About..."
        .byte 0
        .byte 0

;---------------------------------------------------------------------------------------
; the camera (View menu): aim it at the selection; put it on a view's axis, looking at the
; selection (or where it looked), as far from that as it is; turn it round where it looks
; by dragging in the camera view
;---------------------------------------------------------------------------------------
; A = CMD_AIM .. CMD_GRID
cam_cmd:
        cmp #CMD_GRID
        bne _notgrid
        lda ms_grid                     ; Grid: on or off
        eor #1
        sta ms_grid
        beq _gridoff
        lda #<st_gridon
        ldx #>st_gridon
        jmp say
_gridoff:
        lda #<st_gridoff
        ldx #>st_gridoff
        jmp say
_notgrid:
        cmp #CMD_SNAP
        bne _notsnap
        lda ms_snap                     ; Snap: on or off
        eor #1
        sta ms_snap
        beq _snapoff
        lda #<st_snapon
        ldx #>st_snapon
        jmp say
_snapoff:
        lda #<st_snapoff
        ldx #>st_snapoff
        jmp say
_notsnap:
        cmp #CMD_AIM
        bne _place
        lda ms_sel                      ; aim: look at the selection's place in the world
        cmp #$80
        beq _noaim
        jsr sel_world
        bcc _noaim
        #VMOV pk_w, doc_cam_look
        lda #<st_aimed
        ldx #>st_aimed
        jmp say
_noaim: lda #<st_noaim
        ldx #>st_noaim
        jmp say
_place:
        sec                             ; its direction from where it looks: front, top, side
        sbc #CMD_CAMFRONT
        sta co_k
        lda ms_sel                      ; (looking at the selection, if there is one)
        cmp #$80
        beq +
        jsr sel_world
        bcc +
        #VMOV pk_w, doc_cam_look
+       lda co_k
        asl
        adc co_k
        asl
        asl
        tax
        ldy #0
-       lda cam_dirs,x
        sta co_u,y
        inx
        iny
        cpy #12
        bne -
        #VSUB doc_cam_loc, doc_cam_look, co_v   ; its distance (10 if none)
        #DOT co_v, co_v, tq
        jsr fsqrt
        stq co_r
        #BNEZ co_r, +
        #LDIMM FX(10), co_r
+       .for si = 0, si < 3, si += 1
        #FMUL co_u+si*4, co_r, tq
        #ADDQ doc_cam_look+si*4, tq, doc_cam_loc+si*4
        .next
        lda #<st_placed
        ldx #>st_placed
        jmp say
; front: from -z; top: from above (tipped a little towards -z: a camera can't look straight
; along its sky, y); side: from +x, so that z goes to the right as in the side view
cam_dirs:       .dint 0, 0, -ONE,   0, ONE, -ONE / 16,   ONE, 0, 0
st_snapon:      .null "Snap on: 0.5 units, 15 degrees, sizes in quarters"
st_snapoff:     .null "Snap off"
st_gridon:      .null "Grid on"
st_gridoff:     .null "Grid off"
st_aimed:       .null "The camera looks at the selection"
st_noaim:       .null "Select an object or a light to aim the camera at"
st_placed:      .null "Camera placed: drag in the camera view to turn it round"

; a press on nothing in the camera view: turning starts (from the camera as it is)
cam_orbit_start:
        #VSUB doc_cam_loc, doc_cam_look, co_v
        #DOT co_v, co_v, tq             ; the closest it may come to the vertical: |v| / 16
        jsr fsqrt
        #LSRQ_Q
        #LSRQ_Q
        #LSRQ_Q
        #LSRQ_Q
        stq co_hmin
        lda ev_x
        sta co_x
        lda ev_x+1
        sta co_x+1
        lda ev_y
        sta co_y
        lda #1
        sta ms_orbit
        rts

; the pointer moved: v turned by (x0 - x) degrees round the vertical, then by (y - y0)
; degrees up or down (it stops short of straight above or below)
cam_orbit_move:
        lda dr_moved                    ; its first move: undo can go back to before it
        bne +
        inc dr_moved
        jsr u_save
+       sec                             ; yaw (the scene turns with the pointer: the camera
        lda co_x                        ; goes the other way)
        sbc ev_x
        sta co_a+2
        lda co_x+1
        sbc ev_x+1
        sta co_a+3
        lda #0
        sta co_a
        sta co_a+1
        jsr co_cs
        ; x' = x c - z s, z' = x s + z c
        #FMUL co_v, co_c, tq
        #FMUL co_v+8, co_s, co_t
        #SUBQ tq, co_t, co_w
        #FMUL co_v, co_s, tq
        #FMUL co_v+8, co_c, co_t
        #ADDQ tq, co_t, co_w+8
        #MOVQ co_v+4, co_w+4
        ; pitch, in the plane of the vertical and (x', z'): h = |(x', z')|
        #FMUL co_w, co_w, tq
        #FMUL co_w+8, co_w+8, co_t
        #ADDQ tq, co_t, tq
        jsr fsqrt
        stq co_h
        #BLEQ co_h, co_hmin, _set       ; (already at the top or bottom: only round)
        sec                             ; pitch: down the screen, the camera rises
        lda ev_y
        sbc co_y
        sta co_a+2
        lda #0
        sbc #0
        sta co_a+3
        lda #0
        sta co_a
        sta co_a+1
        jsr co_cs
        #FMUL co_h, co_c, tq            ; h' = h c - y s, y' = h s + y c
        #FMUL co_w+4, co_s, co_t
        #SUBQ tq, co_t, co_u
        #BLEQ co_u, co_hmin, _keep      ; too near the vertical: it stays where it got to
        #FMUL co_h, co_s, tq
        #FMUL co_w+4, co_c, co_t
        #ADDQ tq, co_t, co_w+4
        #FDIV co_u, co_h, co_k4         ; x', z' scaled by h' / h
        #FMUL co_w, co_k4, co_w
        #FMUL co_w+8, co_k4, co_w+8
_set:
        .for si = 0, si < 3, si += 1
        #ADDQ doc_cam_look+si*4, co_w+si*4, doc_cam_loc+si*4
        .next
        jsr draw_views
        #FAR OVL_PANEL, draw_props
        rts
_keep:  rts
; co_c, co_s = cos, sin of co_a degrees
co_cs:
        #MOVQ co_a, fs_a
        jsr fcos_deg
        stq co_c
        #MOVQ co_a, fs_a
        jsr fsin_deg
        stq co_s
        rts

co_k:           .byte 0
co_x:           .word 0                 ; where the drag started
co_y:           .byte 0
co_v:           .fill 12                ; the camera from where it looks, as the drag began
co_w:           .fill 12                ; turned
co_u:           .fill 12
co_r:           .dword 0
co_h:           .dword 0
co_hmin:        .dword 0
co_a:           .dword 0
co_c:           .dword 0
co_s:           .dword 0
co_t:           .dword 0
co_k4:          .dword 0

; Material: next / previous (A = 1 / $ff) for the selected object
cmd_mat:
        sta cd_dir
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _r
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_MAT
        clc
        lda (op),y
        adc cd_dir
        bpl +
        lda doc_nmat                    ; below none: the last
+       cmp doc_nmat
        beq +
        bcc +
        lda #0
+       sta (op),y
        jmp redraw_work
_r:     rts

; Material: New - a copy of the selected object's (or the first), given to it
cmd_matnew:
        lda doc_nmat
        cmp #DOC_MAXMAT
        bcs _full
        sta ca_k
        inc doc_nmat
        ldx #0
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs +
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_MAT
        lda (op),y
        beq +
        tax
        dex
+       lda dmat_lo,x                   ; copy material X to the new one
        sta pa
        lda dmat_hi,x
        sta pa+1
        ldx ca_k
        lda dmat_lo,x
        sta lp
        lda dmat_hi,x
        sta lp+1
        ldy #DMAT_SIZE - 1
-       lda (pa),y
        sta (lp),y
        dey
        bpl -
        ldy #DM_NAME                    ; named "New N"
        ldx #0
-       lda st_newmat,x
        sta (lp),y
        beq +
        iny
        inx
        bra -
+       lda ca_k
        clc
        adc #'1'
        dey
        sta (lp),y
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs +
        ldy #O_MAT
        lda ca_k
        clc
        adc #1
        sta (op),y
+       lda ca_k                        ; the editor, for the new one (its undo is kept)
        jmp ed_open
_full:  lda #<st_mfull
        ldx #>st_mfull
        jmp say
st_newmat:      .null "New ?"
st_mfull:       .null "No room for more materials (16)"

; Material: Edit - the selected object's material in the properties panel
cmd_matedit:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _r
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_MAT
        lda (op),y
        beq _none
        sec
        sbc #1
        pha                             ; (an undo step for what the editor changes)
        jsr u_save
        pla
        jmp ed_open
_none:  lda #<st_nomat
        ldx #>st_nomat
        jmp say
_r:     rts
st_nomat:       .null "It has no material: Material, Next gives it one"

;---------------------------------------------------------------------------------------
; dragging the selection in an ortho view (model_drag; a prism's corner is pt_drag):
;   - it moves in the view's plane; inside a group the move is taken into the group's own
;     axes (its transform is a rotation times a scale: along column j of the parent's A
;     the move is (col_j . v) / (col_j . col_j))
;   - with SHIFT (an object) it turns about the axis the view looks along: top RY, front
;     RZ, side RX, a degree a pixel
;   - with CTRL (an object) its scale S changes, by 1/64 of itself a pixel
; Everything is worked out from where the drag began, so View, Snap can catch it: 0.5
; units, 15 degrees, sizes in quarters. The keys are read at every move: pressing or
; letting go of SHIFT or CTRL part way changes the mode from where things are then.
;---------------------------------------------------------------------------------------
MODKEYS         = $D611                 ; bits 0, 1 shift, 2 CTRL
dbg_mod:        .byte 0                 ; (tests: OR'd into MODKEYS)

drag_obj:
        lda dr_moved
        bne +
        inc dr_moved                    ; its first move: undo
        jsr u_save
        lda #$ff                        ; (no mode yet)
        sta dg_mode
+       jsr sel_pos_ptr
        bcs +
        rts
+       lda #0                          ; the mode the keys ask for now: 0 move, 1 turn,
        sta dg_k                        ; 2 size (objects only)
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _mode
        lda MODKEYS
        ora dbg_mod
        tax
        and #%011
        beq +
        inc dg_k
        bra _mode
+       txa
        and #%100
        beq _mode
        lda #2
        sta dg_k
_mode:  lda dg_k                        ; a new mode (or the first): it starts from here,
        cmp dg_mode                     ; the object as it is now
        beq _go
        ldx dg_mode
        sta dg_mode
        inx
        beq +                           ; (the first: from where the button went down)
        lda ev_x
        sta ms_dx
        lda ev_x+1
        sta ms_dx+1
        lda ev_y
        sta ms_dy
+       ldy #11
-       lda (lp),y
        sta dg_p0,y
        dey
        bpl -
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _go
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_ROT + 15                 ; its rotation and scale
-       lda (op),y
        sta dg_r0 - O_ROT,y
        dey
        cpy #O_ROT - 1
        bne -
_go:
        sec                             ; the pointer from where this mode began: dx, dy (up)
        lda ev_x
        sbc ms_dx
        sta dg_dx
        lda ev_x+1
        sbc ms_dx+1
        sta dg_dx+1
        sec
        lda ms_dy
        sbc ev_y
        sta dg_dy
        lda #0
        sbc #0
        sta dg_dy+1
        lda dg_mode
        cmp #1
        bne +
        jmp _turn
+       bcc _move
        jmp _size

_move:
        lda dg_dx                       ; d across = dx / zoom, d up = dy / (zoom * 8/15)
        sta dg_a+2
        lda dg_dx+1
        sta dg_a+3
        lda dg_dy
        sta dg_b+2
        lda dg_dy+1
        sta dg_b+3
        lda #0
        sta dg_a
        sta dg_a+1
        sta dg_b
        sta dg_b+1
        lda ms_drag
        jsr vw_zoom                     ; tq = zoom
        #FDIV dg_a, tq, dg_a
        #FMUL tq, q_aspect, dg_t
        #FDIV dg_b, dg_t, dg_b
        ldx #11                         ; the move in the world
        lda #0
-       sta dg_v,x
        dex
        bpl -
        ldx ms_drag
        lda vw_ha,x
        asl
        asl
        tax
        ldy #0
-       lda dg_a,y
        sta dg_v,x
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
-       lda dg_b,y
        sta dg_v,x
        inx
        iny
        cpy #4
        bne -
        jsr dg_parent                   ; inside a group: in its axes
        ldy #0                          ; position = start + move (each part that moves
_part:                                  ; snapped)
        tya
        tax
        clc
        .for si = 0, si < 4, si += 1
        lda dg_p0+si,x
        adc dg_v+si,x
        sta dg_t+si
        .next
        lda dg_v,x
        ora dg_v+1,x
        ora dg_v+2,x
        ora dg_v+3,x
        beq +
        lda ms_snap
        beq +
        clc                             ; to the nearest 0.5: + 0.25, then the bits below
        lda dg_t+1                      ; 0.5 cleared
        adc #$40
        lda dg_t+2
        adc #0
        sta dg_t+2
        lda dg_t+3
        adc #0
        sta dg_t+3
        lda dg_t+1
        clc
        adc #$40
        and #$80
        sta dg_t+1
        lda #0
        sta dg_t
+       .for si = 0, si < 4, si += 1
        lda dg_t+si
        sta (lp),y
        iny
        .next
        cpy #12
        bne _part
        jmp _show

_turn:  ; the angle about the view's axis: start + dx degrees
        ldx ms_drag
        lda dg_axis,x
        asl
        asl
        sta dg_k
        tax
        clc
        lda dg_r0+2,x
        adc dg_dx
        sta dg_t+2
        lda dg_r0+3,x
        adc dg_dx+1
        sta dg_t+3
        lda dg_r0,x
        sta dg_t
        lda dg_r0+1,x
        sta dg_t+1
        lda ms_snap
        beq +
        jsr dg_snap15
+       lda ms_sel
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        clc
        lda dg_k
        adc #O_ROT
        tay
        ldx #0
-       lda dg_t,x
        sta (op),y
        iny
        inx
        cpx #4
        bne -
        jmp _show

_size:  ; S = start * (1 + dx / 64), at least 1/16 of it
        lda dg_dx                       ; dx / 64 in 16.16 = dx << 10
        asl
        sta dg_t+1
        lda dg_dx+1
        rol
        sta dg_t+2
        lda dg_dx+1                     ; (the sign into the top byte)
        and #$80
        beq +
        lda #$ff
+       sta dg_t+3
        lda #0
        sta dg_t
        asl dg_t+1
        rol dg_t+2
        rol dg_t+3
        clc
        lda dg_t+2
        adc #1                          ; + 1.0
        sta dg_t+2
        lda dg_t+3
        adc #0
        sta dg_t+3
        #BGTQ dg_t, q_sixteenth, +
        #MOVQ q_sixteenth, dg_t
+       #FMUL dg_s0, dg_t, dg_t
        lda ms_snap
        beq _sput
        clc                             ; to the nearest quarter, a quarter at least
        lda dg_t+1
        adc #$20
        and #$c0
        sta dg_t+1
        lda dg_t+2
        adc #0
        sta dg_t+2
        lda dg_t+3
        adc #0
        sta dg_t+3
        lda #0
        sta dg_t
        #BGTQ dg_t, q_quarter, _sput
        #MOVQ q_quarter, dg_t
_sput:  #BGTQ dg_t, q_minscale, +       ; (never 0)
        #MOVQ q_minscale, dg_t
+       ldx ms_sel
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_SCALE
        ldx #0
-       lda dg_t,x
        sta (op),y
        iny
        inx
        cpx #4
        bne -
_show:
        jsr draw_views
        #FAR OVL_PANEL, draw_props
        rts

; inside a group: dg_v (a move in the world) into the parent's axes. (wm is from the click:
; the parent doesn't move while its child is dragged)
dg_parent:
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs _r
        tax
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        beq _r
        sta dg_k
        dec dg_k                        ; the parent: the nearest one before it a level up
        ldx ms_sel
-       dex
        bmi _r
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        lda (op),y
        cmp dg_k
        bne -
        txa
        jsr wm_ptr                      ; pa = its world transform (rows of A, t)
        ldy #35
-       lda (pa),y
        sta dg_m,y
        dey
        bpl -
        lda #0                          ; dg_w[j] = (col_j . v) / (col_j . col_j)
        sta dg_j                        ; (j * 4)
_col:
        ldx dg_j
        ldy #0
-       lda dg_m,x
        sta dg_c,y
        lda dg_m+12,x
        sta dg_c+4,y
        lda dg_m+24,x
        sta dg_c+8,y
        inx
        iny
        cpy #4
        bne -
        #DOT dg_c, dg_v, tq
        #DOT dg_c, dg_c, dg_t
        #MOVQ q_zero, dg_a
        #BEQZ dg_t, +
        #FDIV tq, dg_t, dg_a
+       ldx dg_j
        ldy #0
-       lda dg_a,y
        sta dg_w,x
        inx
        iny
        cpy #4
        bne -
        lda dg_j
        clc
        adc #4
        sta dg_j
        cmp #12
        bne _col
        #VMOV dg_w, dg_v
_r:     rts

; dg_t (16.16 degrees) to the nearest 15
dg_snap15:
        lda dg_t+1                      ; whole degrees, rounded, + 3600 (positive)
        asl
        lda dg_t+2
        adc #<3600
        sta tmp0
        lda dg_t+3
        adc #>3600
        sta tmp1
        clc                             ; + 7, then whole fifteens
        lda tmp0
        adc #7
        sta tmp0
        bcc +
        inc tmp1
+       lda #<(-3600)                   ; count them up from -3600
        sta dg_t+2
        lda #>(-3600)
        sta dg_t+3
_count: lda tmp1
        bne +
        lda tmp0
        cmp #15
        bcc _counted
+       sec
        lda tmp0
        sbc #15
        sta tmp0
        bcs +
        dec tmp1
+       clc
        lda dg_t+2
        adc #15
        sta dg_t+2
        bcc _count
        inc dg_t+3
        bra _count
_counted:
        lda #0
        sta dg_t
        sta dg_t+1
        rts

dg_axis:        .byte 1, 2, 0           ; the angle each view turns: RY, RZ, RX
q_sixteenth:    .dint ONE / 16
q_quarter:      .dint ONE / 4
q_minscale:     .dint ONE / 64
dg_mode:        .byte 0
dg_k:           .byte 0
dg_j:           .byte 0
dg_dx:          .word 0
dg_dy:          .word 0
dg_p0:          .fill 12                ; at the start: its position
dg_r0:          .fill 12                ;  rotation
dg_s0:          .dword 0                ;  and scale (O_ROT, O_SCALE: together)
        .cerror O_SCALE != O_ROT + 12, "drag_obj copies the rotation and scale together"
dg_a:           .dword 0
dg_b:           .dword 0
dg_t:           .dword 0
dg_v:           .fill 12
dg_w:           .fill 12
dg_c:           .fill 12
dg_m:           .fill 36
