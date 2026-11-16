// Spheres: five balls in an arc on a tiled floor at dusk (glass, gold, jade, chrome, coral).
// Lightsource's text test scene; the same as SPHERES.MDL (private/tools/make_mdl.py spheres).

global_settings { max_trace_level 4 }
background { color rgb <0.36, 0.3, 0.55> }
camera { location <0.5, 4, -10> look_at <0, 1.1, 0.5> angle 52 right x*640/375 }
light_source { <-12, 14, -9> color rgb <1, 0.9, 0.78> }
light_source { <14, 6, -6> color rgb <0.3, 0.36, 0.5> shadowless }
#declare M1 = texture { pigment { checker color rgb <0.78, 0.36, 0.22>, color rgb <0.92, 0.86, 0.72> scale 2 } finish { ambient 0.1 diffuse 0.75 phong 0.2 phong_size 20 reflection 0.12 } }
#declare M2 = texture { pigment { color rgb <0.7, 0.8, 0.85> transmit 0.85 } finish { ambient 0 diffuse 0.05 phong 0.9 phong_size 125 reflection 0.1 } }
#declare M3 = texture { pigment { color rgb <0.9, 0.7, 0.2> transmit 0 } finish { ambient 0.1 diffuse 0.6 phong 0.8 phong_size 80 reflection 0.3 } }
#declare M4 = texture { pigment { color rgb <0.25, 0.62, 0.42> transmit 0 } finish { ambient 0.1 diffuse 0.75 phong 0.7 phong_size 70 reflection 0.05 } }
#declare M5 = texture { pigment { color rgb <0.8, 0.82, 0.86> transmit 0 } finish { ambient 0.05 diffuse 0.25 phong 1 phong_size 200 reflection 0.65 } }
#declare M6 = texture { pigment { color rgb <0.95, 0.42, 0.38> transmit 0 } finish { ambient 0.12 diffuse 0.8 phong 0.4 phong_size 30 reflection 0 } }
plane { y, 0 texture { M1 } }
sphere { <0, 0, 0>, 1.6 texture { M2 } interior { ior 1.5 } translate <0, 1.6, 1.8> }
sphere { <0, 0, 0>, 0.9 texture { M3 } translate <-3.4, 0.9, 0.6> }
sphere { <0, 0, 0>, 0.65 texture { M4 } translate <-1.7, 0.65, -2.1> }
sphere { <0, 0, 0>, 1.15 texture { M5 } translate <3.3, 1.15, 1.2> }
sphere { <0, 0, 0>, 0.55 texture { M6 } translate <1.6, 0.55, -2.4> }
