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
        .byte 0
        .byte 0


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
