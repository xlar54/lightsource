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
;   groups   union, merge, intersection, difference of their children
;=======================================================================================

DOC_MAXOBJ      = 32
DOC_MAXMAT      = 16
DOC_MAXLIGHT    = 8
OBJ_SIZE        = 64
DMAT_SIZE       = 80
DLIGHT_SIZE     = 32

OT_SPHERE       = 0
OT_BOX          = 1
OT_CYL          = 2
OT_CONE         = 3
OT_PLANE        = 4
OT_UNION        = 5
OT_MERGE        = 6
OT_INTER        = 7
OT_DIFF         = 8
OT_GROUP        = OT_UNION              ; types from here on are groups

; object record
O_TYPE          = 0
O_DEPTH         = 1
O_MAT           = 2                     ; 0 = none (inherits), k = material k - 1
O_FLAGS         = 3                     ; bit 0 no_shadow
O_NAME          = 4                     ; 11 characters + 0
O_POS           = 16
O_ROT           = 28
O_SCALE         = 40
O_P             = 44                    ; p0, p1, p2
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
doc_version:    .byte 1
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
DOC_SIZE        = doc_end - doc_start

obj_lo:         .byte <(doc_objs + range(DOC_MAXOBJ) * OBJ_SIZE)
obj_hi:         .byte >(doc_objs + range(DOC_MAXOBJ) * OBJ_SIZE)
dmat_lo:        .byte <(doc_mats + range(DOC_MAXMAT) * DMAT_SIZE)
dmat_hi:        .byte >(doc_mats + range(DOC_MAXMAT) * DMAT_SIZE)
dlight_lo:      .byte <(doc_lights + range(DOC_MAXLIGHT) * DLIGHT_SIZE)
dlight_hi:      .byte >(doc_lights + range(DOC_MAXLIGHT) * DLIGHT_SIZE)

