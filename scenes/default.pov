// tinyraytracer's scene (ssloy/tinyraytracer), in renderer65's POV-Ray subset.
// The original is right-handed and looks down -z; here z is the other way round.

global_settings { max_trace_level 5 }
background { color rgb <0.2, 0.7, 0.8> }
camera { location <0, 0, 0>  look_at <0, 0, 1>  angle 89.34  right x*640/375 }

light_source { <-20, 20, -20>  color rgb 1 }
light_source { < 30, 50,  25>  color rgb 1 }
light_source { < 30, 20, -30>  color rgb 1 }

#declare Ivory = texture {
  pigment { color rgb <0.4, 0.4, 0.3> }
  finish { ambient 0 diffuse 0.9 phong 0.5 phong_size 50 reflection 0.1 }
}
#declare Glass = texture {
  pigment { color rgb <0.6, 0.7, 0.8> transmit 0.8 }
  finish { ambient 0 diffuse 0 phong 0.9 phong_size 125 reflection 0.1 }
}
#declare Rubber = texture {
  pigment { color rgb <0.3, 0.1, 0.1> }
  finish { ambient 0 diffuse 1.4 phong 0.3 phong_size 10 }
}
#declare Mirror = texture {
  pigment { color rgb 1 }
  finish { ambient 0 diffuse 0 phong 16 phong_size 1425 reflection 0.8 }
}

sphere { <-3,    0,   16>, 2  texture { Ivory } }
sphere { <-1,   -1.5, 12>, 2  texture { Glass }  interior { ior 1.5 } }
sphere { < 1.5, -0.5, 18>, 3  texture { Rubber } }
sphere { < 7,    5,   18>, 4  texture { Mirror } }

// the checkerboard: a thin slab, 20 x 20 units in 2-unit squares
intersection {
  plane { y, -4 }
  box { <-10, -4.1, 10>, <10, -3, 30> }
  pigment { checker color rgb 0.3, color rgb <0.3, 0.2, 0.1>  scale 2 }
  finish { ambient 0 diffuse 2 }
}
