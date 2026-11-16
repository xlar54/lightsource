TODO
====

Tested in Xemu only, bit-exact against the Python models. Not yet run on a real MEGA65. The
phases are in docs/DESIGN.md.

Done
----

- [x] Phase 1: the renderer core.
  - The scene read at run time.
  - Primitives: sphere, box, cylinder, cone, plane (and prism, on trial: see below).
  - Booleans through interval lists, transforms, a camera that can turn.
  - Coloured lights, ambient light, a refractive index per material, checker pigments.
  - Bounding spheres.
- [x] Phase 2: the scene parser on the MEGA65, with overlays.
- [x] Phase 3: saving the picture as an IFF ILBM (8 planes, ByteRun1, aspect 8:15).
- [x] Phase 4, part 1: `lib/draw640.asm` (lines, rectangles, text, clipping).

Next
----

- [x] Phase 4, part 2: the toolkit (palette, pointer, events with a test queue, menus,
  typing, numbers).
- [x] Phase 5: the modeller (see README). Tested in Xemu by injected events:
  - select (list and views), drag, type values, add objects;
  - preview; render (the final picture matches the models on every pixel);
  - save, new, open, export.
- [ ] Prisms (not committed yet, on trial): an outline of 3 to 16 corners, extruded. Done
  and tested in Xemu:
  - the tracer (concave outlines give interval lists): `scenes/prism.pov` matches the model
    on every pixel, and `default`, `shapes` and `parse1` still do;
  - the MEGA65 parser: its tables match `pov.py` byte for byte;
  - the modeller: Add, Prism; corner handles; pick, drag, insert (I), delete (DEL); the
    properties (H, and CX / CZ of the picked corner); duplicate; save / open; export. A
    render of an edited prism matched the models on every pixel.
  - The corners are a pool of 255 in attic (`.MDL` version 3; older files aren't read).
    Tested: 12 prisms in one document; corners added and removed in the first
    of several prisms (the others' corners move); duplicate, delete, save, open.
  - Not done: handles in the camera view; dragging the height; a mesh (triangles).

- [x] Lathes: a profile of 2 to 16 points in the corner pool, written as a merge of cones
  (tested in Xemu: added, a point dragged, rendered: the picture matched the models).

- [x] 64 primitives and 64 top-level objects (was 32): the records in attic (tested: a
  61-primitive scene's tables and every pixel matched the models).
- [x] The panel: 9 rows (8 pixels apart); B2 for the checker's second colour, No shadow for
  objects; Sq could not be clicked (the Checker toggle took its row).

- [x] Camera tools: Aim camera (A), Camera front / top / side, and turning the camera by
  dragging in the camera view.

- [x] Shaping with the mouse: SHIFT-drag turns, CTRL-drag scales, View, Snap (G); drags
  inside turned or scaled groups follow the pointer; a new group goes where the object it
  takes in was (it used to move it by (0, 0, 12)).
- [x] Blender-like start: the default camera up and back at (7, 5.5, -9) looking down at the
  origin, new objects at the origin, the views centred there at 10 pixels a unit.

- [x] 64 objects and 16 lights in a document (was 32 and 8). The document shares its bank-0
  memory with the compiled scene tables (a render parks it in attic first), which also
  freed about 1 KB. `.MDL` files are version 4 (`private/tools/mdl_v4.py` converts version
  3). Light numbers above 9 show properly in the list.
- [x] A grid in the flat views (View, Grid; spacing 0.25 .. 100 units by the zoom). It
  costs about 12 ms a redraw (JUGGLER 1149 -> 1161 ms, the empty default 204 -> 216 ms);
  `d6_vline` now steps through the framebuffer instead of plotting each pixel. Not in the
  camera view yet (a floor grid there needs lines clipped at the camera plane).
- [x] Prompts that explain: clicking a number in the panel asks with what it means
  ("Ref, reflection: 0 none, 1 a perfect mirror:"). The 42 lines (`src/modelhelp.asm`) ride
  in overlay 4's file past OVL_END, so they stay in attic and cost the window nothing.
  Clicking anywhere while a prompt waits cancels it, and the click then acts as usual.
- [x] `TIE.MDL`: a TIE fighter (37 objects) with a planet and stars on black.
- [x] Faster redraws, every pixel unchanged (the framebuffer compared byte for byte with the
  old code's after `private/tools/bench_redraw.py --dump`, for JUGGLER, TIE and the default):

  | Scene | Full redraw | A drag step |
  |---|---|---|
  | JUGGLER | 1161 -> 585 ms | 1098 -> 568 ms |
  | TIE | 1166 -> 638 ms | 1102 -> 621 ms |
  | The empty default | 216 -> 51 ms | 154 -> 38 ms |

  - `d6_fill` by DMA: a whole cell's rows are one fill, a part cell one fill down each column
    (step 8). `d6_hline` and `d6_vline` are one-row / one-column fills.
  - Circles and rings transform and project each point once (it was twice: each segment's
    two ends), and the flat views skip the coordinate they don't show.
  - `clip_line` draws at once when both ends are inside; `d6_line` then steps the pixel's
    address instead of clipping and addressing each pixel.
- [x] Room: the properties panel is overlay 6 (`modelpanel.asm`, with
  the help lines), reached through `ovl_far`; the grid moved from the resident part into
  overlay 4. Free now: overlay 4 3,349 bytes (was 39), the resident part 663 (was 91),
  overlay 6 about 16 KB. Every pixel of the benchmark screens unchanged; tested in Xemu by
  injected events: a value typed (the help prompt shown), a material click, No shadow, a
  prism corner's CX after picking it, and a value typed after a preview.
- [x] Spotlights (and `DESK.MDL`, lit only by a desk lamp's spotlight).
  - The scene language, the tracer and the models: `spotlight point_at radius falloff
    tightness` as in POV-Ray (`scenes/spot.pov`: tables and every pixel match the models).
    The scene's light record grew to 52 bytes; the parser's error messages moved past
    overlay 2's window (they stay in attic) to make room.
  - The modeller: Add, Spotlight; Spot in a light's panel with AX / AY / AZ, Rad, Fal,
    Tgt; the cone drawn in the views; the aim point dragged; View, Aim light...; the
    export. `.MDL` version 5 (lights 56 bytes; `private/tools/mdl_v5.py` converts version
    4); undo slots 16 KB.
  - Not done: the cone in the camera view when the light is behind the camera (lines with
    an end behind it are dropped).
- [ ] More redraw speed. What's left of a JUGGLER drag step (about 570 ms): transforming the
  points about 160 ms, projecting about 135, clipping and lines about 140, the rest (fills,
  `world_all`, the list) about 130. Ideas:
  - transform each point once for all four views (now once a view);
  - a flat view's projection folded into the object's matrix (2 multiplies a point fewer);
  - fewer circle segments for objects that are small on screen (changes the picture).

Modeller: still to do
---------------------

- [ ] The mouse on real hardware, and in Xemu by hand (only injected events have been tested).
- [ ] Dragging an object inside a transformed group moves it in the group's frame, not the
  view's.
- [x] The list's scroll bar (page clicks, dragging the thumb; tested in Xemu by injected events).
- [x] Undo and redo: 16 snapshots of the document in attic (tested in Xemu: add, delete,
  drag, typed values, hiding; redo dropped by a new change).
- [ ] Rotate and scale by dragging (keys or handles).
- [ ] Editing lights' colours and the background as colours (now three numbers each).
- [x] File, Open: a list of the disk's `.MDL` files (tested in Xemu by injected events:
  scrolling, picking with a click and with the keys, Name..., Cancel, ESC).
- [x] Menus, the Open list and the status-line prompt restore what was under them instead
  of redrawing the screen (tested: the screen after all of them matches one without them).
- [x] File, Exit (back to BASIC through kstream; tested in Xemu: READY. comes back).
- [x] Show / hide each object in the views (a box in the list; tested in Xemu: hiding a group hides its parts, hidden objects aren't picked).
- [x] Picking in the views prefers the selection when it is within reach (dragging a union
  picked in the list grabbed a part at its centre instead). Tested in Xemu: a union with a
  box at its centre, dragged 20 pixels: the union moved 2 units, the box's own position
  stayed 0. Also fixed: a click on nothing in a flat view selected the object numbered as
  the view (an anonymous + label caught the branch). Overlay 4 has about 55 bytes left.
- [x] Indent and Outdent keep the object where it is (they moved it
  when the group was moved, turned or scaled). Tested in Xemu: a sphere taken out of a
  union at (3, 0, 0), turned 30 about y, scaled 2, then put back: its world matrix the
  same, bit for bit, both ways, and its numbers back to (1, 2, 3), 0, 1. Overlay 4 has
  about 80 bytes left; the arctangent is in overlay 6 (`fatan2`).
- [ ] Hidden objects left out of renders, previews and exports too (the same box; not
  committed yet). Tested in Xemu: a hidden union and its box left out; a union whose only
  part is hidden left out; nothing hidden, the text as before.
- [ ] Save as: the same list, to pick a name to replace (now typed only).
- [ ] File, Render POV...: render a `.POV` file from the disk (the parser and tracer can).
- [ ] Reading `.POV` files into the modeller (at least the ones it writes itself).
- [ ] A material list to pick from (now Next / Previous).
- [x] Material files: Material, Save to file... / Load from file...
  (`NAME.MAT`: "R65T", version 1, the 80-byte record; `src/matfile.asm`, overlay 5), and
  15 starter materials on the disk. Tested in Xemu by injected events: the list, a load
  (the selected object takes it), save under a new name and load that back, undo, ESC
  (no undo step left behind), File, Open unchanged.
- [x] The material editor: its own screen (overlay 7) with a preview
  ball traced small by the real tracer, the fields grouped, colour swatches, numbers dragged
  or typed, presets, Done / Cancel. Tested in Xemu by injected events: the screen and
  preview, a preset, a drag, a typed value, the checker toggle, Done, Cancel (the material
  back as it was), Material, New into the editor, and a render after (every pixel
  matched the models).
  - Ideas: a bigger preview; a colour picker; the editor for lights' colours too.

Was in the plan (kept for reference)
------------------------------------

- [ ] Phase 5 as planned:
  - The document: objects with a depth (an outline tree), materials, lights, camera. Plain
    resident tables, about 3.6 KB.
  - Overlay 4:
    - top, front, side and camera wireframe views;
    - the object list and the properties panel;
    - selecting, dragging, number entry;
    - menus: Add, Edit, Material, View.
  - Overlay 5:
    - the POV-Ray writer, into TEXT_BUF, then parsed by the real parser;
    - document save and load (`.MDL`, binary);
    - exporting `.POV`;
    - file name entry.
  - Render and preview take over the whole screen; a key returns to the modeller. The
    preview is a quick render: fewer pixels, depth 1.
  - The boot order: start in the modeller, with tinyraytracer's scene as the document. Keep
    the render-at-boot flow for the tests.
- [ ] Phase 6: animation: `clock` exists in the parser. Keyframes in the modeller; render N
  frames to attic and disk; a playback palette for all the frames together.

Speed
-----

- [x] Faster tracing, every picture unchanged (bit-exact against the models). In Xemu the
  default scene went from 164 s to 133 s (-19%), shapes.pov 236 s to 201 s (-15%),
  prism.pov 311 s to 267 s (-14%), parse1.pov 386 s to 304 s (-21%):
  - the records copied to chip RAM once per render, the shape before R, so an unrotated
    primitive copies 32 bytes instead of 68;
  - tight bounds: each primitive's extent along x, y and z, not a sphere's (the
    checkerboard's bound went from radius 24.6 to 14.2);
  - `SKIP`: an intersection or difference skips its next part when the list so far is
    empty (the checkerboard's box for every ray going up);
  - each light tries the root that last blocked it first;
  - a sphere's and a bounding sphere's `c - o` and `L.L` kept per ray origin;
  - `fmul` returns the product directly when both are positive.
- [ ] More speed. Measured costs (default scene): `fmul` about 20% (16 million calls), the
  checkerboard's box (6 divisions a test) and its boolean about 15%, the record DMA 5%. Ideas:
  - a box test with one division per axis (changes the rounding: the model too);
  - a box-shaped bound for flat roots (a sphere round a 20 x 1 x 20 slab covers the screen);
  - fewer Newton steps in `fsqrt` (a better first guess gives the same result);
  - DMA for the frame push / pop and the light record copy.
- [ ] Profile on hardware (attic DMA is slower there than in Xemu).

Real hardware
-------------

- [ ] Run it on a MEGA65. Things Xemu may not show:
  - the timing of the CPU, the divider and attic RAM;
  - the Q-register flags;
  - kstream after the takeover: it's documented as hanging HYPPO from a custom MAP on
    hardware, but kstream uses the boot MAP, so it should be fine;
  - whether the DOS uses `$C000-$C3FF`: the parser reloads its overlay after reading, and the
    save overlay stays below `$C000`.
- [ ] Check the pixel aspect on a real screen (the rays assume 1.875).

Scene language
--------------

- [ ] Named colours (`colors.inc`), `#include`.
- [ ] Area lights (spotlights: done).
- [ ] `clipped_by`, `inverse`, open cylinders and cones.
- [ ] A torus (a quartic: hard in 16.16).
- [ ] More patterns (gradient, bozo needs noise).
