using Juliagebra
using JuliaGLM
using LinearAlgebra

a = Point(-4,0,0)
b = Point(-3,1,1)
ray = Ray(a,b;color="r",size=4.0f0)
Line(ray)

c = Point(4,3,2)
d = Point(2,-1,-2)
line = Line(c,d;color="b")
Ray(line;size=4.0)

e = Point(1,1,-4)
f = Point(-1,-1,-4)
segment = Segment(e,f)
y = Line(segment;size=2)
z = Ray(segment;size=3,color="r")

Segment(line;size=6.0,color="y")
w = Segment(ray;size=6.0,color="y")

g = Point(0,5,-3)
h = Point(0,3,-3)
ray_on_plane = Ray(g,h;color="r",size=2.0f0)
point_on_plane = Point(-1,-6,-3;color="b")
plane = Plane(point_on_plane,ray_on_plane;color=(.2,.2,.2,.5))

sphere = Sphere((0,10,0),1;color="w")

# Circles
p_start = Point(0,0,0;color="w")
p_end = Point(0,1,0;color="w")
segment_normal = Segment((a,b) -> (a,b),[p_start,p_end];color="w")
p_radius = Point(0,0,.5;color="w")
circle1 = Circle(segment_normal,p_radius;color="w")
p1 = Point(2,0, .5)
p2 = Point(-1,0,0)
line1 = Line(p1,p2;color="b")
it1 = Intersection(circle1,line1;maxIntersectionNum=2)
it1 = Intersection(circle1,line1)
PointSequence([it1[1],it1[2],it1[3],it1[4]]) # Ideally passing it1 would be enough, if it were implemented, but this is good for showcase

# Circle(Vec3D(4,8,-1),1.0,plane)
Circle(Vec3D(4,8,-1),1.0,plane) # no plane given: uses default plane (XY))

p3 = Point(0,8,-1;color="c")
p4 = Point(1,8,-1;color="c")
# Circle(p3,p4,plane;color="c")
Circle(p3,p4;color="c") # no plane given: uses default plane (XY))

p5 = Point(-3,8,-1;color="y")
p6 = Point(-4,8.5,-1;color="y")
p7 = Point(-4.5,7.5,-1;color="y")
Circle(p5,p6,p7;color="y")



Juliagebra.Wait()