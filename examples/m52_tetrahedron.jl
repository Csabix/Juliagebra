using Juliagebra
using JuliaGLM
using LinearAlgebra

#region Colors
invisible=(.0,.0,.0,.0)
green=(.0,1.0,.5)
green_trans=(.0,1.0,.5,.2)
#endregion

A = Point(-6,-2, 0; color=(1.0,1.0,1.0))
B = Point( 4,-2, 0; color=(.75,.75,.75))
C = Point( 0, 4, 0; color=( .5, .5, .5))
D = Point( 0, 0, 6; color=(.25,.25,.25))

tetrahedron = Tetrahedron(A,B,C,D; color=(.0,.5,1.0,.3))

#region Circumscribed Sphere
AB_mid = Midpoint(A,B; color="w")
AB_perp_plane = Perpendicular(AB_mid,B; color=invisible)

AC_mid = Midpoint(A,C; color="w")
AC_perp_plane = Perpendicular(AC_mid,C; color=invisible)

it1 = Intersection(AB_perp_plane,AC_perp_plane)
AB_AC_line = Line(it -> it[1],[it1]; color=green)

AD_mid = Midpoint(A,D; color="w")
AD_perp_plane = Perpendicular(AD_mid,D; color=invisible)

it2 = Intersection(AB_AC_line,AD_perp_plane)
circum_center = Point(it -> it[1],[it2]; color=green)

circum_radius = Distance(A,circum_center)
circumscribed = Sphere(circum_center,circum_radius; color=green_trans)
#endregion




Juliagebra.Wait()
