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
        .byte CMD_CAMFRONT
        .null "Camera front"
        .byte CMD_CAMTOP
        .null "Camera top"
        .byte CMD_CAMSIDE
        .null "Camera side"
        .byte 0
        .byte 0

;---------------------------------------------------------------------------------------
; the camera (View menu): aim it at the selection; put it on a view's axis, looking at the
; selection (or where it looked), as far from that as it is; turn it round where it looks
; by dragging in the camera view
;---------------------------------------------------------------------------------------
; A = CMD_AIM .. CMD_CAMSIDE
cam_cmd:
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
        jmp draw_props
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
+       lda ca_k
        ora #$c0
        sta ms_sel
        lda #<st_matedit
        ldx #>st_matedit
        jmp say
_full:  lda #<st_mfull
        ldx #>st_mfull
        jmp say
st_newmat:      .null "New ?"
st_mfull:       .null "No room for more materials (16)"
st_matedit:     .null "Editing the material: select an object to go back"

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
        ora #$c0
        sta ms_sel
        lda #<st_matedit
        ldx #>st_matedit
        jmp say
_none:  lda #<st_nomat
        ldx #>st_nomat
        jmp say
_r:     rts
st_nomat:       .null "It has no material: Material, Next gives it one"
