;=======================================================================================
; lib/draw640.asm - drawing into a lib/fcm640.asm framebuffer (640x200, 256 colours, cells
; laid out row by row). Everything is clipped to the rectangle d6_cx0..d6_cx1 (words),
; d6_cy0..d6_cy1.
;
;   d6_clip_all    clip to the whole screen
;   d6_plot        (d6_x, d6_y) in d6_col
;   d6_hline       d6_x .. d6_x1 on row d6_y
;   d6_vline       d6_y .. d6_y1 in column d6_x
;   d6_fill        the rectangle d6_x..d6_x1, d6_y..d6_y1
;   d6_frame       its outline
;   d6_line        (d6_x, d6_y) to (d6_x1, d6_y1), signed 16-bit ends (clipped per pixel)
;   d6_text        A/X = zero-terminated ASCII at column d6_tc (0-79, 8-pixel cells), row
;                  d6_y (any pixel row), in d6_col on d6_bg ($ff = transparent)
;   d6_char        one character A there; d6_tc moves on
;
; Needs fcm640 (F640_BUF0 is drawn into) and a font: D6_FONT, glyphs for ASCII 32-127,
; 8 bytes each, bit 7 = the left pixel. d6_p is a 4-byte base-page pointer (default ptr1).
;=======================================================================================

        .weak
D6_FONT         = font8
d6_p            = ptr1
        .endweak

d6_x:           .word 0
d6_y:           .word 0                 ; (words: lines can start off screen)
d6_x1:          .word 0
d6_y1:          .word 0
d6_col:         .byte 1
d6_bg:          .byte 0
d6_tc:          .byte 0
d6_cx0:         .word 0
d6_cx1:         .word 639
d6_cy0:         .word 0
d6_cy1:         .word 199
l_d6_t:         .byte 0
l_d6_n:         .word 0
l_d6_dx:        .word 0
l_d6_dy:        .word 0
l_d6_sx:        .byte 0
l_d6_sy:        .byte 0
l_d6_err:       .word 0
l_d6_e2:        .word 0
l_d6_str:       .word 0
l_d6_gl:        .word 0
l_d6_row:       .byte 0

d6_clip_all:
        lda #0
        sta d6_cx0
        sta d6_cx0+1
        sta d6_cy0
        sta d6_cy0+1
        lda #<639
        sta d6_cx1
        lda #>639
        sta d6_cx1+1
        lda #199
        sta d6_cy1
        lda #0
        sta d6_cy1+1
        rts

; carry set if (d6_x, d6_y) is inside the clip rectangle (signed compares)
l_d6_inside:
        lda d6_x                        ; x >= cx0
        cmp d6_cx0
        lda d6_x+1
        sbc d6_cx0+1
        bvc +
        eor #$80
+       bmi _no
        lda d6_cx1                      ; cx1 >= x
        cmp d6_x
        lda d6_cx1+1
        sbc d6_x+1
        bvc +
        eor #$80
+       bmi _no
        lda d6_y
        cmp d6_cy0
        lda d6_y+1
        sbc d6_cy0+1
        bvc +
        eor #$80
+       bmi _no
        lda d6_cy1
        cmp d6_y
        lda d6_cy1+1
        sbc d6_y+1
        bvc +
        eor #$80
+       bmi _no
        sec
        rts
_no:    clc
        rts

; d6_p = the byte of pixel (d6_x, d6_y) (on screen)
d6_addr:
        lda d6_y
        and #7
        asl
        asl
        asl
        sta l_d6_t
        lda d6_x
        and #7
        ora l_d6_t
        sta d6_p                        ; (y & 7) * 8 + (x & 7)
        lda d6_x+1                      ; xc = x >> 3
        sta l_d6_t
        lda d6_x
        lsr l_d6_t
        ror
        lsr l_d6_t
        ror
        lsr l_d6_t
        ror
        pha
        and #3                          ; + (xc & 3) << 6
        lsr
        ror
        ror
        ora d6_p
        sta d6_p
        pla
        lsr
        lsr
        sta l_d6_t                      ; + (xc >> 2) << 8
        lda d6_y
        lsr
        lsr
        lsr
        tax
        clc
        lda l_d6_t
        adc l_d6_rowm,x
        sta d6_p+1
        lda l_d6_rowh,x
        adc #`F640_BUF0
        sta d6_p+2
        lda #F640_BUF0 >> 24
        sta d6_p+3
        rts
l_d6_rowm:      .byte <((range(25) * 5120) >> 8)
l_d6_rowh:      .byte >((range(25) * 5120) >> 8)

d6_plot:
        jsr l_d6_inside
        bcc +
        jsr d6_addr
        lda d6_col
        ldz #0
        sta [d6_p],z
+       rts

d6_hline:
        ; clip the ends: x = max(x, cx0), x1 = min(x1, cx1); nothing if the row is out
        lda d6_y
        cmp d6_cy0
        lda d6_y+1
        sbc d6_cy0+1
        bmi _out
        lda d6_cy1
        cmp d6_y
        lda d6_cy1+1
        sbc d6_y+1
        bmi _out
        lda d6_x
        cmp d6_cx0
        lda d6_x+1
        sbc d6_cx0+1
        bpl +
        lda d6_cx0
        sta d6_x
        lda d6_cx0+1
        sta d6_x+1
+       lda d6_cx1
        cmp d6_x1
        lda d6_cx1+1
        sbc d6_x1+1
        bpl +
        lda d6_cx1
        sta d6_x1
        lda d6_cx1+1
        sta d6_x1+1
+       sec                             ; n = x1 - x (none if negative)
        lda d6_x1
        sbc d6_x
        sta l_d6_n
        lda d6_x1+1
        sbc d6_x+1
        sta l_d6_n+1
        bmi _out
        jsr d6_addr
        lda d6_p                        ; the cell row's start; Z = x & 7
        and #$f8
        sta d6_p
        lda d6_x
        and #7
        taz
_pix:
        lda d6_col
        sta [d6_p],z
        inz
        cpz #8
        bne +
        ldz #0
        clc                             ; the next cell: + 64
        lda d6_p
        adc #64
        sta d6_p
        bcc +
        inc d6_p+1
        bne +
        inc d6_p+2
+       lda l_d6_n                      ; n pixels more
        ora l_d6_n+1
        beq _end
        lda l_d6_n
        bne _lo
        dec l_d6_n+1
_lo:    dec l_d6_n
        bra _pix
_end:   ldz #0
_out:   rts

d6_vline:
        lda d6_y
        pha
        lda d6_y+1
        pha
_l:     jsr d6_plot
        lda d6_y
        cmp d6_y1
        lda d6_y+1
        sbc d6_y1+1
        bpl +
        inc d6_y
        bne _l
        inc d6_y+1
        bra _l
+       pla
        sta d6_y+1
        pla
        sta d6_y
        rts

d6_fill:
        lda d6_y
        pha
        lda d6_x
        sta l_d6_dx
        lda d6_x+1
        sta l_d6_dx+1
        lda d6_x1
        sta l_d6_dy
        lda d6_x1+1
        sta l_d6_dy+1
_row:
        lda l_d6_dx
        sta d6_x
        lda l_d6_dx+1
        sta d6_x+1
        lda l_d6_dy
        sta d6_x1
        lda l_d6_dy+1
        sta d6_x1+1
        jsr d6_hline
        lda d6_y
        cmp d6_y1
        bcs +
        inc d6_y
        bra _row
+       lda l_d6_dx
        sta d6_x
        lda l_d6_dx+1
        sta d6_x+1
        lda l_d6_dy
        sta d6_x1
        lda l_d6_dy+1
        sta d6_x1+1
        pla
        sta d6_y
        rts

d6_frame:
        lda d6_y                        ; save the corners
        pha
        lda d6_x
        pha
        lda d6_x+1
        pha
        lda d6_x1
        pha
        lda d6_x1+1
        pha
        jsr d6_hline                    ; top
        pla
        sta d6_x1+1
        pla
        sta d6_x1
        pla
        sta d6_x+1
        pla
        sta d6_x
        pla
        sta d6_y
        jsr d6_vline                    ; left
        lda d6_x
        pha
        lda d6_x+1
        pha
        lda d6_x1                       ; right
        sta d6_x
        lda d6_x1+1
        sta d6_x+1
        jsr d6_vline
        pla
        sta d6_x+1
        pla
        sta d6_x
        lda d6_y
        pha
        lda d6_y1                       ; bottom
        sta d6_y
        jsr d6_hline
        pla
        sta d6_y
        rts

; Bresenham, every pixel clipped
d6_line:
        sec                             ; dx = |x1 - x|, sx
        lda d6_x1
        sbc d6_x
        sta l_d6_dx
        lda d6_x1+1
        sbc d6_x+1
        sta l_d6_dx+1
        lda #1
        sta l_d6_sx
        bit l_d6_dx+1
        bpl +
        lda #$ff
        sta l_d6_sx
        sec
        lda #0
        sbc l_d6_dx
        sta l_d6_dx
        lda #0
        sbc l_d6_dx+1
        sta l_d6_dx+1
+       sec                             ; dy = -|y1 - y|, sy
        lda d6_y1
        sbc d6_y
        sta l_d6_dy
        lda d6_y1+1
        sbc d6_y+1
        sta l_d6_dy+1
        lda #1
        sta l_d6_sy
        bit l_d6_dy+1
        bmi +
        sec                             ; (dy = -dy when positive)
        lda #0
        sbc l_d6_dy
        sta l_d6_dy
        lda #0
        sbc l_d6_dy+1
        sta l_d6_dy+1
        bra ++
+       lda #$ff
        sta l_d6_sy
+       clc                             ; err = dx + dy
        lda l_d6_dx
        adc l_d6_dy
        sta l_d6_err
        lda l_d6_dx+1
        adc l_d6_dy+1
        sta l_d6_err+1
_l:
        jsr d6_plot
        lda d6_x
        cmp d6_x1
        bne +
        lda d6_x+1
        cmp d6_x1+1
        bne +
        lda d6_y
        cmp d6_y1
        bne +
        lda d6_y+1
        cmp d6_y1+1
        bne +
        rts
+       lda l_d6_err                    ; e2 = 2 err
        asl
        sta l_d6_e2
        lda l_d6_err+1
        rol
        sta l_d6_e2+1
        ; e2 >= dy: err += dy, x += sx
        lda l_d6_e2
        cmp l_d6_dy
        lda l_d6_e2+1
        sbc l_d6_dy+1
        bvc +
        eor #$80
+       bmi _ny
        clc
        lda l_d6_err
        adc l_d6_dy
        sta l_d6_err
        lda l_d6_err+1
        adc l_d6_dy+1
        sta l_d6_err+1
        lda l_d6_sx
        jsr l_d6_addx
_ny:    ; e2 <= dx: err += dx, y += sy
        lda l_d6_dx
        cmp l_d6_e2
        lda l_d6_dx+1
        sbc l_d6_e2+1
        bvc +
        eor #$80
+       bmi _l
        clc
        lda l_d6_err
        adc l_d6_dx
        sta l_d6_err
        lda l_d6_err+1
        adc l_d6_dx+1
        sta l_d6_err+1
        lda l_d6_sy
        bmi +
        inc d6_y
        bne _l
        inc d6_y+1
        bra _l
+       lda d6_y
        bne +
        dec d6_y+1
+       dec d6_y
        jmp _l
l_d6_addx:
        cmp #1
        bne _left
        inc d6_x
        bne _r
        inc d6_x+1
_r:     rts
_left:  lda d6_x
        bne _lo
        dec d6_x+1
_lo:    dec d6_x
        rts

; text: 8-pixel columns, any row
d6_text:
        sta l_d6_str
        stx l_d6_str+1
_c:     lda l_d6_str
        sta txt_ptr
        lda l_d6_str+1
        sta txt_ptr+1
        ldy #0
        lda (txt_ptr),y
        beq +
        jsr d6_char
        inc l_d6_str
        bne _c
        inc l_d6_str+1
        bra _c
+       rts

d6_char:
        sec                             ; the glyph: D6_FONT + (A - 32) * 8
        sbc #32
        bcs +
        lda #0
+       cmp #96
        bcc +
        lda #0
+       sta l_d6_gl
        lda #0
        sta l_d6_gl+1
        asl l_d6_gl
        rol l_d6_gl+1
        asl l_d6_gl
        rol l_d6_gl+1
        asl l_d6_gl
        rol l_d6_gl+1
        clc
        lda l_d6_gl
        adc #<D6_FONT
        sta l_d6_gl
        lda l_d6_gl+1
        adc #>D6_FONT
        sta l_d6_gl+1
        lda d6_tc                       ; on screen at all?
        cmp #80
        bcs _done
        lda d6_y
        pha
        lda d6_y+1
        pha
        lda d6_tc                       ; x = column * 8
        asl
        asl
        asl
        sta d6_x
        lda d6_tc
        lsr
        lsr
        lsr
        lsr
        lsr
        sta d6_x+1
        lda #0
        sta l_d6_row
_r:
        jsr l_d6_inside                 ; this row inside the clip? (column only checked once)
        bcc _next
        jsr d6_addr
        lda l_d6_gl
        sta tmp6
        lda l_d6_gl+1
        sta tmp6+1
        ldy l_d6_row
        lda (tmp6),y
        sta l_d6_t
        ldz #0
_px:    asl l_d6_t
        bcc _bgp
        lda d6_col
        bra _st
_bgp:   lda d6_bg
        cmp #$ff
        beq _skip
_st:    sta [d6_p],z
_skip:  inz
        cpz #8
        bne _px
        ldz #0
_next:
        inc d6_y
        bne +
        inc d6_y+1
+       inc l_d6_row
        lda l_d6_row
        cmp #8
        bne _r
        pla
        sta d6_y+1
        pla
        sta d6_y
_done:
        inc d6_tc
        rts
