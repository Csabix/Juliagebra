using Juliagebra

App()

a = Point(0,0,0)
b = Point(1,0,0)
c = Point(0,1,0)
d = Point(0,0,1)

Tetrahedra(a,b,c,d)

play!()