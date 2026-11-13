;=======================================================================================
; scene.asm - THE SCENE. Edit the settings below, then build (see README.md, "Editing the
; scene").
;
; Everything between here and "---- tables" is NAME = value, one per line, in a syntax that
; 64tass and Python both read: numbers, (x, y, z) tuples, [lists], and the names above.
; private/tools/ref_trace.py loads these same lines, so the test model follows any edit.
;
; Units are scene units (the original's). The camera looks down -z; +y is up, +x right.
; Keep every distance between things that can see each other under about 120 units: the
; maths is 16.16 fixed point (largest value 32767, and squared distances must fit).
;=======================================================================================

; ---- spheres: one entry per sphere in each of the three lists (about 16 fit) ----------
SPH_C   = [(-3.0, 0.0, -16.0), (-1.0, -1.5, -12.0), (1.5, -0.5, -18.0), (7.0, 5.0, -18.0)]
SPH_R   = [2.0, 2.0, 3.0, 4.0]
SPH_M   = [M_IVORY, M_GLASS, M_RUBBER, M_MIRROR]

; ---- point lights (up to 20), all white and equally bright ----------------------------
LIGHTS  = [(-20.0, 20.0, 20.0), (30.0, 50.0, -25.0), (30.0, 20.0, 30.0)]

; ---- materials: one entry per material in each list (up to 8) --------------------------
; albedo = (diffuse, specular, reflection, refraction) weights; colour = diffuse r, g, b
; (0..1); exponent = highlight sharpness (1..65535). The ids name the list positions.
M_IVORY = 0
M_GLASS = 1
M_RUBBER = 2
M_MIRROR = 3
M_PLANE = 4
MAT_AL  = [(0.9, 0.5, 0.1, 0.0), (0.0, 0.9, 0.1, 0.8), (1.4, 0.3, 0.0, 0.0), (0.0, 16.0, 0.8, 0.0), (2.0, 0.0, 0.0, 0.0)]
MAT_DC  = [(0.4, 0.4, 0.3), (0.6, 0.7, 0.8), (0.3, 0.1, 0.1), (1.0, 1.0, 1.0), (0.0, 0.0, 0.0)]
MAT_SE  = [50, 125, 10, 1425, 0]

; refraction: one index for every material with a refraction weight (1.5 = glass)
IOR     = 1.5

; ---- the checkerboard: the plane y = PLANE_Y, for -PLANE_XMAX < x < PLANE_XMAX and
; PLANE_ZMIN < z < PLANE_ZMAX, in 2-unit squares, material M_PLANE (its colour comes from
; CHECK_A / CHECK_B). PLANE_ON = 0 removes it.
PLANE_ON   = 1
PLANE_Y    = -4.0
PLANE_XMAX = 10.0
PLANE_ZMIN = -30.0
PLANE_ZMAX = -10.0
CHECK_A = (0.3, 0.3, 0.3)
CHECK_B = (0.3, 0.2, 0.1)

; ---- sky, camera ------------------------------------------------------------------------
BG      = (0.2, 0.7, 0.8)               ; what rays that hit nothing see
CAM     = (0.0, 0.0, 0.0)               ; camera position (it always looks down -z)
FOV     = 1.05                          ; vertical field of view, radians (1.05 = 60 deg)
MAXDEPTH = 4                            ; reflection / refraction bounces (0..4)

; ---- tables (nothing to edit below) ----------------------------------------------------

NSPH            = len(SPH_C)
NLIGHT          = len(LIGHTS)
NMAT            = len(MAT_AL)
PLANE_ID        = NSPH                  ; hit ids: 0..NSPH-1 spheres, PLANE_ID, NO_ID
NO_ID           = $ff
PIXEL_ASPECT    = 1.875                 ; a 640x200 pixel on a 4:3 PAL screen (not 2.0)
; the primary rays' z: -(200 rows * aspect / 2) / tan(fov / 2), scaled by 1/512 like x, y
DZ              = -int(round(200 * PIXEL_ASPECT / 2 / tan(FOV / 2) / 512 * 65536))

        .cerror len(SPH_R) != NSPH || len(SPH_M) != NSPH, "SPH_C, SPH_R and SPH_M need one entry per sphere"
        .cerror NSPH < 1 || NSPH > 20, "1 to 20 spheres"
        .cerror NLIGHT < 1 || NLIGHT > 20, "1 to 20 lights"
        .cerror len(MAT_DC) != NMAT || len(MAT_SE) != NMAT, "MAT_AL, MAT_DC and MAT_SE need one entry per material"
        .cerror NMAT > 8, "at most 8 materials"
        .cerror M_PLANE >= NMAT, "M_PLANE must be a material"
        .cerror MAXDEPTH < 0 || MAXDEPTH > 4, "MAXDEPTH is 0..4 (the frame stack)"

; sphere s: sph_c + 12 s (x, y, z), sph_r2 + 4 s, sph_ir + 4 s
sph_c:
        .for si = 0, si < NSPH, si += 1
        .dint FX(SPH_C[si][0]), FX(SPH_C[si][1]), FX(SPH_C[si][2])
        .next
sph_r2:
        .for si = 0, si < NSPH, si += 1
        .dint FX(SPH_R[si] * SPH_R[si])
        .next
sph_ir:
        .for si = 0, si < NSPH, si += 1
        .dint FX(1.0 / SPH_R[si])
        .next
sph_mat:
        .for si = 0, si < NSPH, si += 1
        .cerror SPH_M[si] >= NMAT, "SPH_M names a material that isn't in MAT_AL"
        .byte SPH_M[si]
        .next

light_pos:
        .for si = 0, si < NLIGHT, si += 1
        .dint FX(LIGHTS[si][0]), FX(LIGHTS[si][1]), FX(LIGHTS[si][2])
        .next

bg_col:         .dint FX(BG[0]), FX(BG[1]), FX(BG[2])
check_a:        .dint FX(CHECK_A[0]), FX(CHECK_A[1]), FX(CHECK_A[2])
check_b:        .dint FX(CHECK_B[0]), FX(CHECK_B[1]), FX(CHECK_B[2])
cam_pos:        .dint FX(CAM[0]), FX(CAM[1]), FX(CAM[2])
q_plane_y:      .dint FX(PLANE_Y)
q_plane_x:      .dint FX(PLANE_XMAX)
q_plane_z0:     .dint FX(PLANE_ZMIN)
q_plane_z1:     .dint FX(PLANE_ZMAX)

; one 32-byte record per material, copied to cur_mat (trace.asm) on a hit:
;   +0 albedo 0..3 (4 dwords), +16 colour r, g, b (3 dwords), +28 exponent (word), +30 pad
MATREC          = 32
mat_tbl:
        .for si = 0, si < NMAT, si += 1
        .dint FX(MAT_AL[si][0]), FX(MAT_AL[si][1]), FX(MAT_AL[si][2]), FX(MAT_AL[si][3])
        .dint FX(MAT_DC[si][0]), FX(MAT_DC[si][1]), FX(MAT_DC[si][2])
        .word MAT_SE[si]
        .word 0
        .next

eta_in:         .dint FX(1.0 / IOR)     ; air -> glass
eta2_in:        .dint FX(1.0 / IOR / IOR)
eta_out:        .dint FX(IOR)           ; glass -> air
eta2_out:       .dint FX(IOR * IOR)
