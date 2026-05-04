using Juliagebra
using JuliaGLM

##

# Point
a = Point(1,0,-1);
b = Point(1,0,0,"r+");
c = Point(1,0,1,color="green");
d = Point(1,0,2,color=(0,0,255));
e = Point(1,0,3,color=(0.5,0.5,0.5));
f = Point(1,0,4,style="+",size=50);

Point(() -> Vec3D(0,0,-1))
const offset_point(p) = p .- (2,0,0)
Point(offset_point,[a]);
Point(offset_point,[b],"r+");
Point(offset_point,[c],color="green");
Point(offset_point,[d],color=(0,0,255));
Point(offset_point,[e],color=(0.5,0.5,0.5));
Point(offset_point,[f],style="+",size=50);


@Point() do
    a .- (3,0,0)
end;
@Point("r+") do
    b .- (3,0,0)
end;
@Point(color="green") do
    c .- (3,0,0)
end;
@Point(color=(0,0,255)) do
    d .- (3,0,0)
end;
@Point(color=(0.5,0.5,0.5)) do
    e .- (3,0,0)
end;
@Point(style="+",size=50) do
    f .- (3,0,0)
end;

# PointSet

# Not real PointSet just helper to create points from array of positions and combine them into one vector when used by other dependent
as = PointSet([(-1,1,-1),(0,1,-1),(1,1,-1)]);
bs = PointSet([(-1,1, 0),(0,1, 0),(1,1, 0)],"r+");
cs = PointSet([(-1,1, 1),(0,1, 1),(1,1, 1)],color="green");
ds = PointSet([(-1,1, 2),(0,1, 2),(1,1, 2)],color=(0,0,255));
es = PointSet([(-1,1, 3),(0,1, 3),(1,1, 3)],color=(0.5,0.5,0.5));
fs = PointSet([(-1,1, 4),(0,1, 4),(1,1, 4)],style="+",size=50);

const offset_pointset(positions) = [x .+ (0, 1, 0) for x in positions]

PointSet(offset_pointset,[as]);
PointSet(offset_pointset,[bs],"r+");
PointSet(offset_pointset,[cs],color="green");
PointSet(offset_pointset,[ds],color=(0,0,255));
PointSet(offset_pointset,[es],color=(0.5,0.5,0.5));
PointSet(offset_pointset,[fs],style="+",size=50);

sa = Point(0,3,0);
sb = Point(1,3,0,"r+");
sc = Point(2,3,0,color="green");
sd = Point(3,3,0,color=(0,0,255));
se = Point(4,3,0,color=(0.5,0.5,0.5));
sf = Point(5,3,0,style="+",size=50);

function pointseq_points(p)
    res = Vec3D[]
    for h = 0.0:1.0:(p.z-1.0)
        push!(res,Vec3D(p.x,p.y,h))
    end
    return res
end

PointSequence(pointseq_points,[sa]);
PointSequence(pointseq_points,[sb],"r+");
PointSequence(pointseq_points,[sc],color="green");
PointSequence(pointseq_points,[sd],color=(0,0,255));
PointSequence(pointseq_points,[se],color=(0.5,0.5,0.5));
PointSequence(pointseq_points,[sf],style="+",size=50);
##
ParametricCurve(range(-pi,pi,30)) do t
    (t/pi,1,sin(t))
end
ParametricCurve(range(-pi,pi,30),[Point(0,2,0)],"g->") do t,p
    (t/pi,0,sin(t)) .+ p
end
p = Point(0,3,0)
@ParametricCurve(range(-pi,pi,30),"m:") do t
    (t/pi,0,sin(t)) .+ p
end

# Calls Parametric curve under the hood
Segment(     (-1,0,0),     ( 1,0,0));
Segment(     (-1,0,1),Point( 1,0,1),"r--");
Segment(Point(-1,0,2),     ( 1,0,2),color="green",style="-.");
Segment(Point(-1,0,3),Point( 1,0,3),color=(0,0,255),style=":");
Segment(Point(-1,0,4),Point( 1,0,4),color=(0.5,0.5,0.5),style="~");
Segment(Point(-1,0,5),Point( 1,0,5),color=["r","g"],style="->");
Segment(Point(-1,0,6),Point( 1,0,6),style="<-",size=50.0);

sa = Point(0,3,0);
sb = Point(1,3,0,"r+");
sc = Point(2,3,0,color="green");
sd = Point(3,3,0,color=(0,0,255));
se = Point(4,3,0,color=(0.5,0.5,0.5));
sf = Point(5,3,0,style="+",size=50);

function segseq_points(p)
    res = Vec3D[]
    p.z <= 0.0 && return res
    for h = 0.0:0.1:p.z
        push!(res,Vec3D(p.x,p.y,h))
    end
    return res
end

SegmentSequence(segseq_points,[sa],0);
SegmentSequence(segseq_points,[sb],1,"r:");
SegmentSequence(segseq_points,[sc],2,color="green");
SegmentSequence(segseq_points,[sd],3,color=(0,0,255));
SegmentSequence(segseq_points,[se],4,color=(0.5,0.5,0.5));
SegmentSequence(segseq_points,[sf],5,style="~",size=10);

##

Sphere((0,0,0),1,"r");
Sphere((0,0,2),(0,0,1),color="green");
Sphere((2,0,0),Slider(0.0,1.0,1.0));
Sphere((2,0,2),Point(2,0,3),color=(0.5,0.5,0.5,0.5));

# Any combination should work
Sphere(Point(0,1,-3 ),Point(1,0,-3 ),Point(0,0,-3 ),Point(0.1,0,-2 ));
Sphere(Point(0,1,-6 ),Point(1,0,-6 ),Point(0,0,-6 ),     (0.1,0,-5 ));
Sphere(Point(0,1,-9 ),Point(1,0,-9 ),     (0,0,-9 ),     (0.1,0,-8 ));
Sphere(Point(0,1,-12),     (1,0,-12),     (0,0,-12),     (0.1,0,-11));

p = Point(0,0,4)
s = Slider()
@Sphere () -> (p,s) "r";