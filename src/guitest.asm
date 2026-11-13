; guitest.asm - DBG_GUITEST: draw640 on show (fills, frames, lines, clipping, text)
gui_test:
        lda #<gt_r
        sta f640_pal_r
        lda #>gt_r
        sta f640_pal_r+1
        lda #<gt_g
        sta f640_pal_g
        lda #>gt_g
        sta f640_pal_g+1
        lda #<gt_b
        sta f640_pal_b
        lda #>gt_b
        sta f640_pal_b+1
        jsr f640_palette
        jsr d6_clip_all
        ; a dark background, a menu bar, a panel
        #D6RECT 0, 0, 639, 199, 2
        #D6RECT 0, 0, 639, 9, 5
        #D6RECT 480, 10, 639, 190, 3
        lda #1
        sta d6_col
        lda #5
        sta d6_bg
        lda #1
        sta d6_tc
        lda #1
        sta d6_y
        lda #0
        sta d6_y+1
        lda #<gt_menu
        ldx #>gt_menu
        jsr d6_text
        ; frames
        lda #4
        sta d6_col
        #D6XY 4, 14, 236, 98
        jsr d6_frame
        #D6XY 240, 14, 476, 98
        jsr d6_frame
        ; lines in every direction, clipped to the first frame
        #D6XY 5, 15, 235, 97
        jsr d6_set_clip
        lda #7
        sta d6_col
        #D6XY 120, 56, -50, 0
        jsr d6_line
        #D6XY 120, 56, 300, 20
        jsr d6_line
        #D6XY 120, 56, 200, 150
        jsr d6_line
        #D6XY 120, 56, 10, 90
        jsr d6_line
        #D6XY 120, 56, 120, 16
        jsr d6_line
        #D6XY 120, 56, 230, 56
        jsr d6_line
        jsr d6_clip_all
        lda #1
        sta d6_col
        lda #$ff
        sta d6_bg
        lda #61
        sta d6_tc
        lda #20
        sta d6_y
        lda #<gt_list
        ldx #>gt_list
        jsr d6_text
        lda #61
        sta d6_tc
        lda #29
        sta d6_y
        lda #<gt_list2
        ldx #>gt_list2
        jsr d6_text
        rts

D6XY .macro x0, y0, x1, y1
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
D6RECT .macro x0, y0, x1, y1, c
        #D6XY \x0, \y0, \x1, \y1
        lda #\c
        sta d6_col
        jsr d6_fill
.endmacro

; the clip rectangle = (d6_x, d6_y) - (d6_x1, d6_y1)
d6_set_clip:
        ldx #3
-       lda d6_x,x
        sta d6_cx0,x
        dex
        bpl -
        lda d6_x1
        sta d6_cx1
        lda d6_x1+1
        sta d6_cx1+1
        lda d6_y
        sta d6_cy0
        lda d6_y+1
        sta d6_cy0+1
        lda d6_y1
        sta d6_cy1
        lda d6_y1+1
        sta d6_cy1+1
        rts

gt_menu:        .null "File  Edit  Add  Material  View  Render"
gt_list:        .null "Objects"
gt_list2:       .null " Ivory ball"
gt_r:           .byte 0, 255, 24, 60, 140, 20, 40, 255, range(248) * 0
gt_g:           .byte 0, 255, 26, 64, 140, 40, 80, 220, range(248) * 0
gt_b:           .byte 0, 255, 32, 72, 150, 110, 200, 60, range(248) * 0
