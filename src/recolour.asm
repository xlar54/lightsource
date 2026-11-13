;=======================================================================================
; recolour.asm - pass 2: a palette made for the picture, and the picture remapped to it.
;
; Mirrors private/tools/ref_palette.py (the tests compare palette and pixels with it):
;   1. histogram of the 24-bit image (RGB_IMAGE, attic) at 15 bits, 16-bit counts that
;      stop at $FFFF
;   2. median cut: list the colours present, split the box with the most pixels at the
;      median of its longest axis, until NPAL boxes; palette entry k + 1 = the mean of
;      box k's true 24-bit pixels
;   3. Floyd-Steinberg (errors truncated towards zero) into framebuffer 1, looking each
;      15-bit colour up once in an inverse map (nearest palette entry, filled lazily)
;   4. at the next frame: the new palette and framebuffer 1
;
;   recolour      the whole of it (~10 s)
;=======================================================================================

NPAL            = 254                   ; entries 1..254 (0 black, 255 = colour RAM)
HIST            = $8060000              ; 32768 x 16-bit counts
ENT             = $8070000              ; colours present: (c15 word, count word) each
BOXMAP          = $8090000              ; c15 -> box (bytes)
INVMAP          = $8098000              ; c15 -> palette index, 0 = not looked up yet
ERR_REC         = 6                     ; Floyd-Steinberg error record: r, g, b words
ERR_ROW         = (640 + 2) * ERR_REC

; pointer = 28-bit constant
SETP .macro p, a
        lda #<(\a)
        sta \p
        lda #>(\a)
        sta \p+1
        lda #`(\a)
        sta \p+2
        lda #((\a) >> 24)
        sta \p+3
.endmacro
; 32-bit pointer += small constant
ADDP .macro p, n
        clc
        lda \p
        adc #\n
        sta \p
        bcc +
        inc \p+1
        bne +
        inc \p+2
+
.endmacro
SUBP4 .macro p
        sec
        lda \p
        sbc #4
        sta \p
        bcs +
        lda \p+1
        bne _nb
        dec \p+2
_nb:    dec \p+1
+
.endmacro

recolour:
        jsr rc_clear
        jsr rc_hist
        jsr rc_entries
        jsr rc_cut
        jsr rc_boxmap
        jsr rc_means
        jsr rc_remap
        jmp rc_show

; histogram and inverse map: zero (DMA)
rc_clear:
        .for ci = 0, ci < 2, ci += 1
        lda #<(ci * $8000)
        sta tmp4
        lda #>(ci * $8000)
        sta tmp4+1
        lda #<$8000
        sta tmp5
        lda #>$8000
        sta tmp5+1
        lda #0
        ldx #HIST >> 20
        ldy #(HIST >> 16) & 15
        jsr dma_fill
        .next
        lda #<INVMAP
        sta tmp4
        lda #>INVMAP
        sta tmp4+1
        lda #<$8000
        sta tmp5
        lda #>$8000
        sta tmp5+1
        lda #0
        ldx #INVMAP >> 20
        ldy #(INVMAP >> 16) & 15
        jmp dma_fill

; next pixel of the 24-bit image -> rc_r/g/b, rgb_ptr += 3
rc_read:
        ldz #0
        lda [rgb_ptr],z
        sta rc_r
        inz
        lda [rgb_ptr],z
        sta rc_g
        inz
        lda [rgb_ptr],z
        sta rc_b
        ldz #0
        #ADDP rgb_ptr, 3
        rts

; rc_r/g/b -> rc_c (15 bit: r << 10 | g << 5 | b, of the top 5 bits)
rc_c15:
        lda rc_r
        lsr
        and #$7c
        sta rc_c+1
        lda rc_g
        rol                             ; g bits 7-6 -> 1-0
        rol
        rol
        and #3
        ora rc_c+1
        sta rc_c+1
        lda rc_g
        asl
        asl
        and #$e0
        sta rc_c
        lda rc_b
        lsr
        lsr
        lsr
        ora rc_c
        sta rc_c
        rts

; the image's pixels, one at a time: rc_pix_start, then rc_pix_next (Z set = done)
rc_pix_start:
        #SETP rgb_ptr, RGB_IMAGE
        lda #<(640 * 200)
        sta rc_n
        lda #>(640 * 200)
        sta rc_n+1
        lda #`(640 * 200)
        sta rc_n+2
        rts
rc_pix_next:                            ; one fewer to go; Z set when none are left
        lda rc_n
        bne _l
        lda rc_n+1
        bne _m
        dec rc_n+2
_m:     dec rc_n+1
_l:     dec rc_n
        lda rc_n
        ora rc_n+1
        ora rc_n+2
        rts

;---------------------------------------------------------------------------------------
rc_hist:
        jsr rc_pix_start
_pix:
        jsr rc_read
        jsr rc_c15
        lda rc_c                        ; HIST + 2 c
        asl
        sta ptr0
        lda rc_c+1
        rol
        sta ptr0+1
        lda #`HIST
        sta ptr0+2
        lda #HIST >> 24
        sta ptr0+3
        ldz #0
        lda [ptr0],z
        inz
        and [ptr0],z
        cmp #$ff
        beq _next                       ; saturated
        ldz #0
        lda [ptr0],z
        clc
        adc #1
        sta [ptr0],z
        inz
        lda [ptr0],z
        adc #0
        sta [ptr0],z
_next:
        ldz #0
        jsr rc_pix_next
        bne _pix
        rts

;---------------------------------------------------------------------------------------
; the colours present -> ENT (rc_nent of them); box 0 = all of them
rc_entries:
        #SETP ptr0, HIST
        #SETP ptr1, ENT
        lda #0
        sta rc_c
        sta rc_c+1
        sta rc_nent
        sta rc_nent+1
        sta box_n0
        sta box_n1
        sta box_n2
        sta box_s0
        sta box_s1
_col:
        ldz #0
        lda [ptr0],z
        inz
        ora [ptr0],z
        beq _next
        ldz #0                          ; (c, count)
        lda rc_c
        sta [ptr1],z
        inz
        lda rc_c+1
        sta [ptr1],z
        ldz #0
        lda [ptr0],z
        ldz #2
        sta [ptr1],z
        clc
        adc box_n0
        sta box_n0
        ldz #1
        lda [ptr0],z
        ldz #3
        sta [ptr1],z
        adc box_n1
        sta box_n1
        bcc +
        inc box_n2
+       #ADDP ptr1, 4
        inc rc_nent
        bne _next
        inc rc_nent+1
_next:
        ldz #0
        #ADDP ptr0, 2
        inc rc_c
        bne _col
        inc rc_c+1
        lda rc_c+1
        cmp #$80
        bne _col
        lda rc_nent
        sta box_e0
        lda rc_nent+1
        sta box_e1
        lda #1
        sta rc_nbox
        rts

; ptr <- ENT + 4 * (rc_i), for any 16-bit index (A = low, X = high byte)
ENTP .macro p
        sta \p
        stx \p+1
        lda #0
        sta \p+2
        asl \p
        rol \p+1
        rol \p+2
        asl \p
        rol \p+1
        rol \p+2
        clc
        lda \p+2
        adc #`ENT
        sta \p+2
        lda #ENT >> 24
        sta \p+3
.endmacro

; component rc_axis of the colour at [p] -> A (0..31)
COMP .macro p
        ldz #0
        lda [\p],z
        sta rc_c
        inz
        lda [\p],z
        sta rc_c+1
        ldz #0
        jsr rc_comp
.endmacro
rc_comp:
        lda rc_axis
        beq _r
        cmp #1
        beq _g
        lda rc_c                        ; b
        and #31
        rts
_r:     lda rc_c+1
        lsr
        lsr
        rts
_g:     lda rc_c+1
        and #3
        asl
        asl
        asl
        sta rc_t
        lda rc_c
        lsr
        lsr
        lsr
        lsr
        lsr
        ora rc_t
        rts

;---------------------------------------------------------------------------------------
; median cut
rc_cut:
_loop:
        lda rc_nbox
        cmp #NPAL
        bne +
        rts
+       ; the splittable box (2 or more colours) with the most pixels
        lda #$ff
        sta rc_bx
        ldx #0
_find:
        sec
        lda box_e0,x
        sbc box_s0,x
        sta rc_t
        lda box_e1,x
        sbc box_s1,x
        bne _big
        lda rc_t
        cmp #2
        bcc _fnext
_big:
        lda rc_bx
        cmp #$ff
        beq _take
        ldy rc_bx                       ; n_x > n_best?
        sec
        lda box_n0,y
        sbc box_n0,x
        lda box_n1,y
        sbc box_n1,x
        lda box_n2,y
        sbc box_n2,x
        bcs _fnext                      ; best >= this one
_take:
        stx rc_bx
_fnext:
        inx
        cpx rc_nbox
        bne _find
        lda rc_bx
        cmp #$ff
        bne +
        rts
+       ; ---- the box's bounds per axis ----
        ldx rc_bx
        lda box_n0,x
        sta rc_tot
        lda box_n1,x
        sta rc_tot+1
        lda box_n2,x
        sta rc_tot+2
        lda #31
        sta rc_lo
        sta rc_lo+1
        sta rc_lo+2
        lda #0
        sta rc_hi
        sta rc_hi+1
        sta rc_hi+2
        jsr rc_box_first                ; ptr1 = first entry, rc_cnt = its size
_bnd:
        ldz #0
        lda [ptr1],z
        sta rc_c
        inz
        lda [ptr1],z
        sta rc_c+1
        ldz #0
        lda #0
-       sta rc_axis
        jsr rc_comp
        ldx rc_axis
        cmp rc_lo,x
        bcs +
        sta rc_lo,x
+       cmp rc_hi,x
        bcc +
        sta rc_hi,x
+       inx
        txa
        cmp #3
        bne -
        #ADDP ptr1, 4
        jsr rc_cnt_dec
        bne _bnd
        ; ---- the longest axis (first of equals) ----
        ldx #2
-       sec
        lda rc_hi,x
        sbc rc_lo,x
        sta rc_rng,x
        dex
        bpl -
        lda #0
        sta rc_axis
        lda rc_rng+1
        cmp rc_rng
        beq +
        bcc +
        lda #1
        sta rc_axis
+       ldx rc_axis
        lda rc_rng+2
        cmp rc_rng,x
        beq +
        bcc +
        lda #2
        sta rc_axis
+       ; ---- pixel counts per value on that axis ----
        ldx #31
        lda #0
-       sta bins0,x
        sta bins1,x
        sta bins2,x
        dex
        bpl -
        jsr rc_box_first
_bin:
        #COMP ptr1
        tax
        ldz #2
        lda [ptr1],z
        clc
        adc bins0,x
        sta bins0,x
        inz
        lda [ptr1],z
        adc bins1,x
        sta bins1,x
        bcc +
        inc bins2,x
+       ldz #0
        #ADDP ptr1, 4
        jsr rc_cnt_dec
        bne _bin
        ; ---- the cut: the first v (lo..hi-1) where 2 * running total >= the box's ----
        ldx rc_axis
        lda rc_hi,x
        sta rc_vhi
        lda rc_lo,x
        sta rc_v
        lda #0
        sta rc_acc
        sta rc_acc+1
        sta rc_acc+2
_med:
        ldx rc_v
        clc
        lda rc_acc
        adc bins0,x
        sta rc_acc
        lda rc_acc+1
        adc bins1,x
        sta rc_acc+1
        lda rc_acc+2
        adc bins2,x
        sta rc_acc+2
        lda rc_acc                      ; 2 acc >= tot ?
        asl
        sta rc_t
        lda rc_acc+1
        rol
        sta rc_t+1
        lda rc_acc+2
        rol
        sta rc_t+2
        lda rc_t
        cmp rc_tot
        lda rc_t+1
        sbc rc_tot+1
        lda rc_t+2
        sbc rc_tot+2
        bcs _cut
        inc rc_v
        lda rc_v
        cmp rc_vhi
        bne _med
        dec rc_v                        ; no break: v = hi - 1
_cut:
        ; ---- partition: values <= v first. i = s, j = e (exclusive) ----
        ldx rc_bx
        lda box_s0,x
        sta rc_i
        lda box_s1,x
        sta rc_i+1
        lda box_e0,x
        sta rc_j
        lda box_e1,x
        sta rc_j+1
        lda rc_i
        ldx rc_i+1
        #ENTP ptr1                      ; [ptr1] = entry i
        lda rc_j
        ldx rc_j+1
        #ENTP ptr2
        #SUBP4 ptr2                     ; [ptr2] = entry j - 1
_part:
_adv_i:                                 ; while i < j and comp(i) <= v: i++
        jsr rc_i_lt_j
        bcs _dec_j
        #COMP ptr1
        cmp rc_v
        beq +
        bcs _dec_j
+       inc rc_i
        bne +
        inc rc_i+1
+       #ADDP ptr1, 4
        bra _adv_i
_dec_j:                                 ; while i < j and comp(j - 1) > v: j--
        jsr rc_i_lt_j
        bcs _chk
        #COMP ptr2
        cmp rc_v
        beq _chk
        bcc _chk
        lda rc_j
        bne +
        dec rc_j+1
+       dec rc_j
        #SUBP4 ptr2
        bra _dec_j
_chk:                                   ; i + 1 >= j: done
        clc
        lda rc_i
        adc #1
        sta rc_t
        lda rc_i+1
        adc #0
        sta rc_t+1
        lda rc_t
        cmp rc_j
        lda rc_t+1
        sbc rc_j+1
        bcs _split
        ldz #3                          ; swap entries i and j - 1
-       lda [ptr1],z
        sta rc_t
        lda [ptr2],z
        sta [ptr1],z
        lda rc_t
        sta [ptr2],z
        dez
        bpl -
        ldz #0
        jmp _part
_split:
        ; box bx = [s, i) with acc pixels; new box = [i, e) with tot - acc
        ldx rc_bx
        ldy rc_nbox
        lda box_e0,x
        sta box_e0,y
        lda box_e1,x
        sta box_e1,y
        lda rc_i
        sta box_e0,x
        sta box_s0,y
        lda rc_i+1
        sta box_e1,x
        sta box_s1,y
        sec
        lda rc_tot
        sbc rc_acc
        sta box_n0,y
        lda rc_tot+1
        sbc rc_acc+1
        sta box_n1,y
        lda rc_tot+2
        sbc rc_acc+2
        sta box_n2,y
        lda rc_acc
        sta box_n0,x
        lda rc_acc+1
        sta box_n1,x
        lda rc_acc+2
        sta box_n2,x
        inc rc_nbox
        jmp _loop

; carry clear if rc_i < rc_j (16-bit unsigned)
rc_i_lt_j:
        lda rc_i
        cmp rc_j
        lda rc_i+1
        sbc rc_j+1
        rts

; ptr1 = first entry of box rc_bx, rc_cnt = its entry count
rc_box_first:
        ldx rc_bx
        sec
        lda box_e0,x
        sbc box_s0,x
        sta rc_cnt
        lda box_e1,x
        sbc box_s1,x
        sta rc_cnt+1
        lda box_s0,x
        pha
        lda box_s1,x
        tax
        pla
        #ENTP ptr1
        ldz #0
        rts
; rc_cnt - 1, Z set at 0
rc_cnt_dec:
        lda rc_cnt
        bne +
        dec rc_cnt+1
+       dec rc_cnt
        lda rc_cnt
        ora rc_cnt+1
        rts

;---------------------------------------------------------------------------------------
; BOXMAP[c] = k for every colour of every box
rc_boxmap:
        lda #0
        sta rc_bx
_box:
        jsr rc_box_first
_ent:
        ldz #0
        lda [ptr1],z
        sta ptr0
        inz
        lda [ptr1],z
        sta ptr0+1
        lda #`BOXMAP
        sta ptr0+2
        lda #BOXMAP >> 24
        sta ptr0+3
        ldz #0
        lda rc_bx
        sta [ptr0],z
        #ADDP ptr1, 4
        jsr rc_cnt_dec
        bne _ent
        inc rc_bx
        lda rc_bx
        cmp rc_nbox
        bne _box
        rts

;---------------------------------------------------------------------------------------
; palette entry k + 1 = the mean of box k's pixels
rc_means:
        ldx #0
        lda #0
-       sta sum_r0,x
        sta sum_r1,x
        sta sum_r2,x
        sta sum_r3,x
        sta sum_g0,x
        sta sum_g1,x
        sta sum_g2,x
        sta sum_g3,x
        sta sum_b0,x
        sta sum_b1,x
        sta sum_b2,x
        sta sum_b3,x
        sta sum_n0,x
        sta sum_n1,x
        sta sum_n2,x
        sta sum_n3,x
        sta pal_r,x
        sta pal_g,x
        sta pal_b,x
        inx
        bne -
        jsr rc_pix_start
_pix:
        jsr rc_read
        jsr rc_c15
        lda rc_c
        sta ptr0
        lda rc_c+1
        sta ptr0+1
        lda #`BOXMAP
        sta ptr0+2
        lda #BOXMAP >> 24
        sta ptr0+3
        ldz #0
        lda [ptr0],z
        tax
        clc
        lda sum_r0,x
        adc rc_r
        sta sum_r0,x
        bcc +
        inc sum_r1,x
        bne +
        inc sum_r2,x
        bne +
        inc sum_r3,x
+       clc
        lda sum_g0,x
        adc rc_g
        sta sum_g0,x
        bcc +
        inc sum_g1,x
        bne +
        inc sum_g2,x
        bne +
        inc sum_g3,x
+       clc
        lda sum_b0,x
        adc rc_b
        sta sum_b0,x
        bcc +
        inc sum_b1,x
        bne +
        inc sum_b2,x
        bne +
        inc sum_b3,x
+       inc sum_n0,x
        bne +
        inc sum_n1,x
        bne +
        inc sum_n2,x
+       jsr rc_pix_next
        bne _pix
        ; divide
        ldx #0
_div:
        lda sum_n0,x
        ora sum_n1,x
        ora sum_n2,x
        beq _dnext
        lda sum_n0,x
        sta MULTINB
        lda sum_n1,x
        sta MULTINB+1
        lda sum_n2,x
        sta MULTINB+2
        lda #0
        sta MULTINB+3
        lda sum_r0,x
        sta MULTINA
        lda sum_r1,x
        sta MULTINA+1
        lda sum_r2,x
        sta MULTINA+2
        lda sum_r3,x
        sta MULTINA+3
        jsr rc_divwait
        sta pal_r+1,x
        lda sum_g0,x
        sta MULTINA
        lda sum_g1,x
        sta MULTINA+1
        lda sum_g2,x
        sta MULTINA+2
        lda sum_g3,x
        sta MULTINA+3
        jsr rc_divwait
        sta pal_g+1,x
        lda sum_b0,x
        sta MULTINA
        lda sum_b1,x
        sta MULTINA+1
        lda sum_b2,x
        sta MULTINA+2
        lda sum_b3,x
        sta MULTINA+3
        jsr rc_divwait
        sta pal_b+1,x
_dnext:
        inx
        cpx rc_nbox
        bne _div
        rts
rc_divwait:
-       bit DIVBUSY
        bmi -
        lda DIVOUT+4
        rts

;---------------------------------------------------------------------------------------
; Floyd-Steinberg into framebuffer 1
rc_remap:
        lda #<err_a                     ; cur = a, nxt = b, both zero
        sta rc_pc
        lda #>err_a
        sta rc_pc+1
        lda #<err_b
        sta rc_pn
        lda #>err_b
        sta rc_pn+1
        lda #<err_a
        ldx #>err_a
        jsr rc_err_clear
        lda #<err_b
        ldx #>err_b
        jsr rc_err_clear
        jsr rc_pix_start
        lda #1
        sta f640_buf
        lda #0
        sta px_y
_row:
        lda px_y
        sta f640_y
        jsr f640_row
        lda rc_pc
        sta rc_px
        lda rc_pc+1
        sta rc_px+1
        lda rc_pn
        sta rc_nx
        lda rc_pn+1
        sta rc_nx+1
        lda #<640
        sta rc_cnt
        lda #>640
        sta rc_cnt+1
_pix:
        jsr rc_read
        ; v = clamp(pixel + error at x + 1)
        ldx #0
        ldy #ERR_REC
-       lda rc_r,x
        clc
        adc (rc_px),y
        sta rc_t
        iny
        lda #0
        adc (rc_px),y
        iny
        sta rc_t+1
        lda rc_t+1
        bmi _neg                        ; < 0
        beq _ok                         ; 0..255
        lda #255
        bra _st
_neg:   lda #0
        bra _st
_ok:    lda rc_t
_st:    sta rc_r,x
        inx
        cpx #3
        bne -
        jsr rc_c15
        lda rc_c                        ; INVMAP[c], looked up the first time
        sta ptr0
        clc
        lda rc_c+1
        adc #>INVMAP
        sta ptr0+1
        lda #`INVMAP
        sta ptr0+2
        lda #INVMAP >> 24
        sta ptr0+3
        ldz #0
        lda [ptr0],z
        bne +
        jsr rc_nearest
        ldz #0
        sta [ptr0],z
+       sta rc_k
        #F640_PUT
        ; spread the error: 7/16 right, 3/16 down-left, 5/16 down, 1/16 down-right
        ldx #0
_ch:
        ldy rc_k
        lda #0
        sta rc_sg
        cpx #1                          ; err = v - palette
        beq _eg
        bcs _eb
        lda rc_r,x
        sec
        sbc pal_r,y
        bra _ee
_eg:    lda rc_r,x
        sec
        sbc pal_g,y
        bra _ee
_eb:    lda rc_r,x
        sec
        sbc pal_b,y
_ee:    bcs +
        eor #$ff                        ; negative: magnitude, sign
        adc #1
        dec rc_sg
+       sta rc_m
        txa
        asl
        sta rc_t                        ; 2 * channel
        lda rc_px
        sta rc_ep
        lda rc_px+1
        sta rc_ep+1
        ldy rc_m
        lda fs7,y
        pha
        lda rc_t
        clc
        adc #2 * ERR_REC
        tay
        pla
        jsr rc_eadd                     ; cur[x + 2]
        lda rc_nx
        sta rc_ep
        lda rc_nx+1
        sta rc_ep+1
        ldy rc_m
        lda fs3,y
        ldy rc_t
        jsr rc_eadd                     ; nxt[x]
        ldy rc_m
        lda fs5,y
        pha
        lda rc_t
        clc
        adc #ERR_REC
        tay
        pla
        jsr rc_eadd                     ; nxt[x + 1]
        ldy rc_m
        lda fs1,y
        pha
        lda rc_t
        clc
        adc #2 * ERR_REC
        tay
        pla
        jsr rc_eadd                     ; nxt[x + 2]
        inx
        cpx #3
        beq +
        jmp _ch
+       ; next x
        clc
        lda rc_px
        adc #ERR_REC
        sta rc_px
        bcc +
        inc rc_px+1
+       clc
        lda rc_nx
        adc #ERR_REC
        sta rc_nx
        bcc +
        inc rc_nx+1
+       lda rc_cnt
        bne +
        dec rc_cnt+1
+       dec rc_cnt
        lda rc_cnt
        ora rc_cnt+1
        beq +
        jmp _pix
+       ; next row: nxt becomes cur, the old cur is cleared for the row after
        lda rc_pc
        ldx rc_pn
        sta rc_pn
        stx rc_pc
        lda rc_pc+1
        ldx rc_pn+1
        sta rc_pn+1
        stx rc_pc+1
        lda rc_pn
        ldx rc_pn+1
        jsr rc_err_clear
        inc px_y
        lda px_y
        cmp #200
        beq +
        jmp _row
+       rts

; word at (rc_ep),y += A (rc_sg = 0) or -= A (rc_sg = $ff)
rc_eadd:
        sta rc_ev
        bit rc_sg
        bmi _sub
        clc
        lda (rc_ep),y
        adc rc_ev
        sta (rc_ep),y
        iny
        lda (rc_ep),y
        adc #0
        sta (rc_ep),y
        rts
_sub:
        sec
        lda (rc_ep),y
        sbc rc_ev
        sta (rc_ep),y
        iny
        lda (rc_ep),y
        sbc #0
        sta (rc_ep),y
        rts

; zero an error row at A/X (bank 0)
rc_err_clear:
        sta tmp4
        stx tmp4+1
        lda #<ERR_ROW
        sta tmp5
        lda #>ERR_ROW
        sta tmp5+1
        lda #0
        ldx #0
        ldy #0
        jmp dma_fill

; the palette entry (1..nbox) nearest to the centre of 15-bit colour rc_c -> A
rc_nearest:
        lda rc_c+1                      ; centres: v5 << 3 | 4
        lsr
        lsr
        asl
        asl
        asl
        ora #4
        sta rc_cr
        lda rc_c+1
        and #3
        asl
        asl
        asl
        sta rc_t
        lda rc_c
        lsr
        lsr
        lsr
        lsr
        lsr
        ora rc_t
        asl
        asl
        asl
        ora #4
        sta rc_cg
        lda rc_c
        and #31
        asl
        asl
        asl
        ora #4
        sta rc_cb
        lda #$ff
        sta rc_best
        sta rc_best+1
        sta rc_best+2
        ldy #1
_cand:
        lda rc_cr                       ; d = sq|dr| + sq|dg| + sq|db|
        sec
        sbc pal_r,y
        bcs +
        eor #$ff
        adc #1
+       tax
        lda sq_lo,x
        sta rc_d
        lda sq_hi,x
        sta rc_d+1
        lda #0
        sta rc_d+2
        lda rc_cg
        sec
        sbc pal_g,y
        bcs +
        eor #$ff
        adc #1
+       tax
        clc
        lda sq_lo,x
        adc rc_d
        sta rc_d
        lda sq_hi,x
        adc rc_d+1
        sta rc_d+1
        bcc +
        inc rc_d+2
+       lda rc_cb
        sec
        sbc pal_b,y
        bcs +
        eor #$ff
        adc #1
+       tax
        clc
        lda sq_lo,x
        adc rc_d
        sta rc_d
        lda sq_hi,x
        adc rc_d+1
        sta rc_d+1
        bcc +
        inc rc_d+2
+       lda rc_d                        ; d < best ?
        cmp rc_best
        lda rc_d+1
        sbc rc_best+1
        lda rc_d+2
        sbc rc_best+2
        bcs _cnext
        lda rc_d
        sta rc_best
        lda rc_d+1
        sta rc_best+1
        lda rc_d+2
        sta rc_best+2
        sty rc_bi
_cnext:
        cpy rc_nbox                     ; entries 1..nbox
        bcs +
        iny
        jmp _cand
+       lda rc_bi
        rts

;---------------------------------------------------------------------------------------
; at the next frame: framebuffer 1 and its palette
rc_show:
        lda #<pal_r
        sta f640_pal_r
        lda #>pal_r
        sta f640_pal_r+1
        lda #<pal_g
        sta f640_pal_g
        lda #>pal_g
        sta f640_pal_g+1
        lda #<pal_b
        sta f640_pal_b
        lda #>pal_b
        sta f640_pal_b+1
        jsr wait_frame
        lda #1
        jsr f640_show
        jmp f640_palette

; tables
fs7:
        .for ci = 0, ci < 256, ci += 1
        .byte (ci * 7) >> 4
        .next
fs5:
        .for ci = 0, ci < 256, ci += 1
        .byte (ci * 5) >> 4
        .next
fs3:
        .for ci = 0, ci < 256, ci += 1
        .byte (ci * 3) >> 4
        .next
fs1:
        .for ci = 0, ci < 256, ci += 1
        .byte ci >> 4
        .next
sq_lo:
        .for ci = 0, ci < 256, ci += 1
        .byte <(ci * ci)
        .next
sq_hi:
        .for ci = 0, ci < 256, ci += 1
        .byte >(ci * ci)
        .next

; variables
rc_r:           .byte 0                 ; rc_r, rc_g, rc_b in this order
rc_g:           .byte 0
rc_b:           .byte 0
rc_c:           .word 0
rc_n:           .byte 0, 0, 0
rc_nent:        .word 0
rc_nbox:        .byte 0
rc_bx:          .byte 0
rc_t:           .byte 0, 0, 0
rc_tot:         .byte 0, 0, 0
rc_acc:         .byte 0, 0, 0
rc_lo:          .byte 0, 0, 0
rc_hi:          .byte 0, 0, 0
rc_rng:         .byte 0, 0, 0
rc_axis:        .byte 0
rc_v:           .byte 0
rc_vhi:         .byte 0
rc_i:           .word 0
rc_j:           .word 0
rc_cnt:         .word 0
rc_k:           .byte 0
rc_sg:          .byte 0
rc_m:           .byte 0
rc_cr:          .byte 0
rc_cg:          .byte 0
rc_cb:          .byte 0
rc_d:           .byte 0, 0, 0
rc_best:        .byte 0, 0, 0
rc_bi:          .byte 0
rc_ev:          .byte 0

        .section bss
box_s0:         .fill 256
box_s1:         .fill 256
box_e0:         .fill 256
box_e1:         .fill 256
box_n0:         .fill 256
box_n1:         .fill 256
box_n2:         .fill 256
bins0:          .fill 32
bins1:          .fill 32
bins2:          .fill 32
sum_r0:         .fill 256
sum_r1:         .fill 256
sum_r2:         .fill 256
sum_g0:         .fill 256
sum_g1:         .fill 256
sum_g2:         .fill 256
sum_b0:         .fill 256
sum_b1:         .fill 256
sum_b2:         .fill 256
sum_n0:         .fill 256
sum_n1:         .fill 256
sum_n2:         .fill 256
sum_r3:         .fill 256
sum_g3:         .fill 256
sum_b3:         .fill 256
sum_n3:         .fill 256
pal_r:          .fill 256               ; the new palette (plain 8-bit values)
pal_g:          .fill 256
pal_b:          .fill 256
err_a:          .fill ERR_ROW
err_b:          .fill ERR_ROW
        .endsection
