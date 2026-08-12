using Juliagebra
using JuliaGLM

a = Point(-4,0,0)
b = Point(-3,1,1)
ray = Ray(a,b;color="r",size=4.0f0)
Line(ray)

c = Point(4,3,2)
d = Point(2,-1,-2)
line = Line(c,d;color="b")
Ray(line;size=4.0)

e = Point(1,1,0)
f = Point(-1,-1,0)
segment = Segment(e,f)
y = Line(segment;size=2)
z = Ray(segment;size=3,color="r")

Segment(line;size=6.0,color="y")
w = Segment(ray;size=6.0,color="y")

g = Point(0,5,-3)
h = Point(0,3,-3)
ray_on_plane = Ray(g,h;color="r",size=2.0f0)
point_on_plane = Point(-1,-6,-3;color="b")
x = Plane(point_on_plane,ray_on_plane;color=(.2,.2,.2,.5))

sphere = Sphere((0,10,0),1;color="w")

p1 = Point(.5,5.5,1;color="b")
p2 = Point(-.5,4.5,0;color="b")
Segment(p1,p2;color="b",style="->",size=8)
c1 = Circle((p1,p2) -> (p1,Distance(p1,p2),p2 - p1),[p1,p2];color="b")


Juliagebra.Wait()