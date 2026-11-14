;=======================================================================================
; scene.asm - the compiled scene: the tables the tracer reads (docs/DESIGN.md, "The
; compiled scene"). The parser (parse.asm) fills them from a scene file; a test build can
; take them ready-made from private/tools/pov.py (DBG_SCENEBIN = 1, scene.bin on the
; include path).
;
; The layout is fixed: private/tools/pov.py writes the same bytes (to_bytes), and the
; tests compare them.
;=======================================================================================

MAX_PRIM        = 64
MAX_MAT         = 16
MAX_LIGHT       = 16
MAX_ROOT        = 64
MAX_PTS         = 255                   ; prism points in all (each outline stored closed)
SC_PTS          = $0800                 ; the points (x and z, 8 bytes each): in attic,
                                        ; at FAR_ADDR + SC_PTS (doc.asm)
MAX_PRISM_PTS   = 16                    ; corners of one prism
PRIM_SIZE       = 128                   ; a primitive's record (what the tracer reads)
PRIM_STRIDE     = 160                   ; records in attic: + 32 bytes the parser keeps
P_PAR           = PRIM_SIZE             ; its definition in (sphere c, r; box a, b; ...)
PRIM_ATTIC      = $2000                 ; the records: attic, at FAR_ADDR + this (doc.asm)
MAT_SIZE        = 80
LIGHT_SIZE      = 28
ROOT_SIZE       = 20
HDR_SIZE        = 80

T_SPHERE        = 0
T_BOX           = 1
T_CYL           = 2
T_CONE          = 3
T_PLANE         = 4
T_PRISM         = 5                     ; shape: half height, first point (byte 4) and
                                        ; corners (byte 5), orientation (+-ONE)
F_ROT           = 1                     ; prim flags
F_NOSHADOW      = 2
MF_CHECKER      = 1                     ; material flags
LF_SHADOWLESS   = 1                     ; light flags
RF_BOUND        = 1                     ; root flags
RF_NOSHADOW     = 2
OP_UNION        = $80                   ; boolean program
OP_INTER        = $81
OP_DIFF         = $82
OP_END          = $ff
NO_ID           = $ff

; ---- record offsets ----
; header
SC_NPRIM        = 0
SC_NMAT         = 1
SC_NLIGHT       = 2
SC_NROOT        = 3
SC_MAXD         = 4
SC_NPTS         = 5                     ; prism points in use
SC_BG           = 8
SC_CAM_O        = 20
SC_CAM_R        = 32
SC_CAM_U        = 44
SC_CAM_F        = 56
; light
L_POS           = 0
L_COL           = 12
L_FLAGS         = 24
; root
R_START         = 0
R_FLAGS         = 1
R_BC            = 4
R_BR2           = 16
; material
M_AL            = 0                     ; diffuse, phong, reflection, transmit
M_C1            = 16
M_C2            = 28
M_AMB           = 40
M_PS            = 52                    ; phong_size (word)
M_FLAGS         = 54
M_ETA           = 56                    ; 1/ior, 1/ior^2, ior, ior^2
M_USED          = 72
; primitive
P_TYPE          = 0
P_FLAGS         = 1
P_MAT           = 2
P_C             = 4
P_R             = 16                    ; rows x, y, z
P_S             = 52                    ; shape: 4 dwords
P_HOT           = 68                    ; the bytes the intersection tests use
P_TEXA          = 68
P_TEXT          = 104

; the tables in bank 0; the primitive records are in attic (prim_lo / prim_hi: offsets in
; the FAR bank), with each one's type here too (sc_ptype) for the tracer's quick checks
SCENE_SIZE      = HDR_SIZE + LIGHT_SIZE * MAX_LIGHT + ROOT_SIZE * MAX_ROOT + 256 + MAT_SIZE * MAX_MAT + MAX_PRIM
        .if DBG_SCENEBIN
scene:          .binary "scene.bin"     ; a test build: the tables as pov.py made them
        .cerror * - scene != SCENE_SIZE, "scene.bin is the wrong size"
scene_pts:      .binary "scenepts.bin"  ; and the prism points in use (boot copies them
scene_pts_end:                          ; to SC_PTS)
scene_prims:    .binary "sceneprims.bin" ; and the primitive records (to PRIM_ATTIC)
scene_prims_end:
        .cerror scene_pts_end - scene_pts > 8 * MAX_PTS, "scenepts.bin is too big"
        .else
        .section bss
scene:          .fill SCENE_SIZE
        .send bss
        .endif
sc_hdr          = scene
sc_lights       = sc_hdr + HDR_SIZE
sc_roots        = sc_lights + LIGHT_SIZE * MAX_LIGHT
sc_prog         = sc_roots + ROOT_SIZE * MAX_ROOT
sc_mats         = sc_prog + 256
sc_ptype        = sc_mats + MAT_SIZE * MAX_MAT  ; each primitive's type

sc_nprim        = sc_hdr + SC_NPRIM
sc_nmat         = sc_hdr + SC_NMAT
sc_nlight       = sc_hdr + SC_NLIGHT
sc_nroot        = sc_hdr + SC_NROOT
sc_maxd         = sc_hdr + SC_MAXD
sc_npts         = sc_hdr + SC_NPTS
sc_bg           = sc_hdr + SC_BG
sc_cam_o        = sc_hdr + SC_CAM_O
sc_cam_r        = sc_hdr + SC_CAM_R
sc_cam_u        = sc_hdr + SC_CAM_U
sc_cam_f        = sc_hdr + SC_CAM_F

; record addresses by index
root_lo:        .byte <(sc_roots + range(MAX_ROOT) * ROOT_SIZE)
root_hi:        .byte >(sc_roots + range(MAX_ROOT) * ROOT_SIZE)
mat_lo:         .byte <(sc_mats + range(MAX_MAT) * MAT_SIZE)
mat_hi:         .byte >(sc_mats + range(MAX_MAT) * MAT_SIZE)
light_lo:       .byte <(sc_lights + range(MAX_LIGHT) * LIGHT_SIZE)
light_hi:       .byte >(sc_lights + range(MAX_LIGHT) * LIGHT_SIZE)
prim_lo:        .byte <(PRIM_ATTIC + range(MAX_PRIM) * PRIM_STRIDE)   ; (attic offsets)
prim_hi:        .byte >(PRIM_ATTIC + range(MAX_PRIM) * PRIM_STRIDE)
