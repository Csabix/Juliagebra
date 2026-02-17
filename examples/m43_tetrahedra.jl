using Juliagebra
using JuliaGLM

App()

a = Point(0,0,0)
b = Point(1,0,0)
c = Point(0,1,0)
d = Point(0,0,1)

Tetrahedra(a,b,c,d)

bb = Vec3D(-1,0,0)
cc = Vec3D(0,-1,0)
dd = Vec3D(0,0,-1)

Tetrahedra(a,bb,cc,dd; transparent = true)

aaa = Vec3D(-1,0,0)
ccc = Vec3D(0,-1,0)

Tetrahedra(aaa,b,d,ccc, color = (0.8,0.1,0.2))

play!()