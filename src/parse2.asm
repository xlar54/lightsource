;=======================================================================================
; parse2.asm - the scene parser, continued (included by parse.asm): primitives,
; transforms, textures, and the final compile (frames, bounds, camera).
;=======================================================================================

;---------------------------------------------------------------------------------------
; a primitive: its definition into PW_PARAMS, a new record (identity transforms, no
; material yet), and its program byte. The keyword is ob_kw at this level, already read.
;   sphere   c @0, r @12          box      a @0, b @12
;   cylinder a @0, b @12, r @24   cone     a @0, ra @12, b @16, rb @28
;   plane    n @0, d @12
;---------------------------------------------------------------------------------------
primitive:
        lda sc_nprim
        cmp #MAX_PRIM
        bcc +
        #PERR E_PRIMS
+       tax
        lda par_lo,x
        sta pa
        lda par_hi,x
        sta pa+1
        txa
        asl
        tax
        lda pr_line                     ; its line (the keyword's)
        sta PW_LINES,x
        lda pr_line+1
        sta PW_LINES+1,x
        ldx ob_d
        lda ob_kw-1,x
        sec
        sbc #KW_SPHERE
        sta pr_type
        jsr vector                      ; every primitive starts with a vector
        ldy #0
        jsr par_put12
        #EXPECT ','
        lda pr_type
        cmp #T_BOX
        beq _box
        cmp #T_CYL
        beq _cyl
        cmp #T_CONE
        beq _cone
        jsr number                      ; sphere r, plane d
        ldy #12
        jsr par_put4
        bra _done
_box:
        jsr vector
        ldy #12
        jsr par_put12
        bra _done
_cyl:
        jsr vector
        ldy #12
        jsr par_put12
        #EXPECT ','
        jsr number
        ldy #24
        jsr par_put4
        bra _done
_cone:
        jsr number
        ldy #12
        jsr par_put4
        #EXPECT ','
        jsr vector
        ldy #16
        jsr par_put12
        #EXPECT ','
        jsr number
        ldy #28
        jsr par_put4
_done:
        #ISKW KW_OPEN
        bne +
        #PERR E_OPEN
+       ldx sc_nprim
        jsr prim_ptr_x
        ldy #0
        lda pr_type
        sta (lp),y
        iny
        lda #0
        sta (lp),y
        iny
        lda #$ff                        ; no material yet
        sta (lp),y
        iny
        lda #0
        sta (lp),y
        ldy #P_C                        ; M (A, t) at P_C while parsing; texture at P_TEXA
        jsr put_ident
        ldy #P_TEXA
        jsr put_ident
        lda sc_nprim
        inc sc_nprim
        jmp emit
par_lo:         .byte <(PW_PARAMS + range(MAX_PRIM) * 32)
par_hi:         .byte >(PW_PARAMS + range(MAX_PRIM) * 32)

; V's 3 parts / 1 part into the parameters at (pa) + Y
par_put12:
        ldx #0
-       lda v_c,x
        sta (pa),y
        iny
        inx
        cpx #12
        bne -
        rts
par_put4:
        ldx #0
-       lda v_c,x
        sta (pa),y
        iny
        inx
        cpx #4
        bne -
        rts

; lp = primitive X's record
prim_ptr_x:
        lda prim_lo,x
        sta lp
        lda prim_hi,x
        sta lp+1
        rts

; an identity transform (A = I, t = 0) at (lp) + Y
put_ident:
        ldx #0
-       lda x_ident,x
        sta (lp),y
        iny
        inx
        cpx #48
        bne -
        rts
x_ident:        .dint ONE, 0, 0, 0, ONE, 0, 0, 0, ONE, 0, 0, 0

;=======================================================================================
; transforms. xw = A (rows, 9 dwords) then t (3 dwords): p -> A p + t. The same layout
; everywhere: a primitive's M (at P_C while parsing), its texture matrix (P_TEXA), ninv,
; and the pigment's own (mt_ptex).
;=======================================================================================
XA = xw
XT = xw + 36

; xw <-> the 48 bytes at xp
x_load:
        ldy #47
-       lda (xp),y
        sta xw,y
        dey
        bpl -
        rts
x_store:
        ldy #47
-       lda xw,y
        sta (xp),y
        dey
        bpl -
        rts

; forward: p' = T p, applied as T M (rows)
xf_translate:                           ; t += xv
        .for xi = 0, xi < 3, xi += 1
        #ADDQ XT+xi*4, xv+xi*4, XT+xi*4
        .next
        rts
xf_scale:                               ; row i and t_i times s_i
        .for xi = 0, xi < 3, xi += 1
        .for xj = 0, xj < 3, xj += 1
        #FMUL XA+xi*12+xj*4, xv+xi*4, XA+xi*12+xj*4
        .next
        #FMUL XT+xi*4, xv+xi*4, XT+xi*4
        .next
        rts
; inverse: X T^-1 (columns)
xi_translate:                           ; t -= A v
        .for xi = 0, xi < 3, xi += 1
        #DOT XA+xi*12, xv, tq
        #SUBQ XT+xi*4, tq, XT+xi*4
        .next
        rts
xi_scale:                               ; column j times 1 / s_j
        .for xi = 0, xi < 3, xi += 1
        .for xj = 0, xj < 3, xj += 1
        #FMUL XA+xi*12+xj*4, xinv+xj*4, XA+xi*12+xj*4
        .next
        .next
        rts
; rotation about axis xax by (xc, xs): rows a, b of [A | t] (forward) or columns a, b of A
; (inverse)
xf_rotate:
        ldx xax
        lda rot_a,x
        sta xr_a
        lda rot_b,x
        sta xr_b
        lda #0
        sta xr_j
-       lda xr_a                        ; A[a][j], A[b][j]
        jsr _el
        sta xr_u
        lda xr_b
        jsr _el
        sta xr_v
        jsr rot_pair
        inc xr_j
        lda xr_j
        cmp #3
        bne -
        lda xr_a                        ; t[a], t[b]
        asl
        asl
        clc
        adc #36
        sta xr_u
        lda xr_b
        asl
        asl
        clc
        adc #36
        sta xr_v
        jmp rot_pair
_el:    ; A = 12 row + 4 xr_j
        sta tmp0
        asl
        clc
        adc tmp0                        ; 3 row
        asl
        asl
        sta tmp0
        lda xr_j
        asl
        asl
        clc
        adc tmp0
        rts
xi_rotate:
        ldx xax
        lda rot_a,x
        sta xr_a
        lda rot_b,x
        sta xr_b
        lda #0
        sta xr_j                        ; (the row, here)
-       lda xr_j
        sta tmp0
        asl
        clc
        adc tmp0
        asl
        asl
        sta tmp1                        ; 12 i
        lda xr_a
        asl
        asl
        clc
        adc tmp1
        sta xr_u
        lda xr_b
        asl
        asl
        clc
        adc tmp1
        sta xr_v
        jsr rot_pair
        inc xr_j
        lda xr_j
        cmp #3
        bne -
        rts
rot_a:          .byte 1, 0, 0
rot_b:          .byte 2, 2, 1
rot_minus:      .byte 1, 0, 1           ; x and z: u' = c u - s v; y: u' = c u + s v

; the pair at xw + xr_u, xw + xr_v
rot_pair:
        ldx xr_u
        ldy #0
-       lda xw,x
        sta ru,y
        inx
        iny
        cpy #4
        bne -
        ldx xr_v
        ldy #0
-       lda xw,x
        sta rv,y
        inx
        iny
        cpy #4
        bne -
        ldx xax
        lda rot_minus,x
        beq _plus
        #FMUL xc, ru, tq                ; u' = c u - s v ; v' = s u + c v
        #FMUL xs, rv, tv3
        #SUBQ tq, tv3, ru2
        #FMUL xs, ru, tq
        #FMUL xc, rv, tv3
        #ADDQ tq, tv3, rv2
        bra _put
_plus:
        #FMUL xc, ru, tq                ; u' = c u + s v ; v' = c v - s u
        #FMUL xs, rv, tv3
        #ADDQ tq, tv3, ru2
        #FMUL xc, rv, tq
        #FMUL xs, ru, tv3
        #SUBQ tq, tv3, rv2
_put:
        ldx xr_u
        ldy #0
-       lda ru2,y
        sta xw,x
        inx
        iny
        cpy #4
        bne -
        ldx xr_v
        ldy #0
-       lda rv2,y
        sta xw,x
        inx
        iny
        cpy #4
        bne -
        rts

; the forward / inverse operation xop (0 translate, 1 scale, 2 rotate) on xw
x_fwd:
        lda xop
        bne +
        jmp xf_translate
+       cmp #1
        bne +
        jmp xf_scale
+       jmp xf_rotate
x_inv:
        lda xop
        bne +
        jmp xi_translate
+       cmp #1
        bne +
        jmp xi_scale
+       jmp xi_rotate

; xop on every primitive of this object (and its texture, once it has one), and on ninv
range_op:
        ldx ob_d
        lda ob_p0-1,x
        sta ro_i
_p:
        lda ro_i
        cmp sc_nprim
        beq _ninv
        tax
        jsr prim_ptr_x
        clc
        lda lp
        adc #P_C
        sta xp
        lda lp+1
        adc #0
        sta xp+1
        jsr x_load
        jsr x_fwd
        jsr x_store
        ldx ro_i
        jsr prim_ptr_x
        ldy #P_MAT
        lda (lp),y
        cmp #$ff
        beq +
        clc
        lda lp
        adc #P_TEXA
        sta xp
        lda lp+1
        adc #0
        sta xp+1
        jsr x_load
        jsr x_inv
        jsr x_store
+       inc ro_i
        bra _p
_ninv:
        lda #<ninv
        sta xp
        lda #>ninv
        sta xp+1
        jsr x_load
        jsr x_inv
        jmp x_store

; read `translate v`, `scale v` or `rotate v` (the keyword is the token) and run each step
; through the routine at (ro_fn): range_op for objects, ptex_op for pigments
transform:
        lda tk_kw
        pha
        jsr next_tok
        jsr vector
        ldx #11
-       lda v_c,x
        sta xv,x
        dex
        bpl -
        pla
        cmp #KW_TRANSLATE
        bne +
        lda #0
        sta xop
        jmp (ro_fn)
+       cmp #KW_SCALE
        beq +
        jmp _rot
+       .for xi = 0, xi < 3, xi += 1
        #BEQZ xv+xi*4, _zero
        #LDIMM ONE, tq
        #FDIV tq, xv+xi*4, xinv+xi*4
        .next
        lda #1
        sta xop
        jmp (ro_fn)
_zero:
        #PERR E_SCALE0
_rot:
        lda #2
        sta xop
        ldx #11
-       lda xv,x
        sta xrot,x
        dex
        bpl -
        lda #0
        sta xax
_axis:
        lda xax
        asl
        asl
        tax
        lda xrot,x
        ora xrot+1,x
        ora xrot+2,x
        ora xrot+3,x
        beq _next
        jsr _angle
        jsr fcos_deg
        stq xc
        jsr _angle
        jsr fsin_deg
        stq xs
        jsr _call
_next:
        inc xax
        lda xax
        cmp #3
        bne _axis
        rts
_angle: ; fs_a = the angle about axis xax
        lda xax
        asl
        asl
        tax
        ldy #0
-       lda xrot,x
        sta fs_a,y
        inx
        iny
        cpy #4
        bne -
        rts
_call:  jmp (ro_fn)

; the pigment's transform: its inverse only
ptex_op:
        lda #<mt_ptex
        sta xp
        lda #>mt_ptex
        sta xp+1
        jsr x_load
        jsr x_inv
        jmp x_store

;=======================================================================================
; modifiers: until the object's }. Transforms apply at once to its primitives; a texture
; attaches at the end, as if it came first.
;=======================================================================================
modifiers:
        lda #<ninv
        sta lp
        lda #>ninv
        sta lp+1
        ldy #0
        jsr put_ident
        lda #0
        sta m_active
_l:
        lda #'}'
        jsr accept_char
        bcc _mod
        lda m_active
        beq +
        jmp attach
+       rts
_mod:
        lda tk_type
        cmp #TK_ID
        bne _bad
        lda tk_kw
        cmp #KW_TRANSLATE
        bcc +
        cmp #KW_SCALE + 1
        bcs +
        lda #<range_op
        sta ro_fn
        lda #>range_op
        sta ro_fn+1
        jsr transform
        bra _l
+       cmp #KW_TEXTURE
        bcc _bad
        cmp #KW_INTERIOR + 1
        bcs +
        pha
        jsr mt_begin
        pla
        sec
        sbc #KW_TEXTURE
        asl
        tax
        jsr _surf
        bra _l
+       cmp #KW_NOSHADOW
        bne +
        jsr next_tok
        jsr no_shadow
        bra _l
+       cmp #KW_HOLLOW
        bne _bad
        jsr next_tok
        bra _l
_bad:
        #PERR E_MODIFIER
_surf:  jmp (_surfs,x)
_surfs: .word texture, pigment, finish, interior

; the material being built: the defaults, the first time
mt_begin:
        lda m_active
        bne +
        lda #1
        sta m_active
        jmp mt_reset
+       rts

mt_reset:
        ldx #mt_end - mt_start - 1
        lda #0
-       sta mt_start,x
        dex
        bpl -
        lda #<mt_ptex
        sta lp
        lda #>mt_ptex
        sta lp+1
        ldy #0
        jsr put_ident
        #LDIMM FX(0.1), mt_amb
        #LDIMM FX(0.1), mt_amb+4
        #LDIMM FX(0.1), mt_amb+8
        #LDIMM FX(0.6), mt_diff
        #LDIMM ONE, mt_ior
        lda #40
        sta mt_psize
        rts

no_shadow:
        ldx ob_d
        lda ob_p0-1,x
        sta ro_i
-       lda ro_i
        cmp sc_nprim
        beq +
        tax
        jsr prim_ptr_x
        ldy #P_FLAGS
        lda (lp),y
        ora #F_NOSHADOW
        sta (lp),y
        inc ro_i
        bra -
+       rts

; a block of kind A that starts with a declared name of that kind: read the declared one
; there, through the routine at (db_fn), then come back
from_declared:
        jsr declared_block
        bcc +
        jsr pos_push
        jsr pos_jump
        jsr _call
        jsr pos_pop
+       rts
_call:  jmp (db_fn)

texture:
        lda #KW_TEXTURE
        jsr expect_kw
        #EXPECT '{'
        lda #<texture
        sta db_fn
        lda #>texture
        sta db_fn+1
        lda #SK_TEXTURE
        jsr from_declared
_l:
        lda #'}'
        jsr accept_char
        bcc +
        rts
+       #ISKW KW_PIGMENT
        bne +
        jsr pigment
        bra _l
+       #ISKW KW_FINISH
        bne +
        jsr finish
        bra _l
+       jsr is_xform_kw
        bne +
        jsr pig_transform
        bra _l
+       #PERR E_SETTING

; Z set if the token is translate / rotate / scale
is_xform_kw:
        lda tk_type
        cmp #TK_ID
        bne +
        lda tk_kw
        cmp #KW_TRANSLATE
        bcc ++
        cmp #KW_SCALE + 1
        bcs ++
        lda #0
+       rts
+       lda #1
        rts

pig_transform:
        lda #<ptex_op
        sta ro_fn
        lda #>ptex_op
        sta ro_fn+1
        jmp transform

pigment:
        lda #KW_PIGMENT
        jsr expect_kw
        #EXPECT '{'
        lda #<pigment
        sta db_fn
        lda #>pigment
        sta db_fn+1
        lda #SK_PIGMENT
        jsr from_declared
_l:
        lda #'}'
        jsr accept_char
        bcc +
        rts
+       lda #KW_CHECKER
        jsr accept_kw
        bcc _nchk
        jsr colour
        ldx #19
-       lda col,x
        sta mt_col,x
        dex
        bpl -
        lda #','
        jsr accept_char
        jsr colour
        ldx #19
-       lda col,x
        sta mt_col2,x
        dex
        bpl -
        lda #1
        sta mt_chk
        bra _l
_nchk:
        jsr is_xform_kw
        bne +
        jsr pig_transform
        bra _l
+       jsr is_colour_kw
        beq _col
        lda tk_type                     ; a declared colour
        cmp #TK_ID
        bne _bad
        lda tk_kw
        cmp #KW_NONE
        bne _bad
        jsr sym_find
        bcc _bad
        ldy #SYM_KIND
        lda (sp_),y
        cmp #SK_VAL
        bne _bad
_col:
        jsr colour
        ldx #19
-       lda col,x
        sta mt_col,x
        dex
        bpl -
        lda #0
        sta mt_chk
        jmp _l
_bad:
        #PERR E_SETTING

finish:
        lda #KW_FINISH
        jsr expect_kw
        #EXPECT '{'
        lda #<finish
        sta db_fn
        lda #>finish
        sta db_fn+1
        lda #SK_FINISH
        jsr from_declared
_l:
        lda #'}'
        jsr accept_char
        bcc +
        rts
+       lda #KW_AMBIENT
        jsr accept_kw
        bcc +
        jsr expr_or_colour
        lda #3
        jsr v_promote
        ldx #11
-       lda v_c,x
        sta mt_amb,x
        dex
        bpl -
        bra _l
+       lda #KW_DIFFUSE
        jsr accept_kw
        bcc +
        jsr number
        #MOVQ v_c, mt_diff
        bra _l
+       lda #KW_PHONG
        jsr accept_kw
        bcs _phong
        lda #KW_SPECULAR
        jsr accept_kw
        bcc +
_phong: jsr number
        #MOVQ v_c, mt_phong
        bra _l
+       lda #KW_PHONGSIZE
        jsr accept_kw
        bcc +
        jsr number
        lda v_c+2
        sta mt_psize
        lda v_c+3
        sta mt_psize+1
        jmp _l
+       lda #KW_ROUGHNESS
        jsr accept_kw
        bcc _nrough
        jsr number
        bit v_c+3
        bmi _rough
        #BEQZ v_c, _rough
        #LDIMM ONE, tq
        #FDIV tq, v_c, tq
        lda tq+2
        sta mt_psize
        lda tq+3
        sta mt_psize+1
        jmp _l
_rough: #PERR E_ROUGH
_nrough:
        lda #KW_REFLECTION
        jsr accept_kw
        bcc +
        jsr expr_or_colour              ; a number, or a colour's first part
        #MOVQ v_c, mt_refl
        jmp _l
+       #PERR E_SETTING

; V = a colour's r, g, b (if the token starts one: color, rgb ...) or an expression
expr_or_colour:
        jsr is_colour_kw
        beq +
        jmp expr
+       jsr colour
        ldx #11
-       lda col,x
        sta v_c,x
        dex
        bpl -
        lda #3
        sta v_n
        rts

interior:
        lda #KW_INTERIOR
        jsr expect_kw
        #EXPECT '{'
        lda #<interior
        sta db_fn
        lda #>interior
        sta db_fn+1
        lda #SK_INTERIOR
        jsr from_declared
_l:
        lda #'}'
        jsr accept_char
        bcc +
        rts
+       lda #KW_IOR
        jsr accept_kw
        bcc _set
        jsr number
        bit v_c+3
        bmi _bad
        #BEQZ v_c, _bad
        #MOVQ v_c, mt_ior
        bra _l
_bad:   #PERR E_IOR
_set:   #PERR E_SETTING

;---------------------------------------------------------------------------------------
; attach: the material built (mt_*) -> a material index (an equal record is shared), and
; to each primitive of this object that has none: it, and the texture matrix
; mt_ptex . ninv
;---------------------------------------------------------------------------------------
attach:
        jsr mat_add
        sta at_mat
        jsr tex_matmul
        ldx ob_d
        lda ob_p0-1,x
        sta ro_i
_p:
        lda ro_i
        cmp sc_nprim
        beq _done
        tax
        jsr prim_ptr_x
        ldy #P_MAT
        lda (lp),y
        cmp #$ff
        bne _next
        lda at_mat
        sta (lp),y
        ldy #P_TEXA
        ldx #0
-       lda tw,x
        sta (lp),y
        iny
        inx
        cpx #48
        bne -
_next:
        inc ro_i
        bra _p
_done:
        rts

; the material record from mt_* -> mrec; A = its index (an equal one, or a new one)
mat_add:
        ldx #MAT_SIZE - 1
        lda #0
-       sta mrec,x
        dex
        bpl -
        #MOVQ mt_diff, mrec+M_AL
        #MOVQ mt_phong, mrec+M_AL+4
        #MOVQ mt_refl, mrec+M_AL+8
        #ADDQ mt_col+12, mt_col+16, mrec+M_AL+12
        ldx #11
-       lda mt_col,x
        sta mrec+M_C1,x
        sta mrec+M_C2,x
        lda mt_amb,x
        sta mrec+M_AMB,x
        dex
        bpl -
        lda mt_chk
        beq +
        lda #MF_CHECKER
        sta mrec+M_FLAGS
        ldx #11
-       lda mt_col2,x
        sta mrec+M_C2,x
        dex
        bpl -
+       lda mt_psize+1                  ; phong_size: 0 if negative
        bmi +
        sta mrec+M_PS+1
        lda mt_psize
        sta mrec+M_PS
+       #LDIMM ONE, tq
        #FDIV tq, mt_ior, mrec+M_ETA
        #FMUL mrec+M_ETA, mrec+M_ETA, mrec+M_ETA+4
        #MOVQ mt_ior, mrec+M_ETA+8
        #FMUL mt_ior, mt_ior, mrec+M_ETA+12
        ; the same as one already there?
        lda #0
        sta ma_k
_k:
        lda ma_k
        cmp sc_nmat
        beq _new
        tax
        lda mat_lo,x
        sta lp
        lda mat_hi,x
        sta lp+1
        ldy #0
-       lda (lp),y
        cmp mrec,y
        bne _ne
        iny
        cpy #M_USED
        bne -
        lda ma_k
        rts
_ne:    inc ma_k
        bra _k
_new:
        cmp #MAX_MAT
        bcc +
        #PERR E_MATS
+       tax
        inc sc_nmat
        lda mat_lo,x
        sta lp
        lda mat_hi,x
        sta lp+1
        ldy #0
-       lda mrec,y
        sta (lp),y
        iny
        cpy #MAT_SIZE
        bne -
        lda ma_k
        rts

; tw = P X with P = mt_ptex, X = ninv:  A = P.A X.A, t = P.A X.t + P.t
tex_matmul:
        .for xj = 0, xj < 3, xj += 1
        #MOVQ ninv+xj*4, mm_col         ; column j of X.A
        #MOVQ ninv+12+xj*4, mm_col+4
        #MOVQ ninv+24+xj*4, mm_col+8
        .for xi = 0, xi < 3, xi += 1
        #DOT mt_ptex+xi*12, mm_col, tw+xi*12+xj*4
        .next
        .next
        .for xi = 0, xi < 3, xi += 1
        #DOT mt_ptex+xi*12, ninv+36, tq
        #ADDQ tq, mt_ptex+36+xi*4, tw+36+xi*4
        .next
        rts

;=======================================================================================
; the end: default materials, ambient light, every primitive's frame, roots, the header
;=======================================================================================
finalise:
        lda #0                          ; primitives without a texture: the default material
        sta ro_i
_def:
        lda ro_i
        cmp sc_nprim
        beq _amb
        tax
        jsr prim_ptr_x
        ldy #P_MAT
        lda (lp),y
        cmp #$ff
        bne +
        jsr mt_reset
        jsr mat_add
        pha
        ldx ro_i
        jsr prim_ptr_x
        pla
        ldy #P_MAT
        sta (lp),y
+       inc ro_i
        bra _def
_amb:   ; each material's ambient times ambient_light
        lda #0
        sta ro_i
_m:
        lda ro_i
        cmp sc_nmat
        beq _prims
        tax
        lda mat_lo,x
        sta lp
        lda mat_hi,x
        sta lp+1
        ldy #M_AMB
        ldx #0
-       lda (lp),y
        sta fa_v,x
        iny
        inx
        cpx #12
        bne -
        .for xi = 0, xi < 3, xi += 1
        #FMUL fa_v+xi*4, amb_light+xi*4, fa_v+xi*4
        .next
        ldy #M_AMB
        ldx #0
-       lda fa_v,x
        sta (lp),y
        iny
        inx
        cpx #12
        bne -
        inc ro_i
        bra _m
_prims: ; each primitive's frame and shape
        lda #0
        sta ro_i
-       lda ro_i
        cmp sc_nprim
        beq +
        jsr fin_prim
        inc ro_i
        bra -
+       jsr fin_roots
        ; the depth: max_trace_level - 1, from 0 to 4
        sec
        lda max_trace
        sbc #1
        sta tmp0
        lda max_trace+1
        sbc #0
        bmi _d0
        bne _d4
        lda tmp0
        cmp #4
        bcc +
_d4:    lda #4
        bra +
_d0:    lda #0
+       sta sc_maxd
        jmp fin_camera

;---------------------------------------------------------------------------------------
; fin_prim: primitive ro_i: its definition and M -> c, R, shape, flags. Its bounding
; radius goes into its parameter slot (+0, and +4 = 1 if infinite) for fin_roots.
;---------------------------------------------------------------------------------------
fin_prim:
        ldx ro_i
        jsr prim_ptr_x
        lda par_lo,x
        sta pa
        lda par_hi,x
        sta pa+1
        txa
        asl
        tax
        lda PW_LINES,x                  ; (errors report the primitive's line)
        sta tk_tline
        lda PW_LINES+1,x
        sta tk_tline+1
        ldy #0                          ; the definition
-       lda (pa),y
        sta fp_par,y
        iny
        cpy #32
        bne -
        ldy #P_C                        ; M
        ldx #0
-       lda (lp),y
        sta fm,x
        iny
        inx
        cpx #48
        bne -
        ldy #P_TYPE
        lda (lp),y
        sta fp_type
        ; the columns of A and their lengths
        .for xj = 0, xj < 3, xj += 1
        #MOVQ fm+xj*4, fcol+xj*12
        #MOVQ fm+12+xj*4, fcol+xj*12+4
        #MOVQ fm+24+xj*4, fcol+xj*12+8
        #DOT fcol+xj*12, fcol+xj*12, tq
        jsr fsqrt
        stq fls+xj*4
        .next
        lda #0
        sta fp_inf
        ldx #35                         ; R = identity unless set
-       lda x_ident,x
        sta fmr,x
        dex
        bpl -
        lda fp_type
        asl
        tax
        jmp (_t,x)
_t:     .word fp_sphere, fp_box, fp_cyl, fp_cyl, fp_plane

; write c, R, shape and flags, and the bounding radius
fp_write:
        ldx ro_i
        jsr prim_ptr_x
        ldy #P_C
        ldx #0
-       lda fc,x
        sta (lp),y
        iny
        inx
        cpx #12
        bne -
        ldx #0
-       lda fmr,x
        sta (lp),y
        iny
        inx
        cpx #36
        bne -
        ldx #0
-       lda fsh,x
        sta (lp),y
        iny
        inx
        cpx #16
        bne -
        ldy #P_FLAGS
        lda (lp),y
        and #F_NOSHADOW
        sta tmp0
        ldx #35                         ; rotated?
-       lda fmr,x
        cmp x_ident,x
        bne +
        dex
        bpl -
        bra ++
+       lda tmp0
        ora #F_ROT
        sta tmp0
+       lda tmp0
        sta (lp),y
        ldy #0                          ; the bound, into the parameter slot
        ldx #0
-       lda fp_br,x
        sta (pa),y
        iny
        inx
        cpx #4
        bne -
        lda fp_inf
        sta (pa),y
        rts

; tv3 = tq >> 8 (tq >= 0)
SHR8 .macro src, dst
        lda \src+1
        sta \dst
        lda \src+2
        sta \dst+1
        lda \src+3
        sta \dst+2
        lda #0
        sta \dst+3
.endmacro

; one uniform scale, no shear -> fp_s
check_uniform:
        jsr check_orth
        .for xj = 1, xj < 3, xj += 1
        #SUBQ fls+xj*4, fls, tq         ; |l_j - l_0| > l_0 >> 8: error
        #ABSQ tq, tq
        #SHR8 fls, tv3
        #BGTQ tq, tv3, cu_bad
        .next
        #MOVQ fls, fp_s
        rts
cu_bad: #PERR E_UNIFORM
check_orth:
        .for xpair in [(0, 1), (0, 2), (1, 2)]
        #DOT fcol+xpair[0]*12, fcol+xpair[1]*12, tq
        #ABSQ tq, tq
        #FMUL fls+xpair[0]*4, fls+xpair[1]*4, tv3
        #SHR8 tv3, tv3
        #BGTQ tq, tv3, co_bad
        .next
        rts
co_bad: #PERR E_SHEAR

; fv_out = A p + t, or A p, for the vector at fv_in
apply_point:
        .for xi = 0, xi < 3, xi += 1
        #DOT fm+xi*12, fv_in, tq
        #ADDQ tq, fm+36+xi*4, fv_out+xi*4
        .next
        rts
apply_dir:
        .for xi = 0, xi < 3, xi += 1
        #DOT fm+xi*12, fv_in, fv_out+xi*4
        .next
        rts

fp_sphere:
        jsr check_uniform
        #FMUL fp_par+12, fp_s, fp_r
        jsr fp_radius_ok
        #VMOV fp_par, fv_in
        jsr apply_point
        #VMOV fv_out, fc
        #FMUL fp_r, fp_r, fsh
        #LDIMM ONE, tq
        #FDIV tq, fp_r, fsh+4
        #MOVQ fp_r, fsh+8
        #MOVQ q_zero, fsh+12
        #MOVQ fp_r, fp_br
        jmp fp_write

fp_radius_ok:                           ; fp_r > 0
        bit fp_r+3
        bmi +
        #BEQZ fp_r, +
        rts
+       #PERR E_RADIUS

fp_box:
        jsr check_orth
        .for xi = 0, xi < 3, xi += 1
        #ADDQ fp_par+xi*4, fp_par+12+xi*4, tq   ; m = (a + b) >> 1
        #ASRQ_Q
        stq fv_in+xi*4
        #SUBQ fp_par+12+xi*4, fp_par+xi*4, tq   ; hd = |b - a| >> 1
        #ABSQ tq, tq
        ldq tq
        #LSRQ_Q
        stq fhd+xi*4
        .next
        jsr apply_point
        #VMOV fv_out, fc
        .for xj = 0, xj < 3, xj += 1
        .for xi = 0, xi < 3, xi += 1
        #FDIV fcol+xj*12+xi*4, fls+xj*4, fmr+xj*12+xi*4
        .next
        #FMUL fhd+xj*4, fls+xj*4, fsh+xj*4
        .next
        #MOVQ q_zero, fsh+12
        #DOT fsh, fsh, tq
        jsr fsqrt
        stq fp_br
        jmp fp_write

fp_cyl:                                 ; cylinders and cones
        jsr check_uniform
        #VMOV fp_par, fv_in             ; pa
        jsr apply_point
        #VMOV fv_out, fpa
        ldx #12                         ; pb: a cylinder's at +12, a cone's at +16
        lda fp_type
        cmp #T_CONE
        bne +
        ldx #16
+       ldy #0
-       lda fp_par,x
        sta fv_in,y
        inx
        iny
        cpy #12
        bne -
        jsr apply_point
        #VMOV fv_out, fpb
        #VSUB fpb, fpa, fax             ; axis, L
        #DOT fax, fax, tq
        jsr fsqrt
        stq fp_l
        #BNEZ fp_l, +
        #PERR E_ENDS
+       .for xi = 0, xi < 3, xi += 1
        #FDIV fax+xi*4, fp_l, fmr+12+xi*4        ; ey
        .next
        jsr basis
        .for xi = 0, xi < 3, xi += 1
        #ADDQ fpa+xi*4, fpb+xi*4, tq    ; c = (pa + pb) >> 1
        #ASRQ_Q
        stq fc+xi*4
        .next
        ldq fp_l                        ; h = L >> 1
        #LSRQ_Q
        stq fp_h
        lda fp_type
        cmp #T_CONE
        beq _cone
        #FMUL fp_par+24, fp_s, fp_r
        jsr fp_radius_ok
        #FMUL fp_r, fp_r, fsh
        #MOVQ fp_h, fsh+4
        #LDIMM ONE, tq
        #FDIV tq, fp_r, fsh+8
        #MOVQ q_zero, fsh+12
        #MOVQ fp_r, fp_rm
        jmp _br
_cone:
        #FMUL fp_par+12, fp_s, fp_ra
        #FMUL fp_par+28, fp_s, fp_rb
        bit fp_ra+3
        bmi _bad
        bit fp_rb+3
        bmi _bad
        lda fp_ra
        ora fp_ra+1
        ora fp_ra+2
        ora fp_ra+3
        ora fp_rb
        ora fp_rb+1
        ora fp_rb+2
        ora fp_rb+3
        bne +
_bad:   #PERR E_CONER
+       #ADDQ fp_ra, fp_rb, tq          ; a = (ra + rb) >> 1
        #ASRQ_Q
        stq fsh
        #SUBQ fp_rb, fp_ra, tq          ; b = (rb - ra) / L
        #FDIV tq, fp_l, fsh+4
        #MOVQ fp_h, fsh+8
        #FMUL fsh+4, fsh+4, tq          ; k = 1 / sqrt(1 + b^2)
        #ADDQ q_one, tq, tq
        jsr fsqrt
        stq tv3
        #LDIMM ONE, tq
        #FDIV tq, tv3, fsh+12
        #MOVQ fp_ra, fp_rm              ; the larger radius
        #BLEQ fp_rb, fp_ra, _br
        #MOVQ fp_rb, fp_rm
_br:    ; br = sqrt(h^2 + rm^2)
        #FMUL fp_h, fp_h, tq
        #FMUL fp_rm, fp_rm, tv3
        #ADDQ tq, tv3, tq
        jsr fsqrt
        stq fp_br
        jmp fp_write

fp_plane:
        jsr check_uniform
        #VMOV fp_par, vn_a
        ldx #11
        lda #0
-       ora vn_a,x
        dex
        bpl -
        cmp #0
        bne +
        #PERR E_NORMAL
+       jsr vnorm                       ; nh
        #VMOV vn_r, fnh
        .for xi = 0, xi < 3, xi += 1
        #FMUL fnh+xi*4, fp_par+12, fv_in+xi*4   ; p0 = nh d
        .next
        jsr apply_point
        #VMOV fv_out, fc
        #VMOV fnh, fv_in
        jsr apply_dir
        #VMOV fv_out, vn_a
        jsr vnorm
        #VMOV vn_r, fmr+12               ; ey
        jsr basis
        lda #1
        sta fp_inf
        #MOVQ q_zero, fp_br
        ldx #15
        lda #0
-       sta fsh,x
        dex
        bpl -
        jmp fp_write

; ex, ez at right angles to ey (fmr+12): h = (0, 0, 1) if |ey.z| < 1/2, else (1, 0, 0)
basis:
        #VMOV fmr+12, cr_a
        #VMOV q_zero3p, cr_b
        #ABSQ fmr+20, tq
        #LDIMM ONE / 2, tv3
        #BLTQ tq, tv3, +
        #LDIMM ONE, cr_b
        bra ++
+       #LDIMM ONE, cr_b+8
+       jsr cross
        #VMOV cr_r, vn_a
        jsr vnorm
        #VMOV vn_r, fmr                  ; ex
        #VMOV fmr, cr_a
        #VMOV fmr+12, cr_b
        jsr cross
        #VMOV cr_r, fmr+24               ; ez = ex x ey
        rts

; cr_r = cr_a x cr_b
cross:
        #FMUL cr_a+4, cr_b+8, tq
        #FMUL cr_a+8, cr_b+4, tv3
        #SUBQ tq, tv3, cr_r
        #FMUL cr_a+8, cr_b, tq
        #FMUL cr_a, cr_b+8, tv3
        #SUBQ tq, tv3, cr_r+4
        #FMUL cr_a, cr_b+4, tq
        #FMUL cr_a+4, cr_b, tv3
        #SUBQ tq, tv3, cr_r+8
        rts

; vn_r = vn_a / |vn_a|
vnorm:
        #DOT vn_a, vn_a, tq
        jsr fsqrt
        stq vn_l
        .for xi = 0, xi < 3, xi += 1
        #FDIV vn_a+xi*4, vn_l, vn_r+xi*4
        .next
        rts
q_zero3p:       .dint 0, 0, 0

;---------------------------------------------------------------------------------------
; fin_roots: each root's bounding sphere (from the boxes of its parts), its no-shadow
; flag, and a check of the stack depth its program needs
;---------------------------------------------------------------------------------------
BX_SIZE         = 25                    ; a box: lo (12), hi (12), infinite (1)

fin_roots:
        lda #0
        sta fn_k
_root:
        lda fn_k
        cmp sc_nroot
        bne +
        rts
+       tax
        jsr root_ptr_x
        ldy #R_START
        lda (rp),y
        sta fn_pc
        tax
        lda sc_prog,x                   ; (errors: the line of its first primitive)
        asl
        tax
        lda PW_LINES,x
        sta tk_tline
        lda PW_LINES+1,x
        sta tk_tline+1
        lda #0
        sta bx_sp
        lda #RF_NOSHADOW
        sta fn_fl
_op:
        ldx fn_pc
        inc fn_pc
        lda sc_prog,x
        cmp #OP_END
        beq _end
        cmp #OP_UNION
        bcs _bin
        jsr bx_push_prim
        bra _op
_bin:
        jsr bx_combine
        bra _op
_end:
        ; a single sphere needs no bound
        ldy #R_START
        lda (rp),y
        tax
        lda sc_prog+1,x
        cmp #OP_END
        bne _bound
        lda sc_prog,x
        tax
        jsr prim_ptr_x
        ldy #P_TYPE
        lda (lp),y
        cmp #T_SPHERE
        beq _flags
_bound:
        lda #0                          ; the result: slot 0
        jsr bx_get_a
        lda ba+24
        bne _flags
        .for xi = 0, xi < 3, xi += 1
        #ADDQ ba+xi*4, ba+12+xi*4, tq   ; centre = (lo + hi) >> 1
        #ASRQ_Q
        stq fb_c+xi*4
        #SUBQ ba+12+xi*4, ba+xi*4, tq   ; half = (hi - lo) >> 1
        #LSRQ_Q
        stq fb_h+xi*4
        .next
        #DOT fb_h, fb_h, tq
        jsr fsqrt
        clc
        adq q_margin
        stq tv3
        #FMUL tv3, tv3, fb_r2
        ldy #R_BC
        ldx #0
-       lda fb_c,x
        sta (rp),y
        iny
        inx
        cpx #16
        bne -
        lda fn_fl
        ora #RF_BOUND
        sta fn_fl
_flags:
        lda fn_fl
        ldy #R_FLAGS
        sta (rp),y
        inc fn_k
        jmp _root
q_margin:       .dint BOUND_MARGIN

; push primitive A's box: c +- br, or infinite
bx_push_prim:
        tax
        lda bx_sp
        cmp #MAX_STACK
        bcc +
        #PERR E_NEST
+       jsr prim_ptr_x
        ldy #P_FLAGS                    ; no shadow only if every part has none
        lda (lp),y
        and #F_NOSHADOW
        bne +
        lda #0
        sta fn_fl
+       lda par_lo,x
        sta pa
        lda par_hi,x
        sta pa+1
        ldy #0
-       lda (pa),y
        sta fp_br,y
        iny
        cpy #4
        bne -
        lda (pa),y
        sta ba+24
        ldy #P_C
        ldx #0
-       lda (lp),y
        sta fc,x
        iny
        inx
        cpx #12
        bne -
        .for xi = 0, xi < 3, xi += 1
        #SUBQ fc+xi*4, fp_br, ba+xi*4
        #ADDQ fc+xi*4, fp_br, ba+12+xi*4
        .next
        lda bx_sp
        inc bx_sp
        jmp bx_put_a

; the two top boxes -> one, by the operation A
bx_combine:
        sta bc_op
        dec bx_sp
        lda bx_sp
        jsr bx_get_b                    ; B: the top
        lda bx_sp
        sec
        sbc #1
        jsr bx_get_a                    ; A: under it
        lda bc_op
        cmp #OP_UNION
        bne _ninter
        lda ba+24                       ; union: infinite if either is; else min, max
        ora bb+24
        sta ba+24
        bne _put
        .for xi = 0, xi < 3, xi += 1
        #BLEQ ba+xi*4, bb+xi*4, +
        #MOVQ bb+xi*4, ba+xi*4
+       #BLEQ bb+12+xi*4, ba+12+xi*4, +
        #MOVQ bb+12+xi*4, ba+12+xi*4
+
        .next
        bra _put
_ninter:
        cmp #OP_INTER
        bne _put                        ; difference: A as it is
        lda bb+24                       ; intersection: the finite ones
        bne _put
        lda ba+24
        beq +
        ldx #BX_SIZE - 1                ; A infinite: B
-       lda bb,x
        sta ba,x
        dex
        bpl -
        bra _put
+       .for xi = 0, xi < 3, xi += 1
        #BLEQ bb+xi*4, ba+xi*4, +       ; lo = max
        #MOVQ bb+xi*4, ba+xi*4
+       #BLEQ ba+12+xi*4, bb+12+xi*4, + ; hi = min
        #MOVQ bb+12+xi*4, ba+12+xi*4
+
        .next
_put:
        lda bx_sp
        sec
        sbc #1
        jmp bx_put_a

; slot A <-> ba / bb
bx_get_a:
        tax
        ldy bx_off,x
        ldx #0
-       lda bx,y
        sta ba,x
        iny
        inx
        cpx #BX_SIZE
        bne -
        rts
bx_get_b:
        tax
        ldy bx_off,x
        ldx #0
-       lda bx,y
        sta bb,x
        iny
        inx
        cpx #BX_SIZE
        bne -
        rts
bx_put_a:
        tax
        ldy bx_off,x
        ldx #0
-       lda ba,x
        sta bx,y
        iny
        inx
        cpx #BX_SIZE
        bne -
        rts
bx_off:         .byte range(0, MAX_STACK * BX_SIZE, BX_SIZE)

;---------------------------------------------------------------------------------------
; fin_camera: the camera's frame -> the header
;---------------------------------------------------------------------------------------
fin_camera:
        lda cam_set
        bne +
        jsr cam_defaults
+       lda cam_line
        sta tk_tline
        lda cam_line+1
        sta tk_tline+1
        #VSUB cam_look, cam_loc, vn_a   ; f = look_at - location, normalised
        ldx #11
        lda #0
-       ora vn_a,x
        dex
        bpl -
        cmp #0
        bne +
        #PERR E_CAMLOOK
+       jsr vnorm
        #VMOV vn_r, ca_fv
        #VMOV cam_sky, cr_a             ; r = sky x f, normalised
        #VMOV ca_fv, cr_b
        jsr cross
        #VMOV cr_r, vn_a
        ldx #11
        lda #0
-       ora vn_a,x
        dex
        bpl -
        cmp #0
        bne +
        #PERR E_CAMSKY
+       jsr vnorm
        #VMOV vn_r, sc_cam_r
        #VMOV ca_fv, cr_a               ; u = f x r
        #VMOV sc_cam_r, cr_b
        jsr cross
        #VMOV cr_r, sc_cam_u
        #VMOV cam_loc, sc_cam_o
        ldq cam_angle                   ; half = angle >> 1, 0 < half < 90
        #ASRQ_Q
        stq fs_a
        bit fs_a+3
        bmi _bad
        #BEQZ fs_a, _bad
        #LDIMM 90 * ONE, tq
        #BLEQ tq, fs_a, _bad
        #MOVQ fs_a, ca_half
        jsr fsin_deg
        stq ca_sin
        #MOVQ ca_half, fs_a
        jsr fcos_deg
        stq tq
        #FDIV ca_sin, tq, tv3           ; tan
        #LDIMM 40960, tq                ; F = 0.625 / tan (0.625 = 640 * 64 / 2 / 65536)
        #FDIV tq, tv3, tv3
        .for xi = 0, xi < 3, xi += 1
        #FMUL ca_fv+xi*4, tv3, sc_cam_f+xi*4
        .next
        rts
_bad:   #PERR E_ANGLE

cam_defaults:
        jsr v_zero3
        ldx #11
-       lda v_c,x
        sta cam_loc,x
        sta cam_look,x
        sta cam_sky,x
        dex
        bpl -
        lda #1
        sta cam_look+10
        sta cam_sky+6
        #LDIMM FX(67.38), cam_angle
        rts

;---------------------------------------------------------------------------------------
; sine and cosine of fs_a (degrees, 16.16) -> Q: whole degrees from a table, linear in
; between (pov.py's fxmath.fsin_deg)
;---------------------------------------------------------------------------------------
fcos_deg:
        #LDIMM 90 * ONE, tq
        #ADDQ fs_a, tq, fs_a
fsin_deg:
        ; r = a mod 360, 0 <= r < 360
        #ABSQ fs_a, fs_r
        ldq fs_r
        stq MULTINA
        #LDIMM 360 * ONE, tq
        stq MULTINB
-       bit DIVBUSY
        bmi -
        ldq DIVOUT+4                    ; q = |a| div 360
        stq MULTINA
        #LDIMM 360 * ONE, tq
        stq MULTINB
        #SUBQ fs_r, MULTOUT, fs_r       ; |a| - q 360
        bit fs_a+3
        bpl +
        #BEQZ fs_r, +
        #LDIMM 360 * ONE, tq            ; a < 0: 360 - that
        #SUBQ tq, fs_r, fs_r
+       lda #0
        sta fs_neg
        #LDIMM 180 * ONE, tq
        #BLTQ fs_r, tq, +               ; r >= 180: -sin(r - 180)
        lda #1
        sta fs_neg
        #SUBQ fs_r, tq, fs_r
+       #LDIMM 90 * ONE, tq
        #BLEQ fs_r, tq, +               ; r > 90: sin(180 - r)
        #LDIMM 180 * ONE, tq
        #SUBQ tq, fs_r, fs_r
+       lda fs_r+2                      ; i = whole degrees (0..90), f = the fraction
        cmp #90
        bcc +
        #MOVQ sin_t+90*4, fs_s
        bra _sign
+       sta lp                          ; lp = sin_t + 4 i (16-bit: i reaches 89)
        lda #0
        sta lp+1
        asl lp
        rol lp+1
        asl lp
        rol lp+1
        clc
        lda lp
        adc #<sin_t
        sta lp
        lda lp+1
        adc #>sin_t
        sta lp+1
        ldy #0
-       lda (lp),y
        sta fs_s,y
        iny
        cpy #4
        bne -
        ldx #0
-       lda (lp),y
        sta fs_n,x
        iny
        inx
        cpx #4
        bne -
        #SUBQ fs_n, fs_s, fs_n          ; s = t[i] + (t[i+1] - t[i]) f
        lda fs_r
        sta tq
        lda fs_r+1
        sta tq+1
        lda #0
        sta tq+2
        sta tq+3
        #FMUL fs_n, tq, tq
        #ADDQ fs_s, tq, fs_s
_sign:
        lda fs_neg
        beq +
        #NEGQ fs_s, fs_s
+       ldq fs_s
        rts

; V's number: its sine / cosine (degrees)
fsin_v:
        #MOVQ v_c, fs_a
        jsr fsin_deg
        stq v_c
        rts
fcos_v:
        #MOVQ v_c, fs_a
        jsr fcos_deg
        stq v_c
        rts

sin_t:
        .for xi = 0, xi < 91, xi += 1
        .dint FX(sin(rad(xi)))
        .next
