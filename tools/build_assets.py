"""Build-time asset compiler: src/assets -> src/gen + target/assets. build.bat runs it.

A starting point; replace the layout with the project's own. It reads:
  src/assets/sprites/sprites.png + sprites.txt   24 x 21 cells, 16 a row, and their names
                                                 in sprite-id order
and writes:
  src/gen/palette.asm    the 256 colours (entries 0-15 fixed, art from ART_FIRST)
  src/gen/sprites.asm    SPR_<name> ids and the sprite boxes (copy into lib/blit.asm spr_*)
  src/gen/manifest.asm   the packed files and their attic addresses (lib/manifest.asm)
  target/assets/*        the packed files, and files.txt for build.bat
Edit the PNG freely, but keep the cell grid and the order (sprites.txt).
"""
import os

import m65assets as m

SPRITE_DIR = os.path.join(m.SRC_ASSETS, 'sprites')
FIXED = [(0, 0, 0), (255, 255, 255)]    # entries 0-15: UI colours the code refers to
ART_FIRST = 16
ATTIC_SPRITES = 0x8000000               # copy to chip RAM (lib/blit.asm SPR_BASE) at boot


def build():
    names = m.load_names(os.path.join(SPRITE_DIR, 'sprites.txt'))
    sprites = m.sheet_load(os.path.join(SPRITE_DIR, 'sprites.png'), len(names), 16)
    colours, lookup = m.quantize(sprites, 256 - ART_FIRST)
    pal = FIXED + [(0, 0, 0)] * (ART_FIRST - len(FIXED)) + colours
    m.write_palette(pal)
    data, boxes = m.encode_blit(sprites, lambda c: ART_FIRST + lookup[c])
    m.write_boxes('sprites.asm', names, boxes,
                  ['SPR_COUNT               = %d' % len(names),
                   'SPRITES_BYTES           = %d' % len(data)])
    parts = m.write_parts('SPRITES', data)
    m.write_manifest([(n, ATTIC_SPRITES + off, ln) for n, off, ln in parts],
                     ['ATTIC_SPRITES = $%07x' % ATTIC_SPRITES])


if __name__ == '__main__':
    build()
