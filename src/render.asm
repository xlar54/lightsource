;=======================================================================================
; render.asm - overlay 0's entry points: the render loop, showing the picture as it is
; traced, dithered to a fixed 6x7x6 colour cube.
;
;   render         trace every pixel (dbg_rows lines; 0 = 200), the 24-bit result to
;                  RGB_IMAGE (attic), the dithered preview to framebuffer 0
;   render_palette the cube's palette
;   render_pixel   (debug builds) trace one pixel, (DBG_PX, DBG_PY), with the #LOG on
;=======================================================================================

render_palette:
        lda #<cube_r
        sta f640_pal_r
        lda #>cube_r
        sta f640_pal_r+1
        lda #<cube_g
        sta f640_pal_g
        lda #>cube_g
        sta f640_pal_g+1
        lda #<cube_b
        sta f640_pal_b
        lda #>cube_b
        sta f640_pal_b+1
        jmp f640_palette

        .if DBG_LOG
render_pixel:
        lda #<DBG_LOGBUF
        sta dbg_lp
        lda #>DBG_LOGBUF
        sta dbg_lp+1
        lda #<DBG_PX
        sta px_x
        lda #>DBG_PX
        sta px_x+1
        lda #DBG_PY
        sta px_y
        jmp trace_pixel
        .endif

;---------------------------------------------------------------------------------------
; render_preview: every 4th pixel of every 2nd line, each as a 4 x 2 block (1/8 of the
; work), dithered to the cube; nothing kept in attic
;---------------------------------------------------------------------------------------
render_preview:
        lda #0
        sta fr_sp
        sta px_y
        jsr d6_clip_all
_row:
        lda #0
        sta pr_x
        sta pr_x+1
_pix:
        clc                             ; the block's second column
        lda pr_x
        adc #1
        sta px_x
        lda pr_x+1
        adc #0
        sta px_x+1
        jsr trace_pixel
        jsr cube_index
        sta d6_col
        lda pr_x
        sta d6_x
        lda pr_x+1
        sta d6_x+1
        clc
        lda pr_x
        adc #3
        sta d6_x1
        lda pr_x+1
        adc #0
        sta d6_x1+1
        lda px_y
        sta d6_y
        inc a
        sta d6_y1
        lda #0
        sta d6_y+1
        sta d6_y1+1
        jsr d6_fill
        clc
        lda pr_x
        adc #4
        sta pr_x
        bcc +
        inc pr_x+1
+       lda pr_x
        cmp #<640
        bne _pix
        lda pr_x+1
        cmp #>640
        bne _pix
        inc px_y
        inc px_y
        lda px_y
        cmp #200
        bne _row
        rts
pr_x:           .word 0

;---------------------------------------------------------------------------------------
; render: trace every pixel, top to bottom
;---------------------------------------------------------------------------------------
render:
        lda #0
        sta fr_sp
        lda #<RGB_IMAGE
        sta rgb_ptr
        lda #>RGB_IMAGE
        sta rgb_ptr+1
        lda #`RGB_IMAGE
        sta rgb_ptr+2
        lda #RGB_IMAGE >> 24
        sta rgb_ptr+3
        lda dbg_rows
        bne +
        lda #200
+       sta r_rows
        lda #0
        sta px_y
        sta f640_buf
_row:
        lda px_y
        sta f640_y
        jsr f640_row
        lda #0
        sta px_x
        sta px_x+1
_pixel:
        jsr trace_pixel
        ldz #0                          ; keep the true colour
        lda out_r
        sta [rgb_ptr],z
        inz
        lda out_g
        sta [rgb_ptr],z
        inz
        lda out_b
        sta [rgb_ptr],z
        clc
        lda rgb_ptr
        adc #3
        sta rgb_ptr
        bcc +
        inw rgb_ptr+1
+       jsr cube_index                  ; and show it dithered
        #F640_PUT
        inc px_x
        bne +
        inc px_x+1
+       lda px_x
        cmp #<640
        bne _pixel
        lda px_x+1
        cmp #>640
        bne _pixel
        inc px_y
        lda px_y
        cmp r_rows
        bne _row
        rts
r_rows:         .byte 0

;---------------------------------------------------------------------------------------
; cube_index: out_r/g/b at (px_x, px_y) -> A = 1 + 42 r + 6 g + b of the 6x7x6 cube,
; 4x4 ordered dither
;---------------------------------------------------------------------------------------
cube_index:
        lda px_y
        and #3
        asl
        asl
        sta ci_t
        lda px_x
        and #3
        ora ci_t
        tax
        lda bayer4,x
        sta ci_t
        ldx out_r
        lda cube_q5,x
        clc
        adc ci_t
        lsr
        lsr
        lsr
        lsr
        tay
        lda mul42,y
        sta ci_acc
        ldx out_g
        lda cube_q6,x
        clc
        adc ci_t
        lsr
        lsr
        lsr
        lsr
        tay
        lda mul6,y
        clc
        adc ci_acc
        sta ci_acc
        ldx out_b
        lda cube_q5,x
        clc
        adc ci_t
        lsr
        lsr
        lsr
        lsr
        sec                             ; + 1
        adc ci_acc
        rts
ci_t:           .byte 0
ci_acc:         .byte 0

bayer4:         .byte 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5
mul42:          .byte 0, 42, 84, 126, 168, 210
mul6:           .byte 0, 6, 12, 18, 24, 30, 36
cube_q5:                                ; v * 5 / 255 in sixteenths
        .for ci = 0, ci < 256, ci += 1
        .byte int(ci * 80 / 255)
        .next
cube_q6:
        .for ci = 0, ci < 256, ci += 1
        .byte int(ci * 96 / 255)
        .next
; the cube's palette: entry 1 + 42 r + 6 g + b, 0 and 253..255 black
cube_r:
        .for ci = 0, ci < 256, ci += 1
        .byte (ci >= 1 && ci <= 252) ? int(int((ci - 1) / 42) * 255 / 5) : 0
        .next
cube_g:
        .for ci = 0, ci < 256, ci += 1
        .byte (ci >= 1 && ci <= 252) ? int(int(((ci - 1) % 42) / 6) * 255 / 6) : 0
        .next
cube_b:
        .for ci = 0, ci < 256, ci += 1
        .byte (ci >= 1 && ci <= 252) ? int(((ci - 1) % 6) * 255 / 5) : 0
        .next
