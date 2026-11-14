renderer65 system design
========================

The goal: a scene modeller, a POV-Ray-style scene language and the ray tracer, all running on
the MEGA65. You build a scene in a 640x200 graphical modeller (primitives, booleans, lights,
materials, wireframe views and a quick preview), save it as a text scene file, render it at
640x200 in 256 colours and save the picture to disk. Animation comes later.

This file is the plan and the contract between the parts. `README.md` describes what exists.

Phases
------

| Phase | What | Status |
|---|---|---|
| 1 | Renderer core: the scene read at run time from compiled tables; primitives (sphere, box, cylinder, cone, plane); transforms; booleans; a camera that can turn; coloured lights; a refractive index for each material | done |
| 2 | Scene parser on the MEGA65: the scene language below, read from disk with `kstream` | |
| 3 | Saving the picture: IFF ILBM | done |
| 4 | `draw640` (drawing into the 640x200 framebuffer) and the graphical toolkit | done |
| 5 | The modeller | first version |
| 6 | Animation | |

Each phase is tested the way the tracer is now: a Python model gives the bit-exact expected
result, and a headless Xemu run is compared against it.

The scene language
------------------

A subset of POV-Ray's scene description language. **Every file the system accepts is also a
valid POV-Ray file**, so POV-Ray itself can render it for comparison. The geometry and
framing then match; the shading is close but not the same (see "Lighting").

Coordinates are POV-Ray's, left-handed: +x right, +y up, +z into the screen.

```pov
// comments, and /* block comments */
#declare Name = 1.5;                   // floats, vectors, colours, textures, pigments,
#declare V = <1, 2, 3> * 2;            // finishes and objects can be declared
global_settings { max_trace_level 4  ambient_light rgb <1, 1, 1> }
background { color rgb <0.2, 0.7, 0.8> }
camera { location <0, 0, 0>  look_at <0, 0, 1>  angle 89.13 }
light_source { <-20, 20, -20>  color rgb <1, 1, 1>  [shadowless] }

sphere   { <x, y, z>, r  modifiers }
box      { <x1, y1, z1>, <x2, y2, z2>  modifiers }
cylinder { <base>, <cap>, r  modifiers }
cone     { <base>, r1, <cap>, r2  modifiers }
plane    { <normal>, d  modifiers }                  // the solid half-space below
prism    { [linear_sweep] [linear_spline] h1, h2, n, <x1, z1>, ... <xn, zn>  modifiers }
                                // an outline in x-z (3 to 16 corners), from y = h1 to h2
union        { object object ...  modifiers }
merge        { object object ...  modifiers }        // union without the inner surfaces
intersection { object object ...  modifiers }
difference   { object object ...  modifiers }        // the first minus all the others
object       { Declared_Object  modifiers }

modifiers:
  texture  { pigment { ... }  finish { ... } }   or a declared texture
  pigment  { color rgb <r, g, b> }  { color rgbt <r, g, b, t> }  { color rgb <...> transmit t }
  pigment  { checker color rgb <...>, color rgb <...>  [scale s] [translate v] }
  finish   { ambient a  diffuse d  phong p  phong_size n  reflection r  specular s  roughness q }
  interior { ior n }
  translate <v>   rotate <degrees about x, then y, then z>   scale s   scale <sx, sy, sz>
  no_shadow
```

Expressions: numbers, `+ - * /`, unary minus, brackets, vectors `<a, b, c>` (and 4- or
5-component colours), a number where a vector is wanted (`rgb 1` = `<1, 1, 1>`), the
axis names `x`, `y` and `z`, declared names, the functions `sin cos sqrt abs`, `pi`, and
`clock` (for animation). Anything outside the subset is an error with the line number, never
silently ignored.

Defaults are POV-Ray 3.7's: `ambient 0.1`, `diffuse 0.6`, `phong 0`, `phong_size 40`,
`reflection 0`, `ior 1.0`, `max_trace_level 5` (the renderer stops at 4), camera at the
origin looking along +z.

Numbers are 16.16 fixed point: up to 4 decimal places count, and every value must stay
below 32767. Keep the scene within about 120 units of the camera.

### Rules the renderer imposes

- Spheres, cylinders, cones and planes may be scaled only uniformly. A box may be scaled
  along its own axes before it is rotated (anything that would shear it is an error).
- `open` cylinders and cones aren't supported (they aren't solids).
- A prism is `linear_sweep linear_spline` only, with 3 to 16 corners (255 points in a scene,
  counting one more per prism for closing it). A
  last point that repeats the first is dropped: the outline is closed anyway. It may be
  concave or cross itself (inside means an odd number of edges crossed). Like a box, it
  may be scaled along its own axes.
- A texture is transformed with its object, whether it comes before or after the
  transforms. POV-Ray only transforms textures given before the transforms, so the
  modeller always writes the texture first.
- `checker` is the only pattern. `filter` is treated as `transmit`.
- `color` on a light is any colour; there is no fall-off, spotlight or area light.

### Lighting

The local colour is tinyraytracer's Phong model, with POV-Ray's names for the weights:

    colour = pigment * (ambient * ambient_light + diffuse * sum(light * max(0, N.L)))
           + phong * sum(light * max(0, R.V) ^ phong_size)
           + reflection * reflected + transmit * refracted

`specular s roughness q` is read as `phong s phong_size 1/q`. Each pixel is scaled so its
brightest channel is at most 255, as in tinyraytracer.

The screen
----------

640x200, shown on a PAL display where a pixel is 1.875 times taller than it is wide: the
picture is 640:375, about 16:9.4. `angle` is the horizontal field of view across the 640
pixels. To make POV-Ray frame a scene the same way, render it at 640x375 with
`right x*640/375`.

The compiled scene
------------------

The parser turns the text into tables in bank 0, which the tracer reads directly. The
Python model builds the same tables bit for bit.

**Primitive record** (128 bytes each, up to 32):

| Offset | Size | What |
|---|---|---|
| 0 | 1 | type: 0 sphere, 1 box, 2 cylinder, 3 cone, 4 plane, 5 prism |
| 1 | 1 | flags: bit 0 rotated (R isn't the identity), bit 1 no_shadow |
| 2 | 1 | material |
| 4 | 12 | c: the local origin (sphere centre, box centre, cylinder/cone middle, a point on the plane) |
| 16 | 36 | R: the local x, y, z axes in world coordinates (rows). local = R (p - c) |
| 52 | 16 | shape: sphere r², 1/r, r; box half sizes; cylinder r², h, 1/r; cone a, b, h, 1/sqrt(1+b²); prism h, (first point, corners), orientation (±1) |
| 68 | 36 | texture matrix: the inverse of the object's transform, with the pigment's own transform |
| 104 | 12 | texture offset |
| 116 | 12 | bounding sphere: centre (radius² in the root table) |

In local coordinates: the sphere is centred on the origin; the box is `|x| <= hx`, `|y| <= hy`,
`|z| <= hz`; the cylinder is `x² + z² <= r²`, `|y| <= h`; the cone is
`x² + z² <= (a + b y)²`, `|y| <= h` (radius `r1` at `y = -h`, `r2` at `y = +h`); the plane is
the half-space `y <= 0`; the prism is `|y| <= h` inside its outline.

**Prism points** (in attic at `$8300800`, up to 255 x 8 bytes: the tracer copies a prism's
by DMA when it tests it): x and z of each corner, already scaled. Each outline is stored closed (its first corner again at the end), so edge k runs
from point k to k + 1. The orientation is the sign of the outline's area: it turns each
edge's `(ez, -ex)` into the outward normal.

**Material record** (64 bytes, up to 16): diffuse, phong, reflection, transmit; colour;
second colour (checker); ambient (already multiplied by `ambient_light`); phong_size; flags
(bit 0 checker); 1/ior, 1/ior², ior, ior².

**Objects:** a list of roots. A root is a primitive, or a boolean tree written as a postfix
program: `PRIM n`, `UNION`, `INTER`, `DIFF`, `END`. Unions at the top level are flattened
into separate roots, because they keep their inner surfaces.

**Lights** (up to 16): position, colour, flags (shadowless). **Global:** background,
camera (position, right, up and forward vectors already scaled for the field of view),
`max_trace_level`.

The tracer
----------

- **Rays** are transformed into each primitive's local frame: `o' = R (o - c)`, `d' = R d`.
  R is orthonormal, so `t` is the same in both frames and no precision is lost to scaling.
  Unrotated primitives skip the multiplications.
- **A root that is a primitive** gives its nearest hit beyond EPS directly.
- **A boolean root** is evaluated as interval lists along the ray. Each primitive but the
  prism is convex, so it gives one interval (or none; a plane gives a half-line). One sweep routine combines
  two lists for union, intersection and difference, tracking whether the ray is inside A and
  inside B. Surfaces taken from the subtracted object get flipped normals. A list holds up
  to 8 intervals.
- **A prism** may be concave, so it gives a list of its own (a root that is one prism goes
  through the list path too). The ray's line crosses the outline's edges at sorted `t` (an
  edge holds its start point, not its end); each pair of crossings is a stretch inside,
  narrowed to the slab `|y| <= h`. A ray along the axis is inside all along the slab, or
  not at all (an odd count of crossings ahead along x). Each edge costs one division and
  six multiplications.
- **Self-hits:** a ray remembers the primitive it leaves. For that primitive, the root
  nearest zero is set to exactly zero, so it can't be hit again through rounding. This is
  the same idea as the current `2 tca`, made general.
- **Shadows:** any surface between EPS and the light's distance. `no_shadow` objects are
  skipped.
- **Bounding spheres** for every root reject rays cheaply before the real tests.

Programs and memory
-------------------

One program, `RENDERER65`, with two modes: the modeller and the renderer. When the code no
longer fits below `$C000`, it moves into overlays loaded into attic at boot and copied into
an overlay window by DMA (the `deluxepaint65` pattern). Until the modeller exists, the
program renders `SCENE.POV` from the disk at boot and saves `SCENE.IFF`.

| Area | What |
|---|---|
| `$2001`-`$BFFF` | Program, variables and the compiled scene tables |
| `$0800`, `$C000` | The two 4000-byte screen RAMs (`fcm640`) |
| `$12000`-`$13F3F` | The modeller's screen RAMs (`fcm640`) |
| `$14000`-`$1EFFF` | The scene file's text while it is parsed (44 KB), and `.MDL` files while they load |
| `$20000`-`$3F3FF` | Framebuffer 1: the final picture |
| `$40000`-`$5F3FF` | Framebuffer 0: the preview while rendering; the modeller's screen |
| `$8000000` | The 24-bit picture (384,000 bytes) |
| `$8060000` | Recolouring's work areas |
| `$8300000` | The modeller's corner pool (255 corners), the scene's prism points (`$8300800`), room for moving corners (`$8301000`) |
| `$8100000`... | Modeller: saved screen areas, undo, the scene being edited |
| `$8200000`... | Animation frames (128,000 bytes each) |

Files on disk are SEQ: `NAME.POV` for scenes and `NAME.IFF` for pictures: an ILBM with 8
bitplanes, ByteRun1 compression, a 256-colour CMAP, a hi-res CAMG and a BMHD aspect of 8:15,
which carries
the 1.875 pixel aspect.

The modeller
------------

A 640x200 graphical interface in 256 colours, with the mouse as a hardware sprite and an
8x8 font. Entries 0-15 of the palette are for the interface, and 16-231 are a 6x6x6 cube for
the preview. A finished render is shown full screen with its own palette.

```
+--------------------------------------------------------------------------------+
| File  Edit  Add  View  Render  Help                                            |
+-------------------------------+-------------------------------+----------------+
| Top (x, z)                    | Front (x, y)                  | Objects        |
|                               |                               |  Board         |
|                               |                               |  Ivory ball    |
+-------------------------------+-------------------------------+  Difference    |
| Side (z, y)                   | Camera (wireframe / preview)  |    Box         |
|                               |                               |    Sphere      |
|                               |                               +----------------+
|                               |                               | Properties     |
+-------------------------------+-------------------------------+----------------+
```

- **Views:** top, front and side, orthographic, with zoom and pan; the camera view in
  perspective. Primitives are drawn as their outlines: circles for spheres, edges for boxes,
  rings and lines for cylinders and cones, a grid for planes, the outline at the top and
  bottom for prisms. Boolean parts show all their
  pieces, the selected object highlighted.
- **Editing:** click to select; drag to move in a view's plane; keys or handles for rotating
  and scaling; number entry in the properties panel. Add primitives, booleans and lights from
  the Add menu; group the selection into a boolean; edit materials in a dialog.
- **Preview:** the tracer at low resolution with fewer bounces, in the camera view, in a few
  seconds.
- **Files:** it writes the scene language (texture before transforms, numbers to 4 decimal
  places) and reads it back with the same parser.

Animation (later)
-----------------

The scene language has `clock` (0 to 1 across the animation). The modeller sets keyframes on
an object's position, rotation, scale and colour, and writes them as expressions in `clock`.
The renderer parses the scene once for each frame, renders it, and either saves each frame
(`NAME001.IFF`, ...) or keeps it in attic for playback. A playback palette made for all the
frames together avoids flicker between them.

Testing
-------

- `private/tools/pov.py`: the scene language in Python. It parses a file into the compiled
  tables bit for bit, as the MEGA65 parser does, and can write them as an asm include for a
  test build.
- `private/tools/ref_trace.py`: the tracer model, bit-exact, reading the compiled tables.
- `private/tools/rt_test.py`: boots the D81 in headless Xemu, dumps memory, and compares the
  compiled tables, the framebuffers and the palette with the models.
