using JuliaGLM
using Juliagebra
using LinearAlgebra
##
A = Point(0.0, 0.0)
B = Point(1.0, 0.0)
C = Point(0.6, .55)
ab = Segment(A,B,"b";size=2)
bc = Segment(B,C,"b";size=2)
cd = Segment(C,A,"b";size=2)

Segment(A,B;size=3.0)
Segment(C,B;size=3.0)
Segment(A,C;size=3.0)

Segment(A,Midpoint(B,C),"--")
Segment(B,Midpoint(C,A),"--")
Segment(C,Midpoint(A,B),"--")
S=Midpoint(A,B,C;color_style="k");

PerpendicularBisector(A,B,":")
PerpendicularBisector(B,C,":")
PerpendicularBisector(C,A,":")

k = Circle(A,B,C,"m--")


la = AngleBisector(A,B,C,":")
lb = AngleBisector(B,C,A,":")
lc = AngleBisector(C,A,B,":")
io = Intersection(la,lb)[1]
Circle(io,Distance(io,ab);color="c")

ma = PerpendicularLine(A,bc;style=":");
mb = PerpendicularLine(B,cd;style=":");
mc = PerpendicularLine(C,ab;style=":");
M = Intersection(ma,mb)[1];
Segment(M,add_node!((c) -> Juliagebra.p0(c);parents=[k]),"r")
##
Juliagebra.Wait()