using Juliagebra
using JuliaGLM

Juliagebra.Window() do
    a = Point(0,0,0)
    b = Point(1,0,0)
    c = Point(0,1,0)
    d = Point(0,0,1)

    Tetrahedra(a,b,c,d)

    bb = Vec3D(-1,0,0)
    cc = Vec3D(0,-1,0)
    dd = Vec3D(0,0,-1)

    Tetrahedra(a,bb,cc,dd; transparent = true, border_style = CURVE_SOLID)

    aaa = Vec3D(-1,0,0)
    ccc = Vec3D(0,-1,0)

    Tetrahedra(aaa,b,d,ccc; color = (0.8,0.1,0.2), border_style = CURVE_DOTTED)

    a4 = Point(0,3,0)
    b4 = Point(1,3,0)
    c4 = Point(0,2,0)
    d4 = Point(0,3,1)

    Tetrahedra(a4,b4,d4,c4; color = (0.0,0.0,0.6), border_style = CURVE_ARROW, border_width = 6.0, border_color = (0.9,0.0,0.0))

    a5 = Vec3D(0,4,0)
    b5 = Vec3D(1,4,0)
    c5 = Vec3D(0,3,0)
    d5 = Vec3D(0,4,1)

    Tetrahedra(a5,b5,d5,c5; color = (0.0,0.0,0.6), border_style = CURVE_ARROW, border_width = 6.0, border_color = (0.9,0.0,0.0), border_reversed = true)
end

