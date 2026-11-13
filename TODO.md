TODO
====

Tested in Xemu only (bit-exact against the Python models). Not yet run on a real MEGA65.

Real hardware
-------------

- [ ] Run it on a MEGA65. Things Xemu may not show:
  - the timing of the CPU, the divider and attic RAM (the trace is about 83 s in Xemu);
  - the Q-register flags (N and Z after `ldq`/`adq`/`sbq`);
  - whether the multiplier and divider results agree in every bit;
  - framebuffer 1 in `$20000-$3FFFF` after `rom_unprotect`.
- [ ] Check the pixel aspect on a real screen (the rays assume 1.875; Xemu shows 2.0).

Speed
-----

- [ ] Profile on hardware. The hot spots in Xemu were `fmul` (the call and copy overhead) and the
  sphere tests.
- [ ] Possible gains:
  - a dot-product routine that keeps one operand in MULTINA;
  - bounding tests before the full sphere test;
  - a table-based first guess for `fsqrt`.
- [ ] Trace coarse-to-fine (every 8th pixel first) for a faster first look.

Features
--------

- [ ] Keys after rendering: toggle between the preview and the final picture, start again.
- [ ] Show the render time on screen.
- [ ] Antialiasing (several rays a pixel). It costs time in proportion.
- [ ] Scene features that need code (the settings are in `src/scene.asm`):
  - a camera that can turn (a look-at direction);
  - a refractive index per material;
  - more planes, and a board square size;
  - coloured lights;
  - more spheres (the sphere tests are unrolled, about 850 bytes each: a loop would fit
    any number).
- [ ] More scenes, or the original's later chapters (the duck mesh, environment map).
- [ ] Choose a scene at run time: several scene files loaded at boot.
- [ ] Save the picture (IFF, or raw RGB to the SD card).
