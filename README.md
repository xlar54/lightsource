Lightsource
===========

A ray tracer for the MEGA65 that reads scenes written in a subset of POV-Ray's scene language.
It is built on the standard, openly published ray-tracing methods (ray-shape intersection,
Phong shading, shadow rays, reflection and refraction). The plan is a whole system on the MEGA65: a 640x200 graphical modeller, the scene language, rendering,
and saving the picture (see [docs/DESIGN.md](docs/DESIGN.md)). It was called renderer65
until November 2026.

What works now:
- **The scene language:** spheres, boxes, cylinders, cones, planes and prisms; `union`, `merge`,
  `intersection` and `difference`; `translate`, `rotate` and `scale`; checker and plain
  pigments; Phong finishes, reflection and refraction with a refractive index for each
  material; coloured lights and spotlights, a camera that can turn, and `#declare`. The MEGA65 reads the
  file from disk and compiles it.
- **Rendering** at 640x200 in 256 colours, in two passes:
  1. **Trace.** Every pixel is traced in 16.16 fixed point, with the 24-bit colour kept in
     attic RAM. The picture is shown as it's drawn, dithered to a fixed colour cube.
  2. **Recolour.** A median-cut palette of 254 colours is made for the picture, and the
     picture is Floyd-Steinberg dithered to it.
- **Saving:** `SCENE.IFF`, an IFF ILBM: 8 bitplanes, ByteRun1 compression (about 26 KB for
  the default scene). Its BMHD aspect of 8:15 makes viewers show the true pixel shape.

- **The modeller,** which is what boot starts. See "The modeller" below.

Still to come: animation.

The modeller
------------

Picture viewer
--------------

`VIEWER` on the disk is a BASIC 65 program ([src/basic/viewer.bas](src/basic/viewer.bas)) that
shows the pictures the renderer saves. Leave the modeller (File, Exit), then `RUN "VIEWER"`.
It lists the disk's `.IFF` files; type a name and press RETURN to see it on a 640x200,
256-colour screen, and any key to go back. RETURN on its own stops. It uses BASIC 65's
`LOADIFF`, which opens only PRG files, so the renderer saves its pictures as PRG.

The modeller
------------

The user's manual is [docs/modeller-manual.pdf](docs/modeller-manual.pdf) (a draft: the
screenshots are placeholders). Its text is [docs/manual/modeller.md](docs/manual/modeller.md);
`private/tools/make_manual.py` builds the PDF (it needs reportlab), putting in any
`docs/manual/shots/NAME.png` it finds.

A 640x200 interface in 256 colours, used with the mouse and keyboard. It starts with
`DEFAULT.MDL` from the disk (File, New loads it too): no objects, the camera up and back at
(7, 5.5, -9) looking down at the origin (where Add puts new objects), one light and one white material. Save as `DEFAULT` to change it; without
the file the same empty scene is built in. Whatever it loads, the document is named
`SCENE`. `SPHERES.MDL` is five balls (glass, gold, jade, chrome, coral) on a tiled floor at
dusk; `scenes/default.pov` is the same scene as text, for the tests.

- **Views:** top, front and side (orthographic) and the camera's (in perspective), all
  wireframes. The selected object is yellow, and a selected group shows all its parts.
  Lights are orange crosses; the camera is a small green triangle, its point at the camera and its open end
  towards where it looks (selected: yellow, with a line to that point and a cross there
  that drags where it looks).
  A spotlight also has a line to its aim point (a cross: drag it to re-aim the light) and
  its cone out to there: four lines and a ring at the falloff angle.
- **Object list** (top right): objects as an outline (a group's parts are indented under
  it and hang from a tree line, an L before each name), then the lights and the camera. Click one to select it.
  The box at the left of each object shows it in the views (filled) or hides it (empty):
  click the box to change it. A hidden group hides its parts (their names go grey), and
  hidden objects can't be picked in the views. They are left out of renders, previews and
  exported `.POV` files too (a group with nothing shown in it is left out as well).
  It is saved with the document.
  The scroll bar at the list's right: click above or below the thumb for a page, or drag
  the thumb. The list only jumps to the selection when the selection changes.
- **Properties** (bottom right): position, rotation (degrees), scale and sizes, and the
  material. Click a number to type a new one (RETURN takes it, ESC leaves it). Click the
  name to rename the object, or the material to step to the next one.
- **Click a view's name** (its top-left corner) to make it fill the whole view area; click
  the name again for the four views.
- **Mouse in the views:** click near an object's centre, a light or the camera to select it
  (what is already selected wins when it is within reach). With a group selected, pressing
  on any of its parts drags, turns (SHIFT) or scales (CTRL) the whole group; a click on a
  part without moving selects that part.
  Drag to move it in that view's plane (inside a turned or scaled group it still follows
  the pointer). SHIFT-drag turns an object about the axis the view looks along (top: RY,
  front: RZ, side: RX), CTRL-drag changes its scale S. View, Snap (G) makes drags snap:
  0.5 units, 15 degrees, scales in quarters. In the camera view, drag on empty space to turn
  the camera round the point it looks at (the scene turns with the pointer; it stops short
  of straight above or below).
- **Menus:**
  - **File:** New, Open, Save, Save as, Export POV, Preview, Render, Exit (back to BASIC,
    after Y: anything not saved is lost).
  - A menu, the Open list and typing on the status line put back what they covered when
    they close (saved in attic), so only commands that change something redraw the views.
  - **Edit:** Undo, Redo (16 steps: every change to the document - adding, deleting,
    moving, typed values, materials, corners, the show / hide boxes, New and Open - keeps
    a snapshot in attic first), Delete, Duplicate.
  - **Scene:** Move up and down (inside a Difference this picks what is cut from what),
    Indent (into the group above), Outdent (both keep the object where it is: its
    position, rotation and scale are worked out again in the new group's frame, with an
    arctangent found by halving on sin and cos), and World... (the background colour, BgR /
    BgG / BgB, and Trace: POV-Ray's `max_trace_level`). World is also the first entry in
    the list, above the objects.
  - **Add:** the six primitives, a lathe, a light, a spotlight (aimed at the origin; any
    light becomes one with Spot in the panel: AX / AY / AZ, Rad, Fal, Tgt), and the four
    booleans. A new boolean takes the
    selected object into itself, placed where that object was (so nothing moves).
  - **Material:** Next, Previous, New (a copy, opened in the editor), Edit (the material
    editor: its own screen with a preview ball traced small by the real tracer, the
    settings grouped with colour swatches, numbers dragged or typed, presets Matte /
    Plastic / Metal / Mirror / Glass / Glow, Done or Cancel), Save to file... and Load from file... (a material on its own, `NAME.MAT`: a
    library to share between documents; the disk has 15 to start with, from glass and
    gold to checker floors. A loaded one is added to the document and the selected object
    takes it).
  - **View:** zoom, Locate (the top, front and side views centred on the selection, at
    the zoom they have), reset; Aim camera (it looks at the selection); Aim light... (with
    a light selected, click what it should aim at: it becomes a spotlight); Camera front, top
    and side (it looks at the selection, or where it looked, from that direction, as far
    away as it was); Snap; Grid (on at the start: lines in the top, front and side views
    every 0.25, 0.5, 1, 2, 5, 10, 20, 50 or 100 units, the smallest step that leaves 12
    pixels or more between them at the zoom).
  - **Help:** About... (a box with the version and the build date; a click or a key
    closes it).
- **Prisms** are the shape with points to edit. The selected prism has a handle on each
  corner in the top, front and side views (at its top). Click one to pick it (it fills
  in, and the panel shows its CX and CZ), and drag it to move it. I adds a corner half way
  to the next one, and DEL removes the picked corner. A prism has 3 to 16 corners. All the
  prisms in a document share a pool of 255 corners (in attic RAM), so there can be as many
  as the 64 objects allow. A new one is a house shape, 1 high.
- **Lathes** are a profile turned about the y axis: points of (radius, height), edited
  like a prism's corners (handles in the front and side views; the panel shows the picked
  point's R and Y; I adds a point, DEL removes one). A new one is a pawn. The scene text
  has it as a `merge` of cones, one for each segment that isn't level, so it is solid
  (no hollow cups), each segment is a primitive (64 in a scene), and POV-Ray reads it too.
- **`MEGA65.MDL`** on the disk is an example: the word in prisms (the A's and the 6's holes
  are boxes cut out with a Difference), glass balls, gold cones and a mirror ball. File,
  Open, then click `MEGA65`. It is made by `private/tools/make_mdl.py` (`scenes/mega65.mdl`).
- **`JUGGLER.MDL`**: a robot (copper torso, box head, brass limbs) juggling three mirror
  balls over a checker floor: 30 objects, all of them primitives the modeller makes. Also
  from `make_mdl.py`.
- **`CHESS.MDL`**: a king, a rook (ivory) and a knight (ebony) on a board: lathe bodies, box
  battlements and cross, and a prism for the knight's head. Also from `make_mdl.py`.
- **`CHESSSET.MDL`**: a whole set in the starting position on an 8 x 8 checker board (a1 dark,
  queens on their own colour). A render takes 64 primitives at most, so each piece is one to
  three simple shapes (a cone and a ball for a pawn, a cone for a rook, a prism head on a
  base for a knight, which faces the middle of the board so the camera sees it in profile):
  63 objects, 63 primitives. Also from `make_mdl.py`.
- **`DESK.MDL`**: a desk at night: a tower computer, a flat monitor with a glowing screen, a
  keyboard, a mouse on its pad, and a desk lamp whose spotlight is the only light (the
  materials' own ambient lets the rest show dimly) on black. 35 objects, 29 primitives.
  Also from `make_mdl.py` (`python private/tools/make_mdl.py desk`).
- **`TIE.MDL`**: a TIE fighter in space (made with permission): a ball cockpit with a strutted
  round window and two guns, hexagonal wings (stood-up prisms: a frame, a dark panel, ribs, a
  hub) on tapered arms, a blue planet and twelve stars on black. 37 objects; a full render
  takes about 2 minutes in Xemu. The planet and stars are small and only about 75-90 units
  away: the tracer's 16.16 numbers overflow once a squared distance passes 32768 (about
  180 units), so a scene must stay inside that. Also from `make_mdl.py`.
- **Keys:** `+`/`-` zoom, DEL delete (the picked corner, or the selection), I add a
  corner, U (or Ctrl-Z) undo, Y (or Ctrl-Y) redo, L locate, A aim the camera, G snap, R render, P preview,
  S save.
- **Render** writes the document out as scene text, parses it and renders it full screen.
  Press S on the picture to save it as `NAME.IFF`; any other key or a click goes back.
- **Preview** is quicker: every 4th pixel of every 2nd line, at most one bounce.
- **Files:**
  - Save writes `NAME.MDL`, the document itself.
  - Export POV writes `NAME.POV`: scene text the renderer, or POV-Ray, can read.
  - Open lists the disk's `.MDL` documents in the right-hand panel (up to 48; "more" and
    the panel's title scroll it). Click one, or use the cursor keys and RETURN. Name...
    asks for a name instead; Cancel or ESC goes back.
  - The modeller can't read `.POV` files back; Open reads `.MDL`.

How the scene text is written:
- Primitives are made at the origin and placed with `scale`, `rotate` and `translate`.
- Materials become declared textures `M1`, `M2` and so on.
- A group's material is written on the group, so its parts share it.

Build and run
-------------

- `build.bat` assembles everything with 64tass and writes `target/lightsource.d81`. The disk
  holds:
  - the program and its overlays;
  - every scene in `scenes/`, with `scenes/default.pov` also written as `SCENE.POV`;
  - the starter materials, `scenes/*.mat` (made by `private/tools/make_mdl.py mats`).
- `run.bat` builds and starts Xemu.
- The version number is `LS_VERSION` in `src/version.asm` (0.9 now). `tools/build_info.py`
  writes the build date into `src/gen/build.asm` on every build. Help, About shows both.
- The manual, `docs/modeller-manual.pdf`, is made from `docs/manual/modeller.md` and the
  screenshots in `docs/manual/shots/`.

At boot the program starts the modeller. A test build with `-D DBG_BOOTRENDER=1` renders
`SCENE.POV` instead and saves `SCENE.IFF`. To render another scene that way, set
`M65SCENE` before building, for example `set M65SCENE=scenes\shapes.pov`.

Build-time test settings go in `M65DEFS`, for example `set M65DEFS=-D DBG_ROWS=8 -D DBG_SAVE=0`:

| Setting | Effect |
|---|---|
| `DBG_ROWS` | Lines to trace |
| `DBG_PASS2=0` | Skip the recolouring |
| `DBG_SAVE=0` | Don't save the picture |
| `DBG_BOOTRENDER=1` | Render `SCENE.POV` at boot instead of starting the modeller |
| `DBG_SCENEBIN=1` | Use tables made by `pov.py` instead of parsing |
| `DBG_LOG=1` | Trace one pixel with a value log |

The `done` byte reports progress:

| `done` | Meaning |
|---|---|
| 1 | Traced |
| 2 | Recoloured |
| 3 | Saved |
| 4 | A picture is on the screen (from the modeller) |
| 5 | The modeller is up |
| `$80` | The scene didn't parse; `parse_err` and `parse_line` say why and where |
| `$81` | A file is missing |
| `$82` | The picture couldn't be saved |

Scenes
------

Scenes are text files in the POV-Ray subset described in [docs/DESIGN.md](docs/DESIGN.md);
[scenes/default.pov](scenes/default.pov), [scenes/shapes.pov](scenes/shapes.pov) and
[scenes/spot.pov](scenes/spot.pov) (spotlights) are examples. Every file the system accepts is also valid for POV-Ray itself. To frame a scene the
same way there, render at 640x375 with `right x*640/375`.

The limits:
- 64 primitives, 16 materials, 16 lights and 64 top-level objects. The modeller's documents
  have up to 64 objects and 16 lights (lathes make several primitives each, so a document
  can still be too big to render: the parser says so).
- Booleans nested 7 deep.
- Numbers to 4 decimal places, below 32767.
- Keep everything within about 120 units of the camera.
- Only boxes can be scaled unevenly.
- A texture moves with its object wherever it is written.

Architecture
------------

One assembly makes the resident program and eight overlays. `build.bat` writes each section
to its own file, and `tools/cut.py` trims each one. At boot the overlays are loaded into
attic; `ovl_load` copies one into the window at `$8000-$CFFF` when it's needed.

The modeller is two overlays, 4 and 6 (the properties panel), that call each other
through `ovl_far` (`#FAR OVL_PANEL, draw_props`). It writes the window back to attic
before it copies the other one in, so both keep their variables, and calls can nest; A, X,
Y and the flags go through. A swap is two 20 KB DMA copies, too quick to measure in a
redraw. Neither overlay may use the other's labels directly, which the assembler can't see
(one symbol table): `python private/tools/ovl_check.py` lists any that do.

The material editor is overlay 7, reached the same way (`#FAR OVL_MATED, mat_editor`).
Its preview calls the resident `ed_trace`, which swaps the editor out (written back, so it
keeps its state), parks the document, builds a small scene over it (overlay 5 `ed_doc`: a
floor and a ball wearing the material), writes and parses it, traces every 3rd pixel and
line into the editor's window (overlay 0 `render_window`, a 6x6x6 cube in palette entries
16-231 beside the GUI's 0-15), puts the document back and loads the editor again.

| Part | Files | What |
|---|---|---|
| Resident | `main.asm`, `scene.asm` | Boot, overlay manager, the compiled scene tables. Library: `system`, `dma`, `loader`, `kstream`, `fcm640`, `fixed`, `fixtrig`, `draw640`, `keyboard`, `mouse`, `hwsprite` |
| Overlay 0 | `render.asm`, `trace.asm`, `vars.asm` | Render loop and the tracer: intervals for each primitive, booleans, shading |
| Overlay 1 | `recolour.asm` | Median-cut palette and Floyd-Steinberg |
| Overlay 2 | `parse.asm`, `parse2.asm`, `parsev.asm` | The scene language: tokenizer, expressions, objects, transforms, materials, final compile; the error messages (past the window's end in the file: they stay in attic) |
| Overlay 3 | `save.asm` | IFF ILBM files |
| Overlay 4 | `model.asm`, `model2.asm`, `model3.asm`, `model4.asm` | The modeller: views, wireframes, the grid, list, commands, undo |
| Overlay 5 | `writer.asm`, `doctiny.asm`, `matfile.asm` | The document as scene text; `.MDL`, `.POV` and `.MAT` files; the Open dialog (the disk's directory, for documents or materials) |
| Overlay 6 | `modelpanel.asm`, `modelhelp.asm`, `about.asm` | The modeller's properties panel; the prompts' help lines (past the window's end in the file: they stay in attic); Help, About |
| Overlay 7 | `matedit.asm` | The material editor |
| Resident | `gui.asm`, `doc.asm`, `modelst.asm`, `modes.asm`, `modelres.asm` | The toolkit (palette, pointer, events, menus, typing, numbers); the document; the modeller's lasting state; render and file commands; the modeller's menus, mouse drags and material commands |

New library modules:

| Module | What |
|---|---|
| `lib/fixed.asm` | 16.16 maths on the Q register |
| `lib/fcm640.asm` | 640x200 Full Colour Mode. A buffer can be in attic; `f640_copy10` shows it |
| `lib/draw640.asm` | Lines, rectangles and text in that mode, all clipped |

**Memory:**

| Area | What |
|---|---|
| `$2001-$7FFF` | Resident program and scene tables |
| `$8000-$CFFF` | Overlay window |
| `$0800-$15FF` | Parser work area (names, primitive definitions, value stack) |
| `$12000` | Screen RAM |
| `$14000-$1EFFF` | The scene file's text |
| `$40000-$5F3FF` | Framebuffer |
| `$8000000` | 24-bit picture |
| `$8060000`... | Recolouring's work areas |
| `$8100000` | The recoloured picture before it's shown |
| `$8700000` | The overlays |

**Keep the ROM intact.** The C65 ROM at `$20000-$3FFFF` must not be overwritten: the KERNAL's
disk calls after the takeover need it.

**Testing:** the tools in `private/` (not published) do this:
- `pov.py` is a Python twin of the parser, and `ref_trace.py` a bit-exact model of the tracer.
- `rt_test.py` runs the D81 in headless Xemu and compares the compiled tables, the preview,
  the final palette and pixels, and the saved IFF (decoded by its own reader), byte for byte.

All of these match for the default, shapes and full-syntax test scenes. Nothing has been run
on a real MEGA65 yet.

Rendering notes
---------------

- **Resolution and framing:** 640x200. The rays allow for the PAL pixel shape (1.875 times
  taller than wide).
- **Coordinates:** POV-Ray's, left-handed: the scene looks along +z.
- **Fixed point, not floating point.** A ray remembers the primitive it leaves: for that
  primitive, the root nearest zero is set to zero exactly, so the ray can't hit it again.
- **256 colours:** a palette made for the picture, with error diffusion.

Bundled tools
-------------

The repo root includes three Windows command-line tools that `build.bat` runs:

| Tool | Used for | Project | Source |
|---|---|---|---|
| `64tass.exe` (v1.60.3243) | Assembler | [64tass](https://tass64.sourceforge.net/) | [SourceForge](https://sourceforge.net/projects/tass64/) |
| `c1541.exe` (VICE 3.9) | Writes the D81 | [VICE](https://vice-emu.sourceforge.io/) | [GitHub mirror](https://github.com/VICE-Team/svn-mirror) |
| `petcat.exe` (VICE 3.6.1) | Tokenises the BASIC 65 programs (`src/basic/*.bas`, `-w65`) | [VICE](https://vice-emu.sourceforge.io/) | [GitHub mirror](https://github.com/VICE-Team/svn-mirror) |

These are separate projects by their own authors, distributed under the GNU GPL, and included
unmodified so that the project builds without installing anything else. Their licences apply to
them, not to this project. `src/lib/font8.asm` is cut from the IBM PC CGA ROM font (public
domain), by way of the MEGA65 template's `src/lib/tui/tui_font.asm`.

Note: this is a 45GS02 target. `STZ` stores the Z register, not zero. See
`docs/MEGA65_NOTES.md` for MEGA65 programming notes, and `.claude/CLAUDE.md` for the short
list of gotchas.
