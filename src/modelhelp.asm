;=======================================================================================
; modelhelp.asm - what each property means: the prompt when a value is clicked. These lines
; are in overlay 6's file past OVL_END, so they are loaded into attic with it but never into
; the window: help_prompt (modelpanel.asm) copies the one it needs. Each is 64 bytes; the
; byte before a field's label (modelpanel.asm) is its line's number, (hp_x - OVL_END) >> 6.
;=======================================================================================

HELP .macro text
        .cerror len(\text) > 62, "a help line is too long: ", \text
        .null \text
        .fill 63 - len(\text), 0
.endmacro

        .cerror * != OVL_END, "the help lines must start at OVL_END"
hp_px:  #HELP "X, the position left (-) or right (+): "
hp_py:  #HELP "Y, the position down (-) or up (+): "
hp_pz:  #HELP "Z, the position nearer (-) or further (+) back: "
hp_rx:  #HELP "RX, turned about the x axis (degrees): "
hp_ry:  #HELP "RY, turned about the y axis, upright (degrees): "
hp_rz:  #HELP "RZ, turned about the z axis (degrees): "
hp_s:   #HELP "S, the scale, the same every way (1: as made): "
hp_r:   #HELP "R, the radius: "
hp_r1:  #HELP "R1, the radius at the bottom: "
hp_r2:  #HELP "R2, the radius at the top (0: a point): "
hp_h:   #HELP "H, the height, along y (centred): "
hp_sx:  #HELP "SX, the size along x, left to right (centred): "
hp_sy:  #HELP "SY, the size along y, up and down (centred): "
hp_sz:  #HELP "SZ, the size along z, front to back (centred): "
hp_cx:  #HELP "CX, this corner's place left or right (x): "
hp_cz:  #HELP "CZ, this corner's place front or back (z): "
hp_lpy: #HELP "Y, this profile point's height: "
hp_lr:  #HELP "R, the light's red (1: full; more is brighter): "
hp_lg:  #HELP "G, the light's green (1: full; more is brighter): "
hp_lb:  #HELP "B, the light's blue (1: full; more is brighter): "
hp_cr:  #HELP "R, the colour's red, 0 to 1: "
hp_cg:  #HELP "G, the colour's green, 0 to 1: "
hp_cb:  #HELP "B, the colour's blue, 0 to 1: "
hp_lx:  #HELP "LX, the point the camera looks at, x: "
hp_ly:  #HELP "LY, the point the camera looks at, y: "
hp_lz:  #HELP "LZ, the point the camera looks at, z: "
hp_ang: #HELP "Ang, how wide the camera sees, degrees across: "
hp_bgr: #HELP "BgR, the background's red, 0 to 1: "
hp_bgg: #HELP "BgG, the background's green, 0 to 1: "
hp_bgb: #HELP "BgB, the background's blue, 0 to 1: "
hp_trc: #HELP "Trace, bounces for mirrors and glass (5 is usual): "
hp_dif: #HELP "Dif, diffuse: light it scatters, 0 to 1 (0.6 usual): "
hp_pho: #HELP "Pho, Phong: highlight strength, 0 to 1 (0: none): "
hp_psz: #HELP "Siz, highlight size: bigger is smaller and sharper: "
hp_amb: #HELP "Amb, ambient: light it shows in shadow (0.1 usual): "
hp_ref: #HELP "Ref, reflection: 0 none, 1 a perfect mirror: "
hp_trn: #HELP "Trn, transmit: light let through, 0 to 1 (glass 0.8): "
hp_ior: #HELP "IOR, index of refraction (glass 1.5, water 1.33): "
hp_csz: #HELP "Sq, the checker's square size (1 to 2 for floors): "
hp_r2c: #HELP "R2, the checker's second colour, red 0 to 1: "
hp_g2:  #HELP "G2, the checker's second colour, green 0 to 1: "
hp_b2:  #HELP "B2, the checker's second colour, blue 0 to 1: "
        .cerror * - OVL_END > 64 * 64, "too many help lines"
