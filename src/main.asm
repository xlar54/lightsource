;=======================================================================================
; renderer65 - a ray tracer for the MEGA65, after ssloy/tinyraytracer, reading scenes in
; a subset of POV-Ray's language (docs/DESIGN.md).
;
; 640x200, 256 colours (Full Colour Mode, lib/fcm640.asm). The program is a resident part
; and overlays, all assembled here together: build.bat writes each section to its own file
; (64tass --output-section). At boot the overlays are loaded into attic; ovl_load copies
; one into the window at OVL_BASE when it is needed.
;
;   resident   boot, overlay manager, libraries, the compiled scene tables
;   overlay 0  render.asm + trace.asm: trace every pixel, 24-bit to attic, a dithered preview
;   overlay 1  recolour.asm: a median-cut palette, Floyd-Steinberg into framebuffer 1
;   overlay 2  parse.asm: read SCENE.POV and compile it into the tables
;
; Debug settings (build time: set M65DEFS=-D DBG_ROWS=8 -D DBG_PASS2=0, then build.bat):
;   DBG_ROWS      lines to trace (0 = 200)
;   DBG_PASS2     0 skips the recolouring
;   DBG_SCENEBIN  1: the tables come from scene.bin (private/tools/pov.py), no parsing
;   DBG_LOG       1: trace pixel (DBG_PX, DBG_PY) only, with trace.asm's #LOG on
; Results: ticks_render, ticks_recolour (frames); done = 1 traced, 2 recoloured,
; $80 the scene didn't parse (parse_err, parse_line), $81 a file is missing.
;=======================================================================================
        .cpu "45gs02"

        .include "platform.asm"
        .include "lib/zp.asm"
        .include "zp.asm"

        .weak
DBG_ROWS        = 0
DBG_PASS2       = 1
DBG_SCENEBIN    = 0
DBG_LOG         = 0
DBG_PX          = 0
DBG_PY          = 0
        .endweak
DBG_LOGBUF      = $0800                 ; up to $15FF (debug builds don't parse)
dbg_lp          = ptr2                  ; the log's next byte (bank 0)

RGB_IMAGE       = $8000000              ; 640 x 200 x 3 bytes, row-major, attic
F640_BUF1       = $8100000              ; the recoloured picture is built here (attic): the
                                        ; C65 ROM at $20000 stays intact for kstream
TEXT_BUF        = $14000                ; the scene file while it is parsed
TEXT_MAX        = $1f000 - TEXT_BUF
OVL_BASE        = $8000                 ; the overlay window
OVL_END         = $d000
OVL_ATTIC       = $8700000              ; overlay n at OVL_ATTIC + n * $10000
OVL_TRACE       = 0
OVL_RECOLOUR    = 1
OVL_PARSE       = 2
OVL_COUNT       = 3

; ---- where everything goes -----------------------------------------------------------
        * = $1fff
        .dsection res
        .cerror * > OVL_BASE, "the resident part runs into the overlay window"
        * = $100000
        .dsection ovl0
        * = $110000
        .dsection ovl1
        * = $120000
        .dsection ovl2

;=======================================================================================
; the resident part
;=======================================================================================
        .section res
        .word $2001                     ; the PRG's load address
        .word (+), 2026                 ; BASIC stub: BANK 0 : SYS 8210
        .byte $fe, $02, $30
        .byte ':'
        .byte $9e
        .text "8210"
        .byte 0
+       .word 0
        .fill $2012 - *
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
        jsr dma_init
        ; the overlays into attic, through the KERNAL while BASIC is untouched
        lda #0
        sta ovl_n
_ovl:
        lda #0                          ; its area zeroed (buffers aren't in the file)
        sta tmp4
        sta tmp4+1
        lda #<(OVL_END - OVL_BASE)
        sta tmp5
        lda #>(OVL_END - OVL_BASE)
        sta tmp5+1
        ldy ovl_n                       ; bank (bits 16-19): OVL_ATTIC's are 0
        ldx #OVL_ATTIC >> 20            ; megabyte
        lda #0
        jsr dma_fill
        lda #0
        sta ld_attic
        sta ld_attic+1
        lda ovl_n
        clc
        adc #`OVL_ATTIC
        sta ld_attic+2
        lda #OVL_ATTIC >> 24
        sta ld_attic+3
        lda ovl_n
        ora #'0'
        sta ovl_name+3
        lda #4
        ldx #<ovl_name
        ldy #>ovl_name
        jsr load_to_attic
        bcc +
        lda #$81
        sta done
        rts                             ; back to BASIC: a file is missing
+       inc ovl_n
        lda ovl_n
        cmp #OVL_COUNT
        bne _ovl
        ; kstream's state, after the DOS has done its own set-up (the loads above): at the
        ; top level, so it records the stack the SYS left
        jsr kst_capture

        #TAKEOVER
        ; clear the base page (RAM is random on real hardware)
        lda #0
        ldx #0
-       sta $02,x
        inx
        cpx #zp_end - 2
        bne -
        lda #0
        sta done
        sta ticks
        sta ticks+1
        sta ticks+2
        lda #$ff
        sta ovl_cur
        jsr dma_init
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
        lda #OVL_TRACE
        jsr ovl_load
        jsr render_palette
        cli

        .if DBG_LOG
        jsr render_pixel
        lda #1
        sta done
        jmp idle
        .endif
        .if !DBG_SCENEBIN
        lda #OVL_PARSE
        jsr ovl_load
        jsr parse_scene
        bcc +
        lda #$80
        sta done
        jmp idle
+       lda #0                          ; the time from here
        sta ticks
        sta ticks+1
        sta ticks+2
        .endif
        lda #OVL_TRACE
        jsr ovl_load
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
        lda #OVL_RECOLOUR
        jsr ovl_load
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
; ovl_load: A = overlay: into the window from attic, unless it is there already
;---------------------------------------------------------------------------------------
ovl_load:
        cmp ovl_cur
        bne +
        rts
+       sta ovl_cur
        clc
        adc #`OVL_ATTIC
        sta ptr1+2
        lda #0
        sta ptr1
        sta ptr1+1
        lda #OVL_ATTIC >> 24
        sta ptr1+3
        lda #<OVL_BASE
        sta ptr2
        lda #>OVL_BASE
        sta ptr2+1
        lda #0
        sta ptr2+2
        sta ptr2+3
        lda #<(OVL_END - OVL_BASE)
        sta tmp5
        lda #>(OVL_END - OVL_BASE)
        sta tmp5+1
        jmp dma_copy_far
ovl_cur:        .byte $ff
ovl_n:          .byte 0
ovl_name:       .text "OVL0"

        .include "lib/system.asm"
        .include "lib/dma.asm"
        .include "lib/loader.asm"
        .include "lib/kstream.asm"
        .include "lib/fcm640.asm"
        .include "lib/fixed.asm"
        .include "scene.asm"
        .dsection bss
        .send res

;=======================================================================================
; the overlays: each starts with the two bytes a LOAD skips, then runs at OVL_BASE
;=======================================================================================
        .section ovl0
        .word 0
        .logical OVL_BASE
        .include "render.asm"
        .include "trace.asm"
        .include "vars.asm"
        .cerror * > OVL_END, "overlay 0 is too big"
        .endlogical
        .send ovl0

        .section ovl1
        .word 0
        .logical OVL_BASE
        .include "recolour.asm"
        .dsection rbss
        .cerror * > OVL_END, "overlay 1 is too big"
        .endlogical
        .send ovl1

        .section ovl2
        .word 0
        .logical OVL_BASE
        .include "parse.asm"
        .cerror * > OVL_END, "overlay 2 is too big"
        .endlogical
        .send ovl2
