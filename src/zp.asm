;=======================================================================================
; Project base-page variables, after the library's (lib/zp.asm). Keep below $90: the
; KERNAL owns $90-$FF until the takeover.
;=======================================================================================
        .virtual LIB_ZP_END
f640_ptr:       .dword ?                ; lib/fcm640.asm: current pixel ([f640_ptr],z)
f640_pal_r:     .word ?                 ; f640_palette tables
f640_pal_g:     .word ?
f640_pal_b:     .word ?
rgb_ptr:        .dword ?                ; next pixel of the 24-bit image in attic
        .include "lib/fixed_zp.asm"
tq:             .dword ?
; recolour.asm: error-row pointers (bank 0)
rc_pc:          .word ?                 ; this row's errors
rc_pn:          .word ?                 ; the next row's
rc_px:          .word ?                 ; this row, at x
rc_nx:          .word ?                 ; the next row, at x
rc_ep:          .word ?
zp_end:
        .endv
        .cerror zp_end > $90, "base page variables overflow into KERNAL space"
