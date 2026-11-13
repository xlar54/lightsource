TODO
====

Tested in Xemu only, bit-exact against the Python models. Not yet run on a real MEGA65. The
phases are in docs/DESIGN.md.

Done
----

- [x] Phase 1: the renderer core.
  - The scene read at run time.
  - Primitives: sphere, box, cylinder, cone, plane.
  - Booleans through interval lists, transforms, a camera that can turn.
  - Coloured lights, ambient light, a refractive index per material, checker pigments.
  - Bounding spheres.
- [x] Phase 2: the scene parser on the MEGA65, with overlays.
- [x] Phase 3: saving the picture as an IFF ILBM (8 planes, ByteRun1, aspect 8:15).
- [x] Phase 4, part 1: `lib/draw640.asm` (lines, rectangles, text, clipping).

Next
----

- [ ] Phase 4, part 2: the toolkit (resident):
  - GUI palette and mouse pointer (`hwsprite`, `mouse`);
  - an event loop with a debug event queue for the tests;
  - menu bar and drop-downs;
  - line editing at the status line;
  - number formatting and parsing.
- [ ] Phase 5: the modeller.
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

- [ ] The default scene takes 163 s, against 83 s for the old tracer that had the scene built
  in. Ideas:
  - cache each primitive's local ray origin for all the shadow rays from one point;
  - skip roots whose bound is beyond the light;
  - avoid the DMA copy of the primitive record for spheres;
  - turn macros into subroutines where the code is hot but called rarely.
- [ ] Profile on hardware.

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
