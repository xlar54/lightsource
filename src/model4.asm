;=======================================================================================
; model4.asm - the modeller's undo and redo: snapshots of the whole document (its bank-0
; part and the corner pool) in attic, U_N slots of 16 KB in a ring from U_ATTIC.
;
; The history is a line of snapshots, oldest first: ms_ui of them come before the state
; being edited, and ms_un - ms_ui after it (what Redo goes back to). u_save is called
; before each change; Undo keeps the current state (at the newest end, for Redo) and goes
; back one; Redo forward one. ms_ubase is the slot of the oldest: when all slots are used,
; the oldest is dropped.
;=======================================================================================

U_ATTIC         = $8340000
U_N             = 16
U_SLOT          = $4000                 ; (u_slot: 4 to a 64 KB bank)
        .cerror DOC_SIZE + POOL_BYTES > U_SLOT, "an undo slot is too small for the document"
        .cerror ((U_ATTIC + U_N * U_SLOT - 1) >> 16) > $837, "the undo slots run past $8380000"

; before a change: the current state is kept (anything to redo is dropped)
u_save:
        lda ms_ui
        cmp #U_N
        bcc +
        jsr u_drop
+       lda ms_ui
        jsr u_store
        inc ms_ui
        lda ms_ui
        sta ms_un
        rts

; a u_save that turned out not to be needed (a cancelled Open): taken back
u_unsave:
        lda ms_ui
        beq +
        dec ms_ui
        lda ms_ui
        sta ms_un
+       rts

cmd_undo:
        lda ms_ui
        beq _none
        cmp ms_un
        bne _back
        cmp #U_N                        ; at the newest end: keep this state for Redo
        bcc +
        jsr u_drop
+       lda ms_ui
        jsr u_store
        lda ms_ui
        inc a
        sta ms_un
_back:  dec ms_ui
        lda ms_ui
        jsr u_load
        lda #<st_undone
        ldx #>st_undone
        jmp say
_none:  lda #<st_noundo
        ldx #>st_noundo
        jmp say

cmd_redo:
        lda ms_ui
        inc a
        cmp ms_un
        bcs _none
        sta ms_ui
        jsr u_load
        lda #<st_redone
        ldx #>st_redone
        jmp say
_none:  lda #<st_noredo
        ldx #>st_noredo
        jmp say

; the oldest snapshot goes (its slot is the next to be used)
u_drop:
        lda ms_ubase
        inc a
        and #U_N - 1
        sta ms_ubase
        dec ms_ui
        dec ms_un
        rts

; u_store / u_load: A = a snapshot (0 = the oldest kept) <-> the document
u_store:
        jsr u_slot
        lda #0
        jsr u_parts
        rts
u_load:
        jsr u_slot
        lda #1
        jsr u_parts
        ; the selection, if it is still there
        lda ms_sel
        cmp #DOC_MAXOBJ
        bcs +
        cmp doc_nobj
        bcc _ok
        bcs _off
+       cmp #$40
        bcc _ok
        cmp #$c0                        ; a material (being edited)
        bcc +
        cmp #$ff
        beq _ok
        and #$3f
        cmp doc_nmat
        bcc _ok
        bcs _off
+       cmp #$80
        bcs _ok
        and #$3f
        cmp doc_nlight
        bcc _ok
_off:   lda #$ff
        sta ms_sel
_ok:    lda #$ff
        sta ms_ptobj
        rts

; u_p = the slot of snapshot A (28-bit)
u_slot:
        clc
        adc ms_ubase
        and #U_N - 1
        sta tmp0
        lsr                             ; slot / 4: banks of 64 KB
        lsr
        clc
        adc #(U_ATTIC >> 16) & $ff
        sta u_p+2
        lda #U_ATTIC >> 24
        sta u_p+3
        lda tmp0                        ; (slot & 3) * $4000
        and #3
        asl
        asl
        asl
        asl
        asl
        asl
        sta u_p+1
        lda #0
        sta u_p
        rts

; the two parts between the document and the slot at u_p: A = 0 to the slot, 1 back
u_parts:
        sta u_dir
        ; doc_start .. doc_end (bank 0) <-> slot + 0
        lda #<doc_start
        sta u_q
        lda #>doc_start
        sta u_q+1
        lda #0
        sta u_q+2
        sta u_q+3
        #MOVQ u_p, u_r
        lda #<DOC_SIZE
        sta tmp5
        lda #>DOC_SIZE
        sta tmp5+1
        jsr u_copy
        ; the corner pool (attic) <-> slot + DOC_SIZE
        lda #<(FAR_ADDR + DOC_PTS)
        sta u_q
        lda #>(FAR_ADDR + DOC_PTS)
        sta u_q+1
        lda #(FAR_ADDR >> 16) & $ff
        sta u_q+2
        lda #FAR_ADDR >> 24
        sta u_q+3
        clc
        lda u_p
        adc #<DOC_SIZE
        sta u_r
        lda u_p+1
        adc #>DOC_SIZE
        sta u_r+1
        lda u_p+2
        sta u_r+2
        lda u_p+3
        sta u_r+3
        lda #<POOL_BYTES
        sta tmp5
        lda #>POOL_BYTES
        sta tmp5+1
; u_q -> u_r (u_dir = 0) or u_r -> u_q, tmp5 bytes
u_copy:
        ldx #3
-       lda u_dir
        bne +
        lda u_q,x
        sta ptr1,x
        lda u_r,x
        sta ptr2,x
        bra ++
+       lda u_r,x
        sta ptr1,x
        lda u_q,x
        sta ptr2,x
+       dex
        bpl -
        jmp dma_copy_far

;---------------------------------------------------------------------------------------
; Indent and Outdent keep the object where it is (cmd_depth): kp_before, with the object in
; A, keeps its world transform and its parent's; kp_after (the depths changed) works out
; its position, turn and scale in the new parent's frame. Its parts follow it (theirs are
; relative to it). Matrices are wm's: rows of A at 12 r, t at 36; A = R s (uniform s).
;   position  p_j = (col_j(P) . (t_O - t_P)) / (col_j(P) . col_j(P))
;   scale     the old one times |old parent| / |new parent|
;   turn      unchanged when both parents turn alike; else from N = P^T O (its scale
;             doesn't matter: A = Rz Ry Rx s, so RX = atan2(N21, N22), RY = atan2(-N20,
;             sqrt(N00^2 + N10^2)), RZ = atan2(N10, N00))
;---------------------------------------------------------------------------------------
kp_before:
        sta kp_i
        jsr world_all
        lda kp_i
        jsr wm_ptr
        ldy #47
-       lda (pa),y
        sta kp_o,y
        dey
        bpl -
        jsr kp_frame                    ; the parent's (kp_p), kept as kp_q
        ldx #47
-       lda kp_p,x
        sta kp_q,x
        dex
        bpl -
        rts

kp_after:
        jsr kp_frame                    ; the new parent's
        ldx kp_i
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ; the position: p_j = col_j . v / col_j . col_j
        #VSUB kp_o+36, kp_p+36, kp_v
        lda #0
        sta kp_j
_pos:   jsr kp_pcol                     ; kp_c = column j of P
        jsr kp_c2d
        jsr kp_dot
        stq kp_t2
        #VMOV kp_v, kp_d
        jsr kp_dot
        stq tq
        #FDIV tq, kp_t2, tq
        lda kp_j
        clc
        adc #O_POS
        tay
        jsr kp_store
        jsr kp_jnext
        bne _pos
        ; the two parents' sizes: |col 0|
        lda #<kp_q
        ldx #>kp_q
        jsr kp_len
        stq kp_sq
        lda #<kp_p
        ldx #>kp_p
        jsr kp_len
        stq kp_sp
        ; do they turn alike? (each entry over its size, within 1/256)
        lda #0
        sta kp_k
_alike: ldx kp_k                        ; (the Q macros change X: kp_k counts)
        ldy #0
-       lda kp_q,x
        sta kp_t,y
        lda kp_p,x
        sta kp_t2,y
        inx
        iny
        cpy #4
        bne -
        #FDIV kp_t, kp_sq, kp_t
        #FDIV kp_t2, kp_sp, kp_t2
        #SUBQ kp_t, kp_t2, kp_t
        #ABSQ kp_t, kp_t
        #LDIMM ONE / 256, tq
        #BLTQ kp_t, tq, +
        jmp _turn
+       lda kp_k
        clc
        adc #4
        sta kp_k
        cmp #36
        bne _alike
        ; alike: the angles stay; the scale times |old| / |new| (if they differ)
        #SUBQ kp_sq, kp_sp, tq
        #BEQZ tq, _done
        ldy #O_SCALE
        jsr kp_load
        #FMUL kp_t, kp_sq, kp_t
        #FDIV kp_t, kp_sp, tq
        ldy #O_SCALE
        jsr kp_round
_done:  rts
_turn:  ; N = P^T O: N[i][j] = col_i(P) . col_j(O) (at kp_n + 12 i + 4 j)
        lda #0
        sta kp_j
_ni:    lda #0
        sta kp_k
_nj:    jsr kp_pcol                     ; column i of P
        jsr kp_c2d
        lda #<kp_o                      ; column j of O
        ldx #>kp_o
        ldy kp_k
        jsr kp_colof
        jsr kp_dot
        stq kp_t
        lda kp_j                        ; 12 i + 4 j = 3 (4 i) + 4 j
        asl
        clc
        adc kp_j
        adc kp_k
        tax
        ldy #0
-       lda kp_t,y
        sta kp_n,x
        inx
        iny
        cpy #4
        bne -
        lda kp_k
        clc
        adc #4
        sta kp_k
        cmp #12
        bne _nj
        jsr kp_jnext
        bne _ni
        ; RY = atan2(-N20, sqrt(N00^2 + N10^2))
        #FMUL kp_n, kp_n, tq
        #FMUL kp_n+12, kp_n+12, kp_t
        #ADDQ tq, kp_t, tq
        jsr fsqrt
        stq at_x
        #NEGQ kp_n+24, at_y
        jsr kp_atan
        ldy #O_ROT + 4
        jsr kp_round
        #LDIMM 64, tq                   ; (straight up or down: RZ 0, RX from the rest)
        #BLTQ at_x, tq, _gimbal
        #MOVQ kp_n+28, at_y             ; RX = atan2(N21, N22)
        #MOVQ kp_n+32, at_x
        jsr kp_atan
        ldy #O_ROT
        jsr kp_round
        #MOVQ kp_n+12, at_y             ; RZ = atan2(N10, N00)
        #MOVQ kp_n, at_x
        jsr kp_atan
        ldy #O_ROT + 8
        jsr kp_round
        bra _scale
_gimbal:
        #NEGQ kp_n+20, at_y             ; RX = atan2(-N12, N11)
        #MOVQ kp_n+16, at_x
        jsr kp_atan
        ldy #O_ROT
        jsr kp_round
        #MOVQ q_zero, tq
        ldy #O_ROT + 8
        jsr kp_round
_scale: lda #<kp_o                      ; the scale: |O| / |new parent|
        ldx #>kp_o
        jsr kp_len
        stq kp_t
        #FDIV kp_t, kp_sp, tq
        ldy #O_SCALE
        jmp kp_round

; kp_c = column kp_j / 4 of kp_p; kp_colof: of the matrix at A/X, column Y / 4
kp_pcol:
        lda #<kp_p
        ldx #>kp_p
        ldy kp_j
kp_colof:
        sty kp_t
        clc
        adc kp_t
        sta _s+1
        txa
        adc #0
        sta _s+2
        ldx #11
-       ldy kp_offs,x
_s:     lda $ffff,y                     ; (self-modified)
        sta kp_c,x
        dex
        bpl -
        rts
kp_offs:        .byte 0, 1, 2, 3, 12, 13, 14, 15, 24, 25, 26, 27
kp_c2d:
        ldx #11
-       lda kp_c,x
        sta kp_d,x
        dex
        bpl -
        rts
; Q = kp_c . kp_d
kp_dot:
        #DOT kp_c, kp_d, tq
        rts
; kp_j += 4; Z set at 12
kp_jnext:
        lda kp_j
        clc
        adc #4
        sta kp_j
        cmp #12
        rts
; kp_p = the world transform of object kp_i's parent (the nearest one before it a level
; up), or the identity at the top level
kp_frame:
        ldx #47
        lda #0
-       sta kp_p,x
        dex
        bpl -
        lda #1
        sta kp_p+2
        sta kp_p+16+2
        sta kp_p+32+2
        ldx kp_i
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        ldy #O_DEPTH
        lda (op),y
        beq _r
        sec
        sbc #1
        sta kp_t
-       dex
        bmi _r
        lda obj_lo,x
        sta op
        lda obj_hi,x
        sta op+1
        lda (op),y
        cmp kp_t
        bne -
        txa
        jsr wm_ptr
        ldy #47
-       lda (pa),y
        sta kp_p,y
        dey
        bpl -
_r:     rts

; Q = atan2(at_y, at_x) (degrees): overlay 6's fatan2 (at_x, at_y, at_r are resident)
kp_atan:
        #FAR OVL_PANEL, fatan2
        ldq at_r
        rts

; Q = |column 0| of the matrix at A/X
kp_len:
        ldy #0
        jsr kp_colof
        jsr kp_c2d
        jsr kp_dot
        jmp fsqrt
; kp_round: tq to the nearest 1/256 (angles and scales come back whole, not 29.99997),
; then kp_store
kp_round:
        lda tq
        clc
        adc #$80
        bcc +
        inc tq+1
        bne +
        inw tq+2
+       lda #0
        sta tq
; tq -> the object's dword at Y; kp_t <- it
kp_store:
        ldx #0
-       lda tq,x
        sta (op),y
        iny
        inx
        cpx #4
        bne -
        rts
kp_load:
        ldx #0
-       lda (op),y
        sta kp_t,x
        iny
        inx
        cpx #4
        bne -
        rts

kp_i:           .byte 0
kp_k:           .byte 0
kp_j:           .byte 0
kp_o:           .fill 48                ; the object's world transform (before)
kp_q:           .fill 48                ; its old parent's
kp_p:           .fill 48                ; its new parent's
kp_n:           .fill 36
kp_v:           .fill 12
kp_c:           .fill 12
kp_d:           .fill 36
kp_t:           .dword 0
kp_t2:          .dword 0
kp_sq:          .dword 0
kp_sp:          .dword 0

st_undone:      .null "Undone"
st_redone:      .null "Redone"
st_noundo:      .null "Nothing to undo"
st_noredo:      .null "Nothing to redo"
u_dir:          .byte 0
u_p:            .dword 0
u_q:            .dword 0
u_r:            .dword 0
