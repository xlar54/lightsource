;=======================================================================================
; doc.asm - the modeller's document (resident): objects, materials, lights, camera. All
; numbers are 16.16. The whole of it, doc_start .. doc_end, is what a .MDL file holds.
;
; Objects are an outline: in order, each with a depth; an object's children are the ones
; after it with a greater depth. Primitives are made at the origin and placed by scale,
; rotate (degrees, about x then y then z) and translate, as POV-Ray does:
;   sphere   p0 = radius
;   box      p0, p1, p2 = its size in x, y, z (centred)
;   cylinder p0 = radius, p1 = height (along y, centred)
;   cone     p0 = bottom radius, p1 = top radius, p2 = height (along y, centred)
;   plane    the plane y = 0 (solid below)
;   prism    p0 = height (along y, centred); its outline (3 to 16 corners, x and z) is
;            in the corner pool: O_PFIRST = its first corner there, O_PN = how many
;   lathe    its profile (2 to 16 points: radius in x, height in z) in the corner pool as
;            a prism's; turned about y. Written as a merge of cones, one a segment
;   groups   union, merge, intersection, difference of their children
;
; The corner pool is in attic RAM (FAR_ADDR + DOC_PTS: DOC_POOL corners of 8 bytes, x and
; z), reached by DMA (pool_get / pool_put). (Not in bank 1: the C65 DOS writes there,
; for one thing the date at $1F6C4.) It is kept packed: the prisms' corners fill its first
; pool_count places, each prism's together. A .MDL file is doc_start .. doc_end, then the
; whole pool.
;
; Version 3 (prisms and the corner pool). Older files aren't read.
;=======================================================================================

DOC_MAXOBJ      = 32
DOC_MAXMAT      = 16
DOC_MAXLIGHT    = 8
DOC_MAXPTS      = 16                    ; corners in one prism
DOC_POOL        = 255                   ; corners in all
FAR_ADDR        = $8300000              ; attic: the corner pool, the scene's points, and
FAR_BANK        = (FAR_ADDR >> 16) & $0f ; room to move corners about (offsets in this bank)
FAR_MB          = FAR_ADDR >> 20
DOC_PTS         = $0000                 ; the pool
FAR_SCRATCH     = $1000                 ; (pool_open / pool_close move corners through it)
POOL_BYTES      = 8 * DOC_POOL
OBJ_SIZE        = 64
DMAT_SIZE       = 80
DLIGHT_SIZE     = 32
PSLOT_SIZE      = 8 * DOC_MAXPTS        ; one prism's corners

OT_SPHERE       = 0
OT_BOX          = 1
OT_CYL          = 2
OT_CONE         = 3
OT_PLANE        = 4
OT_PRISM        = 5
OT_LATHE        = 6
OT_UNION        = 7
OT_MERGE        = 8
OT_INTER        = 9
OT_DIFF         = 10
OT_GROUP        = OT_UNION              ; types from here on are groups

; object record
O_TYPE          = 0
O_DEPTH         = 1
O_MAT           = 2                     ; 0 = none (inherits), k = material k - 1
O_FLAGS         = 3                     ; bit 0 no_shadow, bit 1 hidden in the views
OF_HIDE         = 2                     ; (renders still have it)
O_NAME          = 4                     ; 11 characters + 0
O_POS           = 16
O_ROT           = 28
O_SCALE         = 40
O_P             = 44                    ; p0, p1, p2
O_PFIRST        = O_P + 4               ; a prism's first corner in the pool
O_PN            = O_P + 5               ; and how many it has
; material record
DM_NAME         = 0
DM_COL          = 12
DM_COL2         = 24                    ; the checker's other colour
DM_CSCALE       = 36                    ; the checker's square size
DM_FLAGS        = 40                    ; bit 0 checker
DM_PSIZE        = 42                    ; phong_size (word)
DM_AMB          = 44
DM_DIFF         = 48
DM_PHONG        = 52
DM_REFL         = 56
DM_TRANS        = 60
DM_IOR          = 64
; light record
DL_POS          = 0
DL_COL          = 12
DL_FLAGS        = 24                    ; bit 0 shadowless

FXV .function v
        .endf [FX(v[0]), FX(v[1]), FX(v[2])]

; an object: type, depth, material, name, position, rotation, scale, p0, p1, p2
DOBJ .macro t, d, m, name, pos, rot, s, p0=0, p1=0, p2=0
        .byte \t, \d, \m, 0
        .text \name
        .fill 12 - len(\name)
        .dint FXV(\pos), FXV(\rot), FX(\s), FX(\p0), FX(\p1), FX(\p2)
        .fill OBJ_SIZE - 56
.endmacro
; a material: name, colour, colour2, checker size, checker?, phong_size, ambient, diffuse,
; phong, reflection, transmit, ior
DMATR .macro name, c, c2, cs, chk, ps, amb, dif, ph, rf, tr, ior
        .text \name
        .fill 12 - len(\name)
        .dint FXV(\c), FXV(\c2), FX(\cs)
        .byte \chk, 0
        .word \ps
        .dint FX(\amb), FX(\dif), FX(\ph), FX(\rf), FX(\tr), FX(\ior)
        .fill DMAT_SIZE - 68
.endmacro
DLIT .macro pos, c, fl
        .dint FXV(\pos), FXV(\c)
        .byte \fl
        .fill DLIGHT_SIZE - 25
.endmacro

doc_start:
doc_magic:      .text "R65M"
doc_version:    .byte 3
doc_nobj:       .byte 0
doc_nmat:       .byte 0
doc_nlight:     .byte 0
doc_cam_loc:    .fill 12
doc_cam_look:   .fill 12
doc_cam_angle:  .dword 0
doc_bg:         .fill 12
doc_maxtrace:   .byte 0
doc_objs:       .fill OBJ_SIZE * DOC_MAXOBJ
doc_mats:       .fill DMAT_SIZE * DOC_MAXMAT
doc_lights:     .fill DLIGHT_SIZE * DOC_MAXLIGHT
doc_end:
DOC_SIZE        = doc_end - doc_start   ; (the part in bank 0)
MDL_SIZE        = DOC_SIZE + POOL_BYTES ; a .MDL file
        .cerror DOC_PTS + POOL_BYTES > SC_PTS, "the corner pool runs into the scene's points"
        .cerror SC_PTS + 8 * MAX_PTS > FAR_SCRATCH, "the scene's points run into the scratch area"
        .cerror FAR_SCRATCH + POOL_BYTES > PRIM_ATTIC, "the scratch area runs into the primitives"
        .cerror PRIM_ATTIC + PRIM_STRIDE * MAX_PRIM > $10000, "the primitives leave the FAR bank"

obj_lo:         .byte <(doc_objs + range(DOC_MAXOBJ) * OBJ_SIZE)
obj_hi:         .byte >(doc_objs + range(DOC_MAXOBJ) * OBJ_SIZE)
dmat_lo:        .byte <(doc_mats + range(DOC_MAXMAT) * DMAT_SIZE)
dmat_hi:        .byte >(doc_mats + range(DOC_MAXMAT) * DMAT_SIZE)
dlight_lo:      .byte <(doc_lights + range(DOC_MAXLIGHT) * DLIGHT_SIZE)
dlight_hi:      .byte >(doc_lights + range(DOC_MAXLIGHT) * DLIGHT_SIZE)

pt_buf:         .fill PSLOT_SIZE + 8    ; one prism's corners in bank 0 (+ 1: closed)

;---------------------------------------------------------------------------------------
; points in attic, by DMA. px_get / px_put: A = the first point, X = how many (8 bytes
; each), between px_base + 8 A (in attic's FAR bank) and px_b0 (bank 0). The scene's points (the
; parser, SC_PTS) use these too.
;---------------------------------------------------------------------------------------
px_get:
        jsr px_far
        #XC_FROM xc_t, 1
        #XC_TO px_b0, 0
        jmp xcopy
px_put:
        jsr px_far
        #XC_FROM px_b0, 0
        #XC_TO xc_t, 1
        jmp xcopy
; xc_t = px_base + 8 A, xc_n = 8 X
px_far:
        sta xc_t
        lda #0
        sta xc_t+1
        stx xc_n
        sta xc_n+1
        ldx #3
-       asl xc_t
        rol xc_t+1
        asl xc_n
        rol xc_n+1
        dex
        bne -
        clc
        lda xc_t
        adc px_base
        sta xc_t
        lda xc_t+1
        adc px_base+1
        sta xc_t+1
        rts

; the DMA job's source / destination: the word at w, in bank 0 (far = 0) or attic's FAR
; bank (far = 1)
XC_FROM .macro w, far
        lda \w
        sta dmaj_src
        lda \w+1
        sta dmaj_src+1
        lda #(\far ? FAR_BANK : 0)
        sta dmaj_src_bank
        lda #(\far ? FAR_MB : 0)
        sta dmaj_src_mb
.endmacro
XC_TO .macro w, far
        lda \w
        sta dmaj_dst
        lda \w+1
        sta dmaj_dst+1
        lda #(\far ? FAR_BANK : 0)
        sta dmaj_dst_bank
        lda #(\far ? FAR_MB : 0)
        sta dmaj_dst_mb
.endmacro

; xcopy: the DMA job as set up (megabytes too), xc_n bytes (nothing if 0)
xcopy:
        lda xc_n
        ora xc_n+1
        beq +
        lda xc_n
        sta dmaj_count
        lda xc_n+1
        sta dmaj_count+1
        jsr dma_go
        lda #0                          ; (the others expect megabyte 0)
        sta dmaj_src_mb
        sta dmaj_dst_mb
+       rts

; the pool: pool_get / pool_put move corners A .. A + X - 1 to / from pt_buf; the _b
; forms use px_b0 as it is
pool_get:
        ldy #<pt_buf
        sty px_b0
        ldy #>pt_buf
        sty px_b0+1
pool_get_b:
        ldy #<DOC_PTS
        sty px_base
        ldy #>DOC_PTS
        sty px_base+1
        jmp px_get
pool_put:
        ldy #<pt_buf
        sty px_b0
        ldy #>pt_buf
        sty px_b0+1
pool_put_b:
        ldy #<DOC_PTS
        sty px_base
        ldy #>DOC_PTS
        sty px_base+1
        jmp px_put

; A = the corners in use (the prisms' counts added up)
pool_count:
        lda #0
        sta po_used
        ldx #0
-       cpx doc_nobj
        beq +
        jsr po_obj
        bne _n
        clc
        ldy #O_PN
        lda (txt_ptr),y
        adc po_used
        sta po_used
_n:     inx
        bra -
+       lda po_used
        rts
; txt_ptr = object X; Z set if it's a prism
po_obj:
        lda obj_lo,x
        sta txt_ptr
        lda obj_hi,x
        sta txt_ptr+1
        ldy #O_TYPE                     ; (prisms and lathes have corners)
        lda (txt_ptr),y
        cmp #OT_PRISM
        beq +
        cmp #OT_LATHE
+       rts

; pool_open: room for X corners at place A (the ones from there move up; prisms that
; start there or later start that much later). Carry set if the pool is full.
pool_open:
        sta po_at
        stx po_n
        jsr pool_count
        clc
        adc po_n
        bcs _full                       ; (DOC_POOL is 255: a carry is too many)
        sec                             ; the ones after: through TEXT_BUF, then back
        lda po_used
        sbc po_at
        tax
        lda po_at
        jsr po_out
        clc
        lda po_at
        adc po_n
        jsr po_in
        ldx #0
-       cpx doc_nobj
        beq _done
        jsr po_obj
        bne +
        ldy #O_PFIRST
        lda (txt_ptr),y
        cmp po_at
        bcc +
        adc po_n                        ; (carry set: + n - 1 + 1)
        dec a
        sta (txt_ptr),y
+       inx
        bra -
_done:  clc
        rts
_full:  sec
        rts

; pool_close: X corners at place A go (those after them move down; prisms that start
; after A start that much sooner). Call it before changing the counts.
pool_close:
        sta po_at
        stx po_n
        jsr pool_count
        sec
        sbc po_at
        sec
        sbc po_n
        tax                             ; the ones after
        clc
        lda po_at
        adc po_n
        jsr po_out
        lda po_at
        jsr po_in
        ldx #0
-       cpx doc_nobj
        beq _done
        jsr po_obj
        bne +
        ldy #O_PFIRST
        lda (txt_ptr),y
        cmp po_at
        beq +
        bcc +
        sec
        sbc po_n
        sta (txt_ptr),y
+       inx
        bra -
_done:  rts

; po_out: X corners from place A to FAR_SCRATCH (their count kept for po_in); po_in:
; them back to place A
po_out:
        stx po_t
        ldy #<DOC_PTS
        sty px_base
        ldy #>DOC_PTS
        sty px_base+1
        jsr px_far
        #XC_FROM xc_t, 1
        #XC_TO po_scr, 1
        jmp xcopy
po_in:
        ldx po_t
        jsr px_far
        #XC_FROM po_scr, 1
        #XC_TO xc_t, 1
        jmp xcopy
po_scr:         .word FAR_SCRATCH

px_base:        .word 0
px_b0:          .word 0
xc_t:           .word 0
xc_n:           .word 0
po_at:          .byte 0
po_n:           .byte 0
po_used:        .byte 0
po_t:           .byte 0
