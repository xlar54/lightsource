;=======================================================================================
; vars.asm - the tracer's variables (zero-filled in the program file). All are cleared
; at boot anyway: real hardware RAM is random at power-on.
;=======================================================================================
vars_start:
; rays
ray_o:          .fill 12
ray_d:          .fill 12
ray_from:       .byte 0
depth:          .byte 0
cur_d:          .fill 12                ; this cast's incoming direction
hit_n:          .fill 12
hit_p:          .byte 0                 ; the primitive hit (NO_ID: nothing)
hit_s:          .byte 0                 ; its face; bit 7 = normal flipped
hit_t:          .dword 0
; the primitive being tested: a copy of its first P_HOT bytes
cp:
cp_type:        .byte 0
cp_flags:       .byte 0
cp_mat:         .byte 0
                .byte 0
cp_c:           .fill 12
cp_s:           .fill 16                ; (the shape before R: an unrotated primitive needs
cp_r:           .fill 36                ; only the first 32 bytes; trace.asm hot_fill)
        .cerror * - cp != P_HOT, "cp layout"
        .cerror cp_s - cp != 16 || cp_r - cp != 32, "hot_fill's layout"
cpi:            .byte 0
hot_n:          .fill MAX_PRIM          ; the bytes of each one prim_load copies (hot_fill)
cp_own:         .byte 0                 ; 1: the ray starts on this primitive
ol:             .fill 12                ; the ray in its local frame
dl:             .fill 12
; its interval
pv_n:           .byte 0
pv_t0:          .dword 0
pv_s0:          .byte 0
pv_t1:          .dword 0
pv_s1:          .byte 0
; tests
sL:             .fill 12
sLL:            .dword 0
        .cerror sLL != sL + 12, "iv_sphere copies sL and sLL together"
sl_have:        .byte 0
; a sphere's L = c - o and L.L, kept for the origin they were worked out for: the camera's
; (number 0) for every primary ray, a hit point's for its shadow rays and the rays it sends
og_cur:         .word 0                 ; the ray origin's number
og_next:        .word 0
pc_og_lo:       .fill MAX_PRIM          ; each primitive's: the origin ($ffff: none)
pc_og_hi:       .fill MAX_PRIM
pc_l:           .fill 16 * MAX_PRIM     ; and sL, sLL (byte k of primitive i at k * MAX_PRIM + i)
rc_og_lo:       .fill MAX_ROOT          ; the same for each root's bounding sphere
rc_og_hi:       .fill MAX_ROOT
rc_l:           .fill 16 * MAX_ROOT
tca:            .dword 0
tt:             .dword 0
d2:             .dword 0
thc:            .dword 0
ta:             .dword 0
tb:             .dword 0
tn:             .dword 0
tf:             .dword 0
sa:             .byte 0
sb:             .byte 0
sn:             .byte 0
sf:             .byte 0
slab_h:         .dword 0
slab_fa:        .byte 0
sl_o:           .dword 0
sl_d:           .dword 0
qa:             .dword 0
qb:             .dword 0
qc:             .dword 0
disc:           .dword 0
sqd:            .dword 0
rho0:           .dword 0
rhod:           .dword 0
cn_n:           .byte 0
cn_a0:          .dword 0
cn_b0:          .dword 0
cn_a1:          .dword 0
cn_b1:          .dword 0
td_n:           .dword 0
td_d:           .dword 0
td_an:          .dword 0
td_ad:          .dword 0
td_sg:          .byte 0
; prisms
pz_pts:         .fill 8 * (MAX_PRISM_PTS + 1)   ; the outline, closed: x, z per point
pz_n:           .byte 0                 ; its edges
pz_k:           .byte 0
pz_ax:          .dword 0                ; edge k: from (ax, az) to (bx, bz)
pz_az:          .dword 0
pz_bx:          .dword 0
pz_bz:          .dword 0
pz_ex:          .dword 0
pz_ez:          .dword 0
pz_wx:          .dword 0
pz_wz:          .dword 0
pz_dx:          .dword 0                ; the 2-D direction
pz_dz:          .dword 0
pz_den:         .dword 0
pz_ns:          .dword 0
pz_t:           .dword 0
pz_nx:          .byte 0                 ; crossings, sorted
pz_xt:          .fill 4 * MAX_PRISM_PTS
pz_xf:          .fill MAX_PRISM_PTS
pz_ya:          .dword 0                ; the y slab
pz_yb:          .dword 0
pz_fa:          .byte 0
pz_fb:          .byte 0
pz_t0:          .dword 0
pz_t1:          .dword 0
pz_f0:          .byte 0
pz_f1:          .byte 0
pz_bt:          .dword 0
pz_bo:          .byte 0
pz_e:           .byte 0
pz_ivl:         .fill IVL_SIZE          ; the prism's intervals: a list
; roots and booleans
rk:             .byte 0
rpc:            .byte 0
lsp:            .byte 0
rb_c:           .fill 12
rb_r2:          .dword 0
cb_op:          .byte 0
cb_tab:         .byte 0
cb_na:          .byte 0
cb_nb:          .byte 0
cb_ia:          .byte 0
cb_ib:          .byte 0
cb_in:          .byte 0
cb_st:          .byte 0
cb_out:         .byte 0
cb_len:         .byte 0
cb_ta:          .dword 0
cb_tb:          .dword 0
cb_t0:          .dword 0
cb_p0:          .byte 0
cb_s0:          .byte 0
ev_t:           .dword 0
ev_p:           .byte 0
ev_s:           .byte 0
ivl:            .fill IVL_SIZE * IVL_SLOTS
; the surface
pl:             .fill 12
nl:             .fill 12
tex:            .fill 48
; lights (a copy of the light's record)
li_n:           .byte 0
li_pos:         .fill 12
li_col:         .fill 12
li_fl:          .byte 0
                .byte 0
li_tight:       .word 0
li_back:        .fill 12
li_cosf:        .dword 0
li_cosr:        .dword 0
li_inv:         .dword 0
        .cerror * - li_pos != LIGHT_SIZE || li_back - li_pos != L_BACK, "light layout"
li_ct:          .dword 0                ; a spotlight: cos of the angle off its axis
li_att:         .dword 0                ; and how much of its light gets here
li_v:           .fill 12
li_r:           .fill 12
li_di:          .fill 12
li_sp:          .fill 12
li_dt:          .dword 0
li_st:          .dword 0
sh_dist:        .dword 0
sh_last:        .fill MAX_LIGHT         ; the root that last blocked each light ($ff: none)
; current material (a copy of a material record)
cur_mat:
cm_al:          .fill 16
cm_c1:          .fill 12
cm_c2:          .fill 12
cm_amb:         .fill 12
cm_ps:          .word 0
cm_flags:       .byte 0
                .byte 0
cm_eta:         .fill 16
        .cerror * - cur_mat != M_USED, "cur_mat layout"
cm_dc:          .fill 12                ; the colour at the hit
; reflect / refract
rf_k:           .dword 0
rf_t:           .dword 0
rr_c:           .dword 0
rr_n:           .fill 12
rr_eta:         .dword 0
rr_eta2:        .dword 0
rr_k:           .dword 0
rr_t:           .dword 0
; general
tv:             .fill 12
pv:             .fill 12
pd3:            .fill 12
rc:             .fill 12                ; cast's result colour
; pixel
px_x:           .word 0
px_y:           .byte 0
out_r:          .byte 0
out_g:          .byte 0
out_b:          .byte 0
tb_i:           .byte 0
; cast's frame: saved on fr_stack around each recursive call
frame:
fr_col:         .fill 12
fr_p:           .fill 12
fr_tdir:        .fill 12
fr_al2:         .dword 0
fr_al3:         .dword 0
fr_hid:         .byte 0
fr_depth:       .byte 0
fr_og:          .word 0                 ; fr_p's origin number
FRAME_SIZE      = * - frame
fr_sp:          .byte 0
fr_stack:       .fill FRAME_SIZE * 5
        .cerror FRAME_SIZE * 5 > 255, "frame stack must fit an 8-bit index"
vars_end:
