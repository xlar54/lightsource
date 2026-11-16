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
;   overlay 3  save.asm: the picture to disk as SCENE.IFF (ILBM)
;   overlay 4  model*.asm: the modeller (what boot starts)
;   overlay 5  writer.asm: the document as scene text; .MDL and .POV files
;
; Debug settings (build time: set M65DEFS=-D DBG_ROWS=8 -D DBG_PASS2=0, then build.bat):
;   DBG_ROWS      lines to trace (0 = 200)
;   DBG_PASS2     0 skips the recolouring
;   DBG_SCENEBIN  1: the tables come from scene.bin (private/tools/pov.py), no parsing
;   DBG_LOG       1: trace pixel (DBG_PX, DBG_PY) only, with trace.asm's #LOG on
;   DBG_BENCH     1: poking dbg_bench times 16 modeller redraws (private/tools/bench_redraw.py)
; Results: ticks_render, ticks_recolour (frames); done = 1 traced, 2 recoloured,
; 3 saved, $80 the scene didn't parse (parse_err, parse_line), $81 a file is missing,
; $82 the picture couldn't be saved (sv_err). dbg_save: 0 = don't save.
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
DBG_SAVE        = 1
DBG_BOOTRENDER  = 0                     ; 1: render SCENE.POV at boot (the tests), not the
                                        ;    modeller
DBG_BENCH       = 0                     ; 1: dbg_bench times redraws (model.asm)
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
OVL_SAVE        = 3
OVL_MODEL       = 4
OVL_WRITE       = 5
OVL_PANEL       = 6                     ; the modeller's properties panel (ovl_far)
OVL_MATED       = 7                     ; the material editor (ovl_far)
OVL_COUNT       = 8
        .cerror ((OVL_ATTIC >> 16) & $0f) != 0 || OVL_COUNT > 16, "ovl_swap: overlay n in attic bank n"

; a call into another overlay: A, X, Y and the flags go through both ways (ovl_far)
FAR     .macro ovl, routine
        jsr ovl_far
        .byte \ovl
        .word \routine
.endmacro
MOUSE_MAX_X     = 639

; ---- where everything goes -----------------------------------------------------------
        * = $1fff
        .dsection res
        .cerror * > OVL_BASE, "the resident part runs into the overlay window: ", format("$%04x", *)
        * = $100000
        .dsection ovl0
        * = $110000
        .dsection ovl1
        * = $120000
        .dsection ovl2
        * = $130000
        .dsection ovl3
        * = $140000
        .dsection ovl4
        * = $150000
        .dsection ovl5
        * = $160000
        .dsection ovl6
        * = $170000
        .dsection ovl7

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
dbg_save:       .byte DBG_SAVE          ; 0 = don't save the picture
done:           .byte 0
ticks:          .byte 0, 0, 0           ; frames since the start (IRQ)
ticks_render:   .byte 0, 0, 0
ticks_recolour: .byte 0, 0, 0
res_ran:        .byte 0                 ; 0 as loaded; 1 once it has started
        .if DBG_BENCH
dbg_bench:      .byte 0                 ; (model.asm: redraw timing)
dbg_bn:         .byte 0
dbg_btime:      .word 0
        .endif

RES_COPY        = $8320000              ; attic: the resident part as it was loaded

start:
        jsr dma_init
        ; RUN again after File, Exit doesn't reload the program, but it has changed its own
        ; data (gui_inited, ms_inited, ...). So the first start after a LOAD keeps a copy
        ; of it as loaded, and each later start puts that back. (The copy writes over this
        ; code with the same bytes.)
        lda #<$2001
        sta ptr1
        sta ptr2
        lda #>$2001
        sta ptr1+1
        sta ptr2+1
        lda #0
        sta ptr1+2
        sta ptr1+3
        lda #(RES_COPY >> 16) & $ff
        sta ptr2+2
        lda #RES_COPY >> 24
        sta ptr2+3
        lda #<(res_image_end - $2001)
        sta tmp5
        lda #>(res_image_end - $2001)
        sta tmp5+1
        lda res_ran
        beq +
        ldx #3                          ; again: from the copy
-       lda ptr1,x
        ldy ptr2,x
        sta ptr2,x
        sty ptr1,x
        dex
        bpl -
+       jsr dma_copy_far
        lda #1
        sta res_ran
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
        .if !DBG_BOOTRENDER && !DBG_SCENEBIN
        lda #OVL_MODEL                  ; the modeller
        jsr ovl_load
        jmp model_main
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
        .if DBG_SCENEBIN
        lda #OVL_SAVE                   ; the test's tables (in overlay 3) into place
        jsr ovl_load
        lda #<scene_bin
        sta ptr1
        lda #>scene_bin
        sta ptr1+1
        lda #<scene
        sta ptr2
        lda #>scene
        sta ptr2+1
        lda #0
        sta ptr1+2
        sta ptr1+3
        sta ptr2+2
        sta ptr2+3
        lda #<SCENE_SIZE
        sta tmp5
        lda #>SCENE_SIZE
        sta tmp5+1
        jsr dma_copy_far
        lda #<scene_pts                 ; and the prism points
        sta px_b0
        lda #>scene_pts
        sta px_b0+1
        lda #<SC_PTS
        sta px_base
        lda #>SC_PTS
        sta px_base+1
        lda #0
        ldx #(scene_pts_end - scene_pts) / 8
        jsr px_put
        #XC_FROM sp_src, 0               ; and the primitive records
        #XC_TO sp_dst, 1
        lda #<(scene_prims_end - scene_prims)
        sta xc_n
        lda #>(scene_prims_end - scene_prims)
        sta xc_n+1
        jsr xcopy
        bra +
sp_src:         .word scene_prims
sp_dst:         .word PRIM_ATTIC
+
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
        lda dbg_save                    ; the picture to disk
        beq idle
        lda #OVL_SAVE
        jsr ovl_load
        jsr save_iff
        bcs _nosave
        lda #3
        sta done
        bra idle
_nosave:
        lda #$82
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

; ovl_reload: the current overlay again, fresh from attic (after disk calls: the DOS may
; have used part of the window)
ovl_reload:
        lda ovl_cur
        ldx #$ff
        stx ovl_cur
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

;---------------------------------------------------------------------------------------
; ovl_far: jsr ovl_far / .byte overlay / .word routine (the FAR macro) calls the routine
; in that overlay and comes back to the caller's. ovl_swap writes the window back to attic
; before it loads the other overlay, so both keep their variables, and calls can nest (the
; overlay to go back to is on the stack). A, X, Y and the flags go through both ways; the
; base page is untouched (the DMA jobs are fixed lists).
;---------------------------------------------------------------------------------------
ovl_far:
        sta of_a
        stx of_x
        sty of_y
        pla                             ; the return address - 1: the inline bytes follow
        sta _rd+1
        pla
        sta _rd+2
        ldx #3
_rd:    lda $ffff,x                     ; (self-modified)
        sta of_t-1,x
        dex
        bne _rd
        clc                             ; back past them
        lda _rd+1
        adc #3
        tax
        lda _rd+2
        adc #0
        pha
        txa
        pha
        lda ovl_cur                     ; the caller's overlay, to go back to
        pha
        lda of_t+1
        sta of_j+1
        lda of_t+2
        sta of_j+2
        lda of_t
        jsr ovl_swap
        lda of_a
        ldx of_x
        ldy of_y
        jsr of_j
        php
        sta of_a
        stx of_x
        sty of_y
        pla
        sta of_p
        pla
        jsr ovl_swap
        lda of_p
        pha
        lda of_a
        ldx of_x
        ldy of_y
        plp
        rts
of_j:   jmp $ffff                       ; (self-modified)
of_t:           .fill 3                 ; the overlay, the routine
of_a:           .byte 0
of_x:           .byte 0
of_y:           .byte 0
of_p:           .byte 0

; ovl_swap: A = the overlay to have in the window; the one there goes back to attic first
ovl_swap:
        cmp ovl_cur
        beq _r
        pha
        lda ovl_cur
        bmi +                           ; (none)
        sta os_wbank
        lda #>os_wjob
        sta DMA_ADDRMSB
        lda #<os_wjob
        sta DMA_ADDRLSB_ETRIG
+       pla
        sta ovl_cur
        sta os_lbank
        lda #>os_ljob
        sta DMA_ADDRMSB
        lda #<os_ljob
        sta DMA_ADDRLSB_ETRIG
_r:     rts
os_wjob:        .byte DMAOPT_F018B, DMAOPT_SRC_MB, 0, DMAOPT_DST_MB, OVL_ATTIC >> 20, DMAOPT_END
                .byte DMACMD_COPY
                .word OVL_END - OVL_BASE
                .word OVL_BASE
                .byte 0
                .word OVL_ATTIC & $ffff
os_wbank:       .byte 0                 ; overlay n: attic bank n
                .byte 0
                .word 0
os_ljob:        .byte DMAOPT_F018B, DMAOPT_SRC_MB, OVL_ATTIC >> 20, DMAOPT_DST_MB, 0, DMAOPT_END
                .byte DMACMD_COPY
                .word OVL_END - OVL_BASE
                .word OVL_ATTIC & $ffff
os_lbank:       .byte 0
                .word OVL_BASE
                .byte 0
                .byte 0
                .word 0

ovl_cur:        .byte $ff
ovl_n:          .byte 0
ovl_name:       .text "OVL0"

        .include "lib/system.asm"
        .include "lib/dma.asm"
        .include "lib/loader.asm"
        .include "lib/kstream.asm"
        .include "lib/fcm640.asm"
        .include "lib/fixed.asm"
FT_PTR          = lp                    ; (fixtrig: not ptr0, the parser's text pointer)
        .include "lib/fixtrig.asm"
        .include "lib/draw640.asm"
        .include "lib/font8.asm"
        .include "lib/keyboard.asm"
        .include "lib/mouse.asm"
        .include "lib/hwsprite.asm"
        .include "gui.asm"
        .include "doc.asm"
        .include "modelst.asm"
        .include "modes.asm"
        .include "modelres.asm"
        .include "scene.asm"
res_image_end:                          ; (the end of what LOAD puts in memory)
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
        .cerror * > OVL_END, "overlay 2 is too big: ", format("$%04x", *)
ovl2_end:
        .fill OVL_END - *, 0            ; (the file goes on past the window: the error
        .dsection parse_text_s          ;  messages, which stay in attic)
        .endlogical
        .send ovl2

        .section ovl3
        .word 0
        .logical OVL_BASE
        .include "save.asm"
        .if DBG_SCENEBIN                ; (a test build: the tables as pov.py made them;
scene_bin:      .binary "scene.bin"     ;  boot copies them to scene)
        .cerror * - scene_bin != SCENE_SIZE, "scene.bin is the wrong size"
scene_pts:      .binary "scenepts.bin"  ; the prism points in use (to SC_PTS)
scene_pts_end:
scene_prims:    .binary "sceneprims.bin" ; and the primitive records (to PRIM_ATTIC)
scene_prims_end:
        .cerror scene_pts_end - scene_pts > 8 * MAX_PTS, "scenepts.bin is too big"
        .endif
        .cerror * > OVL_END, "overlay 3 is too big"
        .endlogical
        .send ovl3

        .section ovl4
        .word 0
        .logical OVL_BASE
        .include "model.asm"
        .cerror * > OVL_END, "overlay 4 is too big: ", format("$%04x", *)
ovl4_end:
        .endlogical
        .send ovl4

        .section ovl5
        .word 0
        .logical OVL_BASE
        .include "writer.asm"
        .include "doctiny.asm"
        .include "matfile.asm"
        .cerror * > OVL_END, "overlay 5 is too big"
        .endlogical
        .send ovl5

        .section ovl6
        .word 0
        .logical OVL_BASE
        .include "modelpanel.asm"
        .cerror * > OVL_END, "overlay 6 is too big: ", format("$%04x", *)
ovl6_end:
        .fill OVL_END - *, 0            ; (the file goes on past the window: help lines that
        .include "modelhelp.asm"        ;  stay in attic)
        .endlogical
        .send ovl6

        .section ovl7
        .word 0
        .logical OVL_BASE
        .include "matedit.asm"
        .cerror * > OVL_END, "overlay 7 is too big: ", format("$%04x", *)
ovl7_end:
        .endlogical
        .send ovl7
