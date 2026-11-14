;=======================================================================================
; parse.asm - overlay 2: the scene language (a POV-Ray subset, docs/DESIGN.md) read from
; disk and compiled into the scene tables (scene.asm).
;
; Mirrors private/tools/pov.py: for any file it accepts, the tables are the same bytes.
;
;   parse_scene    read SCENE.POV (kstream) into TEXT_BUF and compile it. Carry clear: the
;                  tables are ready. Carry set: parse_err = message number (parse_msgs),
;                  parse_line = the line
;   parse_text     compile the text already at TEXT_BUF (zero-terminated)
;
; A recursive-descent parser over a one-token lookahead (tk_*). Declared objects and
; textures are re-read from the text (their position is kept), as pov.py re-reads tokens.
; Errors unwind straight back to parse_text's caller (parse_sp).
;
; Working memory: the text in bank 1; primitive parameters, names and the value stack in
; bank 0 at PW_BASE (free while parsing; the debug log uses it in builds that don't parse).
;=======================================================================================

PW_BASE         = $0800
PW_LINES        = PW_BASE               ; MAX_PRIM x 2: each primitive's line
PW_BOUND        = PW_BASE + $80         ; MAX_PRIM x 5: its bounding radius, infinite (fin_roots)
PW_SYMS         = PW_BASE + $1c0        ; NSYM x SYM_SIZE: declared names
SYM_SIZE        = 48
NSYM            = 40
SYM_NAME        = 0                     ; 24 bytes, zero-terminated
SYM_KIND        = 24
SYM_VN          = 25                    ; value: 0 number, 3-5 vector
SYM_VAL         = 26                    ; 20 bytes; or text position (word) + line (word)
PW_VSTK         = PW_SYMS + NSYM * SYM_SIZE     ; value stack
VSIZE           = 21                    ; vn + 5 dwords
NVSTK           = 16
        .cerror PW_VSTK + NVSTK * VSIZE > $1600, "parser work area runs into kstream's"

NAME_MAX        = 23
MAX_DEPTH       = 16                    ; objects inside objects
MAX_STACK       = 7                     ; the tracer's interval-list stack
BOUND_MARGIN    = ONE / 16

; token types (punctuation is its own character)
TK_EOF          = 0
TK_NUM          = 1
TK_ID           = 2
TK_DIR          = 3
TK_STR          = 4
KW_NONE         = $ff

; declared-name kinds
SK_VAL          = 0
SK_OBJECT       = 1
SK_TEXTURE      = 2
SK_PIGMENT      = 3
SK_FINISH       = 4
SK_INTERIOR     = 5

; ---- error messages ----
ERRMSG .function n
        .endf n
E_CHAR          = 0
E_COMMENT       = 1
E_NUMBER        = 2
E_NAME          = 3
E_STRING        = 4
E_EXPECT        = 5
E_UNEXPECTED    = 6
E_UNKNOWN       = 7
E_DIV0          = 8
E_VECTOR        = 9
E_NUMWANT       = 10
E_VECPARTS      = 11
E_SQRT          = 12
E_DIRECTIVE     = 13
E_SYMS          = 14
E_BRACE         = 15
E_SETTING       = 16
E_LIGHTS        = 17
E_NOTOBJ        = 18
E_CSGEMPTY      = 19
E_OPEN          = 20
E_PRIMS         = 21
E_DEPTH         = 22
E_SCALE0        = 23
E_MODIFIER      = 24
E_ROUGH         = 25
E_IOR           = 26
E_MATS          = 27
E_UNIFORM       = 28
E_SHEAR         = 29
E_RADIUS        = 30
E_ENDS          = 31
E_CONER         = 32
E_NORMAL        = 33
E_NEST          = 34
E_ROOTS         = 35
E_PROG          = 36
E_CAMLOOK       = 37
E_CAMSKY        = 38
E_ANGLE         = 39
E_FILE          = 40
E_BIG           = 41
E_VSTACK        = 42
E_PRISMPTS      = 43
E_PRISMH        = 44
E_PRISMAREA     = 45
E_PTS           = 46

parse_msgs:
        .word _m0, _m1, _m2, _m3, _m4, _m5, _m6, _m7, _m8, _m9
        .word _m10, _m11, _m12, _m13, _m14, _m15, _m16, _m17, _m18, _m19
        .word _m20, _m21, _m22, _m23, _m24, _m25, _m26, _m27, _m28, _m29
        .word _m30, _m31, _m32, _m33, _m34, _m35, _m36, _m37, _m38, _m39
        .word _m40, _m41, _m42, _m43, _m44, _m45, _m46
_m0:    .null "unexpected character"
_m1:    .null "unterminated comment"
_m2:    .null "number too big"
_m3:    .null "name too long"
_m4:    .null "unterminated string"
_m5:    .null "expected something else here"
_m6:    .null "unexpected word"
_m7:    .null "unknown name"
_m8:    .null "division by zero"
_m9:    .null "a vector inside a vector"
_m10:   .null "expected a number"
_m11:   .null "a vector has 2 to 5 parts"
_m12:   .null "square root of a negative number"
_m13:   .null "directive not supported"
_m14:   .null "too many names"
_m15:   .null "missing }"
_m16:   .null "unknown setting"
_m17:   .null "too many lights (16 at most)"
_m18:   .null "not a declared object"
_m19:   .null "a boolean needs objects"
_m20:   .null "open shapes are not supported"
_m21:   .null "too many primitives (64 at most)"
_m22:   .null "objects nested too deeply"
_m23:   .null "scale by 0"
_m24:   .null "unknown object modifier"
_m25:   .null "roughness must be above 0"
_m26:   .null "ior must be above 0"
_m27:   .null "too many materials (16 at most)"
_m28:   .null "only a box can be scaled unevenly"
_m29:   .null "this transform would shear the object"
_m30:   .null "radius must be above 0"
_m31:   .null "the two ends are at the same point"
_m32:   .null "bad cone radii"
_m33:   .null "a plane needs a normal"
_m34:   .null "booleans nested too deeply"
_m35:   .null "too many objects (64 at most)"
_m36:   .null "the objects are too complicated"
_m37:   .null "the camera looks at its own location"
_m38:   .null "the camera looks along its sky"
_m39:   .null "the camera angle must be 0 to 180"
_m40:   .null "can't read the scene file"
_m41:   .null "the scene file is too big"
_m42:   .null "expression too complicated"
_m43:   .null "a prism has 3 to 16 corners"
_m44:   .null "a prism needs a height"
_m45:   .null "the prism outline has no area"
_m46:   .null "too many prism corners (255 in all)"

; ---- keywords: KW_x = its position in kw_text ----
KWLIST = ["camera", "location", "look_at", "sky", "angle", "right", "up", "perspective", "light_source", "shadowless", "background", "global_settings", "max_trace_level", "ambient_light", "assumed_gamma", "sphere", "box", "cylinder", "cone", "plane", "prism", "union", "merge", "intersection", "difference", "object", "open", "texture", "pigment", "finish", "interior", "color", "colour", "rgb", "rgbt", "rgbf", "rgbft", "filter", "transmit", "checker", "translate", "rotate", "scale", "no_shadow", "hollow", "ambient", "diffuse", "phong", "phong_size", "specular", "roughness", "reflection", "ior", "x", "y", "z", "pi", "clock", "sin", "cos", "sqrt", "abs", "radians", "degrees", "linear_sweep", "linear_spline"]
NKW             = len(KWLIST)
KW_CAMERA       = 0
KW_LOCATION     = 1
KW_LOOK_AT      = 2
KW_SKY          = 3
KW_ANGLE        = 4
KW_RIGHT        = 5
KW_UP           = 6
KW_PERSPECTIVE  = 7
KW_LIGHT        = 8
KW_SHADOWLESS   = 9
KW_BACKGROUND   = 10
KW_GLOBAL       = 11
KW_MAXTRACE     = 12
KW_AMBLIGHT     = 13
KW_GAMMA        = 14
KW_SPHERE       = 15
KW_BOX          = 16
KW_CYLINDER     = 17
KW_CONE         = 18
KW_PLANE        = 19
KW_PRISM        = 20
KW_UNION        = 21
KW_MERGE        = 22
KW_INTER        = 23
KW_DIFF         = 24
KW_OBJECT       = 25
KW_OPEN         = 26
KW_TEXTURE      = 27
KW_PIGMENT      = 28
KW_FINISH       = 29
KW_INTERIOR     = 30
KW_COLOR        = 31
KW_COLOUR       = 32
KW_RGB          = 33
KW_RGBT         = 34
KW_RGBF         = 35
KW_RGBFT        = 36
KW_FILTER       = 37
KW_TRANSMIT     = 38
KW_CHECKER      = 39
KW_TRANSLATE    = 40
KW_ROTATE       = 41
KW_SCALE        = 42
KW_NOSHADOW     = 43
KW_HOLLOW       = 44
KW_AMBIENT      = 45
KW_DIFFUSE      = 46
KW_PHONG        = 47
KW_PHONGSIZE    = 48
KW_SPECULAR     = 49
KW_ROUGHNESS    = 50
KW_REFLECTION   = 51
KW_IOR          = 52
KW_X            = 53
KW_Y            = 54
KW_Z            = 55
KW_PI           = 56
KW_CLOCK        = 57
KW_SIN          = 58
KW_COS          = 59
KW_SQRT         = 60
KW_ABS          = 61
KW_RADIANS      = 62
KW_DEGREES      = 63
KW_LINSWEEP     = 64
KW_LINSPLINE    = 65
        .cerror NKW != 66, "keyword numbers"
kw_text:
        .for kwi = 0, kwi < NKW, kwi += 1
        .null KWLIST[kwi]
        .next
        .byte 0                         ; end of the list

; ---- small macros ----
; a 16-bit increment of an absolute word (inw works on the base page only)
INCW .macro w
        inc \w
        bne +
        inc \w+1
+
.endmacro
; error A = message (unwinds)
PERR .macro n
        lda #\n
        jmp perr
.endmacro
; error unless the token is the character c; then the next token
EXPECT .macro c
        lda #\c
        jsr expect_char
.endmacro
; Z set if the token is keyword k
ISKW .macro k
        lda #\k
        jsr is_kw
.endmacro

;=======================================================================================
; reading the file
;=======================================================================================
parse_scene:
        tsx
        stx parse_sp
        ldy #0
        lda #<scene_name
        ldx #>scene_name
        jsr kst_name_raw
        tya
        jsr kst_open
        bcc +
        #PERR E_FILE
+       lda #<TEXT_BUF
        sta ptr0
        lda #>TEXT_BUF
        sta ptr0+1
        lda #`TEXT_BUF
        sta ptr0+2
        lda #0
        sta ptr0+3
_block:
        jsr kst_read
        lda kst_st
        and #$bf
        bne _bad
        ldx #0
-       cpx kst_count
        beq +
        lda KS_BUF,x
        ldz #0
        sta [ptr0],z
        inw ptr0
        inx
        bra -
+       lda ptr0+1                      ; full?
        cmp #>(TEXT_BUF + TEXT_MAX)
        bcc +
        jsr kst_close
        #PERR E_BIG
+       lda kst_st
        and #$40
        bne _end
        lda kst_count
        bne _block
_end:
        jsr kst_close
        lda #0
        ldz #0
        sta [ptr0],z
        jsr ovl_reload                  ; (the DOS may have used $C000-$C3FF)
        jmp parse_text
_bad:
        jsr kst_close
        #PERR E_FILE
scene_name:     .null "SCENE.POV,S,R"

; error: A = message; back to parse_scene's / parse_text's caller with carry set
perr:
        sta parse_err
        lda tk_tline
        sta parse_line
        lda tk_tline+1
        sta parse_line+1
        ldx parse_sp
        txs
        sec
        rts

;=======================================================================================
; the tokenizer: ptr0 = the next character (bank 1), tk_line = its line
;=======================================================================================
; A = the character at ptr0 + Y (Y = 0 or 1)
peekc:
        phz
        tya
        taz
        lda [ptr0],z
        plz
        ora #0                          ; (plz set the flags from Z: set them from A)
        rts

next_tok:
_skip:
        ldy #0
        jsr peekc
        bne +
        lda #TK_EOF
        sta tk_type
        jmp _mark
+       cmp #$0a
        bne +
        #INCW tk_line
        inw ptr0
        bra _skip
+       cmp #' '
        beq _adv
        cmp #$09
        beq _adv
        cmp #$0d
        beq _adv
        cmp #'/'
        bne _tok
        ldy #1
        jsr peekc
        cmp #'/'
        beq _line
        cmp #'*'
        bne _tok
        inw ptr0                        ; /* ... */
        inw ptr0
-       ldy #0
        jsr peekc
        bne +
        jsr _mark
        #PERR E_COMMENT
+       cmp #$0a
        bne +
        #INCW tk_line
+       cmp #'*'
        bne +
        ldy #1
        jsr peekc
        cmp #'/'
        bne +
        inw ptr0
        inw ptr0
        bra _skip
+       inw ptr0
        bra -
_line:
        ldy #0                          ; // to the end of the line
        jsr peekc
        beq _skip
        cmp #$0a
        beq _skip
        inw ptr0
        bra _line
_adv:
        inw ptr0
        bra _skip
_mark:
        lda ptr0
        sta tk_pos
        lda ptr0+1
        sta tk_pos+1
        lda tk_line
        sta tk_tline
        lda tk_line+1
        sta tk_tline+1
        rts
_tok:
        jsr _mark
        lda #KW_NONE
        sta tk_kw
        ldy #0
        jsr peekc
        jsr is_digit
        bcc _num
        cmp #'.'
        bne +
        ldy #1
        jsr peekc
        jsr is_digit
        bcc _num
        lda #'.'
        bra _bad
+       jsr is_alpha
        bcc _id
        cmp #'#'
        bne +
        jmp _dir
+       cmp #'"'
        bne +
        jmp _str
+       ldx #0
-       cmp punct,x
        beq +
        inx
        cpx #len(PUNCTS)
        bne -
_bad:
        #PERR E_CHAR
+       sta tk_type
        inw ptr0
        rts
_num:
        jmp tok_number
_id:
        ldx #0
-       ldy #0
        jsr peekc
        jsr is_alnum
        bcs +
        cpx #NAME_MAX
        bcc ++
        #PERR E_NAME
+       lda #0
        sta tk_name,x
        stx tk_nlen
        lda #TK_ID
        sta tk_type
        jmp kw_find
+       sta tk_name,x
        inx
        inw ptr0
        bra -
_dir:
        inw ptr0
        ldx #0
-       ldy #0
        jsr peekc
        jsr is_alpha
        bcs +
        cpx #NAME_MAX
        bcs +
        sta tk_name,x
        inx
        inw ptr0
        bra -
+       lda #0
        sta tk_name,x
        lda #TK_DIR
        sta tk_type
        rts
_str:
        inw ptr0
        ldx #0
-       ldy #0
        jsr peekc
        bne +
        #PERR E_STRING
+       inw ptr0
        cmp #'"'
        beq +
        cpx #NAME_MAX
        bcs -
        sta tk_name,x
        inx
        bra -
+       lda #0
        sta tk_name,x
        lda #TK_STR
        sta tk_type
        rts
PUNCTS = "{}<>,()+-*/;="
punct:          .text PUNCTS

; carry clear if A is a digit / letter or _ / either
is_digit:
        cmp #'0'
        bcc _no
        cmp #'9' + 1
        bcs _no
        clc
        rts
_no:    sec
        rts
is_alpha:
        cmp #'_'
        beq _yes
        pha
        and #$df
        cmp #'A'
        bcc +
        cmp #'Z' + 1
        bcs +
        pla
_yes:   clc
        rts
+       pla
        sec
        rts
is_alnum:
        jsr is_digit
        bcc +
        jmp is_alpha
+       rts

; the keyword the name in tk_name is, if any -> tk_kw
kw_find:
        lda #<kw_text
        sta lp
        lda #>kw_text
        sta lp+1
        lda #0
        sta tk_kw
_kw:
        ldy #0
        lda (lp),y
        bne +
        lda #KW_NONE                    ; the end of the list
        sta tk_kw
        rts
+
-       lda (lp),y
        cmp tk_name,y
        bne _no
        cmp #0
        beq _yes
        iny
        bra -
_yes:
        rts
_no:
-       lda (lp),y                      ; to the next keyword
        beq +
        iny
        bra -
+       iny
        tya
        clc
        adc lp
        sta lp
        bcc +
        inc lp+1
+       inc tk_kw
        bra _kw

; a number: up to 4 decimals count, the rest are skipped
tok_number:
        lda #0
        sta nm_ip
        sta nm_ip+1
        sta nm_fr
        sta nm_fr+1
        sta nm_nd
_int:
        ldy #0
        jsr peekc
        jsr is_digit
        bcs _frac
        and #$0f
        sta nm_d
        ; ip = ip * 10 + d, error above 32767
        lda nm_ip
        sta MULTINA
        lda nm_ip+1
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
        adc nm_d
        sta nm_ip
        lda MULTOUT+1
        adc #0
        sta nm_ip+1
        bcs _big
        lda MULTOUT+2
        ora MULTOUT+3
        bne _big
        lda nm_ip+1
        bmi _big
        inw ptr0
        bra _int
_big:
        #PERR E_NUMBER
_frac:
        cmp #'.'
        bne _done
        inw ptr0
_fd:
        ldy #0
        jsr peekc
        jsr is_digit
        bcs _done
        and #$0f
        sta nm_d
        inw ptr0
        lda nm_nd
        cmp #4
        bcs _fd
        inc nm_nd
        lda nm_fr                       ; fr = fr * 10 + d
        sta MULTINA
        lda nm_fr+1
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
        adc nm_d
        sta nm_fr
        lda MULTOUT+1
        adc #0
        sta nm_fr+1
        bra _fd
_done:
        ; v = ip << 16 + (fr << 16 + p / 2) / p, p = 10^nd
        ldx nm_nd
        lda #0
        sta MULTINA
        lda pow10_h,x                   ; p / 2
        sta MULTINA
        lda pow10_h1,x
        sta MULTINA+1
        lda nm_fr
        sta MULTINA+2
        lda nm_fr+1
        sta MULTINA+3
        lda pow10,x
        sta MULTINB
        lda pow10_1,x
        sta MULTINB+1
        lda #0
        sta MULTINB+2
        sta MULTINB+3
-       bit DIVBUSY
        bmi -
        lda DIVOUT+4
        sta tk_num
        lda DIVOUT+5
        sta tk_num+1
        lda nm_ip
        sta tk_num+2
        lda nm_ip+1
        sta tk_num+3
        lda #TK_NUM
        sta tk_type
        rts
pow10:          .byte <1, <10, <100, <1000, <10000
pow10_1:        .byte >1, >10, >100, >1000, >10000
pow10_h:        .byte <0, <5, <50, <500, <5000
pow10_h1:       .byte >0, >5, >50, >500, >5000

;---------------------------------------------------------------------------------------
; token helpers
;---------------------------------------------------------------------------------------
advance = next_tok

; Z set if the token is keyword A
is_kw:
        cmp tk_kw
        bne +
        ldx tk_type
        cpx #TK_ID
+       rts

; the token must be character A
expect_char:
        cmp tk_type
        beq +
        #PERR E_EXPECT
+       jmp next_tok

; carry set (and the next token) if the token is character A
accept_char:
        cmp tk_type
        beq +
        clc
        rts
+       jsr next_tok
        sec
        rts

; carry set (and the next token) if the token is keyword A
accept_kw:
        jsr is_kw
        beq +
        clc
        rts
+       jsr next_tok
        sec
        rts

; the token must be keyword A
expect_kw:
        jsr is_kw
        beq +
        #PERR E_EXPECT
+       jmp next_tok

; push / pop the position of the current token (for re-reading declared things). The
; return address stays on top.
pos_push:
        pla
        sta pp_ret
        pla
        sta pp_ret+1
        lda tk_pos
        pha
        lda tk_pos+1
        pha
        lda tk_tline
        pha
        lda tk_tline+1
        pha
        lda pp_ret+1
        pha
        lda pp_ret
        pha
        rts
pos_pop:
        pla
        sta pp_ret
        pla
        sta pp_ret+1
        pla
        sta tk_line+1
        pla
        sta tk_line
        pla
        sta ptr0+1
        pla
        sta ptr0
        lda pp_ret+1
        pha
        lda pp_ret
        pha
        jmp next_tok
; jump to the declared thing at sym_pos (and read its first token)
pos_jump:
        lda sym_pos
        sta ptr0
        lda sym_pos+1
        sta ptr0+1
        lda sym_line
        sta tk_line
        lda sym_line+1
        sta tk_line+1
        jmp next_tok

;=======================================================================================
; values: V (and W) = vn (0 number, 3-5 vector) + 5 dwords
;=======================================================================================
vpush:
        ldx vsp
        cpx #NVSTK
        bcc +
        #PERR E_VSTACK
+       lda vs_lo,x
        sta lp
        lda vs_hi,x
        sta lp+1
        inc vsp
        ldy #0
-       lda v_n,y
        sta (lp),y
        iny
        cpy #VSIZE
        bne -
        rts
vpop_w:
        dec vsp
        ldx vsp
        lda vs_lo,x
        sta lp
        lda vs_hi,x
        sta lp+1
        ldy #0
-       lda (lp),y
        sta w_n,y
        iny
        cpy #VSIZE
        bne -
        rts
vs_lo:          .byte <(PW_VSTK + range(NVSTK) * VSIZE)
vs_hi:          .byte >(PW_VSTK + range(NVSTK) * VSIZE)

; promote V and W to vectors of the same length (or leave two numbers) -> X = parts
promote_vw:
        lda v_n
        ora w_n
        bne +
        ldx #1
        rts
+       lda v_n                         ; n = max(len V or 3, len W or 3)
        bne +
        lda #3
+       sta vw_n
        lda w_n
        bne +
        lda #3
+       cmp vw_n
        bcc +
        sta vw_n
+       ldx #v_n - v_n
        jsr _one
        ldx #w_n - v_n
        jsr _one
        ldx vw_n
        rts
_one:   ; the value at v_n + X to vw_n parts
        lda v_n,x
        bne _vec
        ldy #4                          ; a number: copy it to every part
-       lda v_c,x
        sta v_c+4,x
        inx
        dey
        bne -
        txa                             ; (X moved on by 4: the same again for 3 more)
        sec
        sbc #4
        tax
        ldy #4
-       lda v_c,x
        sta v_c+8,x
        sta v_c+12,x
        sta v_c+16,x
        inx
        dey
        bne -
        txa
        sec
        sbc #4
        tax
        lda vw_n
        sta v_n,x
        rts
_vec:   ; pad with zeros
        sta vw_k
        txa
        sta vw_x
-       lda vw_k
        cmp vw_n
        bcs +
        asl
        asl
        clc
        adc vw_x
        tax
        lda #0
        sta v_c,x
        sta v_c+1,x
        sta v_c+2,x
        sta v_c+3,x
        inc vw_k
        bra -
+       ldx vw_x
        lda vw_n
        cmp v_n,x
        bcc +
        sta v_n,x
+       rts

; V = W op V, op = A (0 add, 1 subtract, 2 multiply, 3 divide)
binop:
        sta bo_op
        jsr promote_vw
        stx bo_n
        lda #0
        sta bo_i
_part:
        lda bo_i
        asl
        asl
        tax
        ldy #0
-       lda w_c,x
        sta bo_a,y
        lda v_c,x
        sta bo_b,y
        inx
        iny
        cpy #4
        bne -
        lda bo_op
        asl
        tax
        jmp (_ops,x)
_ops:   .word _add, _sub, _mul, _div
_add:   #ADDQ bo_a, bo_b, bo_r
        bra _put
_sub:   #SUBQ bo_a, bo_b, bo_r
        bra _put
_mul:   #FMUL bo_a, bo_b, bo_r
        bra _put
_div:   lda bo_b
        ora bo_b+1
        ora bo_b+2
        ora bo_b+3
        bne +
        #PERR E_DIV0
+       #FDIV bo_a, bo_b, bo_r
_put:
        lda bo_i
        asl
        asl
        tax
        ldy #0
-       lda bo_r,y
        sta v_c,x
        inx
        iny
        cpy #4
        bne -
        inc bo_i
        lda bo_i
        cmp bo_n
        bne _part
        rts

; V must be a number
v_number:
        lda v_n
        beq +
        #PERR E_NUMWANT
+       rts

;---------------------------------------------------------------------------------------
; expressions
;---------------------------------------------------------------------------------------
expr:
        jsr term
_l:
        lda tk_type
        cmp #'+'
        beq +
        cmp #'-'
        beq ++
        rts
+       lda #0
        bra _op
+       lda #1
_op:
        pha
        jsr vpush
        jsr next_tok
        jsr term
        jsr vpop_w
        pla
        jsr binop
        bra _l

term:
        jsr unary
_l:
        lda tk_type
        cmp #'*'
        beq +
        cmp #'/'
        beq ++
        rts
+       lda #2
        bra _op
+       lda #3
_op:
        pha
        jsr vpush
        jsr next_tok
        jsr unary
        jsr vpop_w
        pla
        jsr binop
        bra _l

unary:
        lda tk_type
        cmp #'-'
        bne +
        jsr next_tok
        jsr unary
        jmp v_negate
+       cmp #'+'
        bne +
        jsr next_tok
        jmp unary
+       jmp primary

; V = -V (each part)
v_negate:
        ldx #0
-       sec
        lda #0
        sbc v_c,x
        sta v_c,x
        lda #0
        sbc v_c+1,x
        sta v_c+1,x
        lda #0
        sbc v_c+2,x
        sta v_c+2,x
        lda #0
        sbc v_c+3,x
        sta v_c+3,x
        inx
        inx
        inx
        inx
        cpx #20
        bne -
        rts

primary:
        lda tk_type
        cmp #TK_NUM
        bne +
        lda #0
        sta v_n
        #MOVQ tk_num, v_c
        jmp next_tok
+       cmp #'('
        bne +
        jsr next_tok
        jsr expr
        #EXPECT ')'
        rts
+       cmp #'<'
        bne +
        jmp vec_literal
+       cmp #TK_ID
        beq +
        #PERR E_NUMWANT
+       lda tk_kw
        cmp #KW_NONE
        beq _name
        cmp #KW_X
        bcc _unk
        cmp #KW_Z + 1
        bcc _axis
        cmp #KW_PI
        bne +
        #LDIMM FX(3.141592653589793), v_c
        bra _num
+       cmp #KW_CLOCK
        bne +
        #MOVQ clock, v_c
_num:   lda #0
        sta v_n
        jmp next_tok
+       jmp func                        ; sin ... degrees
_axis:  ; x, y, z: unit vectors
        sec
        sbc #KW_X
        pha
        jsr v_zero3
        pla
        asl
        asl
        tax
        lda #1
        sta v_c+2,x
        jmp next_tok
_name:  ; a declared value
        jsr sym_find
        bcc _unk
        ldy #SYM_KIND
        lda (sp_),y
        cmp #SK_VAL
        bne _unk
        ldy #SYM_VN
        ldx #0
-       lda (sp_),y
        sta v_n,x
        iny
        inx
        cpx #VSIZE
        bne -
        jmp next_tok
_unk:
        #PERR E_UNKNOWN

; V = (0, 0, 0) as a 3-vector
v_zero3:
        lda #3
        sta v_n
        ldx #19
        lda #0
-       sta v_c,x
        dex
        bpl -
        rts

; sin cos sqrt abs radians degrees ( number )
func:
        lda tk_kw
        pha
        jsr next_tok
        #EXPECT '('
        jsr expr
        #EXPECT ')'
        jsr v_number
        pla
        cmp #KW_SIN
        bne +
        #FMUL v_c, q_rad2deg, v_c
        jmp fsin_v
+       cmp #KW_COS
        bne +
        #FMUL v_c, q_rad2deg, v_c
        jmp fcos_v
+       cmp #KW_SQRT
        bne _nsqrt
        bit v_c+3
        bpl +
        #PERR E_SQRT
+       ldq v_c
        jsr fsqrt
        stq v_c
        rts
_nsqrt:
        cmp #KW_ABS
        bne _nabs
        bit v_c+3
        bpl +
        #NEGQ v_c, v_c
+       rts
_nabs:
        cmp #KW_RADIANS
        bne +
        #FDIV v_c, q_rad2deg, v_c
        rts
+       #FMUL v_c, q_rad2deg, v_c       ; degrees
        rts
q_rad2deg:      .dint FX(180.0 / 3.141592653589793)

; < e, e, ... >: 2 to 5 numbers (2 gets a 0)
vec_literal:
        jsr next_tok
        lda #0
        sta vl_k
_part:
        jsr expr
        lda v_n
        beq +
        #PERR E_VECTOR
+       lda vl_k                        ; keep it on the value stack
        pha
        jsr vpush
        pla
        sta vl_k
        inc vl_k
        lda #','
        jsr accept_char
        bcs _part
        #EXPECT '>'
        lda vl_k
        cmp #2
        bcc _bad
        cmp #6
        bcc +
_bad:   #PERR E_VECPARTS
+       sta vl_n
        ; pop them: the last is part vl_n - 1
        jsr v_zero3
_pop:
        dec vl_k
        jsr vpop_w
        lda vl_k
        asl
        asl
        tax
        ldy #0
-       lda w_c,y
        sta v_c,x
        inx
        iny
        cpy #4
        bne -
        lda vl_k
        bne _pop
        lda vl_n
        cmp #3
        bcs +
        lda #3
+       sta v_n
        rts

; number and vector arguments
number:
        jsr expr
        jmp v_number
; V -> a 3-vector (a number fills it; more parts are dropped)
vector:
        jsr expr
        lda #3
        jmp v_promote

; V promoted to at least A parts (a number fills them, a vector gets zeros)
v_promote:
        sta vw_n
        lda v_n
        bne _vec
        #MOVQ v_c, v_c+4
        #MOVQ v_c, v_c+8
        #MOVQ v_c, v_c+12
        #MOVQ v_c, v_c+16
        lda vw_n
        sta v_n
        rts
_vec:
        cmp vw_n
        bcs +
        tax                             ; zeros for parts v_n .. vw_n - 1
-       txa
        asl
        asl
        tay
        lda #0
        sta v_c,y
        sta v_c+1,y
        sta v_c+2,y
        sta v_c+3,y
        inx
        cpx vw_n
        bne -
        lda vw_n
        sta v_n
+       rts

;---------------------------------------------------------------------------------------
; colours: col = r, g, b, filter, transmit
;---------------------------------------------------------------------------------------
colour:
        #ISKW KW_COLOR
        beq +
        #ISKW KW_COLOUR
        bne ++
+       jsr next_tok
+       lda #KW_RGB
        jsr accept_kw
        bcc +
        jsr expr                        ; rgb: 3 parts, filter = transmit = 0
        lda #3
        jsr v_promote
        jsr _rgb
        bra _mods
+       lda #KW_RGBT
        jsr accept_kw
        bcc +
        jsr expr
        lda #4
        jsr v_promote
        jsr _rgb
        #MOVQ v_c+12, col+16            ; the 4th part is transmit
        bra _mods
+       lda #KW_RGBF
        jsr accept_kw
        bcc +
        jsr expr
        lda #4
        jsr v_promote
        jsr _rgb
        #MOVQ v_c+12, col+12            ; the 4th part is filter
        bra _mods
+       lda #KW_RGBFT
        jsr accept_kw
        jsr expr                        ; rgbft or a bare value: 5 parts
        lda #5
        jsr v_promote
        ldx #19
-       lda v_c,x
        sta col,x
        dex
        bpl -
_mods:
        lda #KW_FILTER
        jsr accept_kw
        bcc +
        jsr number
        #MOVQ v_c, col+12
        bra _mods
+       lda #KW_TRANSMIT
        jsr accept_kw
        bcc +
        jsr number
        #MOVQ v_c, col+16
        bra _mods
+       rts
_rgb:   ; col = V's r, g, b; filter = transmit = 0
        ldx #11
-       lda v_c,x
        sta col,x
        dex
        bpl -
        ldx #7
        lda #0
-       sta col+12,x
        dex
        bpl -
        rts

; Z set if the token starts a colour (color colour rgb rgbt rgbf rgbft)
is_colour_kw:
        lda tk_type
        cmp #TK_ID
        bne +
        lda tk_kw
        cmp #KW_COLOR
        bcc ++
        cmp #KW_RGBFT + 1
        bcs ++
        lda #0                          ; Z set
+       rts
+       lda #1                          ; Z clear
        rts

;=======================================================================================
; declared names: sp_ = the entry
;=======================================================================================
; carry set if tk_name is declared (sp_ = it)
sym_find:
        ldx #0
_e:
        cpx sym_count
        bne +
        clc
        rts
+       lda sym_lo,x
        sta sp_
        lda sym_hi,x
        sta sp_+1
        ldy #0
-       lda (sp_),y
        cmp tk_name,y
        bne _next
        cmp #0
        beq _yes
        iny
        bra -
_next:  inx
        bra _e
_yes:   sec
        rts
sym_lo:         .byte <(PW_SYMS + range(NSYM) * SYM_SIZE)
sym_hi:         .byte >(PW_SYMS + range(NSYM) * SYM_SIZE)

; the name in tk_name: its entry (an old one, or a new one) -> sp_
sym_new:
        jsr sym_find
        bcs +
        ldx sym_count
        cpx #NSYM
        bcc ++
        #PERR E_SYMS
+       rts
+       inc sym_count
        lda sym_lo,x
        sta sp_
        lda sym_hi,x
        sta sp_+1
        ldy #0
-       lda tk_name,y
        sta (sp_),y
        beq +
        iny
        bra -
+       rts

; sym_pos / sym_line = the declared position at sp_
sym_get_pos:
        ldy #SYM_VAL
        lda (sp_),y
        sta sym_pos
        iny
        lda (sp_),y
        sta sym_pos+1
        iny
        lda (sp_),y
        sta sym_line
        iny
        lda (sp_),y
        sta sym_line+1
        rts

; if the token is a name declared as kind A: carry set, its position in sym_pos, and the
; next token
declared_block:
        sta db_kind
        lda tk_type
        cmp #TK_ID
        bne _no
        lda tk_kw
        cmp #KW_NONE
        bne _no
        jsr sym_find
        bcc _no
        ldy #SYM_KIND
        lda (sp_),y
        cmp db_kind
        bne _no
        jsr sym_get_pos
        jsr next_tok
        sec
        rts
_no:    clc
        rts

;=======================================================================================
; statements
;=======================================================================================
parse_text:
        tsx
        stx parse_sp
        ; everything starts empty
        lda #<scene
        sta tmp4
        lda #>scene
        sta tmp4+1
        lda #<SCENE_SIZE
        sta tmp5
        lda #>SCENE_SIZE
        sta tmp5+1
        lda #0
        tax
        tay
        jsr dma_fill
        lda #<pv_start                  ; and the parser's variables
        sta tmp4
        lda #>pv_start
        sta tmp4+1
        lda #<(pv_end - pv_start)
        sta tmp5
        lda #>(pv_end - pv_start)
        sta tmp5+1
        lda #0
        tax
        tay
        jsr dma_fill
        lda #$ff                        ; no primitive record in pr_rec yet
        sta pr_cur
        lda #<PRIM_ATTIC                ; the records (in attic) all zero
        sta tmp4
        lda #>PRIM_ATTIC
        sta tmp4+1
        lda #<(MAX_PRIM * PRIM_STRIDE)
        sta tmp5
        lda #>(MAX_PRIM * PRIM_STRIDE)
        sta tmp5+1
        lda #0
        ldx #FAR_MB
        ldy #FAR_BANK
        jsr dma_fill
        lda #0
        sta dmaj_dst_mb
        #LDIMM ONE, amb_light
        #LDIMM ONE, amb_light+4
        #LDIMM ONE, amb_light+8
        lda #5
        sta max_trace
        #MOVQ q_zero, clock
        lda #<TEXT_BUF
        sta ptr0
        lda #>TEXT_BUF
        sta ptr0+1
        lda #`TEXT_BUF
        sta ptr0+2
        lda #0
        sta ptr0+3
        lda #1
        sta tk_line
        lda #0
        sta tk_line+1
        jsr next_tok
_st:
        lda tk_type
        cmp #TK_EOF
        beq _end
        jsr statement
        bra _st
_end:
        jsr finalise
        jsr prim_flush                  ; (the last record back to attic)
        clc
        rts

statement:
        lda tk_type
        cmp #TK_DIR
        bne +
        jmp directive
+       cmp #';'
        bne +
        jmp next_tok
+       cmp #TK_ID
        bne _bad
        lda tk_kw
        cmp #KW_CAMERA
        bne +
        jmp camera_block
+       cmp #KW_LIGHT
        bne +
        jmp light_block
+       cmp #KW_BACKGROUND
        bne +
        jsr next_tok
        #EXPECT '{'
        jsr colour
        ldx #11
-       lda col,x
        sta sc_bg,x
        dex
        bpl -
        #EXPECT '}'
        rts
+       cmp #KW_GLOBAL
        bne +
        jmp global_block
+       jsr is_object_kw
        bne _bad
        lda #1                          ; a top-level object (unions flatten into roots)
        jmp object
_bad:
        #PERR E_UNEXPECTED

; Z set if the token is an object keyword (sphere ... object)
is_object_kw:
        lda tk_type
        cmp #TK_ID
        bne +
        lda tk_kw
        cmp #KW_SPHERE
        bcc ++
        cmp #KW_OBJECT + 1
        bcs ++
        lda #0
+       rts
+       lda #1
        rts

directive:
        ldx #0                          ; which: declare / local / version
-       lda tk_name,x
        cmp dir_declare,x
        bne +
        inx
        cmp #0
        bne -
        bra _decl
+       ldx #0
-       lda tk_name,x
        cmp dir_local,x
        bne +
        inx
        cmp #0
        bne -
        bra _decl
+       ldx #0
-       lda tk_name,x
        cmp dir_version,x
        bne _bad
        inx
        cmp #0
        bne -
        jsr next_tok
        jsr number
        lda #';'
        jsr accept_char
        rts
_bad:
        #PERR E_DIRECTIVE
_decl:
        jsr next_tok
        lda tk_type
        cmp #TK_ID
        bne +
        lda tk_kw
        cmp #KW_NONE
        beq ++
+       #PERR E_EXPECT
+       jsr sym_new
        jsr next_tok
        #EXPECT '='
        jsr is_object_kw
        bne +
        lda #SK_OBJECT
        bra _block
+       lda tk_type
        cmp #TK_ID
        bne _val
        lda tk_kw
        cmp #KW_TEXTURE
        bcc _val
        cmp #KW_INTERIOR + 1
        bcc _tex
        jsr is_colour_kw
        bne _val
        lda sp_                         ; a colour: 5 parts (colour can use sp_)
        pha
        lda sp_+1
        pha
        jsr colour
        pla
        sta sp_+1
        pla
        sta sp_
        ldy #SYM_KIND
        lda #SK_VAL
        sta (sp_),y
        iny
        lda #5
        sta (sp_),y
        iny
        ldx #0
-       lda col,x
        sta (sp_),y
        iny
        inx
        cpx #20
        bne -
        bra _semi
_tex:
        sec
        sbc #KW_TEXTURE - SK_TEXTURE
_block:
        ldy #SYM_KIND                   ; remember where it is, then skip it
        sta (sp_),y
        ldy #SYM_VAL
        lda tk_pos
        sta (sp_),y
        iny
        lda tk_pos+1
        sta (sp_),y
        iny
        lda tk_tline
        sta (sp_),y
        iny
        lda tk_tline+1
        sta (sp_),y
        jsr skip_block
        bra _semi
_val:
        lda sp_                         ; (expr can use sp_)
        pha
        lda sp_+1
        pha
        jsr expr
        pla
        sta sp_+1
        pla
        sta sp_
        ldy #SYM_KIND
        lda #SK_VAL
        sta (sp_),y
        iny
        ldx #0
-       lda v_n,x
        sta (sp_),y
        iny
        inx
        cpx #VSIZE
        bne -
_semi:
        lda #';'
        jsr accept_char
        rts
dir_declare:    .null "declare"
dir_local:      .null "local"
dir_version:    .null "version"

; skip `word { ... }`, checking only the braces
skip_block:
        jsr next_tok
        #EXPECT '{'
        lda #1
        sta sk_depth
_t:
        lda tk_type
        cmp #TK_EOF
        bne +
        #PERR E_BRACE
+       cmp #'{'
        bne +
        inc sk_depth
+       cmp #'}'
        bne +
        dec sk_depth
+       jsr next_tok
        lda sk_depth
        bne _t
        rts

global_block:
        jsr next_tok
        #EXPECT '{'
_l:
        lda #'}'
        jsr accept_char
        bcc +
        rts
+       lda #KW_MAXTRACE
        jsr accept_kw
        bcc +
        jsr number
        lda v_c+2                       ; the whole part
        sta max_trace
        lda v_c+3
        sta max_trace+1
        bra _l
+       lda #KW_AMBLIGHT
        jsr accept_kw
        bcc +
        jsr colour
        ldx #11
-       lda col,x
        sta amb_light,x
        dex
        bpl -
        bra _l
+       lda #KW_GAMMA
        jsr accept_kw
        bcc +
        jsr number
        bra _l
+       #PERR E_SETTING

camera_block:
        jsr next_tok
        #EXPECT '{'
        lda #1
        sta cam_set
        jsr v_zero3                     ; the defaults
        ldx #11
-       lda v_c,x
        sta cam_loc,x
        sta cam_look,x
        sta cam_sky,x
        dex
        bpl -
        lda #1
        sta cam_look+10
        sta cam_sky+6
        #LDIMM FX(67.38), cam_angle
_l:
        lda tk_tline
        sta cam_line
        lda tk_tline+1
        sta cam_line+1
        lda #'}'
        jsr accept_char
        bcc +
        rts
+       lda #KW_LOCATION
        jsr accept_kw
        bcc +
        jsr vector
        ldx #cam_loc - cam_loc
        bra _put
+       lda #KW_LOOK_AT
        jsr accept_kw
        bcc +
        jsr vector
        ldx #cam_look - cam_loc
        bra _put
+       lda #KW_SKY
        jsr accept_kw
        bcc +
        jsr vector
        ldx #cam_sky - cam_loc
        bra _put
+       lda #KW_ANGLE
        jsr accept_kw
        bcc +
        jsr number
        #MOVQ v_c, cam_angle
        bra _l
+       lda #KW_RIGHT
        jsr accept_kw
        bcs _skipv
        lda #KW_UP
        jsr accept_kw
        bcc +
_skipv: jsr vector                      ; the screen fixes these
        bra _l
+       lda #KW_PERSPECTIVE
        jsr accept_kw
        bcs _l
        #PERR E_SETTING
_put:
        ldy #0
-       lda v_c,y
        sta cam_loc,x
        inx
        iny
        cpy #12
        bne -
        jmp _l

light_block:
        jsr next_tok
        #EXPECT '{'
        lda sc_nlight
        cmp #MAX_LIGHT
        bcc +
        #PERR E_LIGHTS
+       jsr vector
        ldx #11
-       lda v_c,x
        sta lt_pos,x
        dex
        bpl -
        lda #','
        jsr accept_char
        #LDIMM ONE, lt_col
        #LDIMM ONE, lt_col+4
        #LDIMM ONE, lt_col+8
        lda #0
        sta lt_fl
_l:
        lda #'}'
        jsr accept_char
        bcs _done
        lda #KW_SHADOWLESS
        jsr accept_kw
        bcc +
        lda #LF_SHADOWLESS
        sta lt_fl
        bra _l
+       jsr is_colour_kw
        bne +
        jsr colour
        ldx #11
-       lda col,x
        sta lt_col,x
        dex
        bpl -
        bra _l
+       lda #KW_TRANSLATE
        jsr accept_kw
        bcc +
        jsr vector
        #VADD lt_pos, v_c, lt_pos
        bra _l
+       #PERR E_SETTING
_done:
        ldx sc_nlight
        inc sc_nlight
        lda light_lo,x
        sta lp
        lda light_hi,x
        sta lp+1
        ldy #0
-       lda lt_pos,y
        sta (lp),y
        iny
        cpy #25
        bne -
        rts

;=======================================================================================
; objects. object: A = 1 at the top level (it becomes a root; a union's parts each do).
; Each nesting level keeps its state in the ob_* arrays at ob_d.
;=======================================================================================
object:
        ldx ob_d
        cpx #MAX_DEPTH
        bcc +
        #PERR E_DEPTH
+       inc ob_d
        sta ob_flat,x
        lda tk_tline                    ; (a primitive's line: its keyword's)
        sta pr_line
        lda tk_tline+1
        sta pr_line+1
        lda tk_kw
        sta ob_kw,x
        lda sc_nprim
        sta ob_p0,x
        lda prog_len
        sta ob_r0,x
        lda #0
        sta ob_cnt,x
        lda tk_kw
        cmp #KW_OBJECT
        bne _new
        ; object { Name modifiers }: the declared object, read again from its text
        jsr next_tok
        #EXPECT '{'
        lda tk_type
        cmp #TK_ID
        bne _notobj
        jsr sym_find
        bcc _notobj
        ldy #SYM_KIND
        lda (sp_),y
        cmp #SK_OBJECT
        bne _notobj
        jsr sym_get_pos
        jsr next_tok                    ; past the name
        jsr pos_push
        jsr pos_jump
        ldx ob_d
        lda ob_flat-1,x
        jsr object
        jsr pos_pop
        ldx ob_d
        lda #0                          ; (the declared object made its own root)
        sta ob_flat-1,x
        jsr modifiers
        dec ob_d
        rts
_notobj:
        #PERR E_NOTOBJ
_new:
        jsr next_tok
        #EXPECT '{'
        ldx ob_d
        lda ob_kw-1,x
        cmp #KW_UNION
        bcc _prim
        ; a boolean: its parts, each followed (after the first) by the operation
_part:
        jsr is_object_kw
        bne _parts_done
        jsr sk_open
        ldx ob_d
        lda ob_kw-1,x
        cmp #KW_UNION
        bne +
        lda ob_flat-1,x                 ; a top-level union: each part is a root
        bne ++
+       lda #0
+       jsr object
        ldx ob_d
        inc ob_cnt-1,x
        lda ob_cnt-1,x
        cmp #2
        bcc _part
        lda ob_kw-1,x                   ; (a flattened union emits nothing)
        cmp #KW_UNION
        bne +
        lda ob_flat-1,x
        bne _part
+       lda ob_kw-1,x
        sec
        sbc #KW_UNION
        tay
        lda csg_ops,y
        jsr emit
        jsr sk_close
        bra _part
_parts_done:
        ldx ob_d
        lda ob_cnt-1,x
        bne +
        #PERR E_CSGEMPTY
+       jsr modifiers
        ldx ob_d
        lda ob_kw-1,x
        cmp #KW_UNION
        bne _root
        lda ob_flat-1,x
        bne _out                        ; a flattened union: no root of its own
        bra _root
_prim:
        jsr primitive
        jsr modifiers
_root:
        ldx ob_d
        lda ob_flat-1,x
        beq _out
        lda #OP_END                     ; a top-level object: its program ends; a root
        jsr emit
        ldx sc_nroot
        cpx #MAX_ROOT
        bcc +
        #PERR E_ROOTS
+       inc sc_nroot
        jsr root_ptr_x
        ldx ob_d
        lda ob_r0-1,x
        ldy #R_START
        sta (rp),y
_out:
        dec ob_d
        rts
csg_ops:        .byte OP_UNION, OP_UNION, OP_INTER, OP_DIFF

; before a part of an intersection or difference, other than the first: OP_SKIP and a
; length, filled in by sk_close once the part and its operation are emitted
sk_open:
        ldx ob_d
        lda ob_cnt-1,x
        beq sk_none
        lda ob_kw-1,x
        sec
        sbc #KW_UNION
        cmp #2
        bcc sk_none
        lda #OP_SKIP
        jsr emit
        ldx ob_d
        lda prog_len
        sta ob_sk-1,x
        lda #0
        jmp emit
sk_none:
        rts
sk_close:
        ldx ob_d
        lda ob_kw-1,x
        sec
        sbc #KW_UNION
        cmp #2
        bcc sk_none
        ldy ob_sk-1,x                   ; length = the bytes after it
        clc
        lda prog_len
        sbc ob_sk-1,x
        sta sc_prog,y
        rts

; rp = root X (bank 0)
root_ptr_x:
        lda root_lo,x
        sta rp
        lda root_hi,x
        sta rp+1
        rts

; one byte of program
emit:
        ldx prog_len
        cpx #255
        bcc +
        #PERR E_PROG
+       sta sc_prog,x
        inc prog_len
        rts


        .include "parse2.asm"
        .include "parsev.asm"
