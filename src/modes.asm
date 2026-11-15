;=======================================================================================
; modes.asm - the modeller's commands that need other overlays (resident): rendering,
; previewing, files. Each loads what it needs and the modeller (overlay 4) again after.
;
;   do_command     A = a command (CMD_RENDER, CMD_PREVIEW, CMD_SAVE, CMD_SAVEAS,
;                  CMD_OPEN, CMD_EXPORT) -> A/X = a message for the status line
;=======================================================================================

do_command:
        sta dc_cmd
        cmp #CMD_RENDER
        beq _render
        cmp #CMD_PREVIEW
        beq _render
        cmp #CMD_SAVEAS
        beq _ask
        cmp #CMD_OPEN
        beq _open
        bra _file
_render:
        jmp do_render
_open:  ; the disk's documents to pick from (or a name typed)
        lda #OVL_WRITE
        jsr ovl_load
        jsr open_dialog
        bcc +
        lda wr_err
        jsr dc_status_msg
        lda #<dc_msg
        ldy #>dc_msg
        jmp _back
+       cmp #1
        beq _typed
        cmp #2
        bne _file
        lda #<dc_cancel
        ldy #>dc_cancel
        jmp _back
_typed: lda #OVL_MODEL                  ; (the prompt's status line, then the writer again)
        jsr ovl_load
_ask:   ; a file name (without its extension)
        ldx #0
-       lda ms_name,x
        sta ge_buf,x
        beq +
        inx
        bra -
+       lda #<dc_pname
        ldx #>dc_pname
        jsr gui_edit
        bcc +
        lda #<dc_cancel
        ldx #>dc_cancel
        rts
+       ldx #0                          ; upper case, at most 12 characters
_up:    lda ge_buf,x
        beq _put
        cmp #'a'
        bcc _put
        cmp #'z' + 1
        bcs _put
        and #$df
_put:   sta ms_name,x
        cmp #0
        beq _file
        inx
        cpx #12
        bne _up
        lda #0
        sta ms_name,x
_file:
        lda #OVL_WRITE
        jsr ovl_load
        lda dc_cmd
        cmp #CMD_OPEN
        bne +
        jsr doc_load
        lda #<dc_opened
        ldy #>dc_opened
        bcc _back_sel
        bra _fail
+       cmp #CMD_EXPORT
        bne +
        jsr export_pov
        lda #<dc_exported
        ldy #>dc_exported
        bcc _back
        bra _fail
+       jsr doc_save
        lda #<dc_saved
        ldy #>dc_saved
        bcc _back
_fail:
        lda wr_err
        jsr dc_status_msg
        lda #<dc_msg
        ldy #>dc_msg
        bra _back
_back_sel:
        ldx #$ff
        stx ms_sel
_back:
        sta dc_m
        sty dc_m+1
        lda #OVL_MODEL
        jsr ovl_load
        lda dc_m
        ldx dc_m+1
        rts

; doc_new: a new document: DEFAULT.MDL from the disk, or if it can't be read the built-in
; one (overlay 5); named SCENE either way. Then the modeller's overlay again.
doc_new:
        lda #OVL_WRITE
        jsr ovl_load
        jsr doc_default
        ldx #0
-       lda dn_default,x
        sta ms_name,x
        beq +
        inx
        bra -
+       jsr doc_load                    ; (it leaves the document alone if it fails)
        ldx #0
-       lda dn_scene,x
        sta ms_name,x
        beq +
        inx
        bra -
+       lda #OVL_MODEL
        jmp ovl_load
dn_default:     .null "DEFAULT"
dn_scene:       .null "SCENE"

; dc_msg = "Disk trouble: NN" (A = the drive's status; $ff = not a document)
dc_status_msg:
        cmp #$ff
        bne _num
        ldx #0
-       lda dc_notdoc,x
        sta dc_msg,x
        beq _r
        inx
        bra -
_r:     rts
_num:   sta gf_v+2
        lda #0
        sta gf_v
        sta gf_v+1
        sta gf_v+3
        jsr gui_fmt
        ldx #0
-       lda dc_disk,x
        beq +
        sta dc_msg,x
        inx
        bra -
+       ldy #0
-       lda gf_str,y
        sta dc_msg,x
        beq +
        inx
        iny
        bra -
+       rts

;---------------------------------------------------------------------------------------
; do_render: write the scene, parse it, trace it (and recolour it); then show it until a
; key or a click (S saves the picture as NAME.IFF)
;---------------------------------------------------------------------------------------
do_render:
        jsr gui_off
        lda #OVL_WRITE
        jsr ovl_load
        jsr write_pov
        jsr doc_park                    ; (the scene tables go where the document is)
        lda #OVL_PARSE
        jsr ovl_load
        jsr parse_text
        bcc +
        jmp _perr
+       lda dc_cmd                      ; a preview: one bounce at most
        cmp #CMD_PREVIEW
        bne +
        lda sc_maxd
        cmp #2
        bcc +
        lda #1
        sta sc_maxd
+       lda #OVL_TRACE
        jsr ovl_load
        jsr render_palette
        lda #0
        sta f640_fill
        lda #0
        jsr f640_clear
        lda dc_cmd
        cmp #CMD_PREVIEW
        bne +
        jsr render_preview
        bra _show
+       jsr render
        lda #OVL_RECOLOUR
        jsr ovl_load
        jsr recolour
_show:
        lda #4                          ; (tests: done = 4 while a picture is shown)
        sta done
        jsr key_flush                   ; input from before it doesn't count:
        lda #25                         ; and for half a second nothing does
        sta dc_quiet
-       jsr wait_frame
        jsr gui_poll
        dec dc_quiet
        bne -
_wait:
        jsr wait_frame
        jsr gui_poll
        lda dbg_hold                    ; (tests: keep showing it)
        bne _wait
        lda ev_type
        cmp #EV_DOWN
        beq _done
        cmp #EV_KEY
        bne _wait
        lda ev_key
        cmp #'s'
        bne _done
        lda dc_cmd
        cmp #CMD_PREVIEW
        beq _done
        ; save it: NAME.IFF
        lda #OVL_SAVE
        jsr ovl_load
        ldx #0
-       lda ms_name,x
        beq +
        sta sv_name,x
        inx
        bra -
+       ldy #0
-       lda dc_iff,y
        sta sv_name,x
        beq +
        inx
        iny
        bra -
+       jsr save_iff
        lda #<dc_picsaved
        ldy #>dc_picsaved
        bcc +
        lda sv_err
        jsr dc_status_msg
        lda #<dc_msg
        ldy #>dc_msg
+       jmp _back
_done:
        lda #<dc_rendered
        ldy #>dc_rendered
        lda dc_cmd
        cmp #CMD_PREVIEW
        bne +
        lda #<dc_previewed
        ldy #>dc_previewed
        jmp _back
+       lda #<dc_rendered
        ldy #>dc_rendered
        jmp _back
_perr:  ; "Scene error, line N: the message" (the text is in overlay 2: copy it now)
        lda parse_line
        sta gf_v+2
        lda parse_line+1
        sta gf_v+3
        lda #0
        sta gf_v
        sta gf_v+1
        jsr gui_fmt
        ldx #0
-       lda dc_serr,x
        beq +
        sta dc_msg,x
        inx
        bra -
+       ldy #0
-       lda gf_str,y
        beq +
        sta dc_msg,x
        inx
        iny
        bra -
+       lda #':'
        sta dc_msg,x
        inx
        lda #' '
        sta dc_msg,x
        inx
        ldy #0                          ; the message (perr put it in pe_msg)
-       lda pe_msg,y
        sta dc_msg,x
        beq +
        inx
        iny
        cpx #DC_MSGMAX
        bne -
        lda #0
        sta dc_msg,x
+       lda #<dc_msg
        ldy #>dc_msg
        jmp _back
_back:
        sta dc_m
        sty dc_m+1
        jsr doc_unpark                  ; the document again, over the scene tables
        lda #5                          ; (tests: back in the modeller)
        sta done
        lda #OVL_MODEL
        jsr ovl_load
        lda dc_m
        ldx dc_m+1
        rts

DC_MSGMAX       = 72
dbg_hold:       .byte 0                 ; (tests: nonzero keeps a picture on the screen)
dc_quiet:       .byte 0
dc_cmd:         .byte 0
dc_m:           .word 0
dc_msg:         .fill DC_MSGMAX + 1
dc_pname:       .null "File name: "
dc_cancel:      .null "Cancelled"
dc_opened:      .null "Opened"
dc_saved:       .null "Saved"
dc_exported:    .null "Exported the scene as NAME.POV"
dc_rendered:    .null "Rendered (press S on the picture to save it)"
dc_previewed:   .null "Previewed"
dc_picsaved:    .null "Saved the picture"
dc_notdoc:      .null "That file isn't a modeller document"
dc_disk:        .null "Disk trouble: "
dc_serr:        .null "Scene error, line "
dc_iff:         .null ".IFF"
