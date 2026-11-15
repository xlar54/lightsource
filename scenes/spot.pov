// Spotlights: three coloured cones on a checkered floor, with a soft one from behind.
// Tests the cone (radius, falloff), tightness, a hard edge (radius = falloff), a
// shadowless spot and a translated spot (point_at moves with it).

global_settings { max_trace_level 2  ambient_light rgb 0.15 }
background { color rgb <0.05, 0.05, 0.1> }
camera { location <0, 6, -14>  look_at <0, 0, 2>  angle 70 }

light_source { <-6, 10, -4>  color rgb <1, 0.3, 0.3>
  spotlight  point_at <-4, 0, 4>  radius 12  falloff 20 }
light_source { <0, 10, -4>  color rgb <0.3, 1, 0.3>
  spotlight  point_at <0, 0, 4>  radius 15  falloff 15 }
light_source { <0, 10, -4>  color rgb <0.4, 0.4, 1>
  spotlight  point_at <0, 0, 4>  radius 10  falloff 25  tightness 20  shadowless
  translate <6, 0, 0> }
light_source { <0, 8, 20>  color rgb 0.5
  spotlight  point_at <0, 0, 0>  radius 30  falloff 50  tightness 2 }

plane { y, 0
  pigment { checker color rgb 0.8, color rgb 0.4  scale 2 }
  finish { ambient 1 diffuse 0.8 }
}
sphere { <-4, 1.5, 4>, 1.5  pigment { color rgb 1 }  finish { ambient 1 diffuse 0.8 phong 0.6 phong_size 40 } }
box { <-1.2, 0, 2.8>, <1.2, 2.4, 5.2>  pigment { color rgb 1 }  finish { ambient 1 diffuse 0.8 } }
cylinder { <6, 0, 4>, <6, 3, 4>, 1  pigment { color rgb 1 }  finish { ambient 1 diffuse 0.8 phong 0.4 } }
