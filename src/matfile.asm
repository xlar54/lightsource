;=======================================================================================
; matfile.asm - overlay 5: materials as files of their own (NAME.MAT), a library to share
; between documents. A .MAT file is "R65T", a version byte (1), then the material's 80-byte
; record (doc.asm DM_*), 85 bytes in all.
;
;   mat_save    Material, Save to file...: the material being edited (ms_sel $c0+), or the
;               selected object's, to NAME.MAT (the name asked, the material's to start)
;   mat_load    Material, Load from file...: the disk's .MAT files listed (the Open dialog);
;               the one picked is added to the document, and the selected object takes it
;               (with nothing selected, it is shown for editing)
; Both return A/Y = a message for the status line.
;=======================================================================================

MT_VERSION      = 1
MT_HDR          = 5
MT_SIZE         = MT_HDR + DMAT_SIZE

mat_save:
        jsr mat_which
        bcc +
        lda #<st_mwhich
        ldy #>st_mwhich
        rts
+       stx mt_i
        lda dmat_lo,x                   ; the prompt starts with its name
        sta txt_ptr
        lda dmat_hi,x
        sta txt_ptr+1
        ldy #DM_NAME
-       lda (txt_ptr),y
        sta ge_buf,y
        beq +
        iny
        cpy #11
        bne -
        lda #0
        sta ge_buf,y
+       lda #<st_msave
        ldx #>st_msave
        jsr gui_edit
        bcs mt_cancel
        jsr mt_name
        beq mt_cancel
        ldx mt_i                        ; the file's bytes: the tag, then the record
        lda dmat_lo,x
        sta txt_ptr
        lda dmat_hi,x
        sta txt_ptr+1
        ldy #0
-       lda mt_tag,y
        sta mt_buf,y
        iny
        cpy #MT_HDR
        bne -
        ldy #0
-       lda (txt_ptr),y
        sta mt_buf + MT_HDR,y
        iny
        cpy #DMAT_SIZE
        bne -
        lda #<ext_mat
        ldx #>ext_mat
        jsr wr_open_w
        bcs mt_fail
        lda #0
        sta mt_k
-       ldy mt_k
        lda mt_buf,y
        jsr wr_put
        inc mt_k
        lda mt_k
        cmp #MT_SIZE
        bne -
        jsr wr_close
        bcs mt_fail2
        lda #<st_msaved
        ldy #>st_msaved
        rts
mt_cancel:
        lda #<dc_cancel
        ldy #>dc_cancel
        rts
mt_fail:
        jsr kst_status
        sta wr_err
mt_fail2:
        ldz #0
        lda wr_err
        jsr dc_status_msg
        lda #<dc_msg
        ldy #>dc_msg
        rts

mat_load:
        lda doc_nmat
        cmp #DOC_MAXMAT
        bcc +
        lda #<st_mtfull
        ldy #>st_mtfull
        rts
+       lda #<mt_fname                  ; the Open dialog, for .MAT files (the name
        sta wr_nm                       ; picked goes to mt_fname)
        lda #>mt_fname
        sta wr_nm+1
        lda #<ext_mat
        sta dl_ext
        lda #>ext_mat
        sta dl_ext+1
        lda #<st_mtitle
        sta dl_title
        lda #>st_mtitle
        sta dl_title+1
        lda #<st_mdlg
        sta dl_stat
        lda #>st_mdlg
        sta dl_stat+1
        jsr open_dialog
        bcs mt_fail2
        cmp #2
        beq mt_cancel
        cmp #1
        bne _read
        lda #0                          ; Name...: typed
        sta ge_buf
        lda #<st_mname
        ldx #>st_mname
        jsr gui_edit
        bcs mt_cancel
        jsr mt_name
        beq mt_cancel
_read:
        lda #<ext_mat
        ldx #>ext_mat
        jsr wr_open_r
        bcs mt_fail
        lda #0
        sta mt_k
_blk:   jsr kst_read
        ldx #0
_b:     cpx kst_count
        beq _got
        lda KS_BUF,x
        ldy mt_k                        ; (no more than one byte past a material)
        cpy #MT_SIZE + 1
        bcs +
        sta mt_buf,y
        inc mt_k
+       inx
        bra _b
_got:   lda kst_st
        and #$40
        bne _done
        lda kst_count
        bne _blk
_done:  jsr kst_close
        ldz #0
        lda mt_k                        ; exactly a material, starting with the tag
        cmp #MT_SIZE
        bne _bad
        ldy #MT_HDR - 1
-       lda mt_buf,y
        cmp mt_tag,y
        bne _bad
        dey
        bpl -
        ldx doc_nmat                    ; added as material n (O_MAT n + 1)
        inc doc_nmat
        stx mt_i
        lda dmat_lo,x
        sta txt_ptr
        lda dmat_hi,x
        sta txt_ptr+1
        ldy #0
-       lda mt_buf + MT_HDR,y
        sta (txt_ptr),y
        iny
        cpy #DMAT_SIZE
        bne -
        lda ms_sel                      ; the selected object takes it
        cmp #DOC_MAXOBJ
        bcs _show
        tax
        lda obj_lo,x
        sta txt_ptr
        lda obj_hi,x
        sta txt_ptr+1
        ldx mt_i
        inx
        txa
        ldy #O_MAT
        sta (txt_ptr),y
        bra _ok
_show:  lda mt_i                        ; nothing selected: the material, to edit
        ora #$c0
        sta ms_sel
_ok:    lda #<dc_matloaded
        ldy #>dc_matloaded
        rts
_bad:   lda #<st_mbad
        ldy #>st_mbad
        rts

; X = the material to save: the one being edited, or the selected object's own. Carry set:
; none (nothing selected, a light, the camera, or an object without a material of its own)
mat_which:
        lda ms_sel
        cmp #$ff
        beq _no
        cmp #$c0
        bcc +
        and #$3f
        tax
        cpx doc_nmat
        bcs _no
        clc
        rts
+       cmp #DOC_MAXOBJ
        bcs _no
        tax
        lda obj_lo,x
        sta txt_ptr
        lda obj_hi,x
        sta txt_ptr+1
        ldy #O_MAT
        lda (txt_ptr),y
        beq _no
        tax
        dex
        clc
        rts
_no:    sec
        rts

; ge_buf -> mt_fname in capitals (12 characters at most), and wr_nm points at it. Z set if
; it's empty.
mt_name:
        lda #<mt_fname
        sta wr_nm
        lda #>mt_fname
        sta wr_nm+1
        ldx #0
-       lda ge_buf,x
        beq +
        cmp #'a'
        bcc _p
        cmp #'z' + 1
        bcs _p
        and #$df
_p:     sta mt_fname,x
        inx
        cpx #12
        bne -
+       lda #0
        sta mt_fname,x
        cpx #0
        rts

;---------------------------------------------------------------------------------------
; ed_doc: the material editor's preview scene, made over the document (parked in attic
; by modes.asm ed_trace): a checker floor, a ball wearing material ed_n (copied from the
; parked document), a light and a dim fill light, a blue-grey background
;---------------------------------------------------------------------------------------
ED_HDR          = doc_objs - doc_start
ed_doc:
        jsr doc_default                 ; (all of it zero, and the usual header)
        #DT_COPY ed_hdr, doc_start, ED_HDR
        #DT_COPY ed_objs, doc_objs, ed_objs_end - ed_objs
        #DT_COPY ed_mats, doc_mats, DMAT_SIZE
        #DT_COPY ed_lights, doc_lights, ed_lights_end - ed_lights
        ldx ed_n                        ; the material: from the parked document
        sec
        lda dmat_lo,x
        sbc #<doc_start
        sta tmp0
        lda dmat_hi,x
        sbc #>doc_start
        sta tmp0+1
        clc
        lda tmp0
        adc #<DOC_PARK
        sta dmaj_src
        lda tmp0+1
        adc #>DOC_PARK
        sta dmaj_src+1
        lda #(DOC_PARK >> 16) & $0f
        sta dmaj_src_bank
        lda #DOC_PARK >> 20
        sta dmaj_src_mb
        lda #<(doc_mats + DMAT_SIZE)
        sta dmaj_dst
        lda #>(doc_mats + DMAT_SIZE)
        sta dmaj_dst+1
        lda #0
        sta dmaj_dst_bank
        sta dmaj_dst_mb
        lda #<DMAT_SIZE
        sta xc_n
        lda #0
        sta xc_n+1
        jmp xcopy
        .cerror ((DOC_PARK & $ffff) + DOC_SIZE) > $10000, "ed_doc: the parked document crosses a bank"

ed_hdr:
        .text "R65M"
        .byte DOC_VERSION, 2, 2, 2      ; version, objects, materials, lights
        .dint FXV((0, 1.5, -5.2)), FXV((0, 0.9, 0)), FX(50)
        .dint FXV((0.32, 0.42, 0.58))
        .byte 4
        .cerror * - ed_hdr != ED_HDR, "the preview's header"
ed_objs:
        #DOBJ OT_PLANE, 0, 1, "Floor", (0, 0, 0), (0, 0, 0), 1
        #DOBJ OT_SPHERE, 0, 2, "Ball", (0, 1, 0), (0, 0, 0), 1, 1
ed_objs_end:
ed_mats:
        #DMATR "Floor", (0.85, 0.85, 0.85), (0.22, 0.22, 0.28), 1, 1, 40, 0.15, 0.7, 0, 0, 0, 1
ed_lights:
        #DLIT (-6, 8, -7), (1, 1, 1), 0
        #DLIT (6, 4, -5), (0.3, 0.3, 0.35), 1
ed_lights_end:

mt_tag:         .text "R65T"
                .byte MT_VERSION
ext_mat:        .null ".MAT"
st_mwhich:      .null "Select an object with a material, or Material, Edit, first"
st_msave:       .null "Save the material as (NAME.MAT): "
st_msaved:      .null "Saved the material"
st_mtfull:       .null "No room for more materials (16)"
st_mtitle:      .null "Materials"
st_mdlg:        .null "Load a material: click one, or the cursor keys and RETURN. ESC cancels"
st_mname:       .null "Material file name: "
st_mbad:        .null "That file isn't a material"
mt_fname:       .fill 13
mt_buf:         .fill MT_SIZE + 1
mt_i:           .byte 0
mt_k:           .byte 0
