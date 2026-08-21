using Juliagebra
using JuliaGLM
using LinearAlgebra

#region Colors
invisible=(.0,.0,.0,.0)
white_trans=(1.0,1.0,1.0,.3)
green=(.0,1.0,.5)
green_trans=(.0,1.0,.5,.2)
blue=(.0,.5,1.0)
blue_trans=(.0,.5,1.0,.3)
#endregion

A = Point( 4,-2, 0; color=(1.0,1.0,1.0))
B = Point(-6,-2, 0; color=(.75,.75,.75))
C = Point( 0, 4, 0; color=( .5, .5, .5))
D = Point( 0, 0, 6; color=(.25,.25,.25))

ABC = Triangle(A,B,C; color=invisible)
ADB = Triangle(A,D,B; color=invisible)
CBD = Triangle(C,B,D; color=invisible)
ACD = Triangle(A,C,D; color=invisible)

tetrahedron = Tetrahedron(A,B,C,D; color=white_trans)

# =

#region Circumscribed Sphere
AB_mid = Midpoint(A,B; size=0)
AB_perp_plane = Perpendicular(AB_mid,B; color=invisible)

AC_mid = Midpoint(A,C; size=0)
AC_perp_plane = Perpendicular(AC_mid,C; color=invisible)

it1 = Intersection(AB_perp_plane,AC_perp_plane)
circumscribed_line = Line(it -> it[1],[it1]; size=0)

AD_mid = Midpoint(A,D; size=0)
AD_perp_plane = Perpendicular(AD_mid,D; color=invisible)

it2 = Intersection(circumscribed_line,AD_perp_plane)
circumscribed_center = Point(it -> it[1],[it2]; color="g")

circumscribed = Sphere(circumscribed_center,A; color=green_trans)

Segment(circumscribed_center,A; color=green, size=3)
Segment(circumscribed_center,B; color=green, size=3)
Segment(circumscribed_center,C; color=green, size=3)
Segment(circumscribed_center,D; color=green, size=3)
#endregion


#region Inscribed sphere
ABC_ADB_plane = AngleBisectorPlane(A,ABC,ADB; color=invisible)
ABC_CBD_plane = AngleBisectorPlane(B,ABC,CBD; color=invisible)
ACD_CBD_plane = AngleBisectorPlane(C,ACD,CBD; color=invisible)

it3 = Intersection(ABC_ADB_plane,ABC_CBD_plane)
inscribed_line = Line(it -> it[1],[it3]; size=0)

it4 = Intersection(inscribed_line,ACD_CBD_plane)
inscribed_center = Point(it -> it[1],[it4]; color="b")

inscribed_sphere = Sphere(inscribed_center,ClosestPoint(inscribed_center,A,B,C); color=blue_trans)

Segment(inscribed_center,ClosestPoint(inscribed_center,ABC; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,ADB; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,ACD; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,CBD; color=blue, size=20); color=blue, size=3)
#endregion

# =#

Juliagebra.Wait()
