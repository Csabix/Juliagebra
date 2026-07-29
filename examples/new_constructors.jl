using Juliagebra
using JuliaGLM

a = Point(-4,0,0)
b = Point(-3,1,1)
ray = Ray(a,b;color="r",size=4.0)
Line(ray)

c = Point(4,3,2)
d = Point(2,-1,-2)
line = Line(c,d;color="b")
Ray(line;size=4.0)

e = Point(1,1,0)
f = Point(-1,-1,0)
segment = Segment(e,f)
Line(segment;size=2.0)
Ray(segment;size=3.0,color="r")

Segment(line)
Segment(ray)



Juliagebra.Wait()
