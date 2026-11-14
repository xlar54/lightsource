;=======================================================================================
; model4.asm - the modeller's undo and redo: snapshots of the whole document (its bank-0
; part and the corner pool) in attic, U_N slots of 8 KB in a ring from U_ATTIC.
;
; The history is a line of snapshots, oldest first: ms_ui of them come before the state
; being edited, and ms_un - ms_ui after it (what Redo goes back to). u_save is called
; before each change; Undo keeps the current state (at the newest end, for Redo) and goes
; back one; Redo forward one. ms_ubase is the slot of the oldest: when all slots are used,
; the oldest is dropped.
;=======================================================================================

U_ATTIC         = $8340000
U_N             = 16
U_SLOT          = $2000
        .cerror DOC_SIZE + POOL_BYTES > U_SLOT, "an undo slot is too small for the document"

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
        lsr                             ; slot / 8: banks of 64 KB
        lsr
        lsr
        clc
        adc #(U_ATTIC >> 16) & $ff
        sta u_p+2
        lda #U_ATTIC >> 24
        sta u_p+3
        lda tmp0                        ; (slot & 7) * $2000
        and #7
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

st_undone:      .null "Undone"
st_redone:      .null "Redone"
st_noundo:      .null "Nothing to undo"
st_noredo:      .null "Nothing to redo"
u_dir:          .byte 0
u_p:            .dword 0
u_q:            .dword 0
u_r:            .dword 0
