using Juliagebra
using JuliaGLM

##

# Point
a = Point(1,0,-1);
b = Point(1,0,"r+");
c = Point(1,0,1,color="green",axis_constraint=AXIS_X);
d = Point(1,0,2,color=(0,0,255),axis_constraint=AXIS_X|AXIS_Z);
e = Point(1,0,3,color=(0.5,0.5,0.5));
f = Point(1,0,4,style="+",size=50);

Point(() -> Vec3D(0,0,-1))
const offset_point(p) = p .- (2,0,0)
Point(offset_point,[a];axis_constraint=AXIS_FULL); # Default AXIS_NONE -> Can't be moved using gizmo
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
end;
ParametricCurve(range(-pi,pi,30),[Point(0,2,0)],"g->") do t,p
    (t/pi,0,sin(t)) .+ p
end;
p = Point(0,3,0)
@ParametricCurve(range(-pi,pi,30),"m:") do t
    (t/pi,0,sin(t)) .+ p
end;
ParametricCurve(range(-pi,pi,30)) do a
    return sin(a), cos(a)
end;

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
SegmentSequence() do
    [(3,0),(3,1),(4,0),(4,1),(5,0),(5,1),(6,0),(6,1),(7,0),(7,1)]
end;
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

##

Triangle(     (0,0,0.1),   (1,1,0.1),   (0,1,0.1));
Triangle(     (0,0,1),     (1,1,1),Point(0,1,1),"r");
Triangle(     (0,0,2),Point(1,1,2),Point(0,1,2),color="white");
Triangle(Point(0,0,3),Point(1,1,3),Point(0,1,3),color=(0.5,0.5,0.5,0.5));

function parametric_sphere(u, v, c)
    r = 1.0
    theta = 2 * π * u
    phi = π * v
    
    x = c[1] + r * sin(phi) * cos(theta)
    y = c[3] + r * cos(phi)
    z = c[2] + r * sin(phi) * sin(theta)
    
    return (x, y, z)
end

ParametricSurface(parametric_sphere,range(0.0,1.0,50),range(0.0,1.0,50),[Point(3,0,0)],color=(100,100,80,250));

p = Point(-3,0,0);
r = Slider();
@ParametricSurface(range(0.0,1.0,50),range(0.0,1.0,50),color="y") do u,v
    theta = 2 * π * u
    phi = π * v
    
    x = p[1] + r * sin(phi) * cos(theta)
    y = p[3] + r * cos(phi)
    z = p[2] + r * sin(phi) * sin(theta)
    
    return (x, y, z)
end;

dir = @__DIR__ ;
FILE = dir * "\\scenes\\scene_1.fbx";
scene = load_scene(FILE;scale_factor=0.5f0);

TriangleCluster(scene[1];color=(1.0,1.0,0.0,1.0));
TriangleCluster(scene[2],"r");
TriangleCluster(scene[3], [Point(3, 3, 3)]; color=(0.5, 0.5, 0.5, 0.5)) do p
    return [
        1.0  0.0  0.0  p[1];
        0.0  1.0  0.0  p[2];
        0.0  0.0  1.0  p[3];
        0.0  0.0  0.0  1.0
    ]
end;

scale = Slider(0.0,0.1,5.0)
@TriangleCluster(scene[2];color="k") do
    return [
        scale  0.0    0.0    0.0
        0.0    scale  0.0    0.0;
        0.0    0.0    scale  0.0;
        0.0    0.0    0.0    1.0
    ]
end;

count = Slider(0.0,0.0,100.0)
@TriangleCluster("c") do
    n_segments = Int(floor(count[]))
    vertices = Vector{Tuple{Float64, Float64, Float64}}()
    
    # Spiral Settings
    turns = 5.0
    h_step = 0.05   # Vertical rise per radian
    r_base = 1.0    # Starting radius
    width = 0.3     # Ribbon width
    
    for i in 0:n_segments-1
        # Parameter t
        t1 = i / 100.0  # Normalized based on max slider range for consistency
        t2 = (i + 1) / 100.0
        
        θ1 = t1 * turns * 2π
        θ2 = t2 * turns * 2π
        
        # Radii
        r1 = r_base + (t1 * 0.5)
        r2 = r_base + (t2 * 0.5)
        
        # Z-height
        z1 = θ1 * h_step
        z2 = θ2 * h_step

        # Coordinates for the inner edge
        p1_in  = (r1 * cos(θ1), r1 * sin(θ1), z1)
        p2_in  = (r2 * cos(θ2), r2 * sin(θ2), z2)
        
        # Coordinates for the outer edge
        p1_out = ((r1 + width) * cos(θ1), (r1 + width) * sin(θ1), z1)
        p2_out = ((r2 + width) * cos(θ2), (r2 + width) * sin(θ2), z2)

        # TRIANGLE 1 (Inner1 -> Outer1 -> Inner2)
        # Maintaining Counter-Clockwise winding
        push!(vertices, p1_out)
        push!(vertices, p1_in)
        push!(vertices, p2_in)

        # TRIANGLE 2 (Outer1 -> Outer2 -> Inner2)
        push!(vertices, p2_out)
        push!(vertices, p1_out)
        push!(vertices, p2_in)
    end
    return vertices
end;

# Zero based vertex indexing
TriangleCluster(color="w") do
    cx, cy, cz = 3.0, 3.0, 3.0
    s = 0.5

    positions = [
        (cx-s, cy-s, cz-s),
        (cx+s, cy-s, cz-s),
        (cx+s, cy+s, cz-s),
        (cx-s, cy+s, cz-s),
        (cx-s, cy-s, cz+s),
        (cx+s, cy-s, cz+s),
        (cx+s, cy+s, cz+s),
        (cx-s, cy+s, cz+s) 
    ]

    indices = [
        0, 1, 2,  0, 2, 3,
        4, 6, 5,  4, 7, 6,
        0, 7, 4,  0, 3, 7,
        1, 6, 2,  1, 5, 6,
        3, 6, 7,  3, 2, 6,
        0, 5, 1,  0, 4, 5
    ]
    return positions, indices
end;

##

a = Point(0,0,0);
b = Point(1,0,0);
c = Point(0,1,0);
d = Point(0,0,1);
Tetrahedra(a,b,c,d);

bb = Vec3D(-1,0,0)
cc = Vec3D(0,-1,0)
dd = Vec3D(0,0,-1)
Tetrahedra(a,bb,cc,dd; color=(0.5,0.5,0.5,0.5), border_style="-");

aaa = Vec3D(-1,0,0)
ccc = Vec3D(0,-1,0)
Tetrahedra(aaa,b,d,ccc; color=(0.8,0.1,0.2), border_style=":");

a4 = Point(0,3,0)
b4 = Point(1,3,0)
c4 = Point(0,2,0)
d4 = Point(0,3,1)
Tetrahedra(a4,b4,d4,c4,"b"; border_color="r", border_style ="->", border_size=6.0);

a5 = Vec3D(0,4,0)
b5 = Vec3D(1,4,0)
c5 = Vec3D(0,3,0)
d5 = Vec3D(0,4,1)
Tetrahedra(a5,b5,d5,c5; color=(0.0,0.0,0.6), border_color=(0.9,0.0,0.0), border_style="<-", border_size=6.0);