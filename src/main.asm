;=======================================================================================
; renderer65 - a ray tracer for the MEGA65, after ssloy/tinyraytracer.
;
; 640x200, 256 colours (Full Colour Mode, lib/fcm640.asm). Two passes:
;   1. trace every pixel in 16.16 fixed point (trace.asm, lib/fixed.asm), keep the
;      24-bit result in attic RAM and show it as it goes, ordered-dithered to a fixed
;      colour cube;
;   2. recolour.asm: a median-cut palette of the whole picture, then Floyd-Steinberg
;      into the second framebuffer, shown with its palette at the next frame.
;
; Debug settings (build time: set M65DEFS=-D DBG_ROWS=8 -D DBG_PASS2=0, then build.bat):
; DBG_ROWS lines to trace (0 = 200), DBG_PASS2 = 0 skips the recolouring. Results: ticks_render, ticks_recolour (frames),
; done = 1 (traced), 2 (recoloured).
;=======================================================================================
        .cpu "45gs02"

        .include "platform.asm"
        .include "lib/zp.asm"
        .include "zp.asm"

        .weak
DBG_ROWS        = 0                     ; build.bat: set M65DEFS=-D DBG_ROWS=8 ...
DBG_PASS2       = 1
DBG_SCENEBIN    = 0                     ; 1: the scene tables from scene.bin (pov.py)
DBG_LOG         = 0                     ; 1: trace pixel (DBG_PX, DBG_PY) only, logging
DBG_PX          = 0                     ;    values (trace.asm #LOG) from DBG_LOGBUF
DBG_PY          = 0
        .endweak
DBG_LOGBUF      = $0800                 ; up to $15FF
dbg_lp          = ptr2                  ; the log's next byte (bank 0)

RGB_IMAGE       = $8000000              ; 640 x 200 x 3 bytes, row-major, attic

        * = $2001                       ; BASIC stub: BANK 0 : SYS 8210
        .word (+), 2026
        .byte $fe, $02, $30
        .byte ':'
        .byte $9e
        .text "8210"
        .byte 0
+       .word 0

        * = $2012
entry:
        cld
        jmp start
        ; harness bytes at fixed addresses (also in the .lbl file)
dbg_rows:       .byte DBG_ROWS          ; 0 = all 200 lines
dbg_pass2:      .byte DBG_PASS2         ; 0 = stop after tracing
done:           .byte 0
ticks:          .byte 0, 0, 0           ; frames since the start (IRQ)
ticks_render:   .byte 0, 0, 0
ticks_recolour: .byte 0, 0, 0

start:
        #TAKEOVER
        ; clear the variables (RAM is random on real hardware)
        lda #0
        ldx #0
-       sta $02,x                       ; base page from $02
        inx
        cpx #zp_end - 2
        bne -
        lda #<vars_start
        sta ptr0
        lda #>vars_start
        sta ptr0+1
        ldy #0
-       lda #0
        sta (ptr0),y
        inw ptr0
        lda ptr0
        cmp #<vars_end
        bne -
        lda ptr0+1
        cmp #>vars_end
        bne -
        lda #0
        sta done
        sta ticks
        sta ticks+1
        sta ticks+2
        jsr dma_init
        jsr rom_unprotect               ; framebuffer 1 lives in $20000-$3FFFF
        lda #<tick
        sta irq_hook
        lda #>tick
        sta irq_hook+1
        jsr irq_install
        lda #0
        sta f640_fill
        lda #0
        jsr f640_clear
        lda #1
        jsr f640_clear
        jsr f640_init
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
        jsr f640_palette
        cli

        .if DBG_LOG
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
        jsr trace_pixel
        lda #1
        sta done
        jmp idle
        .endif
        jsr render
        ldx #2
-       lda ticks,x
        sta ticks_render,x
        dex
        bpl -
        lda #1
        sta done
        lda dbg_pass2
        beq idle
        jsr recolour
        sec
        ldx #0
        ldy #3
-       lda ticks,x
        sbc ticks_render,x
        sta ticks_recolour,x
        inx
        dey
        bne -
        lda #2
        sta done
idle:
        jsr wait_frame
        bra idle

; frame IRQ hook: count frames
tick:
        inc ticks
        bne +
        inc ticks+1
        bne +
        inc ticks+2
+       rts

;---------------------------------------------------------------------------------------
; render: trace every pixel, top to bottom
;---------------------------------------------------------------------------------------
render:
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

        .include "lib/system.asm"
        .include "lib/dma.asm"
        .include "lib/fcm640.asm"
        .include "lib/fixed.asm"
        .include "scene.asm"
        .include "trace.asm"
        .include "recolour.asm"
        .include "vars.asm"

        .dsection bss

        .cerror * > $d000, "the program overflows into the I/O area at $D000"
