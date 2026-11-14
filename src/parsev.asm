;=======================================================================================
; parsev.asm - the parser's variables (overlay 2). pv_start..pv_end is cleared at the start
; of every parse.
;=======================================================================================
sp_             = pb                    ; base-page pointers: a declared name's entry
xp              = pd                    ; a transform (48 bytes) in bank 0

parse_err:      .byte 0                 ; results
parse_line:     .word 0
parse_sp:       .byte 0

pv_start:
; tokens
tk_type:        .byte 0
tk_kw:          .byte 0
tk_num:         .dword 0
tk_name:        .fill NAME_MAX + 1
tk_nlen:        .byte 0
tk_pos:         .word 0                 ; where the token starts (bank 1)
tk_tline:       .word 0                 ; and its line
tk_line:        .word 0                 ; the line at ptr0
nm_ip:          .word 0
nm_fr:          .word 0
nm_nd:          .byte 0
nm_d:           .byte 0
pp_ret:         .word 0
sym_count:      .byte 0
sym_pos:        .word 0
sym_line:       .word 0
db_kind:        .byte 0
db_fn:          .word 0
sk_depth:       .byte 0
; values
v_n:            .byte 0                 ; V
v_c:            .fill 20
w_n:            .byte 0                 ; W (must follow V)
w_c:            .fill 20
vsp:            .byte 0
vw_n:           .byte 0
vw_k:           .byte 0
vw_x:           .byte 0
bo_op:          .byte 0
bo_n:           .byte 0
bo_i:           .byte 0
bo_a:           .dword 0
bo_b:           .dword 0
bo_r:           .dword 0
vl_k:           .byte 0
vl_n:           .byte 0
col:            .fill 20                ; a colour: r, g, b, filter, transmit
tv3:            .dword 0
; the scene's settings
amb_light:      .fill 12
max_trace:      .word 0
clock:          .dword 0
cam_set:        .byte 0
cam_line:       .word 0
cam_loc:        .fill 12
cam_look:       .fill 12
cam_sky:        .fill 12
cam_angle:      .dword 0
lt_pos:         .fill 12                ; a light, as its record
lt_col:         .fill 12
lt_fl:          .byte 0
; objects
prog_len:       .byte 0
pr_type:        .byte 0
pr_line:        .word 0
ob_d:           .byte 0
ob_flat:        .fill MAX_DEPTH
ob_kw:          .fill MAX_DEPTH
ob_p0:          .fill MAX_DEPTH         ; its first primitive
ob_r0:          .fill MAX_DEPTH         ; where its program starts
ob_cnt:         .fill MAX_DEPTH
; transforms
xw:             .fill 48
xv:             .fill 12
xinv:           .fill 12
xrot:           .fill 12
xc:             .dword 0
xs:             .dword 0
xax:            .byte 0
xop:            .byte 0
xr_a:           .byte 0
xr_b:           .byte 0
xr_j:           .byte 0
xr_u:           .byte 0
xr_v:           .byte 0
ru:             .dword 0
rv:             .dword 0
ru2:            .dword 0
rv2:            .dword 0
ro_fn:          .word 0
ro_i:           .byte 0
ninv:           .fill 48                ; the inverse of this object's transforms so far
; the material being built
m_active:       .byte 0
at_mat:         .byte 0
ma_k:           .byte 0
mt_start:
mt_col:         .fill 20
mt_col2:        .fill 20
mt_chk:         .byte 0
mt_ptex:        .fill 48
mt_amb:         .fill 12
mt_diff:        .dword 0
mt_phong:       .dword 0
mt_psize:       .word 0
mt_refl:        .dword 0
mt_ior:         .dword 0
mt_end:
        .cerror mt_end - mt_start > 128, "mt_reset's loop"
mrec:           .fill MAT_SIZE
tw:             .fill 48
mm_col:         .fill 12
; finalising
fa_v:           .fill 12
fp_par:         .fill 32
fm:             .fill 48                ; M: A, t
fcol:           .fill 36                ; A's columns
fls:            .fill 12                ; their lengths
fc:             .fill 12                ; the record's c, R, shape
fmr:            .fill 36
fsh:            .fill 16
fp_type:        .byte 0
fp_inf:         .byte 0
fp_br:          .dword 0
fp_s:           .dword 0
fp_r:           .dword 0
fp_ra:          .dword 0
fp_rb:          .dword 0
fp_rm:          .dword 0
fp_l:           .dword 0
fp_h:           .dword 0
fv_in:          .fill 12
fv_out:         .fill 12
fhd:            .fill 12
fpa:            .fill 12
fpb:            .fill 12
fax:            .fill 12
fnh:            .fill 12
cr_a:           .fill 12
cr_b:           .fill 12
cr_r:           .fill 12
vn_a:           .fill 12
vn_r:           .fill 12
vn_l:           .dword 0
fn_k:           .byte 0
fn_pc:          .byte 0
fn_fl:          .byte 0
fb_c:           .fill 12                ; a root's bound: centre, radius^2 (together)
fb_r2:          .dword 0
fb_h:           .fill 12
bx_sp:          .byte 0
bc_op:          .byte 0
ba:             .fill BX_SIZE
bb:             .fill BX_SIZE
bx:             .fill BX_SIZE * MAX_STACK
ca_fv:          .fill 12
ca_half:        .dword 0
ca_sin:         .dword 0
pr_n:           .byte 0                 ; prisms
fz_i:           .byte 0
fz_a:           .fill 16
fz_area:        .dword 0
fz_rm:          .dword 0
pv_end:
