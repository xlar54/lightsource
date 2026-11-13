;=======================================================================================
; save.asm - overlay 3: the picture to disk as a Windows BMP (kstream, a SEQ file).
;
;   save_bmp       A = 0: 8-bit, framebuffer 0 with the palette in the VIC-IV (129,078 bytes)
;                  A = 1: 24-bit, the true-colour picture at RGB_IMAGE (384,054 bytes)
;                  sv_name = the file name (zero-terminated, as typed: upper case). Replaces
;                  a file of that name. Carry set if it failed: sv_err = the drive's status.
;
; Rows are bottom-up, as BMP wants them. The pixels-per-metre fields carry the display's
; pixel shape (a 640x200 pixel is 1.875 times taller than wide): 2835 across, 1512 down.
; Keep this overlay below $C000: the DOS may use $C000-$C3FF while it works.
;=======================================================================================

save_bmp:
        sta sv_24
        ; remove the old file (if any), then open the new one
        lda #<sv_name
        ldx #>sv_name
        jsr kst_remove
        ldy #0
        lda #<sv_name
        ldx #>sv_name
        jsr kst_name_put
        lda #<sv_write
        ldx #>sv_write
        jsr kst_name_raw
        tya
        jsr kst_open
        bcc +
        jmp _fail
+       lda #0
        sta kst_count
        ; the header: 14 + 40 bytes
        ldx #0
-       lda sv_hdr8,x
        ldy sv_24
        beq +
        lda sv_hdr24,x
+       phx
        jsr sv_put
        plx
        inx
        cpx #54
        bne -
        lda sv_24
        bne _rows24
        ; the palette: 256 x (blue, green, red, 0), nibble-swapped back
        lda #0
        sta sv_i
-       ldx sv_i
        lda $d300,x
        jsr sv_unswap
        jsr sv_put
        ldx sv_i
        lda $d200,x
        jsr sv_unswap
        jsr sv_put
        ldx sv_i
        lda $d100,x
        jsr sv_unswap
        jsr sv_put
        lda #0
        jsr sv_put
        inc sv_i
        bne -
        ; 8-bit rows, bottom-up: row y is 80 runs of 8 bytes, 64 apart
        lda #199
        sta sv_y
_row8:
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
        lda #80
        sta sv_i
_cell:
        ldz #0
-       lda [ptr0],z
        phz
        jsr sv_put
        plz
        inz
        cpz #8
        bne -
        ldz #0
        clc                             ; next cell: + 64
        lda ptr0
        adc #64
        sta ptr0
        bcc +
        inc ptr0+1
        bne +
        inc ptr0+2
+       dec sv_i
        bne _cell
        dec sv_y
        lda sv_y
        cmp #$ff
        bne _row8
        jmp _close
_rows24:
        ; 24-bit rows, bottom-up: blue, green, red from RGB_IMAGE (row-major r, g, b)
        lda #199
        sta sv_y
_row24:
        lda sv_y                        ; ptr0 = RGB_IMAGE + y * 1920
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3
        lda #<1920
        sta MULTINB
        lda #>1920
        sta MULTINB+1
        lda #0
        sta MULTINB+2
        sta MULTINB+3
        clc
        lda MULTOUT
        adc #<RGB_IMAGE
        sta ptr0
        lda MULTOUT+1
        adc #>RGB_IMAGE
        sta ptr0+1
        lda MULTOUT+2
        adc #`RGB_IMAGE
        sta ptr0+2
        lda #RGB_IMAGE >> 24
        sta ptr0+3
        lda #<640
        sta sv_n
        lda #>640
        sta sv_n+1
_px:
        ldz #2
        lda [ptr0],z
        jsr sv_put
        ldz #1
        lda [ptr0],z
        jsr sv_put
        ldz #0
        lda [ptr0],z
        jsr sv_put
        clc
        lda ptr0
        adc #3
        sta ptr0
        bcc +
        inw ptr0+1
+       lda sv_n
        bne +
        dec sv_n+1
+       dec sv_n
        lda sv_n
        ora sv_n+1
        bne _px
        dec sv_y
        lda sv_y
        cmp #$ff
        beq _close
        jmp _row24
_close:
        jsr sv_flush
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

; A -> the next byte of the file (through KS_BUF, 255 bytes at a time)
sv_put:
        ldx kst_count
        sta KS_BUF,x
        inx
        stx kst_count
        cpx #255
        bne +
        jsr kst_write
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

sv_write:       .null ",S,W"
sv_name:        .null "SCENE.BMP"
                .fill 16
sv_24:          .byte 0
sv_err:         .byte 0
sv_i:           .byte 0
sv_y:           .byte 0
sv_n:           .word 0
; (y >> 3) * 5120 as bits 8-15 and 16-23
sv_row_lo:      .byte <((range(25) * 5120) >> 8)
sv_row_hi:      .byte >((range(25) * 5120) >> 8)

BMP_HDR .macro bpp, offset, colours
        .text "BM"
        .dword \offset + 640 * 200 * \bpp / 8   ; file size
        .dword 0
        .dword \offset                  ; where the pixels start
        .dword 40                       ; BITMAPINFOHEADER
        .dword 640, 200                 ; (positive height: bottom-up)
        .word 1, \bpp
        .dword 0                        ; no compression
        .dword 640 * 200 * \bpp / 8
        .dword 2835, 1512               ; pixels per metre: the 1.875 pixel shape
        .dword \colours, 0
.endmacro
sv_hdr8:        #BMP_HDR 8, 54 + 1024, 256
sv_hdr24:       #BMP_HDR 24, 54, 0
        .cerror * > $c000, "the save overlay must stay below $C000"
