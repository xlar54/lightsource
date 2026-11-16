// Every primitive and boolean: a test scene for Lightsource.

global_settings { max_trace_level 3  ambient_light rgb 1 }
background { color rgb <0.1, 0.12, 0.2> }
camera { location <0, 5, -14>  look_at <0, 0.5, 0>  angle 75  right x*640/375 }

light_source { <-10, 15, -10>  color rgb <1, 0.95, 0.9> }
light_source { < 12, 8, -6>  color rgb <0.4, 0.45, 0.6> }

#declare Matt = finish { ambient 0.1 diffuse 0.8 phong 0.4 phong_size 30 }

plane { y, 0
  pigment { checker color rgb 0.8, color rgb 0.25  scale 2 }
  finish { ambient 0.1 diffuse 0.7 reflection 0.15 }
}

// a box with a ball cut out of its corner
difference {
  box { <-1.5, 0, -1.5>, <1.5, 3, 1.5> }
  sphere { <1.5, 3, -1.5>, 1.8 }
  pigment { color rgb <0.9, 0.3, 0.2> }
  finish { Matt }
  rotate y*30
  translate <-5, 0, 2>
}

// a cylinder through a sphere: only the overlap
intersection {
  sphere { <0, 1.6, 0>, 1.6 }
  cylinder { <0, 0, -2>, <0, 3.2, 2>, 1.1 }
  pigment { color rgb <0.2, 0.7, 0.3> }
  finish { Matt }
  translate <0, 0, 3>
}

// a cone, tipped over
cone { <0, 0, 0>, 1.2, <0, 2.5, 0>, 0.2
  pigment { color rgb <0.9, 0.8, 0.2> }
  finish { Matt }
  rotate z*-20
  translate <4.5, 0.2, 1>
}

// a glass ball and a mirror ball
sphere { <-1.8, 1, -4>, 1
  pigment { color rgb <0.7, 0.8, 0.9> transmit 0.85 }
  finish { ambient 0 diffuse 0 phong 0.9 phong_size 120 reflection 0.1 }
  interior { ior 1.5 }
}
sphere { <2, 1.2, -3.5>, 1.2
  pigment { color rgb 1 }
  finish { ambient 0 diffuse 0.05 phong 1 phong_size 400 reflection 0.8 }
}

// a merged pair of boxes, tilted
merge {
  box { <-0.5, 0, -0.5>, <0.5, 2.5, 0.5> }
  box { <-1.2, 1, -0.5>, <1.2, 1.6, 0.5> }
  pigment { color rgb <0.4, 0.5, 0.9> }
  finish { Matt }
  rotate <0, -40, 10>
  translate <0, 0, 7>
}
