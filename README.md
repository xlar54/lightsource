renderer65
==========

A ray tracer for the MEGA65, after [ssloy/tinyraytracer](https://github.com/ssloy/tinyraytracer).
It renders that project's scene: an ivory, a glass, a red rubber and a mirror sphere above a
checkerboard, with three point lights, shadows, Phong highlights, reflections and refraction.
The picture is 640x200 in 256 colours.

It works in two passes:

1. **Trace** (about 83 s in Xemu). Every pixel is traced in 16.16 fixed point. Its 24-bit
   colour is kept in attic RAM, and it is shown as it is drawn, ordered-dithered to a fixed
   6x7x6 colour cube.
2. **Recolour** (about 9 s). A median-cut palette of 254 colours is made for the whole
   picture. The picture is Floyd-Steinberg dithered to it in the second framebuffer, and both
   are switched in at one vertical blank.

Build
-----

Run `build.bat`. It assembles `src/main.asm` with 64tass and writes `target/renderer65.d81` with
c1541. There are no assets: the scene is in `src/scene.asm`.

For a test build, set `M65DEFS` first, for example `set M65DEFS=-D DBG_ROWS=8 -D DBG_PASS2=0`
(trace 8 lines, skip the recolouring).

Run
---

`run.bat` builds the project and starts Xemu with `-autoload`. On a real MEGA65, mount the D81
and run it; `AUTOBOOT.C65` starts it automatically. There are no controls. When the picture is
finished it stays on screen; reset to leave.

Editing the scene
-----------------

The whole scene is the settings at the top of [`src/scene.asm`](src/scene.asm). Change them,
run `build.bat`, then `run.bat` (or test it, below). Each setting is one `NAME = value` line:

| Setting | What |
|---|---|
| `SPH_C`, `SPH_R`, `SPH_M` | Sphere centres `(x, y, z)`, radii, materials: one entry per sphere in each list |
| `LIGHTS` | Point lights `(x, y, z)`, all white and equally bright |
| `MAT_AL`, `MAT_DC`, `MAT_SE` | Materials. `MAT_AL` = `(diffuse, specular, reflection, refraction)` weights, `MAT_DC` = diffuse colour `(r, g, b)` from 0 to 1, `MAT_SE` = highlight sharpness (bigger is tighter) |
| `M_IVORY` ... | Names for the material positions in those lists (0, 1, 2, ...) |
| `IOR` | Refractive index of every material with a refraction weight (1.5 = glass) |
| `PLANE_ON`, `PLANE_Y`, `PLANE_XMAX`, `PLANE_ZMIN`, `PLANE_ZMAX` | The checkerboard: on/off, height, and extent (`-XMAX < x < XMAX`, `ZMIN < z < ZMAX`) |
| `CHECK_A`, `CHECK_B`, `M_PLANE` | The two square colours, and the material whose weights the board uses |
| `BG` | Sky colour |
| `CAM`, `FOV` | Camera position, vertical field of view in radians |
| `MAXDEPTH` | Reflection / refraction bounces, 0 to 4 |

Coordinates are the original's: +x is right, +y up, and the camera looks down -z (the
spheres are at z = -12 to -18).

**To add a sphere,** add an entry to each of `SPH_C`, `SPH_R` and `SPH_M`.

**To add a material:**
1. Give it a name with the next number, for example `M_GREEN = 5`.
2. Add an entry to each of `MAT_AL`, `MAT_DC` and `MAT_SE`.

The build counts the lists itself. It stops with a message if they don't match or a limit is
passed.

For example, this green sphere sits in front of the red one:

```
SPH_C   = [..., (4.5, -2.5, -11.0)]
SPH_R   = [..., 1.5]
SPH_M   = [..., M_GREEN]
M_GREEN = 5
MAT_AL  = [..., (1.2, 0.6, 0.0, 0.0)]       ; matt, with a highlight
MAT_DC  = [..., (0.1, 0.5, 0.15)]
MAT_SE  = [..., 30]
```

**Material recipes**, as albedo `(diffuse, specular, reflection, refraction)`:

| Look | Albedo |
|---|---|
| Matt colour | `(1.4, 0.3, 0.0, 0.0)` (the red rubber) |
| Shiny colour | `(0.9, 0.5, 0.1, 0.0)` (the ivory) |
| Mirror | `(0.0, 16.0, 0.8, 0.0)` with exponent 1425 |
| Glass | `(0.0, 0.9, 0.1, 0.8)` |

Each picture is scaled so that its brightest channel is 255. A very bright highlight
therefore darkens the rest of the picture, as in the original.

**Limits:**
- **Spheres:** about 16. Each one adds about 850 bytes of code, and the program must end below
  `$C000`. The build says so if it doesn't fit.
- **Other counts:** 20 lights and 8 materials.
- **Distances:** keep things within about 120 units of each other. The maths is 16.16 fixed point:
  the largest value is 32767, and squared distances must fit.
- **What's fixed in the code:**
  - the camera always looks down -z;
  - there is one refractive index for all materials;
  - the board's squares are 2 units;
  - there is no more than one plane.
- **Time:** it grows with the work. The default scene takes about 83 s; the 5-sphere example above
  takes 116 s.

**Testing an edit:** `private/tools/ref_trace.py` reads the same lines from `scene.asm`, so
there is nothing else to change. `python private\tools\ref_trace.py fixed private\temp\look.png`
shows the picture in a few seconds, without the MEGA65: look at `look_4x3.png`.
`python private\tools\rt_test.py --want 2` checks the MEGA65 build against it.

Architecture
------------

| File | What |
|---|---|
| `src/main.asm` | Boot, takeover, the render loop (pixel -> attic RGB -> cube dither), timing (`ticks_render`, `ticks_recolour`, in frames) |
| `src/lib/fixed.asm` | New library module: 16.16 maths on the 45GS02's 32-bit Q register: `fmul` (signed, from the unsigned hardware multiplier), `fdiv` and `fsqrt` (Newton iteration on the hardware divider), `ppow` (in 0.32), vector macros |
| `src/scene.asm` | Spheres, lights, materials, written as 64tass expressions (`FX(0.4)`) |
| `src/trace.asm` | `cast` (recursive, with its own frame stack), the scene and shadow intersections, refraction, primary rays |
| `src/recolour.asm` | Histogram, median cut, palette means, Floyd-Steinberg with a lazily filled inverse colour map |
| `src/lib/fcm640.asm` | New library module: 640x200 Full Colour Mode with two framebuffers |

Library modules used: `system`, `dma`, `fcm640`, `fixed`.

**Memory:**

| Area | What |
|---|---|
| `$40000-$5F3FF` | Framebuffer 0 (the trace and its preview) |
| `$20000-$3F3FF` | Framebuffer 1 (the recoloured picture), after `rom_unprotect` |
| `$0800`, `$C000` | The two 4000-byte screen RAMs. The program must end below `$C000` |
| `$8000000` | The 24-bit image, 384,000 bytes (attic) |
| `$8060000`... | Recolouring: histogram, colour list, box map, inverse map (attic) |

**Testing:** `private/tools/ref_trace.py` is a bit-exact Python model of the fixed-point tracer,
and `private/tools/ref_palette.py` models the recolouring. `private/tools/rt_test.py` boots the
D81 in headless Xemu, waits for the render, dumps memory and compares both framebuffers and the
palette with the models. All 128,000 pixels and all 254 palette entries match.

Differences from the original
-----------------------------

* **Resolution and framing:** 640x200 instead of 1024x768. The rays allow for the display's
  pixel shape: a pixel is 1.875 times taller than wide on a 4:3 PAL screen. The vertical field
  of view is the original's 60 degrees, so the 16:10 picture shows a little more at the sides.
* **Fixed point instead of float.** Results match the float version to within 8/255 on all but
  313 of the 128,000 pixels; the rest are on the glass sphere's edges.
* **Rays don't hit the surface they leave.** The original avoids that with a 0.001 epsilon,
  which in fixed point left speckles on the glass and the mirror. Here each ray remembers its
  object: for that sphere the far root is `2 tca` exactly, and the plane is skipped.
* **Less work, same picture:**
  * reflection and refraction rays are traced only when the material's albedo needs them;
  * shadow rays are skipped when the light would add nothing;
  * reflected and refracted directions are not normalised again (they are already unit length);
  * the sphere normal is `(p - c) / r`.
* **256 colours:** a palette made for the picture, plus error diffusion, instead of 24-bit colour.

Bundled tools
-------------

The repo root includes two Windows command-line tools that `build.bat` runs:

| Tool | Used for | Project | Source |
|---|---|---|---|
| `64tass.exe` (v1.60.3243) | Assembler | [64tass](https://tass64.sourceforge.net/) | [SourceForge](https://sourceforge.net/projects/tass64/) |
| `c1541.exe` (VICE 3.9) | Writes the D81 | [VICE](https://vice-emu.sourceforge.io/) | [GitHub mirror](https://github.com/VICE-Team/svn-mirror) |

These are separate projects by their own authors, distributed under the GNU GPL, and included
unmodified so that the project builds without installing anything else. Their licences apply to them,
not to this project.

Note: this is a 45GS02 target. `STZ` stores the Z register, not zero; use `LDA #0 / STA`. See
`docs/MEGA65_NOTES.md` for MEGA65 programming notes, and `.claude/CLAUDE.md` for the short
list of gotchas.

`tools/` holds only the scripts the build needs (none are used yet). `private/` is gitignored. It
holds local notes, the library examples, the test tools and models, temporary data and the MEGA65
book, so none of them are published.
