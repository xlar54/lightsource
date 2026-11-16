// Prisms: outlines in the x-z plane, extruded along y. A test scene for Lightsource.

global_settings { max_trace_level 3  ambient_light rgb 1 }
background { color rgb <0.1, 0.12, 0.2> }
camera { location <0, 6, -13>  look_at <0, 1, 0>  angle 70  right x*640/375 }

light_source { <-10, 15, -10>  color rgb <1, 0.95, 0.9> }
light_source { < 12, 8, -6>  color rgb <0.4, 0.45, 0.6> }

#declare Matt = finish { ambient 0.1 diffuse 0.8 phong 0.4 phong_size 30 }

plane { y, 0
  pigment { checker color rgb 0.8, color rgb 0.25  scale 2 }
  finish { ambient 0.1 diffuse 0.7 reflection 0.15 }
}

// a five-pointed star (not convex: a ray goes in and out more than once)
prism { linear_sweep linear_spline 0, 1, 11,
  <0, 2>, <0.47, 0.65>, <1.9, 0.62>, <0.76, -0.25>, <1.18, -1.62>,
  <0, -0.8>, <-1.18, -1.62>, <-0.76, -0.25>, <-1.9, 0.62>, <-0.47, 0.65>, <0, 2>
  pigment { color rgb <0.95, 0.75, 0.2> }
  finish { Matt }
  rotate y*15
  translate <-4, 0, 1>
}

// an L, standing up and turned
prism { 0, 0.8, 6, <0, 0>, <2, 0>, <2, 0.7>, <0.7, 0.7>, <0.7, 3>, <0, 3>
  pigment { color rgb <0.3, 0.6, 0.9> }
  finish { Matt }
  rotate x*-90
  rotate y*-30
  translate <0.5, 0, 2>
}

// a hexagonal nut: a prism with a hole (a difference)
difference {
  prism { -0.5, 0.5, 6, <1.6, 0>, <0.8, 1.39>, <-0.8, 1.39>, <-1.6, 0>, <-0.8, -1.39>, <0.8, -1.39> }
  cylinder { <0, -1, 0>, <0, 1, 0>, 0.7 }
  pigment { color rgb <0.8, 0.8, 0.85> }
  finish { ambient 0.05 diffuse 0.5 phong 0.9 phong_size 80 reflection 0.3 }
  rotate x*-60
  translate <4.2, 1.6, 0>
}

// an arrow, lying flat
prism { 0, 0.3, 7, <-1.5, -0.3>, <0.3, -0.3>, <0.3, -0.8>, <1.5, 0>, <0.3, 0.8>, <0.3, 0.3>, <-1.5, 0.3>
  pigment { color rgb <0.85, 0.2, 0.15> }
  finish { Matt }
  rotate y*-20
  translate <-0.5, 0, -4>
}