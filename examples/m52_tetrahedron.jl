using Juliagebra
using JuliaGLM
using LinearAlgebra

#region Colors
invisible=(.0,.0,.0,.0)
white_trans=(1.0,1.0,1.0,.15)
green=(.0,1.0,.5)
green_trans=(.0,1.0,.5,.2)
blue=(.0,.5,1.0)
blue_trans=(.0,.5,1.0,.3)
#endregion

A = Point( 4,-2, 0; color=(1.0,1.0,1.0))
B = Point(-6,-2, 0; color=(.75,.75,.75))
C = Point( 0, 4, 0; color=( .5, .5, .5))
D = Point( 0, 0, 6; color=(.25,.25,.25))

((ABC,ADB,ACD,BDC), (AB,_,_,AD,AC,_)) = Tetrahedron(A,B,C,D; color=white_trans,node=false,faces=true,edges=true)

#region Circumscribed Sphere
AB_mid = Midpoint(AB; color="c",size=5)
AB_perp_plane = Perpendicular(AB_mid,B; color=invisible)

AC_mid = Midpoint(AC; size=0)
AC_perp_plane = Perpendicular(AC_mid,C; color=invisible)

circumscribed_line = Line(Intersection(AB_perp_plane,AC_perp_plane)[1]; size=0)

AD_mid = Midpoint(AD; color="c",size=5)
AD_perp_plane = Perpendicular(AD_mid,D; color=invisible)

circumscribed_center = Point(Intersection(circumscribed_line,AD_perp_plane)[1]; color="g")

circumscribed = Sphere(circumscribed_center,A; color=green_trans)

Segment(circumscribed_center,A; color=green, size=3)
Segment(circumscribed_center,B; color=green, size=3)
Segment(circumscribed_center,C; color=green, size=3)
Segment(circumscribed_center,D; color=green, size=3)
#endregion


#region Inscribed sphere
ABC_ADB_plane = AngleBisectorPlane(A,ABC,ADB; color=invisible,external=true)
ABC_BDC_plane = AngleBisectorPlane(B,ABC,BDC; color=invisible,external=true)
ACD_BDC_plane = AngleBisectorPlane(C,ACD,BDC; color=invisible,external=true)

inscribed_line = Line(Intersection(ABC_ADB_plane,ABC_BDC_plane)[1]; size=0)

inscribed_center = Point(Intersection(inscribed_line,ACD_BDC_plane)[1]; color="b")

inscribed_sphere = Sphere(inscribed_center,ClosestPoint(inscribed_center,A,B,C); color=blue_trans)

Segment(inscribed_center,ClosestPoint(inscribed_center,ABC; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,ADB; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,ACD; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,BDC; color=blue, size=20); color=blue, size=3)
#endregion

Juliagebra.Wait()
