;=======================================================================================
; doctiny.asm - overlay 5: the default document, which File, New and boot start from:
; no objects, the camera at the origin looking along +z (where Add puts things, at z =
; 12), one white light, and one plain material for what gets added. (tinyraytracer's
; scene, the old default, is scenes/tinyray.mdl.) Only the records it uses are kept here;
; doc_default clears the rest.
;=======================================================================================

DT_HDR          = doc_objs - doc_start  ; the header's size

; doc_default: the document becomes the default one
doc_default:
        lda #<doc_start                 ; all of it zero
        sta tmp4
        lda #>doc_start
        sta tmp4+1
        lda #<DOC_SIZE
        sta tmp5
        lda #>DOC_SIZE
        sta tmp5+1
        lda #0
        tax
        tay
        jsr dma_fill
        #DT_COPY dt_hdr, doc_start, DT_HDR
        #DT_COPY dt_mats, doc_mats, dt_mats_end - dt_mats
        #DT_COPY dt_lights, doc_lights, dt_lights_end - dt_lights
        rts

; (n must not be 0: a DMA count of 0 is 64 KB)
DT_COPY .macro src, dst, n
        .cerror (\n) == 0, "DT_COPY of nothing"
        lda #<\src
        sta dmaj_src
        lda #>\src
        sta dmaj_src+1
        lda #<\dst
        sta dmaj_dst
        lda #>\dst
        sta dmaj_dst+1
        lda #<(\n)
        sta dmaj_count
        lda #>(\n)
        sta dmaj_count+1
        lda #0
        sta dmaj_src_bank
        sta dmaj_dst_bank
        sta dmaj_src_mb
        sta dmaj_dst_mb
        jsr dma_go
.endmacro

dt_hdr:
        .text "R65M"
        .byte 3, 0, 1, 1                ; version, objects, materials, lights
        .dint FXV((0, 0, 0)), FXV((0, 0, 1)), FX(60)
        .dint FXV((0.2, 0.7, 0.8))
        .byte 5
        .cerror * - dt_hdr != DT_HDR, "the default document's header"
dt_mats:
        #DMATR "White", (0.8, 0.8, 0.8), (0, 0, 0), 1, 0, 40, 0.1, 0.7, 0.3, 0, 0, 1
dt_mats_end:
dt_lights:
        #DLIT (-20, 20, -20), (1, 1, 1), 0
dt_lights_end:
