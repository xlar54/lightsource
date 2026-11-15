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
- [ ] Redraws are slow: JUGGLER.MDL (30 objects) takes 1.1 s for the views, the list and the
  panel, and 1.06 s for the views alone (each step of a drag). `private/tools/bench_redraw.py`
  measures it.

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
- [x] Show / hide each object in the views (a box in the list; tested in Xemu: hiding a group hides its parts, hidden objects aren't picked, the export still has them).
- [ ] Hide objects from renders too (a second box, or a menu item).
- [ ] Save as: the same list, to pick a name to replace (now typed only).
- [ ] File, Render POV...: render a `.POV` file from the disk (the parser and tracer can).
- [ ] Reading `.POV` files into the modeller (at least the ones it writes itself).
- [ ] A material list to pick from (now Next / Previous).

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
- [ ] Spotlights, area lights.
- [ ] `clipped_by`, `inverse`, open cylinders and cones.
- [ ] A torus (a quartic: hard in 16.16).
- [ ] More patterns (gradient, bozo needs noise).
