;=======================================================================================
; doctiny.asm - overlay 4: the default document (tinyraytracer's scene). Only the records
; it uses are kept here; doc_default clears the rest.
;=======================================================================================

DT_HDR          = doc_objs - doc_start  ; the header's size

; doc_default: the document becomes tinyraytracer's scene
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
        #DT_COPY dt_objs, doc_objs, dt_objs_end - dt_objs
        #DT_COPY dt_mats, doc_mats, dt_mats_end - dt_mats
        #DT_COPY dt_lights, doc_lights, dt_lights_end - dt_lights
        rts

DT_COPY .macro src, dst, n
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
        .byte 1, 7, 5, 3                ; version, objects, materials, lights
        .dint FXV((0, 0, 0)), FXV((0, 0, 1)), FX(89.34)
        .dint FXV((0.2, 0.7, 0.8))
        .byte 5
        .cerror * - dt_hdr != DT_HDR, "the default document's header"
dt_objs:
        #DOBJ OT_SPHERE, 0, 1, "Ivory", (-3, 0, 16), (0, 0, 0), 1, 2
        #DOBJ OT_SPHERE, 0, 2, "Glass", (-1, -1.5, 12), (0, 0, 0), 1, 2
        #DOBJ OT_SPHERE, 0, 3, "Rubber", (1.5, -0.5, 18), (0, 0, 0), 1, 3
        #DOBJ OT_SPHERE, 0, 4, "Mirror", (7, 5, 18), (0, 0, 0), 1, 4
        #DOBJ OT_INTER, 0, 5, "Board", (0, 0, 0), (0, 0, 0), 1
        #DOBJ OT_PLANE, 1, 0, "Floor", (0, -4, 0), (0, 0, 0), 1
        #DOBJ OT_BOX, 1, 0, "Edges", (0, -3.55, 20), (0, 0, 0), 1, 20, 1.1, 20
dt_objs_end:
dt_mats:
        #DMATR "Ivory", (0.4, 0.4, 0.3), (0, 0, 0), 1, 0, 50, 0, 0.9, 0.5, 0.1, 0, 1
        #DMATR "Glass", (0.6, 0.7, 0.8), (0, 0, 0), 1, 0, 125, 0, 0, 0.9, 0.1, 0.8, 1.5
        #DMATR "Rubber", (0.3, 0.1, 0.1), (0, 0, 0), 1, 0, 10, 0, 1.4, 0.3, 0, 0, 1
        #DMATR "Mirror", (1, 1, 1), (0, 0, 0), 1, 0, 1425, 0, 0, 16, 0.8, 0, 1
        #DMATR "Board", (0.3, 0.3, 0.3), (0.3, 0.2, 0.1), 2, 1, 40, 0, 2, 0, 0, 0, 1
dt_mats_end:
dt_lights:
        #DLIT (-20, 20, -20), (1, 1, 1), 0
        #DLIT (30, 50, 25), (1, 1, 1), 0
        #DLIT (30, 20, -30), (1, 1, 1), 0
dt_lights_end:
