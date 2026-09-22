using JuliaGLM
using Juliagebra
using LinearAlgebra
##
set_at!(0.5,0.2,0)
set_eye!(0.5,0.1999,1.5)
set_ortho!()

A = Point(0.0, 0.0, "b"; size=15)
B = Point(1.0, 0.0, "b"; size=15)
C = Point(0.6, .55, "b"; size=15)
ab = Segment(A,B,"b";size=4)
bc = Segment(B,C,"b";size=4)
cd = Segment(C,A,"b";size=4)

Segment(A,Midpoint(B,C;color_style="k",size=15),"k--", size=3)
Segment(B,Midpoint(C,A;color_style="k",size=15),"k--", size=3)
Segment(C,Midpoint(A,B;color_style="k",size=15),"k--", size=3)
S=Midpoint(A,B,C;color_style="k",size=15);

b_ab = PerpendicularBisector(A,B,"m:";size=3)
b_bc = PerpendicularBisector(B,C,"m:";size=3)
PerpendicularBisector(C,A,"m:";size=3)

Point(Intersection(b_ab,b_bc)[1],"m";size=15)
k = Circle(A,B,C,"m--";size=3)

la = AngleBisector(A,B,C,"c:",size=3)
lb = AngleBisector(B,C,A,"c:",size=3)
lc = AngleBisector(C,A,B,"c:",size=3)

io = Point(Intersection(la,lb)[1],"c";size=15)
Circle(io,Distance(io,ab);color="c")

ma = PerpendicularLine(A,bc;color_style="k:",size=3);
mb = PerpendicularLine(B,cd;color_style="k:",size=3);
mc = PerpendicularLine(C,ab;color_style="k:",size=3);
M = Intersection(ma,mb)[1];
Segment(M,add_node!((c) -> Juliagebra.p0(c);parents=[k]),"r",size=3.1)
##
Juliagebra.Wait()