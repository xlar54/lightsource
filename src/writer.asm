;=======================================================================================
; writer.asm - overlay 5: the document as scene text (POV-Ray), and files.
;
;   write_pov      the document -> TEXT_BUF (zero-terminated): what Render parses, and what
;                  Export saves
;   export_pov     write_pov, then TEXT_BUF to NAME.POV. Carry set: wr_err = the drive's
;                  status
;   doc_save       the document to NAME.MDL (a SEQ file: doc_start .. doc_end)
;   doc_load       NAME.MDL back (checked: its first bytes and its size)
; NAME is ms_name. Keep this overlay below $C000: the DOS may use $C000-$C3FF.
;=======================================================================================

wp              = ptr0                  ; where the text goes next (bank 1)

write_pov:
        lda #<TEXT_BUF
        sta wp
        lda #>TEXT_BUF
        sta wp+1
        lda #`TEXT_BUF
        sta wp+2
        lda #0
        sta wp+3
        #WS ws_head
        #WSA ms_name
        jsr w_nl
        ; global settings, background, camera
        #WS ws_global
        lda doc_maxtrace
        jsr w_int
        #WS ws_close_nl
        #WS ws_bg
        lda #<doc_bg
        ldx #>doc_bg
        jsr w_vec
        #WS ws_close_nl
        #WS ws_cam1
        lda #<doc_cam_loc
        ldx #>doc_cam_loc
        jsr w_vec
        #WS ws_cam2
        lda #<doc_cam_look
        ldx #>doc_cam_look
        jsr w_vec
        #WS ws_cam3
        lda #<doc_cam_angle
        ldx #>doc_cam_angle
        jsr w_num
        #WS ws_cam4
        ; lights
        lda #0
        sta wr_i
_light:
        lda wr_i
        cmp doc_nlight
        beq _mats
        tax
        lda dlight_lo,x
        sta wr_p
        lda dlight_hi,x
        sta wr_p+1
        #WS ws_light1
        lda wr_p
        ldx wr_p+1
        jsr w_vec
        #WS ws_light2
        clc
        lda wr_p
        adc #DL_COL
        tay
        lda wr_p+1
        adc #0
        tax
        tya
        jsr w_vec
        lda wr_p
        sta txt_ptr
        lda wr_p+1
        sta txt_ptr+1
        ldy #DL_FLAGS
        lda (txt_ptr),y
        and #1
        beq +
        #WS ws_shadowless
+       #WS ws_close_nl
        inc wr_i
        bra _light
_mats:  ; each material as a declared texture, M1 ... M16
        lda #0
        sta wr_i
_mat:
        lda wr_i
        cmp doc_nmat
        bne +
        jmp _objs
+       tax
        lda dmat_lo,x
        sta wr_p
        lda dmat_hi,x
        sta wr_p+1
        #WS ws_c
        lda wr_p                        ; "// name"
        ldx wr_p+1
        jsr w_str
        jsr w_nl
        #WS ws_decl
        lda wr_i
        jsr w_mname
        #WS ws_tex
        ldy #DM_FLAGS
        jsr wr_byte
        and #1
        beq _plain
        #WS ws_checker
        lda #DM_COL
        jsr w_col
        #WS ws_comma
        lda #DM_COL2
        jsr w_col
        #WS ws_scale
        lda #DM_CSCALE
        jsr w_field
        bra _fin
_plain:
        lda #DM_COL
        jsr w_col
_fin:
        #WS ws_finish
        #WS ws_amb
        lda #DM_AMB
        jsr w_field
        #WS ws_dif
        lda #DM_DIFF
        jsr w_field
        #WS ws_pho
        lda #DM_PHONG
        jsr w_field
        #WS ws_psz
        ldy #DM_PSIZE
        jsr wr_byte
        sta wr_w
        iny
        jsr wr_byte
        sta wr_w+1
        jsr w_word
        #WS ws_ref
        lda #DM_REFL
        jsr w_field
        #WS ws_texend
        inc wr_i
        jmp _mat
_objs:
        ; objects: the outline, with a stack of open groups
        lda #0
        sta wr_i
        sta wr_gn
wr_obj:
        lda wr_i
        cmp doc_nobj
        bne +
        jmp wr_closeall
+       tax
        jsr wr_obj_ptr
        ldy #O_DEPTH
        lda (wo),y
        sta wr_d
        jsr close_groups                ; those that end before this one
        ldx wr_i
        jsr wr_obj_ptr
        #WS ws_c                        ; "// name"
        jsr w_indent
        clc
        lda wo
        adc #O_NAME
        tay
        lda wo+1
        adc #0
        tax
        tya
        jsr w_str
        jsr w_nl
        jsr w_indent
        ldy #O_TYPE
        lda (wo),y
        cmp #OT_GROUP
        bcc _prim
        ; a group: open it, unless it has nothing in it
        ldx wr_i
        inx
        cpx doc_nobj
        bcs _empty
        txa
        tax
        jsr wr_obj_ptr2
        ldy #O_DEPTH
        lda (wo2),y
        cmp wr_d
        beq _empty
        bcc _empty
        ldy #O_TYPE
        lda (wo),y
        sec
        sbc #OT_GROUP
        asl
        tax
        lda ws_groups,x
        pha
        lda ws_groups+1,x
        tax
        pla
        jsr w_str
        jsr w_nl
        ldx wr_gn                       ; push it
        lda wr_i
        sta wr_gs,x
        inc wr_gn
        bra wr_next
_empty:
        #WS ws_emptygroup
        bra wr_next
_prim:
        asl
        tax
        jmp (_p,x)
_p:     .word wp_sphere, wp_box, wp_cyl, wp_cone, wp_plane, wp_prism
wp_done:
        jsr w_mods
        #WS ws_close_nl
wr_next:
        inc wr_i
        jmp wr_obj
wr_closeall:
        lda #0
        sta wr_d
        jsr close_groups
        lda #0                          ; the end
        ldz #0
        sta [wp],z
        rts

wp_sphere:
        #WS ws_sphere
        lda #O_P
        jsr w_ofield
        jmp wp_done
wp_box:
        #WS ws_box                      ; box { <-x/2, -y/2, -z/2>, <x/2, y/2, z/2>
        lda #'<'
        jsr w_chr
        lda #$ff
        jsr _halves
        #WS ws_vcomma
        lda #0
        jsr _halves
        lda #'>'
        jsr w_chr
        jmp wp_done
_halves:
        sta wr_sign
        lda #0
        sta wr_k
-       lda wr_k
        asl
        asl
        clc
        adc #O_P
        tay
        jsr w_half
        inc wr_k
        lda wr_k
        cmp #3
        beq +
        #WS ws_comma
        bra -
+       rts
wp_cyl:
        #WS ws_cyl1                     ; cylinder { <0, -h/2, 0>, <0, h/2, 0>, r
        lda #$ff
        sta wr_sign
        ldy #O_P+4
        jsr w_half
        #WS ws_cyl2
        lda #0
        sta wr_sign
        ldy #O_P+4
        jsr w_half
        #WS ws_cyl3
        lda #O_P
        jsr w_ofield
        jmp wp_done
wp_cone:
        #WS ws_cyl1x                    ; cone { <0, -h/2, 0>, r1, <0, h/2, 0>, r2
        lda #$ff
        sta wr_sign
        ldy #O_P+8
        jsr w_half
        #WS ws_cone2
        lda #O_P
        jsr w_ofield
        #WS ws_cone3
        lda #0
        sta wr_sign
        ldy #O_P+8
        jsr w_half
        #WS ws_cyl3
        lda #O_P+4
        jsr w_ofield
        jmp wp_done
wp_plane:
        #WS ws_plane
        jmp wp_done
wp_prism:
        #WS ws_prism                    ; prism { -h/2, h/2, n + 1, <x, z>, ... <x0, z0>
        lda #$ff                        ; (closed: the first point again, as POV-Ray
        sta wr_sign                     ;  wants)
        ldy #O_P
        jsr w_half
        #WS ws_comma
        lda #0
        sta wr_sign
        ldy #O_P
        jsr w_half
        #WS ws_comma
        ldy #O_PN
        lda (wo),y
        sta wr_k
        inc a
        jsr w_int
        ldy #O_PFIRST                   ; its corners, from the pool
        lda (wo),y
        ldx wr_k
        jsr pool_get
        lda #<pt_buf
        sta wr_p
        lda #>pt_buf
        sta wr_p+1
        lda #0
        sta wr_m
-       #WS ws_comma
        jsr _pt
        inc wr_m
        lda wr_m
        cmp wr_k
        bne -
        lda #0
        sta wr_m
        #WS ws_comma
        jsr _pt
        jmp wp_done
_pt:    ; <x, z> of corner wr_m
        lda #'<'
        jsr w_chr
        lda wr_m
        asl
        asl
        asl
        clc
        adc wr_p
        sta wr_v
        lda wr_p+1
        adc #0
        sta wr_v+1
        lda wr_v
        ldx wr_v+1
        jsr w_num
        #WS ws_comma
        clc
        lda wr_v
        adc #4
        pha
        lda wr_v+1
        adc #0
        tax
        pla
        jsr w_num
        lda #'>'
        jmp w_chr

; close open groups whose depth >= wr_d
close_groups:
        lda wr_gn
        beq _r
        ldx wr_gn
        lda wr_gs-1,x
        tax
        jsr wr_obj_ptr
        ldy #O_DEPTH
        lda (wo),y
        cmp wr_d
        bcc _r
        dec wr_gn
        lda wr_d                        ; (w_mods / w_indent use the group's depth)
        pha
        ldy #O_DEPTH
        lda (wo),y
        sta wr_d
        jsr w_indent
        jsr w_mods
        #WS ws_close_nl
        pla
        sta wr_d
        bra close_groups
_r:     rts

; the modifiers of the object at wo: texture, interior, scale, rotate, translate, no_shadow
w_mods:
        ldy #O_MAT
        lda (wo),y
        beq _xf
        sta wr_m
        #WS ws_texuse
        ldx wr_m
        dex
        txa
        jsr w_mname
        #WS ws_texuse2
        ldx wr_m                        ; an index of refraction other than 1
        dex
        lda dmat_lo,x
        sta txt_ptr
        lda dmat_hi,x
        sta txt_ptr+1
        ldy #DM_IOR
        lda (txt_ptr),y
        bne _ior
        iny
        lda (txt_ptr),y
        bne _ior
        iny
        lda (txt_ptr),y
        cmp #1
        bne _ior
        iny
        lda (txt_ptr),y
        beq _xf
_ior:
        clc                             ; (its address first: w_str uses txt_ptr)
        lda txt_ptr
        adc #DM_IOR
        sta wr_v
        lda txt_ptr+1
        adc #0
        sta wr_v+1
        #WS ws_ior
        lda wr_v
        ldx wr_v+1
        jsr w_num
        #WS ws_iorend
_xf:
        ldy #O_SCALE                    ; scale, if not 1
        lda (wo),y
        bne _s
        iny
        lda (wo),y
        bne _s
        iny
        lda (wo),y
        cmp #1
        bne _s
        iny
        lda (wo),y
        beq _r
_s:
        #WS ws_xscale
        lda #O_SCALE
        jsr w_ofield
_r:
        lda #O_ROT                      ; rotate, if any
        jsr wr_nonzero
        beq +
        #WS ws_xrot
        lda #O_ROT
        jsr w_ovec
+       lda #O_POS                      ; translate, if anywhere
        jsr wr_nonzero
        beq +
        #WS ws_xtrans
        lda #O_POS
        jsr w_ovec
+       ldy #O_FLAGS
        lda (wo),y
        and #1
        beq +
        #WS ws_noshadow
+       rts

; Z clear if the vector at wo + A isn't zero
wr_nonzero:
        tay
        ldx #12
        lda #0
-       ora (wo),y
        iny
        dex
        bne -
        cmp #0
        rts

;---------------------------------------------------------------------------------------
; text out
;---------------------------------------------------------------------------------------
WS .macro str
        lda #<\str
        ldx #>\str
        jsr w_str
.endmacro
WSA .macro addr
        lda #<\addr
        ldx #>\addr
        jsr w_str
.endmacro

w_chr:
        ldz #0
        sta [wp],z
        inw wp
        rts
w_str:
        sta txt_ptr
        stx txt_ptr+1
        ldy #0
-       lda (txt_ptr),y
        beq +
        phy
        jsr w_chr
        ply
        iny
        bne -
+       rts
w_nl:
        lda #$0a
        jmp w_chr
; two spaces per depth (wr_d)
w_indent:
        ldx wr_d
        beq +
-       lda #' '
        jsr w_chr
        lda #' '
        jsr w_chr
        dex
        bne -
+       rts
; "M" + A + 1
w_mname:
        clc
        adc #1
        sta gf_v+2
        lda #'M'
        jsr w_chr
        lda #0
        sta gf_v
        sta gf_v+1
        sta gf_v+3
        lda #0
        jsr gui_fmt
        #WSA gf_str
        rts
; the 16.16 number at A/X: 4 decimals, no trailing zeros
w_num:
        sta txt_ptr
        stx txt_ptr+1
        ldy #3
-       lda (txt_ptr),y
        sta gf_v,y
        dey
        bpl -
w_gfv:
        lda #$84
        jsr gui_fmt
        #WSA gf_str
        rts
; A = a whole number (byte)
w_int:
        sta gf_v+2
        lda #0
        sta gf_v
        sta gf_v+1
        sta gf_v+3
        jmp w_gfv
; wr_w = a whole number (word)
w_word:
        lda wr_w
        sta gf_v+2
        lda wr_w+1
        sta gf_v+3
        lda #0
        sta gf_v
        sta gf_v+1
        jmp w_gfv
; <x, y, z> from A/X
w_vec:
        sta wr_v
        stx wr_v+1
        lda #'<'
        jsr w_chr
        ldx #0
-       phx
        clc
        txa
        adc wr_v
        pha
        lda wr_v+1
        adc #0
        tax
        pla
        jsr w_num
        plx
        inx
        inx
        inx
        inx
        cpx #12
        beq +
        phx
        #WS ws_comma
        plx
        bra -
+       lda #'>'
        jmp w_chr
; the number / vector at wo + A
w_ofield:
        clc
        adc wo
        pha
        lda wo+1
        adc #0
        tax
        pla
        jmp w_num
w_ovec:
        clc
        adc wo
        pha
        lda wo+1
        adc #0
        tax
        pla
        jmp w_vec
; the number at wr_p + A (a material's)
w_field:
        clc
        adc wr_p
        pha
        lda wr_p+1
        adc #0
        tax
        pla
        jmp w_num
; "color rgb <colour at wr_p + A> transmit t" (transmit only if not 0)
w_col:
        pha
        #WS ws_rgb
        pla
        clc
        adc wr_p
        pha
        lda wr_p+1
        adc #0
        tax
        pla
        jsr w_vec
        lda wr_p
        sta txt_ptr
        lda wr_p+1
        sta txt_ptr+1
        ldy #DM_TRANS
        lda #0
        ldx #4
-       ora (txt_ptr),y
        iny
        dex
        bne -
        cmp #0
        beq +
        #WS ws_transmit
        lda #DM_TRANS
        jmp w_field
+       rts
; half the number at wo + Y, negated if wr_sign
w_half:
        ldx #0
-       lda (wo),y
        sta gf_v,x
        iny
        inx
        cpx #4
        bne -
        ldq gf_v
        #ASRQ_Q
        stq gf_v
        lda wr_sign
        beq +
        #NEGQ gf_v, gf_v
+       jmp w_gfv
; A = the byte at wr_p + Y
wr_byte:
        lda wr_p
        sta txt_ptr
        lda wr_p+1
        sta txt_ptr+1
        lda (txt_ptr),y
        rts
wr_obj_ptr:
        lda obj_lo,x
        sta wo
        lda obj_hi,x
        sta wo+1
        rts
wr_obj_ptr2:
        lda obj_lo,x
        sta wo2
        lda obj_hi,x
        sta wo2+1
        rts

ws_head:        .null "// renderer65 modeller: "
ws_global:      .null "global_settings { max_trace_level "
ws_close_nl:    .text " }"
                .byte $0a, 0
ws_bg:          .null "background { color rgb "
ws_cam1:        .null "camera { location "
ws_cam2:        .null " look_at "
ws_cam3:        .null " angle "
ws_cam4:        .text " right x*640/375 }"
                .byte $0a, 0
ws_light1:      .null "light_source { "
ws_light2:      .null " color rgb "
ws_shadowless:  .null " shadowless"
ws_c:           .null "// "
ws_decl:        .null "#declare "
ws_tex:         .null " = texture { pigment { "
ws_checker:     .null "checker "
ws_comma:       .null ", "
ws_vcomma:      .null ">, <"
ws_scale:       .null " scale "
ws_rgb:         .null "color rgb "
ws_transmit:    .null " transmit "
ws_finish:      .null " } finish {"
ws_amb:         .null " ambient "
ws_dif:         .null " diffuse "
ws_pho:         .null " phong "
ws_psz:         .null " phong_size "
ws_ref:         .null " reflection "
ws_texend:      .text " } }"
                .byte $0a, 0
ws_groups:      .word ws_union, ws_merge, ws_inter, ws_diff
ws_union:       .null "union {"
ws_merge:       .null "merge {"
ws_inter:       .null "intersection {"
ws_diff:        .null "difference {"
ws_emptygroup:  .text "// (an empty group: left out)"
                .byte $0a, 0
ws_sphere:      .null "sphere { <0, 0, 0>, "
ws_box:         .null "box { "
ws_cyl1:        .null "cylinder { <0, "
ws_cyl1x:       .null "cone { <0, "
ws_cyl2:        .null ", 0>, <0, "
ws_cyl3:        .null ", 0>, "
ws_cone2:       .null ", 0>, "
ws_cone3:       .null ", <0, "
ws_plane:       .null "plane { y, 0"
ws_prism:       .null "prism { "
ws_texuse:      .null " texture { "
ws_texuse2:     .null " }"
ws_ior:         .null " interior { ior "
ws_iorend:      .null " }"
ws_xscale:      .null " scale "
ws_xrot:        .null " rotate "
ws_xtrans:      .null " translate "
ws_noshadow:    .null " no_shadow"

;=======================================================================================
; files
;=======================================================================================
; kst_name = NAME + ext (A/X) + mode (wr_mode)
wr_name:
        sta wr_v
        stx wr_v+1
        ldy #0
        lda #<ms_name
        ldx #>ms_name
        jsr kst_name_put
        lda wr_v
        ldx wr_v+1
        jsr kst_name_raw
        lda wr_md
        ldx wr_md+1
        jmp kst_name_raw
; the name without the mode, for kst_remove: wr_plain (NAME + ext)
wr_plain_name:
        sta wr_v
        stx wr_v+1
        ldx #0
-       lda ms_name,x
        sta wr_plain,x
        beq +
        inx
        bra -
+       ldy #0
-       lda (wr_vp),y
        sta wr_plain,x
        beq +
        inx
        iny
        bra -
+       rts
wr_vp = txt_ptr

; open NAME + ext (A/X) for writing (replacing it): carry set if it failed
wr_open_w:
        pha
        phx
        sta txt_ptr
        stx txt_ptr+1
        jsr wr_plain_name
        lda #<wr_plain
        ldx #>wr_plain
        jsr kst_remove
        lda #<sv_mw
        sta wr_md
        lda #>sv_mw
        sta wr_md+1
        plx
        pla
        jsr wr_name
        tya
        jsr kst_open
        lda #0
        sta kst_count
        rts
wr_open_r:
        pha
        lda #<sv_mr
        sta wr_md
        lda #>sv_mr
        sta wr_md+1
        pla
        jsr wr_name
        tya
        jmp kst_open
sv_mw:          .null ",S,W"
sv_mr:          .null ",S,R"
ext_pov:        .null ".POV"
ext_mdl:        .null ".MDL"

; finish writing: flush, close, the drive's status -> carry
wr_close:
        lda kst_count
        beq +
        jsr kst_write
+       jsr kst_close
        jsr kst_status
        sta wr_err
        cmp #0
        bne +
        clc
        rts
+       sec
        rts
; A -> the file being written
wr_put:
        ldx kst_count
        sta KS_BUF,x
        inx
        stx kst_count
        cpx #255
        bne +
        phz
        jsr kst_write
        plz
        lda #0
        sta kst_count
+       rts

export_pov:
        jsr write_pov
        lda #<ext_pov
        ldx #>ext_pov
        jsr wr_open_w
        bcs _fail
        lda #<TEXT_BUF                  ; TEXT_BUF up to its zero
        sta wp
        lda #>TEXT_BUF
        sta wp+1
        lda #`TEXT_BUF
        sta wp+2
        lda #0
        sta wp+3
-       ldz #0
        lda [wp],z
        beq +
        jsr wr_put
        inw wp
        bra -
+       jmp wr_close
_fail:
        jsr kst_status
        sta wr_err
        sec
        rts

; NAME.MDL: the document's bank-0 part, then the corner pool (from bank 1)
doc_save:
        lda #<ext_mdl
        ldx #>ext_mdl
        jsr wr_open_w
        bcs _fail
        lda #<doc_start
        sta wr_v
        lda #>doc_start
        sta wr_v+1
-       lda wr_v                        ; (kstream uses txt_ptr: set it each time)
        sta txt_ptr
        lda wr_v+1
        sta txt_ptr+1
        ldy #0
        lda (txt_ptr),y
        jsr wr_put
        inc wr_v
        bne +
        inc wr_v+1
+       lda wr_v
        cmp #<doc_end
        bne -
        lda wr_v+1
        cmp #>doc_end
        bne -
        lda #<DOC_PTS                   ; (attic: a 28-bit pointer)
        sta wp
        lda #>DOC_PTS
        sta wp+1
        lda #(FAR_ADDR >> 16) & $ff
        sta wp+2
        lda #FAR_ADDR >> 24
        sta wp+3
        lda #<POOL_BYTES
        sta wr_v
        lda #>POOL_BYTES
        sta wr_v+1
-       ldz #0
        lda [wp],z
        jsr wr_put
        inw wp
        lda wr_v
        bne +
        dec wr_v+1
+       dec wr_v
        lda wr_v
        ora wr_v+1
        bne -
        jmp wr_close
_fail:
        jsr kst_status
        sta wr_err
        sec
        rts

; NAME.MDL -> TEXT_BUF, checked, then into the document. Carry set: no (wr_err = the drive's
; status, or $ff: not a document; files from before version 3 aren't read)
doc_load:
        lda #<ext_mdl
        ldx #>ext_mdl
        jsr wr_open_r
        bcc +
        jmp _fail
+       lda #<TEXT_BUF
        sta wp
        lda #>TEXT_BUF
        sta wp+1
        lda #`TEXT_BUF
        sta wp+2
        lda #0
        sta wp+3
        sta wr_n
        sta wr_n+1
_blk:
        jsr kst_read
        ldx #0
_byte:  cpx kst_count
        beq _got
        lda KS_BUF,x
        ldz #0
        sta [wp],z
        inw wp
        inc wr_n
        bne +
        inc wr_n+1
+       inx
        bra _byte
_got:   lda wr_n+1                      ; more than a document: stop
        cmp #>(MDL_SIZE + 256)
        bcs _done
        lda kst_st
        and #$40
        bne _done
        lda kst_count
        bne _blk
_done:
        jsr kst_close
        lda wr_n                        ; exactly a document
        cmp #<MDL_SIZE
        bne _bad
        lda wr_n+1
        cmp #>MDL_SIZE
        bne _bad
_size:
        lda #<TEXT_BUF                  ; starting R65M
        sta wp
        lda #>TEXT_BUF
        sta wp+1
        ldy #0
-       tya
        taz
        lda [wp],z
        cmp doc_tag,y
        bne _bad
        iny
        cpy #4
        bne -
        ldz #0
        lda #<TEXT_BUF                  ; into place (DMA from bank 1)
        sta dmaj_src
        lda #>TEXT_BUF
        sta dmaj_src+1
        lda #`TEXT_BUF
        sta dmaj_src_bank
        lda #<doc_start
        sta dmaj_dst
        lda #>doc_start
        sta dmaj_dst+1
        lda #0
        sta dmaj_dst_bank
        sta dmaj_src_mb
        sta dmaj_dst_mb
        lda #<DOC_SIZE
        sta xc_n
        lda #>DOC_SIZE
        sta xc_n+1
        jsr xcopy
        lda #<(TEXT_BUF + DOC_SIZE)     ; version 3: the pool as it is
        sta dmaj_src
        lda #>(TEXT_BUF + DOC_SIZE)
        sta dmaj_src+1
        lda #`TEXT_BUF
        sta dmaj_src_bank
        lda #<DOC_PTS
        sta dmaj_dst
        lda #>DOC_PTS
        sta dmaj_dst+1
        lda #FAR_BANK
        sta dmaj_dst_bank
        lda #FAR_MB
        sta dmaj_dst_mb
        lda #<POOL_BYTES
        sta xc_n
        lda #>POOL_BYTES
        sta xc_n+1
        jsr xcopy
_ok:
        clc
        rts
_bad:
        ldz #0
        lda #$ff
        sta wr_err
        sec
        rts
_fail:
        jsr kst_status
        sta wr_err
        sec
        rts
doc_tag:        .text "R65M"

;=======================================================================================
; the Open dialog: the disk's .MDL files in the right-hand panel. open_dialog -> A = 0 a
; file was picked (ms_name is its name), 1 type a name instead, 2 cancelled (carry set:
; the disk couldn't be read, wr_err = its status)
;=======================================================================================
DLG_MAX         = 48                    ; names kept
DLG_ROWS        = 16                    ; shown at once
DLG_Y0          = 23                    ; the first row's y
DLG_COL         = 61
DLG_BY          = 179                   ; the buttons' text row

open_dialog:
        lda #<st_reading
        ldx #>st_reading
        jsr gui_status
        jsr dir_read
        bcc +
        rts
+       lda #0
        sta dl_sel
        sta dl_top
        lda #<st_dlg
        ldx #>st_dlg
        jsr gui_status
        #GXY 480, 10, 639, 189          ; (put back when it closes)
        ldx #0
        jsr gui_save
        jsr dlg_draw
_loop:
        jsr wait_frame
        jsr gui_poll
        lda ev_type
        cmp #EV_KEY
        beq _key
        cmp #EV_DOWN
        bne _loop
        ; a click: the panel's title (scroll up), a row, "more" (scroll down), a button
        lda ev_x+1
        cmp #>480
        bcc _loop
        bne +
        lda ev_x
        cmp #<480
        bcc _loop
+       lda ev_y
        cmp #DLG_BY - 3
        bcc _rows
        lda ev_x+1                      ; the buttons: Name... (x < 560), Cancel
        cmp #>560
        bcc _type
        bne _cancel
        lda ev_x
        cmp #<560
        bcc _type
        bra _cancel
_rows:  sec
        sbc #DLG_Y0 - 1
        bcs _row
        lda dl_top                      ; above the rows: a page up
        sec
        sbc #DLG_ROWS - 1
        bcs +
        lda #0
+       sta dl_top
        jmp _redraw
_row:   ldx #0                          ; row = (y - y0) / 9
-       cmp #9
        bcc +
        sbc #9
        inx
        bra -
+       cpx #DLG_ROWS
        bcc +
        jsr dlg_more                    ; the "more" row: a page down
        bcc _loop
        clc
        lda dl_top
        adc #DLG_ROWS - 1
        sta dl_top
        jmp _redraw
+       txa
        clc
        adc dl_top
        cmp dl_n
        bcs _loop
        sta dl_sel
        bra _pick
_key:
        lda ev_key
        cmp #K_ESC
        beq _cancel
        cmp #K_STOP
        beq _cancel
        cmp #K_RETURN
        bne +
        lda dl_n
        beq _loop
        bra _pick
+       cmp #K_UP
        bne +
        lda dl_sel
        beq _loop
        dec dl_sel
        bra _moved
+       cmp #K_DOWN
        bne _loop
        ldx dl_sel
        inx
        cpx dl_n
        bcs _loop
        stx dl_sel
_moved: lda dl_sel                      ; keep it in view
        cmp dl_top
        bcs +
        sta dl_top
+       sec
        sbc #DLG_ROWS - 1
        bcc _redraw
        beq _redraw
        cmp dl_top
        bcc _redraw
        sta dl_top
_redraw:
        jsr dlg_draw
        jmp _loop
_type:  lda #1
        bra dlg_close
_cancel:
        lda #2
        bra dlg_close
_pick:  ldx dl_sel                      ; its name
        lda dl_lo,x
        sta txt_ptr
        lda dl_hi,x
        sta txt_ptr+1
        ldy #0
-       lda (txt_ptr),y
        sta ms_name,y
        beq +
        iny
        bra -
+       lda #0
; the panel as it was; A = the answer
dlg_close:
        pha
        ldx #0
        jsr gui_restore
        pla
        clc
        rts

; carry set if there are names below the rows shown
dlg_more:
        clc
        lda dl_top
        adc #DLG_ROWS
        cmp dl_n
        bcs +
        sec
        rts
+       clc
        rts

dlg_draw:
        jsr d6_clip_all
        #GXY 480, 10, 639, 189
        lda #GC_PANEL
        jsr gui_fill
        #GTEXT DLG_COL, 12, GC_YELLOW, $ff, st_open
        lda dl_top
        beq +
        #GTEXT 73, 12, GC_LIGHT, $ff, st_up
+       lda dl_n
        bne +
        #GTEXT DLG_COL, DLG_Y0, GC_LIGHT, $ff, st_nodocs
+       lda #0
        sta dg_r
_r:     clc
        lda dg_r
        adc dl_top
        sta dl_i
        cmp dl_n
        bcs _rows_done
        lda dg_r                        ; y = y0 + 9 r
        asl
        asl
        asl
        clc
        adc dg_r
        adc #DLG_Y0
        sta dg_y
        lda dl_i
        cmp dl_sel
        bne +
        lda dg_y
        sec
        sbc #1
        sta d6_y
        clc
        adc #8
        sta d6_y1
        lda #0
        sta d6_y+1
        sta d6_y1+1
        lda #<480
        sta d6_x
        lda #>480
        sta d6_x+1
        lda #<639
        sta d6_x1
        lda #>639
        sta d6_x1+1
        lda #GC_SEL
        jsr gui_fill
+       lda #DLG_COL
        sta d6_tc
        lda dg_y
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_WHITE
        sta d6_col
        lda #$ff
        sta d6_bg
        ldx dl_i
        lda dl_lo,x
        pha
        lda dl_hi,x
        tax
        pla
        jsr d6_text
        inc dg_r
        lda dg_r
        cmp #DLG_ROWS
        bne _r
_rows_done:
        jsr dlg_more
        bcc +
        #GTEXT DLG_COL, DLG_Y0 + 9 * DLG_ROWS, GC_LIGHT, $ff, st_down
+       ; the buttons
        #GXY 484, DLG_BY - 2, 555, DLG_BY + 8
        lda #GC_FRAME
        sta d6_col
        jsr d6_frame
        #GXY 564, DLG_BY - 2, 635, DLG_BY + 8
        jsr d6_frame
        #GTEXT DLG_COL + 1, DLG_BY, GC_WHITE, $ff, st_bname
        #GTEXT 71 + 1, DLG_BY, GC_WHITE, $ff, st_bcancel
        rts

; dir_read: the directory ("$", read as a program) -> dl_n names of SEQ ... .MDL files,
; without the .MDL. Carry set: no disk (wr_err = the status)
dir_read:
        lda #0
        sta dl_n
        sta dl_line
        sta kst_sa                      ; (secondary address 0: the listing)
        ldy #0
        lda #<st_dollar
        ldx #>st_dollar
        jsr kst_name_raw
        tya
        jsr kst_open
        lda #2
        sta kst_sa
        bcc +
        jsr kst_status
        sta wr_err
        sec
        rts
+       jsr kst_rewind
        jsr kst_getc                    ; the load address
        jsr kst_getc
_line:
        jsr kst_getc                    ; the link: 0 at the end
        bcs _end
        sta dl_t
        jsr kst_getc
        bcs _end
        ora dl_t
        beq _end
        jsr kst_getc                    ; the blocks
        jsr kst_getc
        lda #0
        sta dl_q                        ; 0 before the name, 1 in it, 2 after
        sta dl_len
_ch:
        jsr kst_getc
        bcs _end
        cmp #0
        beq _eol
        cmp #'"'
        bne +
        inc dl_q
        bra _ch
+       ldx dl_q
        cpx #1
        bne _ch
        ldx dl_len
        cpx #16
        bcs _ch
        cmp #$c1                        ; the DOS's a-z ($C1-$DA) as ASCII
        bcc +
        cmp #$db
        bcs +
        sec
        sbc #$60
+       sta dl_tmp,x
        inc dl_len
        bra _ch
_eol:
        inc dl_line
        lda dl_line
        cmp #1
        beq _line                       ; (the first line is the disk's name)
        lda dl_q
        cmp #2
        bne _line
        lda dl_len                      ; NAME.MDL?
        cmp #5
        bcc _line
        tax
        ldy #3
-       dex
        lda dl_tmp,x
        cmp ext_mdl,y
        bne _line
        dey
        bpl -
        lda dl_n
        cmp #DLG_MAX
        bcs _line
        tay                             ; keep it, without the .MDL (at most 12)
        lda dl_lo,y
        sta txt_ptr
        lda dl_hi,y
        sta txt_ptr+1
        sec
        lda dl_len
        sbc #4
        sta dl_len
        ldy #0
-       cpy dl_len
        beq +
        lda dl_tmp,y
        sta (txt_ptr),y
        iny
        cpy #12
        bne -
+       lda #0
        sta (txt_ptr),y
        inc dl_n
        jmp _line
_end:
        jsr kst_close
        clc
        rts

st_dollar:      .null "$"
st_reading:     .null "Reading the disk..."
st_dlg:         .null "Open: click a document, or the cursor keys and RETURN. ESC cancels"
st_open:        .null "Open"
st_up:          .null "^ more"
st_down:        .null "v more"
st_nodocs:      .null "(no documents)"
st_bname:       .null "Name..."
st_bcancel:     .null "Cancel"
dl_lo:          .byte <(dl_names + range(DLG_MAX) * 13)
dl_hi:          .byte >(dl_names + range(DLG_MAX) * 13)
dl_names:       .fill DLG_MAX * 13
dl_tmp:         .fill 16
dl_n:           .byte 0
dl_sel:         .byte 0
dl_top:         .byte 0
dg_r:           .byte 0
dl_i:           .byte 0
dg_y:           .byte 0
dl_t:           .byte 0
dl_q:           .byte 0
dl_len:         .byte 0
dl_line:        .byte 0

wr_err:         .byte 0
wr_i:           .byte 0
wr_k:           .byte 0
wr_d:           .byte 0
wr_m:           .byte 0
wr_gn:          .byte 0
wr_gs:          .fill 16
wr_sign:        .byte 0
wr_p:           .word 0
wr_v:           .word 0
wr_w:           .word 0
wr_n:           .word 0
wr_md:          .word 0
wr_plain:       .fill 24
wo              = pb                    ; object records (base page)
wo2             = pd
        .cerror * > $c000, "the writer overlay must stay below $C000"
