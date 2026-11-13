;=======================================================================================
; trace.asm - the ray tracer (after ssloy/tinyraytracer), in 16.16 fixed point.
;
; Mirrors private/tools/ref_trace.py step for step (cast, scene, occluded, plane_t,
; sphere_t, refract), so the RGB it produces is bit-identical to the model's.
;
;   trace_pixel   ray through pixel (px_x, px_y) -> out_r, out_g, out_b (0..255)
;
; Rays: ray_o (origin), ray_d (unit direction), ray_from (the object the ray leaves, so
; it can't hit itself through rounding; NO_ID for camera rays). set_origin caches
; L = centre - origin and L.L per sphere, shared by every ray from one point.
;
; cast recurses for reflections and refractions (up to MAXDEPTH), saving its frame (fr_*)
; on a small stack of its own. Its result is in rc (r, g, b, 16.16).
;=======================================================================================

EPS             = 66                    ; 0.001: the original's "t > .001"

;---------------------------------------------------------------------------------------
; sphere test, unrolled per sphere. Ray in ray_d, origin cache from set_origin.
; shadow = 0: nearest hit -> best_t / hit_id.  shadow = 1: t < sh_dist -> jmp occ_yes
;---------------------------------------------------------------------------------------
SPHTEST .macro i, shadow
        #DOT sph_L+\i*12, ray_d, tca
        lda ray_from
        cmp #\i
        bne _other
        ldq tca                         ; leaving this sphere: t0 = 0, t1 = 2 tca
        #ASLQ_Q
        stq tt
        sec
        sbq q_eps1
        bpl _cand
        jmp _miss
_other:
        bit tca+3
        bpl _front
        sec                             ; tca < 0 and the origin outside: miss
        ldq sph_LL+\i*4
        sbq sph_r2+\i*4
        bmi _front
        stq tq
        lda tq
        ora tq+1
        ora tq+2
        ora tq+3
        beq _front
        jmp _miss
_front:
        #FMUL tca, tca, tq
        #SUBQ sph_LL+\i*4, tq, d2       ; d2 = L.L - tca^2
        sec
        sbq sph_r2+\i*4                 ; d2 > r2: miss
        bmi _in
        stq tq
        lda tq
        ora tq+1
        ora tq+2
        ora tq+3
        beq _in
        jmp _miss
_in:
        #SUBQ sph_r2+\i*4, d2, tq
        jsr fsqrt
        stq thc
        #SUBQ tca, thc, tt              ; t0
        sec
        sbq q_eps1
        bpl _cand
        #ADDQ tca, thc, tt              ; t1
        sec
        sbq q_eps1
        bpl _cand
        jmp _miss
_cand:
        .if \shadow
        sec
        ldq tt
        sbq sh_dist
        bpl _miss
        jmp occ_yes
        .else
        lda hit_id
        cmp #NO_ID
        beq _take
        sec                             ; t > best: keep the old one
        ldq best_t
        sbq tt
        bmi _miss
_take:
        #MOVQ tt, best_t
        lda #\i
        sta hit_id
        .endif
_miss:
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

; copy n bytes (n <= 128... any n < 256)
COPYB .macro src, dst, n
        ldx #0
-       lda \src,x
        sta \dst,x
        inx
        cpx #\n
        bne -
.endmacro

;---------------------------------------------------------------------------------------
; set_origin: per sphere L = c - ray_o, LL = L.L
;---------------------------------------------------------------------------------------
set_origin:
        .for si = 0, si < NSPH, si += 1
        #VSUB sph_c+si*12, ray_o, sph_L+si*12
        #DOT sph_L+si*12, sph_L+si*12, sph_LL+si*4
        .next
        rts

;---------------------------------------------------------------------------------------
; plane_test: carry set = the ray hits the checkerboard at pl_t (pl_x, pl_z)
;---------------------------------------------------------------------------------------
plane_test:
        .if PLANE_ON == 0
        clc
        rts
        .endif
        lda ray_from
        cmp #PLANE_ID
        bne +
        jmp _no
+       #MOVQ ray_d+4, pl_ady           ; |dy| <= EPS: parallel
        bit pl_ady+3
        bpl +
        #NEGQ pl_ady, pl_ady
+       sec
        ldq pl_ady
        sbq q_eps1
        bpl +
        jmp _no
+       sec                             ; num = -(o.y - PLANE_Y)
        ldq ray_o+4
        sbq q_plane_y
        stq pl_num
        #NEGQ pl_num, pl_num
        lda pl_num
        ora pl_num+1
        ora pl_num+2
        ora pl_num+3
        bne +
        jmp _no
+       lda pl_num+3                    ; d = num / dy <= 0
        eor ray_d+7
        bpl +
        jmp _no
+       #MOVQ pl_num, pl_anum           ; |num| >= |dy| * 128: too far
        bit pl_anum+3
        bpl +
        #NEGQ pl_anum, pl_anum
+       ldq pl_ady
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        #ASLQ_Q
        stq pl_lim
        sec
        ldq pl_anum
        sbq pl_lim
        bmi +
        jmp _no
+       #FDIV pl_num, ray_d+4, pl_t
        sec
        sbq q_eps1
        bpl +
        jmp _no
+       #FMUL ray_d, pl_t, pl_x
        clc
        adq ray_o
        stq pl_x
        #FMUL ray_d+8, pl_t, pl_z
        clc
        adq ray_o+8
        stq pl_z
        ; -PLANE_XMAX < x < PLANE_XMAX, PLANE_ZMIN < z < PLANE_ZMAX
        sec
        ldq pl_x
        sbq q_plane_x                   ; x >= xmax
        bmi +
        jmp _no
+       clc
        ldq pl_x
        adq q_plane_x                   ; x <= -xmax
        bmi _no
        stq tq
        lda tq
        ora tq+1
        ora tq+2
        ora tq+3
        beq _no
        sec
        ldq pl_z
        sbq q_plane_z1                  ; z >= zmax
        bpl _no
        sec
        ldq pl_z
        sbq q_plane_z0                  ; z <= zmin
        bmi _no
        stq tq
        lda tq
        ora tq+1
        ora tq+2
        ora tq+3
        beq _no
        sec
        rts
_no:
        clc
        rts

;---------------------------------------------------------------------------------------
; intersect: nearest hit of ray_o + t ray_d -> hit_id (NO_ID = none), best_t, hit_chk
;---------------------------------------------------------------------------------------
intersect:
        lda #NO_ID
        sta hit_id
        jsr plane_test
        bcc _noplane
        #MOVQ pl_t, best_t
        lda #PLANE_ID
        sta hit_id
        ; checker: (int(x / 2 + 1000) + int(z / 2)) odd. int() truncates towards zero, so
        ; the parity is bit 17 of x xor bit 17 of |z|
        #MOVQ pl_z, tq
        bit tq+3
        bpl +
        #NEGQ pl_z, tq
+       lda tq+2
        eor pl_x+2
        and #2
        sta hit_chk
_noplane:
        .for si = 0, si < NSPH, si += 1
        #SPHTEST si, 0
        .next
        rts

;---------------------------------------------------------------------------------------
; occluded: carry set if anything is hit closer than sh_dist
;---------------------------------------------------------------------------------------
occluded:
        jsr plane_test
        bcc +
        sec
        ldq pl_t
        sbq sh_dist
        bpl +
        jmp occ_yes
+
        .for si = 0, si < NSPH, si += 1
        #SPHTEST si, 1
        .next
        clc
        rts
occ_yes:
        sec
        rts

;---------------------------------------------------------------------------------------
; refract cur_d through hit_n (glass) -> fr_tdir
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
        #NEGQ hit_n, rr_n               ; leaving the glass: flip the normal
        #NEGQ hit_n+4, rr_n+4
        #NEGQ hit_n+8, rr_n+8
        #NEGQ rr_c, rr_c
        #MOVQ eta_out, rr_eta
        #MOVQ eta2_out, rr_eta2
        bra _go
_enter:
        #VMOV hit_n, rr_n
        #MOVQ eta_in, rr_eta
        #MOVQ eta2_in, rr_eta2
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
        jsr set_origin
        jsr intersect
        lda hit_id
        cmp #NO_ID
        bne _hit
        #VMOV bg_col, rc
        rts
_hit:
        sta fr_hid
        #VMOV ray_d, cur_d
        #VSCALE cur_d, best_t, tv       ; point = o + d t
        #VADD ray_o, tv, fr_p
        lda fr_hid
        cmp #PLANE_ID
        bne _sphere
        ldx #0                          ; the board: material, checker colour, up
-       lda mat_tbl+M_PLANE*MATREC,x
        sta cur_mat,x
        inx
        cpx #MATREC
        bne -
        ldx #0
        lda hit_chk
        beq _chkb
-       lda check_a,x
        sta cm_dc,x
        inx
        cpx #12
        bne -
        bra _chkd
_chkb:
-       lda check_b,x
        sta cm_dc,x
        inx
        cpx #12
        bne -
_chkd:
        #MOVQ q_zero, hit_n
        #MOVQ q_one, hit_n+4
        #MOVQ q_zero, hit_n+8
        jmp _lit
_sphere:
        tax                             ; material record
        lda sph_mat,x
        asl
        asl
        asl
        asl
        asl
        tax
        ldy #0
-       lda mat_tbl,x
        sta cur_mat,y
        inx
        iny
        cpy #MATREC
        bne -
        lda fr_hid                      ; centre and 1 / r of sphere i
        asl
        asl
        sta tmp0
        tax
        ldy #0
-       lda sph_ir,x
        sta s_ir,y
        inx
        iny
        cpy #4
        bne -
        lda tmp0
        asl
        adc tmp0                        ; i * 12
        tax
        ldy #0
-       lda sph_c,x
        sta s_c,y
        inx
        iny
        cpy #12
        bne -
        #VSUB fr_p, s_c, tv             ; N = (p - c) / r
        #VSCALE tv, s_ir, hit_n
_lit:
        ; ---- lights: shadow rays from the hit point ----
        #VMOV fr_p, ray_o
        lda fr_hid
        sta ray_from
        jsr set_origin
        #MOVQ q_zero, li_di
        #MOVQ q_zero, li_sp
        lda #0
        sta li_n
_light:
        lda li_n
        asl
        adc li_n
        asl
        asl                             ; light * 12
        tax
        ldy #0
-       lda light_pos,x
        sta li_pos,y
        inx
        iny
        cpy #12
        bne -
        #VSUB li_pos, fr_p, li_v
        #DOT li_v, li_v, tq
        jsr fsqrt
        stq sh_dist
        #FDIV li_v, sh_dist, ray_d      ; light direction (unit)
        #FDIV li_v+4, sh_dist, ray_d+4
        #FDIV li_v+8, sh_dist, ray_d+8
        #DOT ray_d, hit_n, li_dt
        bit li_dt+3
        bpl +
        #MOVQ q_zero, li_dt
+       #MOVQ q_zero, li_st
        lda cm_al+4
        ora cm_al+5
        ora cm_al+6
        ora cm_al+7
        beq _nospec
        #REFLECT ray_d, hit_n, li_r
        #DOT li_r, cur_d, tq
        bit tq+3
        bmi _nospec
        lda tq
        ora tq+1
        ora tq+2
        ora tq+3
        beq _nospec
        lda cm_se
        sta pw_e
        lda cm_se+1
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
        jsr occluded
        bcs _next
        #ADDQ li_di, li_dt, li_di
        #ADDQ li_sp, li_st, li_sp
_next:
        inc li_n
        lda li_n
        cmp #NLIGHT
        beq +
        jmp _light
+
        ; ---- local colour: dc * (di * al0) + sp * al1 ----
        #FMUL li_di, cm_al, li_dt
        #FMUL li_sp, cm_al+4, li_st
        .for si = 0, si < 3, si += 1
        #FMUL cm_dc+si*4, li_dt, tq
        #ADDQ tq, li_st, fr_col+si*4
        .next
        #MOVQ cm_al+8, fr_al2
        #MOVQ cm_al+12, fr_al3
        ; ---- refraction direction, before cur_d / hit_n are lost ----
        lda fr_al3
        ora fr_al3+1
        ora fr_al3+2
        ora fr_al3+3
        beq +
        lda fr_depth
        cmp #MAXDEPTH
        bcs +
        jsr refract
+
        ; ---- reflection ----
        lda fr_al2
        ora fr_al2+1
        ora fr_al2+2
        ora fr_al2+3
        beq _norefl
        lda fr_depth
        cmp #MAXDEPTH
        bcc +
        #VMOV bg_col, rc                ; too deep: the background
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
        lda fr_al3
        ora fr_al3+1
        ora fr_al3+2
        ora fr_al3+3
        beq _done
        lda fr_depth
        cmp #MAXDEPTH
        bcc +
        #VMOV bg_col, rc
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
        ; d = ((2x + 1 - 640) * 64, (199 - 2y) * 120, DZ), normalised
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
        #LDIMM DZ & $ffffffff, pv+8
        #DOT pv, pv, tq
        jsr fsqrt
        stq tv
        #FDIV pv, tv, ray_d
        #FDIV pv+4, tv, ray_d+4
        #FDIV pv+8, tv, ray_d+8
        #VMOV cam_pos, ray_o
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
        lda tq
        ora tq+1
        ora tq+2
        ora tq+3
        beq _zero
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

q_eps1:         .dint EPS + 1
q_one1:         .dint ONE + 1
