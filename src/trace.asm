;=======================================================================================
; trace.asm - the ray tracer, in 16.16 fixed point, reading the compiled scene (scene.asm).
;
; Mirrors private/tools/ref_trace.py step for step, so the RGB it produces is bit-identical
; to the model's. docs/DESIGN.md ("The tracer") describes the method.
;
;   trace_pixel   ray through pixel (px_x, px_y) -> out_r, out_g, out_b (0..255)
;
; Rays: ray_o (origin), ray_d (unit direction), ray_from (the primitive the ray leaves, so
; it can't hit it again through rounding; NO_ID for camera rays).
;
; Each primitive gives one interval along the ray (or none): pv_n = 0/1, pv_t0/pv_s0 (the
; way in: t and which face) and pv_t1/pv_s1 (the way out). A root that is one primitive
; uses that directly; a boolean root runs its postfix program over interval lists.
;
; cast recurses for reflections and refractions (up to the scene's depth), saving its frame
; (fr_*) on a small stack of its own. Its result is in rc (r, g, b, 16.16).
;=======================================================================================

EPS             = 66                    ; 0.001: the original's "t > .001"
INF             = $3fffffff
NINF            = -$3fffffff
MAXIV           = 8                     ; intervals in a list
IVL_SIZE        = 1 + MAXIV * 12        ; count, then (t0, prim0, sub0, t1, prim1, sub1)
IVL_SLOTS       = 8                     ; 7 for the program's stack, the last for combine
CHECK_TOL       = 66

; ---- comparisons of dwords (signed; the values never differ by 2^31 or more) ----------
; branch if a > b
BGTQ .segment a, b, label
        sec
        ldq \b
        sbq \a
        bmi \label
.endsegment
; branch if a <= b
BLEQ .segment a, b, label
        sec
        ldq \b
        sbq \a
        bpl \label
.endsegment
; branch if a < b
BLTQ .segment a, b, label
        sec
        ldq \a
        sbq \b
        bmi \label
.endsegment
; branch if the dword is zero
BEQZ .segment a, label
        lda \a
        ora \a+1
        ora \a+2
        ora \a+3
        beq \label
.endsegment
BNEZ .segment a, label
        lda \a
        ora \a+1
        ora \a+2
        ora \a+3
        bne \label
.endsegment
; dst = |src|
ABSQ .segment src, dst
        ldq \src
        stq \dst
        bit \dst+3
        bpl +
        #NEGQ \src, \dst
+
.endsegment
; dst = arithmetic shift left of src by one
DBLQ .segment src, dst
        ldq \src
        #ASLQ_Q
        stq \dst
.endsegment

; debug builds (DBG_LOG = 1): append n bytes at addr to the log at DBG_LOGBUF
LOG .macro addr, n
        .if DBG_LOG
        ldx #0
-       lda \addr,x
        ldy #0
        sta (dbg_lp),y
        inw dbg_lp
        inx
        cpx #\n
        bne -
        .endif
.endmacro

; copy n bytes (n < 256)
COPYB .macro src, dst, n
        ldx #0
-       lda \src,x
        sta \dst,x
        inx
        cpx #\n
        bne -
.endmacro

; dst = i - n * 2 (i . n)
REFLECT .macro i, n, dst
        #DOT \i, \n, rf_k
        #ASLQ_M rf_k
        #FMUL \n, rf_k, rf_t
        #SUBQ \i, rf_t, \dst
        #FMUL \n+4, rf_k, rf_t
        #SUBQ \i+4, rf_t, \dst+4
        #FMUL \n+8, rf_k, rf_t
        #SUBQ \i+8, rf_t, \dst+8
.endmacro

;---------------------------------------------------------------------------------------
; tdiv: Q = td_n / td_d as a ray parameter: +-INF once |t| >= 256 (or td_d = 0)
;---------------------------------------------------------------------------------------
tdiv:
        lda td_n+3
        eor td_d+3
        sta td_sg
        #ABSQ td_n, td_an
        #ABSQ td_d, td_ad
        ; (|n| >> 8) >= |d|: compare [an1 an2 an3 0] with [ad0 ad1 ad2 ad3], unsigned
        lda td_ad+3
        bne _fin
        lda td_an+3
        cmp td_ad+2
        bcc _fin
        bne _inf
        lda td_an+2
        cmp td_ad+1
        bcc _fin
        bne _inf
        lda td_an+1
        cmp td_ad
        bcc _fin
_inf:
        bit td_sg
        bmi +
        #LDIMM INF, td_an
        rts
+       #LDIMM NINF & $ffffffff, td_an
        rts
_fin:
        ldq td_n
        stq fd_a
        ldq td_d
        jmp fdiv

; Q = tdiv(num, den)
TDIV .macro num, den, dst
        #MOVQ \num, td_n
        #MOVQ \den, td_d
        jsr tdiv
        stq \dst
.endmacro

;---------------------------------------------------------------------------------------
; prim_load: A = primitive -> cp (its first P_HOT bytes, by DMA), cpi, cp_own
;---------------------------------------------------------------------------------------
prim_load:
        sta cpi
        tax
        lda prim_lo,x
        sta cp_job_src
        lda prim_hi,x
        sta cp_job_src+1
        lda #>cp_job
        sta DMA_ADDRMSB
        lda #<cp_job
        sta DMA_ADDRLSB_ETRIG
        lda #0
        ldx cpi
        cpx ray_from
        bne +
        lda #1
+       sta cp_own
        rts
cp_job:
        .byte DMAOPT_F018B, DMAOPT_SRC_MB, 0, DMAOPT_DST_MB, 0, DMAOPT_END
        .byte DMACMD_COPY
        .word P_HOT
cp_job_src:
        .word 0
        .byte 0
        .word cp
        .byte 0
        .byte 0
        .word 0

;---------------------------------------------------------------------------------------
; to_local: ol = R (o - c), dl = R d (or just o - c and d when not rotated)
;---------------------------------------------------------------------------------------
to_local:
        #VSUB ray_o, cp_c, tv
        lda cp_flags
        and #F_ROT
        bne +
        #VMOV tv, ol
        #VMOV ray_d, dl
        rts
+       #DOT cp_r, tv, ol
        #DOT cp_r+12, tv, ol+4
        #DOT cp_r+24, tv, ol+8
        #DOT cp_r, ray_d, dl
        #DOT cp_r+12, ray_d, dl+4
        #DOT cp_r+24, ray_d, dl+8
        rts

; pv = one interval [tn (face sn), tf (face sf)]; for the ray's own primitive, the end
; nearest zero becomes zero
pv_set:
        lda cp_own
        beq _put
        #ABSQ tn, ta
        #ABSQ tf, tb
        #BGTQ ta, tb, _far              ; |tn| > |tf|: tf = 0
        #MOVQ q_zero, tn
        bra _put
_far:
        #MOVQ q_zero, tf
_put:
        #MOVQ tn, pv_t0
        #MOVQ tf, pv_t1
        lda sn
        sta pv_s0
        lda sf
        sta pv_s1
        lda #1
        sta pv_n
        rts

; the slab |v| <= h along one local axis: ta, tb (faces sa, sb), sorted, then narrowed into
; tn/sn, tf/sf. X = axis (0, 1, 2), h at slab_h, faces: sa = slab_fa, sb = slab_fa + 1
slab:
        txa
        asl
        asl
        tax
        ldy #0
-       lda ol,x
        sta sl_o,y
        lda dl,x
        sta sl_d,y
        inx
        iny
        cpy #4
        bne -
        #NEGQ slab_h, tq                ; ta = tdiv(-h - o, d)
        sec
        sbq sl_o
        stq td_n
        #MOVQ sl_d, td_d
        jsr tdiv
        stq ta
        sec                             ; tb = tdiv(h - o, d)
        ldq slab_h
        sbq sl_o
        stq td_n
        #MOVQ sl_d, td_d
        jsr tdiv
        stq tb
        lda slab_fa
        sta sa
        inc a
        sta sb
        #BLEQ ta, tb, +                 ; ta > tb: swap
        #MOVQ ta, tq
        #MOVQ tb, ta
        #MOVQ tq, tb
        lda sa
        ldx sb
        stx sa
        sta sb
+       #BLEQ ta, tn, +                 ; ta > tn: tn = ta
        #MOVQ ta, tn
        lda sa
        sta sn
+       #BLTQ tb, tf, +                 ; tb < tf: tf = tb
        rts
+       #MOVQ tb, tf
        lda sb
        sta sf
        rts

;---------------------------------------------------------------------------------------
; the primitives: cp loaded -> pv_n (0/1), pv_t0, pv_s0, pv_t1, pv_s1
;---------------------------------------------------------------------------------------
prim_iv:
        jsr prim_load
        lda #0
        sta pv_n
        lda cp_type
        asl
        tax
        jmp (piv_tab,x)
piv_tab:        .word iv_sphere, iv_box, iv_cyl, iv_cone, iv_plane

iv_sphere:
        #VSUB cp_c, ray_o, sL           ; L = c - o
        #DOT sL, ray_d, tca
        lda #0
        sta pv_s0
        sta pv_s1
        lda cp_own
        beq _other
        #DBLQ tca, tt                   ; leaving this sphere: [0, 2 tca] or [2 tca, 0]
        #BEQZ tt, _none
        bit tt+3
        bmi _behind
        #MOVQ q_zero, pv_t0
        #MOVQ tt, pv_t1
        bra _one
_behind:
        #MOVQ tt, pv_t0
        #MOVQ q_zero, pv_t1
        bra _one
_other:
        #DOT sL, sL, sLL
        bit tca+3                       ; tca < 0 and LL > r2: behind, outside
        bpl _front
        #BGTQ sLL, cp_s, _none
_front:
        #FMUL tca, tca, tq
        #SUBQ sLL, tq, d2               ; d2 = LL - tca^2
        #BGTQ d2, cp_s, _none
        #SUBQ cp_s, d2, tq
        jsr fsqrt
        stq thc
        #SUBQ tca, thc, pv_t0
        #ADDQ tca, thc, pv_t1
_one:
        lda #1
        sta pv_n
_none:
        rts

iv_box:
        jsr to_local
        jsr tn_tf_init
        .for si = 0, si < 3, si += 1
        #MOVQ cp_s+si*4, slab_h
        lda #si*2
        sta slab_fa
        ldx #si
        jsr slab
        .next
        jmp tn_tf_done

; tn = NINF, tf = INF, faces 0
tn_tf_init:
        #LDIMM NINF & $ffffffff, tn
        #LDIMM INF, tf
        lda #0
        sta sn
        sta sf
        rts
; tn > tf: none, else the interval
tn_tf_done:
        #BGTQ tn, tf, +
        jmp pv_set
+       rts

; the caps of a cylinder or cone: the y slab, faces 1 (bottom) and 2 (top). The half
; height is shape word 1 of a cylinder, word 2 of a cone.
caps:
        lda cp_type
        cmp #T_CONE
        beq +
        #MOVQ cp_s+4, slab_h
        bra ++
+       #MOVQ cp_s+8, slab_h
+       lda #1
        sta slab_fa
        ldx #1
        jmp slab

iv_cyl:
        jsr to_local
        ; a = dx^2 + dz^2, b = ox dx + oz dz, c = ox^2 + oz^2 - r2
        #FMUL dl, dl, tq
        #FMUL dl+8, dl+8, tv
        #ADDQ tq, tv, qa
        #FMUL ol, dl, tq
        #FMUL ol+8, dl+8, tv
        #ADDQ tq, tv, qb
        #FMUL ol, ol, tq
        #FMUL ol+8, ol+8, tv
        #ADDQ tq, tv, tq
        sec
        sbq cp_s
        stq qc
        lda #0
        sta sn
        sta sf
        #BNEZ qa, _q
        bit qc+3                        ; parallel to the axis: inside the tube or not
        bmi +
        #BEQZ qc, +
        rts
+       #LDIMM NINF & $ffffffff, tn
        #LDIMM INF, tf
        bra _caps
_q:
        #FMUL qb, qb, tq                ; disc = b^2 - a c
        #FMUL qa, qc, tv
        #SUBQ tq, tv, disc
        bit disc+3
        bpl +
        rts
+       ldq disc
        jsr fsqrt
        stq sqd
        #NEGQ qb, tq                    ; t0 = (-b - sq) / a
        sec
        sbq sqd
        stq td_n
        #MOVQ qa, td_d
        jsr tdiv
        stq tn
        #SUBQ sqd, qb, td_n             ; t1 = (sq - b) / a
        #MOVQ qa, td_d
        jsr tdiv
        stq tf
_caps:
        jsr caps
        jmp tn_tf_done

iv_cone:
        jsr to_local
        ; rho0 = a + b oy, rhod = b dy
        #FMUL cp_s+4, ol+4, tq
        #ADDQ cp_s, tq, rho0
        #FMUL cp_s+4, dl+4, rhod
        ; A = dx^2 + dz^2 - rhod^2
        #FMUL dl, dl, tq
        #FMUL dl+8, dl+8, tv
        #ADDQ tq, tv, tq
        stq qa
        #FMUL rhod, rhod, tv
        #SUBQ qa, tv, qa
        ; B = ox dx + oz dz - rho0 rhod
        #FMUL ol, dl, tq
        #FMUL ol+8, dl+8, tv
        #ADDQ tq, tv, qb
        #FMUL rho0, rhod, tv
        #SUBQ qb, tv, qb
        ; C = ox^2 + oz^2 - rho0^2
        #FMUL ol, ol, tq
        #FMUL ol+8, ol+8, tv
        #ADDQ tq, tv, qc
        #FMUL rho0, rho0, tv
        #SUBQ qc, tv, qc
        ; pieces: up to two (cn_n), [cn_a0, cn_b0] and [cn_a1, cn_b1]
        lda #1
        sta cn_n
        #BNEZ qa, _quad
        #BNEZ qb, _lin
        bit qc+3                        ; A = B = 0: all or nothing
        bmi _all
        #BEQZ qc, _all
        rts
_all:
        #LDIMM NINF & $ffffffff, cn_a0
        #LDIMM INF, cn_b0
        jmp _pieces
_lin:
        #NEGQ qc, td_n                  ; tr = -C / 2B
        #DBLQ qb, td_d
        jsr tdiv
        stq tq
        bit qb+3
        bmi +
        #LDIMM NINF & $ffffffff, cn_a0  ; B > 0: (-inf, tr]
        #MOVQ tq, cn_b0
        jmp _pieces
+       #MOVQ tq, cn_a0                 ; B < 0: [tr, inf)
        #LDIMM INF, cn_b0
        jmp _pieces
_quad:
        #FMUL qb, qb, tq                ; disc = B^2 - A C
        #FMUL qa, qc, tv
        #SUBQ tq, tv, disc
        bit disc+3
        bpl _roots
        bit qa+3                        ; no roots: A > 0 none, A < 0 all
        bmi _all
        rts
_roots:
        ldq disc
        jsr fsqrt
        stq sqd
        #NEGQ qb, tq                    ; r1 = (-B - sq) / A
        sec
        sbq sqd
        stq td_n
        #MOVQ qa, td_d
        jsr tdiv
        stq ta
        #SUBQ sqd, qb, td_n             ; r2 = (sq - B) / A
        #MOVQ qa, td_d
        jsr tdiv
        stq tb
        #BLEQ ta, tb, +                 ; lo, hi
        #MOVQ ta, tq
        #MOVQ tb, ta
        #MOVQ tq, tb
+       bit qa+3
        bmi _two
        #MOVQ ta, cn_a0                 ; A > 0: [lo, hi]
        #MOVQ tb, cn_b0
        bra _pieces
_two:
        #LDIMM NINF & $ffffffff, cn_a0  ; A < 0: (-inf, lo], [hi, inf)
        #MOVQ ta, cn_b0
        #MOVQ tb, cn_a1
        #LDIMM INF, cn_b1
        lda #2
        sta cn_n
_pieces:
        ; the first piece that the caps leave
        #MOVQ cn_a0, tn
        #MOVQ cn_b0, tf
        lda #0
        sta sn
        sta sf
        jsr caps
        #BGTQ tn, tf, +
        jmp pv_set
+       lda cn_n
        cmp #2
        bne +
        #MOVQ cn_a1, tn
        #MOVQ cn_b1, tf
        lda #0
        sta sn
        sta sf
        jsr caps
        jmp tn_tf_done
+       rts

iv_plane:
        #VSUB ray_o, cp_c, tv
        lda cp_flags
        and #F_ROT
        bne +
        #MOVQ tv+4, sl_o                ; oy, dy
        #MOVQ ray_d+4, sl_d
        bra _go
+       #DOT cp_r+12, tv, sl_o
        #DOT cp_r+12, ray_d, sl_d
_go:
        lda #0
        sta pv_s0
        sta pv_s1
        lda cp_own
        beq +
        #MOVQ q_zero, sl_o
+       #BNEZ sl_o, _off
        ; on the plane: moving out (dy > 0) leaves (-inf, 0]; moving in, [0, inf)
        bit sl_d+3
        bmi _in0
        #BEQZ sl_d, _none
        #LDIMM NINF & $ffffffff, pv_t0
        #MOVQ q_zero, pv_t1
        bra _one
_in0:
        #MOVQ q_zero, pv_t0
        #LDIMM INF, pv_t1
        bra _one
_off:
        #NEGQ sl_o, td_n                ; ts = -oy / dy
        #MOVQ sl_d, td_d
        jsr tdiv
        stq tt
        bit tt+3                        ; ts <= 0, or infinite: no crossing ahead
        bmi _const
        #BEQZ tt, _const
        lda tt+3
        cmp #>(INF >> 16)
        bne +
        lda tt+2
        cmp #<(INF >> 16)
        bne +
        lda tt+1
        cmp #>INF
        bne +
        lda tt
        cmp #<INF
        beq _const
+       bit sl_d+3
        bmi _cin
        #LDIMM NINF & $ffffffff, pv_t0  ; dy > 0: (-inf, ts]
        #MOVQ tt, pv_t1
        bra _one
_cin:
        #MOVQ tt, pv_t0                 ; dy < 0: [ts, inf)
        #LDIMM INF, pv_t1
        bra _one
_const:
        bit sl_o+3                      ; inside (oy < 0) all along, or never
        bpl _none
        #LDIMM NINF & $ffffffff, pv_t0
        #LDIMM INF, pv_t1
_one:
        lda #1
        sta pv_n
_none:
        rts

;---------------------------------------------------------------------------------------
; interval lists. List k is at ivl + k * IVL_SIZE: a count, then intervals of 12 bytes
; (t0, prim0, sub0, t1, prim1, sub1). sub bit 7 = flipped normal.
;---------------------------------------------------------------------------------------
; push pv (primitive cpi) as a list at slot lsp
pv_push:
        ldx lsp
        lda ivl_lo,x
        sta lp
        lda ivl_hi,x
        sta lp+1
        ldy #0
        lda pv_n
        sta (lp),y
        beq +
        ldy #1
        ldx #0
-       lda pv_t0,x
        sta (lp),y
        lda pv_t1,x
        phy
        pha
        tya
        clc
        adc #6
        tay
        pla
        sta (lp),y
        ply
        iny
        inx
        cpx #4
        bne -
        lda cpi
        ldy #5
        sta (lp),y
        ldy #11
        sta (lp),y
        lda pv_s0
        ldy #6
        sta (lp),y
        lda pv_s1
        ldy #12
        sta (lp),y
+       inc lsp
        rts

; event e (0..15) of the list at (pa) or (pb): ev_t, ev_p, ev_s
EVENT .macro ptr, idx
        ldx \idx
        ldy ev_off,x
        ldx #0
-       lda (\ptr),y
        sta ev_t,x
        iny
        inx
        cpx #4
        bne -
        lda (\ptr),y
        sta ev_p
        iny
        lda (\ptr),y
        sta ev_s
.endmacro
; the t of event e: Q and the dword at dst
EVT .macro ptr, idx, dst
        ldx \idx
        ldy ev_off,x
        ldx #0
-       lda (\ptr),y
        sta \dst,x
        iny
        inx
        cpx #4
        bne -
.endmacro

; combine: the lists at slots lsp-2 (A) and lsp-1 (B) with cb_op -> slot lsp-2; lsp - 1
combine:
        ldx lsp
        dex
        lda ivl_lo,x
        sta pb
        lda ivl_hi,x
        sta pb+1
        dex
        lda ivl_lo,x
        sta pa
        lda ivl_hi,x
        sta pa+1
        lda #<(ivl + (IVL_SLOTS - 1) * IVL_SIZE)
        sta pd
        lda #>(ivl + (IVL_SLOTS - 1) * IVL_SIZE)
        sta pd+1
        ldy #0
        lda (pa),y
        asl
        sta cb_na
        lda (pb),y
        asl
        sta cb_nb
        lda #0
        sta cb_ia
        sta cb_ib
        sta cb_in                       ; bit 1 = inside A, bit 0 = inside B
        sta cb_st
        sta cb_out
        lda cb_op                       ; the truth table of the operation
        sec
        sbc #OP_UNION
        asl
        asl
        sta cb_tab
_loop:
        lda cb_ia
        cmp cb_na
        bne _havea
        lda cb_ib
        cmp cb_nb
        bne _takeb
        jmp _end
_havea:
        lda cb_ib
        cmp cb_nb
        beq _takea
        #EVT pa, cb_ia, cb_ta
        #EVT pb, cb_ib, cb_tb
        #BLEQ cb_ta, cb_tb, _takea
_takeb:
        #EVENT pb, cb_ib
        lda cb_op
        cmp #OP_DIFF
        bne +
        lda ev_s
        eor #$80
        sta ev_s
+       lda cb_in
        eor #1
        sta cb_in
        inc cb_ib
        bra _state
_takea:
        #EVENT pa, cb_ia
        lda cb_in
        eor #2
        sta cb_in
        inc cb_ia
_state:
        lda cb_in
        clc
        adc cb_tab
        tax
        lda cb_truth,x
        cmp cb_st
        beq _loop
        sta cb_st
        cmp #0
        beq _close
        #MOVQ ev_t, cb_t0               ; an interval starts
        lda ev_p
        sta cb_p0
        lda ev_s
        sta cb_s0
        jmp _loop
_close:
        #BLEQ ev_t, cb_t0, _skip        ; zero length: dropped
        lda cb_out
        cmp #MAXIV
        bcs _skip
        tax
        ldy ev_off2,x                   ; 1 + 12 * out
        ldx #0
-       lda cb_t0,x
        sta (pd),y
        iny
        inx
        cpx #4
        bne -
        lda cb_p0
        sta (pd),y
        iny
        lda cb_s0
        sta (pd),y
        iny
        ldx #0
-       lda ev_t,x
        sta (pd),y
        iny
        inx
        cpx #4
        bne -
        lda ev_p
        sta (pd),y
        iny
        lda ev_s
        sta (pd),y
        inc cb_out
_skip:
        jmp _loop
_end:
        ; the result back into slot lsp-2
        ldy #0
        lda cb_out
        sta (pa),y
        ldx cb_out
        lda ev_off2,x                   ; bytes in use
        sta cb_len
        ldy #1
-       cpy cb_len
        beq +
        lda (pd),y
        sta (pa),y
        iny
        bra -
+       dec lsp
        rts

; inside A (bit 1), inside B (bit 0) -> inside the result, for UNION, INTER, DIFF
cb_truth:       .byte 0, 1, 1, 1,   0, 0, 0, 1,   0, 0, 1, 0
ev_off:         .byte 1 + 12 * (range(16) >> 1) + 6 * (range(16) & 1)
ev_off2:        .byte 1 + 12 * range(MAXIV + 1)
ivl_lo:         .byte <(ivl + range(IVL_SLOTS) * IVL_SIZE)
ivl_hi:         .byte >(ivl + range(IVL_SLOTS) * IVL_SIZE)

;---------------------------------------------------------------------------------------
; root_iv: the root at rp -> its intervals in slot 0 (a list), from the program
;---------------------------------------------------------------------------------------
root_iv:
        ldy #R_START
        lda (rp),y
        sta rpc
        lda #0
        sta lsp
_op:
        ldx rpc
        inc rpc
        lda sc_prog,x
        cmp #OP_END
        beq _done
        cmp #OP_UNION
        bcs _bin
        jsr prim_iv
        jsr pv_push
        bra _op
_bin:
        sta cb_op
        jsr combine
        bra _op
_done:
        rts

; bound_test: the root at rp has a bounding sphere: carry set if the ray may hit it
bound_test:
        ldy #R_BC
        ldx #0
-       lda (rp),y
        sta rb_c,x
        iny
        inx
        cpx #16
        bne -
        #VSUB rb_c, ray_o, sL
        #DOT sL, sL, sLL
        #BLEQ sLL, rb_r2, _yes          ; the origin is inside
        #DOT sL, ray_d, tca
        bit tca+3
        bmi _no
        #FMUL tca, tca, tq
        #SUBQ sLL, tq, d2
        #BLEQ d2, rb_r2, _yes
_no:
        clc
        rts
_yes:
        sec
        rts

; rp = root X
root_ptr:
        lda root_lo,x
        sta rp
        lda root_hi,x
        sta rp+1
        rts

; single: carry set if the root at rp is one primitive (A = it)
root_single:
        ldy #R_START
        lda (rp),y
        tax
        lda sc_prog+1,x
        cmp #OP_END
        bne +
        lda sc_prog,x
        sec
        rts
+       clc
        rts

;---------------------------------------------------------------------------------------
; intersect: nearest hit along the ray -> hit_p (NO_ID = none), hit_t, hit_s
;---------------------------------------------------------------------------------------
intersect:
        lda #NO_ID
        sta hit_p
        lda #0
        sta rk
_root:
        ldx rk
        cpx sc_nroot
        bne +
        rts
+       jsr root_ptr
        ldy #R_FLAGS
        lda (rp),y
        and #RF_BOUND
        beq +
        jsr bound_test
        bcc _next
+       jsr root_single
        bcc _list
        jsr prim_iv                     ; one primitive: its interval
        lda pv_n
        beq _next
        lda cpi
        sta ev_p
        #BLEQ pv_t0, q_eps, +
        #MOVQ pv_t0, ev_t
        lda pv_s0
        sta ev_s
        bra _cand
+       #BLEQ pv_t1, q_eps, _next
        #MOVQ pv_t1, ev_t
        lda pv_s1
        sta ev_s
        bra _cand
_list:
        jsr root_iv                     ; booleans: the first boundary beyond EPS
        lda ivl
        sta cb_out
        lda #0
        sta cb_ia
_iv:
        lda cb_ia
        cmp cb_out
        beq _next
        tax
        lda ev_off2,x
        sta cb_len
        tax
        ldy #0
-       lda ivl,x
        sta ev_t,y
        inx
        iny
        cpy #4
        bne -
        lda ivl,x
        sta ev_p
        lda ivl+1,x
        sta ev_s
        #BGTQ ev_t, q_eps, _cand
        ldx cb_len
        ldy #0
-       lda ivl+6,x
        sta ev_t,y
        inx
        iny
        cpy #4
        bne -
        lda ivl+6,x
        sta ev_p
        lda ivl+7,x
        sta ev_s
        #BGTQ ev_t, q_eps, _cand
        inc cb_ia
        bra _iv
_cand:
        lda hit_p                       ; nearer (or as near): take it
        cmp #NO_ID
        beq _take
        #BGTQ ev_t, hit_t, _next
_take:
        #MOVQ ev_t, hit_t
        lda ev_p
        sta hit_p
        lda ev_s
        sta hit_s
_next:
        inc rk
        jmp _root

;---------------------------------------------------------------------------------------
; occluded: carry set if anything is hit between EPS and sh_dist
;---------------------------------------------------------------------------------------
occluded:
        lda #0
        sta rk
_root:
        ldx rk
        cpx sc_nroot
        bne +
        clc
        rts
+       jsr root_ptr
        ldy #R_FLAGS
        lda (rp),y
        and #RF_NOSHADOW
        bne _next
        lda (rp),y
        and #RF_BOUND
        beq +
        jsr bound_test
        bcc _next
+       jsr root_single
        bcc _list
        jsr prim_iv
        lda pv_n
        beq _next
        #MOVQ pv_t0, ev_t
        jsr _between
        bcs _yes
        #MOVQ pv_t1, ev_t
        jsr _between
        bcs _yes
        bra _next
_list:
        jsr root_iv
        lda #<ivl
        sta pa
        lda #>ivl
        sta pa+1
        lda ivl
        asl
        sta cb_na                       ; events
        lda #0
        sta cb_ia
_ev:
        lda cb_ia
        cmp cb_na
        beq _next
        #EVT pa, cb_ia, ev_t
        jsr _between
        bcs _yes
        inc cb_ia
        bra _ev
_next:
        inc rk
        jmp _root
_yes:
        sec
        rts
; carry set if EPS < ev_t < sh_dist
_between:
        #BLEQ ev_t, q_eps, +
        #BLTQ ev_t, sh_dist, ++
+       clc
        rts
+       sec
        rts

;---------------------------------------------------------------------------------------
; the surface at the hit: normal (hit_n), material (cur_mat), colour (cm_dc)
;---------------------------------------------------------------------------------------
surface:
        lda hit_p
        jsr prim_load                   ; (sets cp_own too: unused here)
        ; the material
        ldx cp_mat
        lda mat_lo,x
        sta lp
        lda mat_hi,x
        sta lp+1
        ldy #0
-       lda (lp),y
        sta cur_mat,y
        iny
        cpy #M_USED
        bne -
        lda cp_type
        cmp #T_SPHERE
        bne _local
        #VSUB fr_p, cp_c, tv            ; sphere: N = (p - c) / r
        #VSCALE tv, cp_s+4, hit_n
        jmp _flip
_local:
        #VSUB fr_p, cp_c, tv
        lda cp_flags
        and #F_ROT
        bne +
        #VMOV tv, pl
        bra _shape
+       #DOT cp_r, tv, pl
        #DOT cp_r+12, tv, pl+4
        #DOT cp_r+24, tv, pl+8
_shape:
        #VMOV q_zero3, nl
        lda hit_s
        and #$7f
        sta tmp0
        lda cp_type
        cmp #T_BOX
        bne _nbox
        lda tmp0                        ; face 2a (-) or 2a + 1 (+) on axis a
        lsr
        asl
        asl
        tax
        lda tmp0
        and #1
        beq +
        lda #1                          ; + ONE
        sta nl+2,x
        bra _world
+       lda #$ff                        ; - ONE
        sta nl+2,x
        sta nl+3,x
        bra _world
_nbox:
        cmp #T_PLANE
        beq _up
        lda tmp0
        cmp #1
        beq _down
        cmp #2
        beq _up
        lda cp_type
        cmp #T_CYL
        bne _cone
        #FMUL pl, cp_s+8, nl            ; cylinder side: (x / r, 0, z / r)
        #FMUL pl+8, cp_s+8, nl+8
        bra _world
_cone:
        #FMUL cp_s+4, pl+4, tq          ; rho = a + b y
        #ADDQ cp_s, tq, rho0
        #LDIMM 16, tq
        #BLTQ rho0, tq, _apex
        #FDIV pl, rho0, tq              ; (x / rho, -b, z / rho) * k
        #FMUL tq, cp_s+12, nl
        #NEGQ cp_s+4, tq
        #FMUL tq, cp_s+12, nl+4
        #FDIV pl+8, rho0, tq
        #FMUL tq, cp_s+12, nl+8
        bra _world
_apex:
        bit cp_s+7                      ; (0, 1, 0) if b < 0, else (0, -1, 0)
        bmi _up
_down:
        lda #$ff
        sta nl+6
        sta nl+7
        bra _world
_up:
        lda #1
        sta nl+6
_world:
        lda cp_flags
        and #F_ROT
        bne +
        #VMOV nl, hit_n
        bra _flip
+       .for si = 0, si < 3, si += 1    ; N_j = nl . (column j of R)
        #FMUL nl, cp_r+si*4, tq
        #FMUL nl+4, cp_r+12+si*4, tv
        #ADDQ tq, tv, tq
        #FMUL nl+8, cp_r+24+si*4, tv
        #ADDQ tq, tv, hit_n+si*4
        .next
_flip:
        bit hit_s
        bpl +
        #NEGQ hit_n, hit_n
        #NEGQ hit_n+4, hit_n+4
        #NEGQ hit_n+8, hit_n+8
+       ; the colour
        lda cm_flags
        and #MF_CHECKER
        bne +
        #VMOV cm_c1, cm_dc
        rts
+       ldx hit_p                       ; the texture matrix and offset
        lda prim_lo,x
        clc
        adc #P_TEXA
        sta lp
        lda prim_hi,x
        adc #0
        sta lp+1
        ldy #0
-       lda (lp),y
        sta tex,y
        iny
        cpy #48
        bne -
        lda #0
        sta tmp0                        ; parity
        .for si = 0, si < 3, si += 1
        #DOT tex+si*12, fr_p, tq
        clc
        adq tex+36+si*4
        stq tq
        #LDIMM CHECK_TOL, tv
        clc
        ldq tq
        adq tv
        stq tq
        lda tq+2                        ; floor: the integer part's low bit
        eor tmp0
        sta tmp0
        .next
        lda tmp0
        and #1
        bne +
        #VMOV cm_c1, cm_dc
        rts
+       #VMOV cm_c2, cm_dc
        rts

;---------------------------------------------------------------------------------------
; refract cur_d through hit_n with the material's indices -> fr_tdir
;---------------------------------------------------------------------------------------
refract:
        #DOT cur_d, hit_n, rr_c
        #NEGQ rr_c, rr_c                ; cosi = -(i . n), clamped to [-1, 1]
        sec
        sbq q_one1
        bmi +
        #MOVQ q_one, rr_c
+       clc
        ldq rr_c
        adq q_one
        bpl +
        #NEGQ q_one, rr_c
+       bit rr_c+3
        bpl _enter
        #NEGQ hit_n, rr_n               ; leaving: flip the normal
        #NEGQ hit_n+4, rr_n+4
        #NEGQ hit_n+8, rr_n+8
        #NEGQ rr_c, rr_c
        #MOVQ cm_eta+8, rr_eta
        #MOVQ cm_eta+12, rr_eta2
        bra _go
_enter:
        #VMOV hit_n, rr_n
        #MOVQ cm_eta, rr_eta
        #MOVQ cm_eta+4, rr_eta2
_go:
        #FMUL rr_c, rr_c, tq            ; k = 1 - eta^2 (1 - cosi^2)
        #SUBQ q_one, tq, tq
        #FMUL rr_eta2, tq, tq
        #SUBQ q_one, tq, rr_k
        bit rr_k+3
        bpl +
        #MOVQ q_one, fr_tdir            ; total internal reflection: (1, 0, 0)
        #MOVQ q_zero, fr_tdir+4
        #MOVQ q_zero, fr_tdir+8
        rts
+       ldq rr_k
        jsr fsqrt
        stq tq
        #FMUL rr_eta, rr_c, rr_t        ; t = eta cosi - sqrt(k)
        sec
        sbq tq
        stq rr_t
        .for si = 0, si < 3, si += 1
        #FMUL cur_d+si*4, rr_eta, tq
        #FMUL rr_n+si*4, rr_t, rr_k
        #ADDQ tq, rr_k, fr_tdir+si*4
        .next
        rts

;---------------------------------------------------------------------------------------
; cast: colour seen along ray_o + t ray_d (from ray_from, at depth) -> rc
;---------------------------------------------------------------------------------------
cast:
        lda depth
        sta fr_depth
        jsr intersect
        lda hit_p
        cmp #NO_ID
        bne _hit
        #VMOV sc_bg, rc
        rts
_hit:
        sta fr_hid
        #VMOV ray_d, cur_d
        #VSCALE cur_d, hit_t, tv        ; point = o + d t
        #VADD ray_o, tv, fr_p
        jsr surface
        ; ---- lights: shadow rays from the hit point ----
        #VMOV fr_p, ray_o
        lda fr_hid
        sta ray_from
        #VMOV q_zero3, li_di
        #VMOV q_zero3, li_sp
        lda #0
        sta li_n
_light:
        lda li_n
        cmp sc_nlight
        bne +
        jmp _local
+       tax
        lda light_lo,x
        sta lp
        lda light_hi,x
        sta lp+1
        ldy #0
-       lda (lp),y
        sta li_pos,y
        iny
        cpy #LIGHT_SIZE
        bne -
        #VSUB li_pos, fr_p, li_v
        #DOT li_v, li_v, tq
        jsr fsqrt
        stq sh_dist
        #BEQZ sh_dist, _next             ; the light is at the point
        #FDIV li_v, sh_dist, ray_d      ; light direction (unit)
        #FDIV li_v+4, sh_dist, ray_d+4
        #FDIV li_v+8, sh_dist, ray_d+8
        #DOT ray_d, hit_n, li_dt
        bit li_dt+3
        bpl +
        #MOVQ q_zero, li_dt
+       #MOVQ q_zero, li_st
        #BEQZ cm_al+4, _nospec
        #REFLECT ray_d, hit_n, li_r
        #DOT li_r, cur_d, tq
        bit tq+3
        bmi _nospec
        #BEQZ tq, _nospec
        lda cm_ps
        sta pw_e
        lda cm_ps+1
        sta pw_e+1
        ldq tq
        jsr ppow
        stq li_st
_nospec:
        lda li_dt                       ; nothing to add: skip the shadow ray
        ora li_dt+1
        ora li_dt+2
        ora li_dt+3
        ora li_st
        ora li_st+1
        ora li_st+2
        ora li_st+3
        beq _next
        lda li_fl
        and #LF_SHADOWLESS
        bne +
        jsr occluded
        bcs _next
+       .for si = 0, si < 3, si += 1
        #FMUL li_col+si*4, li_dt, tq
        #ADDQ li_di+si*4, tq, li_di+si*4
        #FMUL li_col+si*4, li_st, tq
        #ADDQ li_sp+si*4, tq, li_sp+si*4
        .next
_next:
        inc li_n
        jmp _light
_local:
        ; ---- local colour: dc * (di * al0 + amb) + sp * al1 ----
        .for si = 0, si < 3, si += 1
        #FMUL li_di+si*4, cm_al, tq
        #ADDQ tq, cm_amb+si*4, tq
        #FMUL cm_dc+si*4, tq, tv
        #FMUL li_sp+si*4, cm_al+4, tq
        #ADDQ tv, tq, fr_col+si*4
        .next
        #MOVQ cm_al+8, fr_al2
        #MOVQ cm_al+12, fr_al3
        ; ---- refraction direction, before cur_d / hit_n are lost ----
        #BEQZ fr_al3, +
        lda fr_depth
        cmp sc_maxd
        bcs +
        jsr refract
+
        ; ---- reflection ----
        #BEQZ fr_al2, _norefl
        lda fr_depth
        cmp sc_maxd
        bcc +
        #VMOV sc_bg, rc                 ; too deep: the background
        bra _addrefl
+       #REFLECT cur_d, hit_n, ray_d
        jsr push_frame
        #VMOV fr_p, ray_o
        lda fr_hid
        sta ray_from
        ldx fr_depth
        inx
        stx depth
        jsr cast
        jsr pop_frame
_addrefl:
        .for si = 0, si < 3, si += 1
        #FMUL rc+si*4, fr_al2, tq
        #ADDQ fr_col+si*4, tq, fr_col+si*4
        .next
_norefl:
        ; ---- refraction ----
        #BEQZ fr_al3, _done
        lda fr_depth
        cmp sc_maxd
        bcc +
        #VMOV sc_bg, rc
        bra _addrefr
+       #VMOV fr_tdir, ray_d
        jsr push_frame
        #VMOV fr_p, ray_o
        lda fr_hid
        sta ray_from
        ldx fr_depth
        inx
        stx depth
        jsr cast
        jsr pop_frame
_addrefr:
        .for si = 0, si < 3, si += 1
        #FMUL rc+si*4, fr_al3, tq
        #ADDQ fr_col+si*4, tq, fr_col+si*4
        .next
_done:
        #VMOV fr_col, rc
        rts

; frames go on fr_stack (fr_sp = bytes in use)
push_frame:
        ldy fr_sp
        ldx #0
-       lda frame,x
        sta fr_stack,y
        inx
        iny
        cpx #FRAME_SIZE
        bne -
        sty fr_sp
        rts
pop_frame:
        sec
        lda fr_sp
        sbc #FRAME_SIZE
        sta fr_sp
        tay
        ldx #0
-       lda fr_stack,y
        sta frame,x
        inx
        iny
        cpx #FRAME_SIZE
        bne -
        rts

;---------------------------------------------------------------------------------------
; trace_pixel: (px_x 0..639, px_y 0..199) -> out_r, out_g, out_b
;---------------------------------------------------------------------------------------
trace_pixel:
        ; X = (2x + 1 - 640) * 64, Y = (199 - 2y) * 120, d = r X + u Y + f, normalised
        lda px_x
        asl
        sta tq
        lda px_x+1
        rol
        sta tq+1                        ; 2x
        sec
        lda tq
        sbc #<639
        sta tq
        lda tq+1
        sbc #>639
        sta tq+1                        ; 2x + 1 - 640 (signed 16)
        and #$80
        beq +
        lda #$ff
+       sta tq+2
        sta tq+3
        ldq tq
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        stq pv
        lda px_y                        ; (199 - 2y) * 120
        asl
        sta tq
        lda #0
        rol
        sta tq+1                        ; 2y
        sec
        lda #199
        sbc tq
        sta MULTINA
        lda #0
        sbc tq+1
        sta MULTINA+1                   ; signed 16 -> 32 bit
        and #$80
        beq +
        lda #$ff
+       sta MULTINA+2
        sta MULTINA+3
        lda #120
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        ldq MULTOUT                     ; (low 32 bits of the product are right signed)
        stq pv+4
        .for si = 0, si < 3, si += 1
        #FMUL sc_cam_r+si*4, pv, tq
        #FMUL sc_cam_u+si*4, pv+4, tv
        #ADDQ tq, tv, tq
        clc
        adq sc_cam_f+si*4
        stq pd3+si*4
        .next
        #DOT pd3, pd3, tq
        jsr fsqrt
        stq tv
        #FDIV pd3, tv, ray_d
        #FDIV pd3+4, tv, ray_d+4
        #FDIV pd3+8, tv, ray_d+8
        #VMOV sc_cam_o, ray_o
        lda #NO_ID
        sta ray_from
        lda #0
        sta depth
        jsr cast
        ; ---- 255 * c / max(1, r, g, b) ----
        #MOVQ q_one, tv
        .for si = 0, si < 3, si += 1
        sec
        ldq tv
        sbq rc+si*4
        bpl +
        #MOVQ rc+si*4, tv
+
        .next
        .for si = 0, si < 3, si += 1
        #MOVQ rc+si*4, tq
        lda #si
        sta tb_i
        jsr to_byte
        .next
        rts

; tq (16.16) -> out_r + tb_i: 0 if <= 0, else (tq * 255) / tv
to_byte:
        bit tq+3
        bmi _zero
        #BEQZ tq, _zero
        lda #0                          ; tq * 256 - tq
        sta pv
        lda tq
        sta pv+1
        lda tq+1
        sta pv+2
        lda tq+2
        sta pv+3
        sec
        ldq pv
        sbq tq
        stq MULTINA
        ldq tv
        stq MULTINB
-       bit DIVBUSY
        bmi -
        lda DIVOUT+5
        ora DIVOUT+6
        ora DIVOUT+7
        bne _max
        lda DIVOUT+4
        bra _put
_max:
        lda #255
        bra _put
_zero:
        lda #0
_put:
        ldx tb_i
        sta out_r,x
        rts

q_eps:          .dint EPS
q_one1:         .dint ONE + 1
q_zero3:        .dint 0, 0, 0
