;=======================================================================================
; gui.asm - the 640x200 graphical toolkit (resident): palette, mouse pointer, events,
; menus, the status line, typing a value, numbers as text.
;
;   gui_on         the interface's palette, pointer on (after a render took the screen)
;   gui_off        pointer off
;   gui_poll       once a frame: ev_type (EV_*), ev_x (word) / ev_y, ev_key. Tests inject
;                  events: dbg_ev (EV_MAX x 4 bytes: type, x lo, x hi, y; ev_key from
;                  dbg_keys for EV_KEY), dbg_evn = how many
;   gui_text       A/X = string, d6_tc / d6_y / d6_col / d6_bg as for d6_text
;   gui_status     A/X = string on the status line
;   gui_menubar    draw the menu bar (gui_menus)
;   gui_menu       ev_x = where the bar was clicked: open that menu, track it -> A =
;                  command (0 = none)
;   gui_edit       A/X = prompt, ge_buf = the text to start from: edit it on the status
;                  line. Carry clear = RETURN, set = ESC / STOP
;   gui_fmt        gf_v (16.16) with A decimals (bit 7 set: drop trailing zeros) ->
;                  gf_str (zero-terminated)
;   gui_num        ge_buf -> gf_v; carry set if it isn't a number
;   gui_fill       the rectangle d6_x.. d6_y1 in A
;
; The palette: entries 0-15 are the interface's (GC_* names); renders use their own.
;=======================================================================================

EV_NONE         = 0
EV_KEY          = 1
EV_DOWN         = 2
EV_UP           = 3
EV_MOVE         = 4                     ; with the left button held
EV_RDOWN        = 5
EV_MAX          = 16

GC_BLACK        = 0
GC_WHITE        = 1
GC_BG           = 2                     ; views
GC_PANEL        = 3
GC_FRAME        = 4
GC_BAR          = 5
GC_SEL          = 6                     ; selection background
GC_YELLOW       = 7
GC_ORANGE       = 8
GC_GREEN        = 9
GC_RED          = 10
GC_CYAN         = 11
GC_WIRE         = 12
GC_LIGHT        = 13
GC_DARK         = 14

MENU_ROW        = 1                     ; the bar's text row (pixels)
STATUS_Y        = 191

;---------------------------------------------------------------------------------------
gui_on:
        lda #<gui_pal_r
        sta f640_pal_r
        lda #>gui_pal_r
        sta f640_pal_r+1
        lda #<gui_pal_g
        sta f640_pal_g
        lda #>gui_pal_g
        sta f640_pal_g+1
        lda #<gui_pal_b
        sta f640_pal_b
        lda #>gui_pal_b
        sta f640_pal_b+1
        jsr f640_palette
        lda gui_inited
        bne +
        lda #1
        sta gui_inited
        jsr hws_init
        ldx #0
        lda #<gui_arrow
        ldy #>gui_arrow
        jsr hws_shape
        ldx #0
        lda #GC_WHITE
        jsr hws_colour
        jsr mouse_init
+       ldx #0
        jsr hws_on
        jmp gui_pointer
gui_off:
        ldx #0
        jmp hws_off
gui_inited:     .byte 0

; the pointer where the mouse is (sprites are placed in 320-wide units)
gui_pointer:
        lda mouse_x+1                   ; x / 2: all 16 bits (x reaches 639)
        lsr
        sta hws_x+1
        lda mouse_x
        ror
        sta hws_x
        lda mouse_y
        sta hws_y
        lda #0
        sta hws_y+1
        ldx #0
        jmp hws_place

gui_poll:
        lda #EV_NONE
        sta ev_type
        lda dbg_evp                     ; an injected event?
        cmp dbg_evn
        bcs _real
        asl
        asl
        tax
        inc dbg_evp
        lda dbg_ev,x
        sta ev_type
        lda dbg_ev+1,x
        sta ev_x
        sta mouse_x
        lda dbg_ev+2,x
        sta ev_x+1
        sta mouse_x+1
        lda dbg_ev+3,x
        sta ev_y
        sta mouse_y
        lda ev_type
        cmp #EV_KEY
        bne +
        jsr key_get
        sta ev_key
+       jmp gui_pointer
_real:
        jsr mouse_poll
        jsr gui_pointer
        lda mouse_x
        sta ev_x
        lda mouse_x+1
        sta ev_x+1
        lda mouse_y
        sta ev_y
        jsr key_get
        beq +
        sta ev_key
        lda #EV_KEY
        sta ev_type
        rts
+       lda mouse_left_click
        beq +
        lda #1
        sta gui_held
        lda #EV_DOWN
        sta ev_type
        bra _moved
+       lda mouse_left_release
        beq +
        lda #0
        sta gui_held
        lda #EV_UP
        sta ev_type
        bra _moved
+       lda mouse_right_click
        beq +
        lda #EV_RDOWN
        sta ev_type
        rts
+       lda gui_held                    ; held and moved: a drag step
        beq _moved
        lda ev_x
        cmp gui_lx
        bne +
        lda ev_x+1
        cmp gui_lx+1
        bne +
        lda ev_y
        cmp gui_ly
        beq _moved
+       lda #EV_MOVE
        sta ev_type
_moved:
        lda ev_x
        sta gui_lx
        lda ev_x+1
        sta gui_lx+1
        lda ev_y
        sta gui_ly
        rts

ev_type:        .byte 0
ev_x:           .word 0
ev_y:           .byte 0
ev_key:         .byte 0
gui_held:       .byte 0
gui_lx:         .word 0
gui_ly:         .byte 0
dbg_ev:         .fill EV_MAX * 4        ; injected events (tests)
dbg_evn:        .byte 0
dbg_evp:        .byte 0

;---------------------------------------------------------------------------------------
; text and fills
;---------------------------------------------------------------------------------------
gui_text = d6_text

; the rectangle d6_x, d6_y - d6_x1, d6_y1 in colour A
gui_fill:
        sta d6_col
        jmp d6_fill

; GXY: d6_x / d6_y / d6_x1 / d6_y1 = constants
GXY .macro x0, y0, x1, y1
        lda #<(\x0)
        sta d6_x
        lda #>(\x0)
        sta d6_x+1
        lda #<(\y0)
        sta d6_y
        lda #>(\y0)
        sta d6_y+1
        lda #<(\x1)
        sta d6_x1
        lda #>(\x1)
        sta d6_x1+1
        lda #<(\y1)
        sta d6_y1
        lda #>(\y1)
        sta d6_y1+1
.endmacro
; text at column c, row y, colours fg / bg
GTEXT .macro c, y, fg, bg, str
        lda #\c
        sta d6_tc
        lda #<(\y)
        sta d6_y
        lda #>(\y)
        sta d6_y+1
        lda #\fg
        sta d6_col
        lda #\bg
        sta d6_bg
        lda #<\str
        ldx #>\str
        jsr d6_text
.endmacro

gui_status:
        pha
        phx
        jsr d6_clip_all
        #GXY 0, STATUS_Y - 1, 639, 199
        lda #GC_BAR
        jsr gui_fill
        plx
        pla
        sta txt_ptr
        stx txt_ptr+1
        lda #1
        sta d6_tc
        lda #STATUS_Y
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_WHITE
        sta d6_col
        lda #GC_BAR
        sta d6_bg
        lda txt_ptr
        ldx txt_ptr+1
        jmp d6_text

;---------------------------------------------------------------------------------------
; menus. gui_menus: for each menu: its column on the bar, its title, then its items
; (command byte, string); a zero command ends the items; a zero column ends the list.
;---------------------------------------------------------------------------------------
gui_menubar:
        jsr d6_clip_all
        #GXY 0, 0, 639, 9
        lda #GC_BAR
        jsr gui_fill
        lda #<gui_menus
        sta gm_p
        lda #>gui_menus
        sta gm_p+1
_m:
        jsr gm_byte
        beq _done
        sta d6_tc
        lda #MENU_ROW
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_WHITE
        sta d6_col
        lda #GC_BAR
        sta d6_bg
        jsr gm_string_draw
-       jsr gm_byte                     ; skip the items
        beq _m
        jsr gm_skip_string
        bra -
_done:  rts

; A = the next byte of the menu table (gm_p moves on), Z set if zero
gm_byte:
        ldy #0
        lda gm_p
        sta txt_ptr
        lda gm_p+1
        sta txt_ptr+1
        lda (txt_ptr),y
        inc gm_p
        bne +
        inc gm_p+1
+       cmp #0
        rts
gm_skip_string:
-       jsr gm_byte
        bne -
        rts
; draw the string at gm_p (d6_* set) and move past it
gm_string_draw:
        lda gm_p
        ldx gm_p+1
        jsr d6_text
        jmp gm_skip_string

gui_menu:
        ; which title: the last whose column is at or left of the click
        lda ev_x+1                      ; column = x / 8
        sta tmp0
        lda ev_x
        lsr tmp0
        ror
        lsr tmp0
        ror
        lsr tmp0
        ror
        sta gm_col
        lda #<gui_menus
        sta gm_p
        lda #>gui_menus
        sta gm_p+1
        lda #0
        sta gm_sel
        sta gm_sel+1
_m:
        lda gm_p                        ; this menu starts here
        sta gm_here
        lda gm_p+1
        sta gm_here+1
        jsr gm_byte
        beq _found
        cmp gm_col
        beq +
        bcs _found
+       sta gm_tcol
        lda gm_here
        sta gm_sel
        lda gm_here+1
        sta gm_sel+1
        jsr gm_skip_string
-       jsr gm_byte
        beq _m
        jsr gm_skip_string
        bra -
_found:
        lda gm_sel+1
        bne +
        lda #0
        rts
+       ; the menu at gm_sel: count its items, draw the box under its title
        lda gm_sel
        sta gm_p
        lda gm_sel+1
        sta gm_p+1
        jsr gm_byte
        sta gm_tcol
        jsr gm_skip_string
        lda gm_p                        ; the items start here
        sta gm_items
        lda gm_p+1
        sta gm_items+1
        jsr gui_menu_draw
        ; track: a click on an item gives its command; anything else closes it
_wait:
        jsr wait_frame
        jsr gui_poll
        lda ev_type
        cmp #EV_KEY
        bne +
        lda ev_key
        cmp #K_ESC
        beq _none
        cmp #K_STOP
        beq _none
        bra _wait
+       cmp #EV_DOWN
        bne _wait
        ; which item: rows from y 11, 9 pixels each, in columns gm_tcol .. + 16
        lda ev_x+1
        sta tmp0
        lda ev_x
        lsr tmp0
        ror
        lsr tmp0
        ror
        lsr tmp0
        ror
        sec
        sbc gm_tcol
        bcc _none
        cmp #GM_WIDTH
        bcs _none
        sec
        lda ev_y
        sbc #11
        bcc _none
        ldx #0
-       cmp #9
        bcc +
        sbc #9
        inx
        bra -
+       cpx gm_n
        bcs _none
        stx gm_pick
        ; its command
        lda gm_items
        sta gm_p
        lda gm_items+1
        sta gm_p+1
-       jsr gm_byte
        sta gm_cmd
        lda gm_pick
        beq +
        dec gm_pick
        jsr gm_skip_string
        bra -
+       lda gm_cmd
        bra +
_none:
        lda #0
+       pha                             ; what was under it, back
        ldx #0
        jsr gui_restore
        pla
        rts
GM_WIDTH        = 18                    ; a drop-down's width in columns

gui_menu_draw:
        lda gm_items                    ; count the items
        sta gm_p
        lda gm_items+1
        sta gm_p+1
        lda #0
        sta gm_n
-       jsr gm_byte
        beq +
        inc gm_n
        jsr gm_skip_string
        bra -
+       jsr d6_clip_all
        lda gm_tcol                     ; the box: x = col * 8 - 4 .. + GM_WIDTH * 8 + 4
        asl
        asl
        asl
        sec
        sbc #4
        sta d6_x
        lda #0
        sbc #0
        sta d6_x+1
        lda gm_tcol
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc d6_x+1
        sta d6_x+1
        clc
        lda d6_x
        adc #<(GM_WIDTH * 8 + 4)
        sta d6_x1
        lda d6_x+1
        adc #>(GM_WIDTH * 8 + 4)
        sta d6_x1+1
        lda #10
        sta d6_y
        lda #0
        sta d6_y+1
        sta d6_y1+1
        lda gm_n                        ; y1 = 11 + 9 n
        asl
        asl
        asl
        clc
        adc gm_n
        adc #11
        sta d6_y1
        ldx #0                          ; (gui_menu puts this back when it closes)
        jsr gui_save
        lda #GC_PANEL
        jsr gui_fill
        lda #GC_FRAME
        sta d6_col
        jsr d6_frame
        ; the items
        lda gm_items
        sta gm_p
        lda gm_items+1
        sta gm_p+1
        lda #12
        sta gm_y
-       jsr gm_byte
        beq +
        lda gm_tcol
        sta d6_tc
        lda gm_y
        sta d6_y
        lda #0
        sta d6_y+1
        lda #GC_WHITE
        sta d6_col
        lda #GC_PANEL
        sta d6_bg
        jsr gm_string_draw
        clc
        lda gm_y
        adc #9
        sta gm_y
        bra -
+       rts

gm_p:           .word 0
gm_here:        .word 0
gm_sel:         .word 0
gm_items:       .word 0
gm_col:         .byte 0
gm_tcol:        .byte 0
gm_n:           .byte 0
gm_pick:        .byte 0
gm_cmd:         .byte 0
gm_y:           .byte 0

;---------------------------------------------------------------------------------------
; gui_save / gui_restore: X = a slot (0 or 1). Save keeps what is on the screen in the
; rectangle d6_x .. d6_y1 (rounded out to whole 8x8 cells), in attic; restore puts it
; back. The cells of one 8-pixel band are one run of memory (fcm640's layout), so a band
; is one DMA copy. Menus and the Open dialog use slot 0, typing on the status line slot 1.
;---------------------------------------------------------------------------------------
GS_ATTIC        = $8310000              ; slot n at GS_ATTIC + n * $8000 (32 KB each)
gui_save:
        stx gs_s
        lda d6_x                        ; cells: c0 = x >> 3, nc = (x1 >> 3) - c0 + 1
        ldy d6_x+1
        jsr gs_cell
        sta gs_c0,x
        lda d6_x1
        ldy d6_x1+1
        jsr gs_cell
        sec
        sbc gs_c0,x
        inc a
        sta gs_nc,x
        lda d6_y                        ; bands: b0 = y >> 3, nb = (y1 >> 3) - b0 + 1
        lsr
        lsr
        lsr
        sta gs_b0,x
        lda d6_y1
        lsr
        lsr
        lsr
        sec
        sbc gs_b0,x
        inc a
        sta gs_nb,x
        lda #0
        bra gs_copy
gui_restore:
        stx gs_s
        lda #1
gs_copy:
        sta gs_dir
        ldx gs_s
        lda gs_nc,x                     ; bytes a band: nc * 64
        sta gs_n
        lda #0
        sta gs_n+1
        ldy #6
-       asl gs_n
        rol gs_n+1
        dey
        bne -
        lda gs_c0,x                     ; the screen: F640_BUF0 + c0 * 64 + b0 * 5120
        sta gs_fb
        lda #0
        sta gs_fb+1
        ldy #6
-       asl gs_fb
        rol gs_fb+1
        dey
        bne -
        lda #`F640_BUF0
        sta gs_fb+2
        ldy gs_b0,x
_b0:    cpy #0                          ; + 5120 (= $1400) per band
        beq _b0done
        clc
        lda gs_fb+1
        adc #$14
        sta gs_fb+1
        bcc _b0next
        inc gs_fb+2
_b0next:
        dey
        bra _b0
_b0done:
        lda #0                          ; the slot
        sta gs_sv
        sta gs_sv+1
        txa
        lsr
        lda #0
        ror
        sta gs_sv+1                     ; (slot 1: + $8000)
        lda gs_nb,x
        sta gs_k
_band:
        ldx #0
        ldy #0
        lda gs_dir
        bne _back
-       lda gs_fb,x                     ; save: screen -> slot
        sta ptr1,x
        lda gs_sv_full,x
        sta ptr2,x
        inx
        cpx #4
        bne -
        bra _go
_back:
-       lda gs_sv_full,x                ; restore: slot -> screen
        sta ptr1,x
        lda gs_fb,x
        sta ptr2,x
        inx
        cpx #4
        bne -
_go:    lda gs_n
        sta tmp5
        lda gs_n+1
        sta tmp5+1
        jsr dma_copy_far
        clc                             ; the next band: screen + 5120, slot + n
        lda gs_fb+1
        adc #$14
        sta gs_fb+1
        bcc +
        inc gs_fb+2
+       clc
        lda gs_sv
        adc gs_n
        sta gs_sv
        lda gs_sv+1
        adc gs_n+1
        sta gs_sv+1
        dec gs_k
        bne _band
        rts
; A = (Y:A) >> 3 (x up to 2047)
gs_cell:
        lsr
        lsr
        lsr
        sta gs_t
        tya
        asl
        asl
        asl
        asl
        asl
        ora gs_t
        rts
gs_t:           .byte 0
gs_s:           .byte 0
gs_dir:         .byte 0
gs_k:           .byte 0
gs_n:           .word 0
gs_fb:          .byte 0, 0, 0, 0        ; (28-bit: byte 3 is 0)
gs_sv_full:
gs_sv:          .word 0                 ; the slot: GS_ATTIC + gs_sv
                .byte (GS_ATTIC >> 16) & $ff, GS_ATTIC >> 24
gs_c0:          .fill 2
gs_nc:          .fill 2
gs_b0:          .fill 2
gs_nb:          .fill 2

;---------------------------------------------------------------------------------------
; gui_edit: type on the status line (what was there comes back afterwards)
;---------------------------------------------------------------------------------------
GE_MAX          = 30
gui_edit:
        sta ge_prompt
        stx ge_prompt+1
        #GXY 0, STATUS_Y - 1, 639, 199
        ldx #1
        jsr gui_save
        ldx #0                          ; the text's length
-       lda ge_buf,x
        beq +
        inx
        cpx #GE_MAX
        bne -
        lda #0
        sta ge_buf,x
+       stx ge_len
_draw:
        lda ge_prompt
        ldx ge_prompt+1
        jsr gui_status
        lda #GC_YELLOW
        sta d6_col
        lda #<ge_buf
        ldx #>ge_buf
        jsr d6_text
        lda #'_'
        jsr d6_char
        lda #' '
        jsr d6_char
_wait:
        jsr wait_frame
        jsr gui_poll
        lda ev_type
        cmp #EV_KEY
        bne _wait
        lda ev_key
        cmp #K_RETURN
        bne +
        ldx #1
        jsr gui_restore
        clc
        rts
+       cmp #K_ESC
        beq _cancel
        cmp #K_STOP
        beq _cancel
        cmp #K_DEL
        bne +
        ldx ge_len
        beq _wait
        dex
        stx ge_len
        lda #0
        sta ge_buf,x
        bra _draw
+       cmp #' '
        bcc _wait
        cmp #127
        bcs _wait
        ldx ge_len
        cpx #GE_MAX
        bcs _wait
        sta ge_buf,x
        inx
        stx ge_len
        lda #0
        sta ge_buf,x
        bra _draw
_cancel:
        ldx #1
        jsr gui_restore
        sec
        rts
ge_prompt:      .word 0
ge_len:         .byte 0
ge_buf:         .fill GE_MAX + 1

;---------------------------------------------------------------------------------------
; numbers as text
;---------------------------------------------------------------------------------------
; gf_v with A decimals (bit 7: drop trailing zeros) -> gf_str
gui_fmt:
        sta gf_flags
        and #7
        sta gf_d
        ldx #0
        stx gf_n
        ; |v|, and the sign
        #ABSQ gf_v, gf_a
        bit gf_v+3
        bpl +
        #BEQZ gf_a, +                   ; (never "-0")
        lda #'-'
        sta gf_str
        inc gf_n
+       ; scaled = (|v| * 10^d + 32768) >> 16
        ldq gf_a
        stq MULTINA
        ldx gf_d
        lda gf_p10l,x
        sta MULTINB
        lda gf_p10h,x
        sta MULTINB+1
        lda #0
        sta MULTINB+2
        sta MULTINB+3
        clc
        lda MULTOUT
        adc #0
        lda MULTOUT+1
        adc #$80
        lda MULTOUT+2
        adc #0
        sta gf_s
        lda MULTOUT+3
        adc #0
        sta gf_s+1
        lda MULTOUT+4
        adc #0
        sta gf_s+2
        lda MULTOUT+5
        adc #0
        sta gf_s+3
        ; its digits, last first, into gf_dig (at least d + 1 of them)
        lda #0
        sta gf_k
_dig:
        ldq gf_s
        stq MULTINA
        lda #10
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
-       bit DIVBUSY
        bmi -
        ldq DIVOUT+4                    ; q = s / 10
        stq gf_q
        stq MULTINA
        lda #10
        sta MULTINB
        sec                             ; digit = s - 10 q
        lda gf_s
        sbc MULTOUT
        ldx gf_k
        ora #'0'
        sta gf_dig,x
        inc gf_k
        #MOVQ gf_q, gf_s
        lda gf_k
        cmp gf_d
        bcc _dig                        ; (all the decimals)
        beq _dig                        ; (and one whole digit)
        #BNEZ gf_s, _dig
        ; out: whole digits, the point, the decimals
        ldx gf_k
        ldy gf_n
-       cpx gf_d
        beq +
        dex
        lda gf_dig,x
        sta gf_str,y
        iny
        bra -
+       lda gf_d
        beq _end
        lda #'.'
        sta gf_str,y
        iny
        sty gf_pt
-       dex
        bmi +
        lda gf_dig,x
        sta gf_str,y
        iny
        bra -
+       bit gf_flags                    ; drop trailing zeros, and a bare point
        bpl _end
-       dey
        lda gf_str,y
        cmp #'0'
        beq -
        cmp #'.'
        beq _end
        iny
_end:
        lda #0
        sta gf_str,y
        rts
gf_p10l:        .byte <1, <10, <100, <1000, <10000
gf_p10h:        .byte >1, >10, >100, >1000, >10000

; ge_buf -> gf_v (up to 4 decimals count); carry set if it isn't a number
gui_num:
        ldx #0
        stx gf_neg
        lda #0
        sta gf_ip
        sta gf_ip+1
        sta gf_fr
        sta gf_fr+1
        sta gf_nd
        sta gf_any
-       lda ge_buf,x                    ; leading spaces, a sign
        cmp #' '
        bne +
        inx
        bra -
+       cmp #'-'
        bne +
        inc gf_neg
        inx
+       lda ge_buf,x
        jsr gf_digit
        bcs _frac
        sta gf_c
        lda gf_ip                       ; ip = ip * 10 + c
        sta MULTINA
        lda gf_ip+1
        sta MULTINA+1
        lda #0
        sta MULTINA+2
        sta MULTINA+3
        lda #10
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        clc
        lda MULTOUT
        adc gf_c
        sta gf_ip
        lda MULTOUT+1
        adc #0
        sta gf_ip+1
        bcs _bad
        bmi _bad
        lda MULTOUT+2
        bne _bad
        inc gf_any
        inx
        bra -
_frac:
        cmp #'.'
        bne _end
        inx
-       lda ge_buf,x
        jsr gf_digit
        bcs _end
        inc gf_any
        inx
        ldy gf_nd
        cpy #4
        bcs -
        inc gf_nd
        sta gf_c
        lda gf_fr
        sta MULTINA
        lda gf_fr+1
        sta MULTINA+1
        lda #0
        sta MULTINA+2
        sta MULTINA+3
        lda #10
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        clc
        lda MULTOUT
        adc gf_c
        sta gf_fr
        lda MULTOUT+1
        adc #0
        sta gf_fr+1
        bra -
_end:
        lda ge_buf,x                    ; only spaces may follow
        beq +
        cmp #' '
        bne _bad
        inx
        bra _end
+       lda gf_any
        beq _bad
        ldx gf_nd                       ; v = ip << 16 + (fr << 16 + p / 2) / p
        lda tok_ph,x
        sta MULTINA
        lda tok_ph1,x
        sta MULTINA+1
        lda gf_fr
        sta MULTINA+2
        lda gf_fr+1
        sta MULTINA+3
        lda gf_p10l,x
        sta MULTINB
        lda gf_p10h,x
        sta MULTINB+1
        lda #0
        sta MULTINB+2
        sta MULTINB+3
-       bit DIVBUSY
        bmi -
        lda DIVOUT+4
        sta gf_v
        lda DIVOUT+5
        sta gf_v+1
        lda gf_ip
        sta gf_v+2
        lda gf_ip+1
        sta gf_v+3
        lda gf_neg
        beq +
        #NEGQ gf_v, gf_v
+       clc
        rts
_bad:
        sec
        rts
tok_ph:         .byte <0, <5, <50, <500, <5000
tok_ph1:        .byte >0, >5, >50, >500, >5000
; carry clear and A = the digit, if A is one
gf_digit:
        cmp #'0'
        bcc _no
        cmp #'9' + 1
        bcs _no
        and #$0f
        clc
        rts
_no:    sec
        rts

gf_v:           .dword 0
gf_a:           .dword 0
gf_s:           .dword 0
gf_q:           .dword 0
gf_flags:       .byte 0
gf_d:           .byte 0
gf_n:           .byte 0
gf_k:           .byte 0
gf_pt:          .byte 0
gf_dig:         .fill 12
gf_str:         .fill 16
gf_neg:         .byte 0
gf_ip:          .word 0
gf_fr:          .word 0
gf_nd:          .byte 0
gf_c:           .byte 0
gf_any:         .byte 0

;---------------------------------------------------------------------------------------
; the palette: 0-15 the interface's
;---------------------------------------------------------------------------------------
GUIPAL_R = [0, 255, 22, 54, 140, 24, 40, 255, 255, 80, 230, 80, 120, 200, 12]
GUIPAL_G = [0, 255, 24, 58, 144, 46, 90, 220, 150, 220, 70, 210, 128, 200, 13]
GUIPAL_B = [0, 255, 30, 68, 156, 120, 200, 60, 40, 100, 70, 230, 140, 210, 16]
gui_pal_r:      .byte GUIPAL_R, range(256 - len(GUIPAL_R)) * 0
gui_pal_g:      .byte GUIPAL_G, range(256 - len(GUIPAL_G)) * 0
gui_pal_b:      .byte GUIPAL_B, range(256 - len(GUIPAL_B)) * 0

; the mouse pointer: an arrow, 24 x 21, one colour
        .align 64
gui_arrow:
        .byte %10000000, 0, 0
        .byte %11000000, 0, 0
        .byte %11100000, 0, 0
        .byte %11110000, 0, 0
        .byte %11111000, 0, 0
        .byte %11111100, 0, 0
        .byte %11111110, 0, 0
        .byte %11111000, 0, 0
        .byte %11011000, 0, 0
        .byte %10001100, 0, 0
        .byte %00001100, 0, 0
        .byte %00000110, 0, 0
        .fill 9 * 3
        .byte 0
