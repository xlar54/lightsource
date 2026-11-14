renderer65
==========

A ray tracer for the MEGA65 that reads scenes written in a subset of POV-Ray's scene language.
It began as a port of [ssloy/tinyraytracer](https://github.com/ssloy/tinyraytracer). The plan
is a whole system on the MEGA65: a 640x200 graphical modeller, the scene language, rendering,
and saving the picture (see [docs/DESIGN.md](docs/DESIGN.md)).

What works now:
- **The scene language:** spheres, boxes, cylinders, cones, planes and prisms; `union`, `merge`,
  `intersection` and `difference`; `translate`, `rotate` and `scale`; checker and plain
  pigments; Phong finishes, reflection and refraction with a refractive index for each
  material; coloured lights, a camera that can turn, and `#declare`. The MEGA65 reads the
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

A 640x200 interface in 256 colours, used with the mouse and keyboard. It starts with
tinyraytracer's scene as its document.

- **Views:** top, front and side (orthographic) and the camera's (in perspective), all
  wireframes. The selected object is yellow, and a selected group shows all its parts.
  Lights are orange crosses; the camera is a green cross with a line to where it looks.
- **Object list** (top right): objects as an outline (a group's parts are indented under
  it), then the lights and the camera. Click one to select it.
  The box at the left of each object shows it in the views (filled) or hides it (empty):
  click the box to change it. A hidden group hides its parts (their names go grey), and
  hidden objects can't be picked in the views. Renders and previews still have them.
  It is saved with the document.
- **Properties** (bottom right): position, rotation (degrees), scale and sizes, and the
  material. Click a number to type a new one (RETURN takes it, ESC leaves it). Click the
  name to rename the object, or the material to step to the next one.
- **Click a view's name** (its top-left corner) to make it fill the whole view area; click
  the name again for the four views.
- **Mouse in the views:** click near an object's centre, a light or the camera to select it.
  Drag to move it in that view's plane.
- **Menus:**
  - **File:** New, Open, Save, Save as, Export POV, Preview, Render, Exit (back to BASIC,
    after Y: anything not saved is lost).
  - A menu, the Open list and typing on the status line put back what they covered when
    they close (saved in attic), so only commands that change something redraw the views.
  - **Edit:** Delete, Duplicate, Move up and down, Indent (into the group above),
    Outdent.
  - **Add:** the six primitives, a light, and the four booleans. A new boolean takes the
    selected object into itself.
  - **Material:** Next, Previous, New (a copy), Edit (the properties panel then shows the
    material).
  - **View:** zoom, reset.
- **Prisms** are the shape with points to edit. The selected prism has a handle on each
  corner in the top, front and side views (at its top). Click one to pick it (it fills
  in, and the panel shows its CX and CZ), and drag it to move it. I adds a corner half way
  to the next one, and DEL removes the picked corner. A prism has 3 to 16 corners. All the
  prisms in a document share a pool of 255 corners (in attic RAM), so there can be as many
  as the 32 objects allow. A new one is a house shape, 1 high.
- **`MEGA65.MDL`** on the disk is an example: the word in prisms (the A's and the 6's holes
  are boxes cut out with a Difference), glass balls, gold cones and a mirror ball. File,
  Open, then click `MEGA65`. It is made by `private/tools/make_mdl.py` (`scenes/mega65.mdl`).
- **Keys:** `+`/`-` zoom, DEL delete (the picked corner, or the selection), I add a
  corner, R render, P preview, S save.
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

- `build.bat` assembles everything with 64tass and writes `target/renderer65.d81`. The disk
  holds:
  - the program and its overlays;
  - every scene in `scenes/`, with `scenes/default.pov` also written as `SCENE.POV`.
- `run.bat` builds and starts Xemu.

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
| `DBG_GUITEST=1` | Draw the `draw640` test screen |

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
[scenes/default.pov](scenes/default.pov) and [scenes/shapes.pov](scenes/shapes.pov) are
examples. Every file the system accepts is also valid for POV-Ray itself. To frame a scene the
same way there, render at 640x375 with `right x*640/375`.

The limits:
- 32 primitives, 16 materials, 16 lights and 32 top-level objects.
- Booleans nested 7 deep.
- Numbers to 4 decimal places, below 32767.
- Keep everything within about 120 units of the camera.
- Only boxes can be scaled unevenly.
- A texture moves with its object wherever it is written.

Architecture
------------

One assembly makes the resident program and four overlays. `build.bat` writes each section
to its own file, and `tools/cut.py` trims each one. At boot the overlays are loaded into
attic; `ovl_load` copies one into the window at `$8000-$CFFF` when it's needed.

| Part | Files | What |
|---|---|---|
| Resident | `main.asm`, `scene.asm` | Boot, overlay manager, the compiled scene tables. Library: `system`, `dma`, `loader`, `kstream`, `fcm640`, `fixed`, `fixtrig`, `draw640`, `keyboard`, `mouse`, `hwsprite` |
| Overlay 0 | `render.asm`, `trace.asm`, `vars.asm` | Render loop and the tracer: intervals for each primitive, booleans, shading |
| Overlay 1 | `recolour.asm` | Median-cut palette and Floyd-Steinberg |
| Overlay 2 | `parse.asm`, `parse2.asm`, `parsev.asm` | The scene language: tokenizer, expressions, objects, transforms, materials, final compile |
| Overlay 3 | `save.asm` | IFF ILBM files |
| Overlay 4 | `model.asm`, `model2.asm`, `model3.asm`, `doctiny.asm` | The modeller: views, wireframes, list, properties, commands |
| Overlay 5 | `writer.asm` | The document as scene text; `.MDL` and `.POV` files; the Open dialog (the disk's directory) |
| Resident | `gui.asm`, `doc.asm`, `modelst.asm`, `modes.asm` | The toolkit (palette, pointer, events, menus, typing, numbers); the document; the modeller's lasting state; render and file commands |

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

Differences from tinyraytracer
------------------------------

- **Resolution and framing:** 640x200 instead of 1024x768. The rays allow for the PAL pixel
  shape (1.875 times taller than wide).
- **Coordinates:** POV-Ray's, left-handed: the scene looks along +z. The default scene's z is
  negated to match.
- **Fixed point instead of float.** A ray remembers the primitive it leaves: for that
  primitive, the root nearest zero is set to zero exactly, so the ray can't hit it again.
- **The board** is a thin slab (a plane intersected with a box) instead of a rectangle.
- **256 colours:** a palette made for the picture, with error diffusion.

Bundled tools
-------------

The repo root includes two Windows command-line tools that `build.bat` runs:

| Tool | Used for | Project | Source |
|---|---|---|---|
| `64tass.exe` (v1.60.3243) | Assembler | [64tass](https://tass64.sourceforge.net/) | [SourceForge](https://sourceforge.net/projects/tass64/) |
| `c1541.exe` (VICE 3.9) | Writes the D81 | [VICE](https://vice-emu.sourceforge.io/) | [GitHub mirror](https://github.com/VICE-Team/svn-mirror) |

These are separate projects by their own authors, distributed under the GNU GPL, and included
unmodified so that the project builds without installing anything else. Their licences apply to
them, not to this project. `src/font8.asm` is cut from the IBM PC CGA ROM font (public domain),
by way of `src/tui/tui_font.asm`.

Note: this is a 45GS02 target. `STZ` stores the Z register, not zero. See
`docs/MEGA65_NOTES.md` for MEGA65 programming notes, and `.claude/CLAUDE.md` for the short
list of gotchas.
