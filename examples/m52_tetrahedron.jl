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

A = Point(-6,-2, 0; color=(1.0,1.0,1.0))
B = Point( 4,-2, 0; color=(.75,.75,.75))
C = Point( 0, 4, 0; color=( .5, .5, .5))
D = Point( 0, 0, 6; color=(.25,.25,.25))

tetrahedron = Tetrahedron(A,B,C,D; color=white_trans)

# =

#region Circumscribed Sphere
AB_mid = Midpoint(A,B; color="w")
AB_perp_plane = Perpendicular(AB_mid,B; color=invisible)

AC_mid = Midpoint(A,C; color="w")
AC_perp_plane = Perpendicular(AC_mid,C; color=invisible)

it1 = Intersection(AB_perp_plane,AC_perp_plane)
circumscribed_line = Line(it -> it[1],[it1]; size=0)

AD_mid = Midpoint(A,D; color="w")
AD_perp_plane = Perpendicular(AD_mid,D; color=invisible)

it2 = Intersection(circumscribed_line,AD_perp_plane)
circumscribed_center = Point(it -> it[1],[it2]; color="g")

circumscribed_radius = Distance(A,circumscribed_center)
circumscribed = Sphere(circumscribed_center,circumscribed_radius; color=green_trans)

Segment(circumscribed_center,A; color=green, size=3)
Segment(circumscribed_center,B; color=green, size=3)
Segment(circumscribed_center,C; color=green, size=3)
Segment(circumscribed_center,D; color=green, size=3)
#endregion


#region Inscribed sphere
ABC = Triangle(A,C,B; color=invisible)
ABD = Triangle(A,B,D; color=invisible)
BCD = Triangle(B,C,D; color=invisible)
ACD = Triangle(C,A,D; color=invisible)

ABC_ABD_plane = Plane([A,ABC,ABD]; color=invisible) do point,t1,t2
    normal = normalize(n(t1) - n(t2))
    return (point,normal)
end
ABC_BCD_plane = Plane([B,ABC,BCD]; color=invisible) do point,t1,t2
    normal = normalize(n(t1) - n(t2))
    return (point,normal)
end
ACD_BCD_plane = Plane([C,ACD,BCD]; color=invisible) do point,t1,t2
    normal = normalize(n(t1) - n(t2))
    return (point,normal)
end

it3 = Intersection(ABC_ABD_plane,ABC_BCD_plane)
inscribed_line = Line(it -> it[1],[it3]; size=0)

it4 = Intersection(inscribed_line,ACD_BCD_plane)
inscribed_center = Point(it -> it[1],[it4]; color="b")

inscribed_radius = Distance(inscribed_center,A,B,C)
inscribed_sphere = Sphere(inscribed_center,inscribed_radius; color=blue_trans)

Segment(inscribed_center,ClosestPoint(inscribed_center,ABC; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,ABD; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,ACD; color=blue, size=20); color=blue, size=3)
Segment(inscribed_center,ClosestPoint(inscribed_center,BCD; color=blue, size=20); color=blue, size=3)
#endregion

# =#

Juliagebra.Wait()
