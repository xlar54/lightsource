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
hit_id:         .byte 0
hit_chk:        .byte 0
best_t:         .dword 0
; origin cache (set_origin)
sph_L:          .fill 12 * NSPH
sph_LL:         .fill 4 * NSPH
; sphere test
tca:            .dword 0
tt:             .dword 0
d2:             .dword 0
thc:            .dword 0
; plane test
pl_ady:         .dword 0
pl_num:         .dword 0
pl_anum:        .dword 0
pl_lim:         .dword 0
pl_t:           .dword 0
pl_x:           .dword 0
pl_z:           .dword 0
; lights
li_n:           .byte 0
li_pos:         .fill 12
li_v:           .fill 12
li_r:           .fill 12
li_di:          .dword 0
li_sp:          .dword 0
li_dt:          .dword 0
li_st:          .dword 0
sh_dist:        .dword 0
; current material (a copy of a mat_tbl record)
cur_mat:
cm_al:          .fill 16
cm_dc:          .fill 12
cm_se:          .word 0
                .word 0
        .cerror * - cur_mat != MATREC, "cur_mat layout"
s_c:            .fill 12
s_ir:           .dword 0
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
FRAME_SIZE      = * - frame
fr_sp:          .byte 0
fr_stack:       .fill FRAME_SIZE * (MAXDEPTH + 1)
        .cerror FRAME_SIZE * (MAXDEPTH + 1) > 255, "frame stack must fit an 8-bit index"
vars_end:
