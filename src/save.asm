;=======================================================================================
; save.asm - overlay 3: the picture to disk as an IFF ILBM (kstream, a SEQ file).
;
;   save_iff       framebuffer 0 with the palette in the VIC-IV -> sv_name (zero-terminated,
;                  as typed: upper case), replacing a file of that name. Carry set if it
;                  failed: sv_err = the drive's status.
;
; FORM ILBM: BMHD (640 x 200, 8 planes, ByteRun1, aspect 8:15 - a 640x200 pixel is 1.875
; times taller than wide), CMAP (256 colours), CAMG (hi-res), BODY. Each row is cut into
; its 8 bitplanes (80 bytes each), and each plane's row is compressed by itself.
; Writing is one pass: kstream can't go back, so a first pass only counts the BODY's size.
; Keep this overlay below $C000: the DOS may use $C000-$C3FF while it works.
;=======================================================================================

save_iff:
        ; pass 1: the BODY's size
        lda #0
        sta sv_write_on
        jsr sv_body
        ldx #2                          ; (sv_size goes on counting the header's bytes)
-       lda sv_size,x
        sta sv_bsize,x
        dex
        bpl -
        ; the file
        lda #<sv_name
        ldx #>sv_name
        jsr kst_remove
        ldy #0
        lda #<sv_name
        ldx #>sv_name
        jsr kst_name_put
        lda #<sv_mode
        ldx #>sv_mode
        jsr kst_name_raw
        tya
        jsr kst_open
        bcc +
        jmp _fail
+       lda #0
        sta kst_count
        lda #1
        sta sv_write_on
        ; FORM size = 4 ("ILBM") + 8 + 20 (BMHD) + 8 + 768 (CMAP) + 8 + 4 (CAMG) + 8 + body
        ; (+ 1 if the body is odd: chunks are padded to even)
        lda sv_bsize
        and #1
        sta sv_pad
        clc
        lda sv_bsize
        adc #<(4 + 28 + 776 + 12 + 8)
        sta sv_form
        lda sv_bsize+1
        adc #>(4 + 28 + 776 + 12 + 8)
        sta sv_form+1
        lda sv_bsize+2
        adc #0
        sta sv_form+2
        clc
        lda sv_form
        adc sv_pad
        sta sv_form
        bcc +
        inc sv_form+1
        bne +
        inc sv_form+2
+       lda #<sv_form_id
        ldx #>sv_form_id
        jsr sv_text4
        lda #0                          ; size, big-endian
        jsr sv_out
        lda sv_form+2
        jsr sv_out
        lda sv_form+1
        jsr sv_out
        lda sv_form
        jsr sv_out
        ldx #0                          ; "ILBM", BMHD, "CMAP" + its size
-       lda sv_hdr,x
        phx
        jsr sv_out
        plx
        inx
        cpx #sv_hdr_len
        bne -
        ; the palette, nibble-swapped back: red, green, blue
        lda #0
        sta sv_i
-       ldx sv_i
        lda $d100,x
        jsr sv_unswap
        jsr sv_out
        ldx sv_i
        lda $d200,x
        jsr sv_unswap
        jsr sv_out
        ldx sv_i
        lda $d300,x
        jsr sv_unswap
        jsr sv_out
        inc sv_i
        bne -
        ldx #0                          ; CAMG, "BODY"
-       lda sv_hdr2,x
        phx
        jsr sv_out
        plx
        inx
        cpx #sv_hdr2_len
        bne -
        lda #0
        jsr sv_out
        lda sv_bsize+2
        jsr sv_out
        lda sv_bsize+1
        jsr sv_out
        lda sv_bsize
        jsr sv_out
        ; pass 2: the BODY itself
        jsr sv_body
        lda sv_pad
        beq +
        lda #0
        jsr sv_out
+       jsr sv_flush
        jsr kst_close
        jsr kst_status                  ; 00 = fine
        sta sv_err
        cmp #0
        bne _bad
        clc
        rts
_fail:
        jsr kst_status
        sta sv_err
_bad:
        sec
        rts

; the 4 characters at A/X
sv_text4:
        sta tmp6
        stx tmp6+1
        ldy #0
-       lda (tmp6),y
        phy
        jsr sv_out
        ply
        iny
        cpy #4
        bne -
        rts

;---------------------------------------------------------------------------------------
; sv_body: every row, top to bottom: its 8 planes, each compressed. sv_size counts the bytes
; (both passes); they are written only when sv_write_on is set.
;---------------------------------------------------------------------------------------
sv_body:
        lda #0
        sta sv_size
        sta sv_size+1
        sta sv_size+2
        sta sv_y
_row:
        jsr sv_planes
        lda #0
        sta sv_p
-       jsr sv_pack
        inc sv_p
        lda sv_p
        cmp #8
        bne -
        inc sv_y
        lda sv_y
        cmp #200
        bne _row
        rts

; row sv_y of framebuffer 0 -> sv_pl: plane p at sv_pl + 80 p, bit 7 = the leftmost pixel
sv_planes:
        lda sv_y                        ; ptr0 = $40000 + (y >> 3) * 5120 + (y & 7) * 8
        and #7
        asl
        asl
        asl
        sta ptr0
        lda sv_y
        lsr
        lsr
        lsr
        tax
        lda sv_row_lo,x
        sta ptr0+1
        lda sv_row_hi,x
        clc
        adc #`F640_BUF0
        sta ptr0+2
        lda #0
        sta ptr0+3
        lda #0
        sta sv_k                        ; the byte (8 pixels) in each plane's row
_cell:
        ldz #0
-       lda [ptr0],z                    ; each pixel's bits into the 8 planes' bytes
        lsr
        rol sv_b
        lsr
        rol sv_b+1
        lsr
        rol sv_b+2
        lsr
        rol sv_b+3
        lsr
        rol sv_b+4
        lsr
        rol sv_b+5
        lsr
        rol sv_b+6
        lsr
        rol sv_b+7
        inz
        cpz #8
        bne -
        ldx sv_k
        .for si = 0, si < 8, si += 1
        lda sv_b+si
        sta sv_pl+si*80,x
        .next
        clc                             ; the next cell: + 64
        lda ptr0
        adc #64
        sta ptr0
        bcc +
        inc ptr0+1
        bne +
        inc ptr0+2
+       inc sv_k
        lda sv_k
        cmp #80
        bne _cell
        ldz #0
        rts

; ByteRun1 of plane sv_p's 80 bytes: a run of 3 to 128 equal bytes is (257 - n, byte);
; anything else is literals (n - 1, n bytes), up to 128, stopping before such a run
sv_pack:
        ldx sv_p
        lda sv_plo,x
        sta tmp6
        lda sv_phi,x
        sta tmp6+1
        lda #0
        sta sv_i                        ; i
_next:
        lda sv_i
        cmp #80
        bne +
        rts
+       jsr sv_runlen                   ; A = the run of equal bytes at i
        cmp #3
        bcc _lit
        sta sv_n                        ; a repeat: 257 - n, the byte
        sec
        lda #1                          ; (257 - n) & 255 = 1 - n
        sbc sv_n
        jsr sv_out
        ldy sv_i
        lda (tmp6),y
        jsr sv_out
        clc
        lda sv_i
        adc sv_n
        sta sv_i
        bra _next
_lit:   ; literals from i to k (exclusive): k grows until a run of 3, the end, or 128
        lda sv_i
        sta sv_s
_k:
        inc sv_i
        lda sv_i
        cmp #80
        beq _emit
        sec
        sbc sv_s
        cmp #128
        beq _emit
        jsr sv_runlen
        cmp #3
        bcc _k
_emit:
        sec                             ; n - 1, then the n bytes
        lda sv_i
        sbc sv_s
        sta sv_n
        dec a
        jsr sv_out
        ldy sv_s
-       lda (tmp6),y
        phy
        jsr sv_out
        ply
        iny
        cpy sv_i
        bne -
        bra _next

; A = how many bytes from i on equal the one at i (1 to 128, not past the row)
sv_runlen:
        ldy sv_i
        lda (tmp6),y
        sta sv_c
        ldx #1
-       iny
        cpy #80
        beq +
        lda (tmp6),y
        cmp sv_c
        bne +
        inx
        cpx #128
        bne -
+       txa
        rts

; A -> the file (pass 2) and counted (both passes)
sv_out:
        inc sv_size
        bne +
        inc sv_size+1
        bne +
        inc sv_size+2
+       ldx sv_write_on
        beq +
        ldx kst_count                   ; through KS_BUF, 255 bytes at a time
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
sv_flush:
        lda kst_count
        beq +
        jsr kst_write
        lda #0
        sta kst_count
+       rts

; the VIC-IV's nibble-swapped palette byte -> a plain 8-bit value
sv_unswap:
        asl
        adc #$80
        rol
        asl
        adc #$80
        rol
        rts

sv_mode:        .null ",P,W"                ; (PRG: BASIC 65's LOADIFF opens only PRG files)
sv_name:        .null "SCENE.IFF"
                .fill 16
sv_form_id:     .text "FORM"
; "ILBM", then BMHD (big-endian), then the CMAP chunk's header
sv_hdr:
        .text "ILBM"
        .text "BMHD"
        .byte 0, 0, 0, 20
        .byte >640, <640, >200, <200    ; width, height
        .byte 0, 0, 0, 0                ; x, y
        .byte 8                         ; planes
        .byte 0                         ; no mask
        .byte 1                         ; ByteRun1
        .byte 0                         ; pad
        .byte 0, 0                      ; transparent colour
        .byte 8, 15                     ; x aspect : y aspect (the pixel's shape)
        .byte >640, <640, >200, <200    ; page width, height
        .text "CMAP"
        .byte 0, 0, >768, <768
sv_hdr_len = * - sv_hdr
sv_hdr2:
        .text "CAMG"
        .byte 0, 0, 0, 4
        .byte 0, 0, $80, $00            ; HIRES
        .text "BODY"
sv_hdr2_len = * - sv_hdr2

sv_err:         .byte 0
sv_write_on:    .byte 0
sv_size:        .fill 3
sv_bsize:       .fill 3                 ; the BODY's size, from pass 1
sv_form:        .fill 3
sv_pad:         .byte 0
sv_i:           .byte 0
sv_s:           .byte 0
sv_n:           .byte 0
sv_c:           .byte 0
sv_k:           .byte 0
sv_p:           .byte 0
sv_y:           .byte 0
sv_b:           .fill 8
; (y >> 3) * 5120 as bits 8-15 and 16-23
sv_row_lo:      .byte <((range(25) * 5120) >> 8)
sv_row_hi:      .byte >((range(25) * 5120) >> 8)
; plane p's row at sv_pl + 80 p
sv_plo:         .byte <(sv_pl + range(8) * 80)
sv_phi:         .byte >(sv_pl + range(8) * 80)
        .align 256
sv_pl:          .fill 640
        .cerror * > $c000, "the save overlay must stay below $C000"
