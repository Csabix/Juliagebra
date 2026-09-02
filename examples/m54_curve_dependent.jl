using Juliagebra
using JuliaGLM

f6 = Func((-1.5,1.5)) do t
    return t^3 - t
end

f6_curve = Curve!(f6)
ParametricCurve(f6_curve; color="r")

f6_curve_1st = Derive(f6_curve)
ParametricCurve(f6_curve_1st; color="g", size=4.25)

f6_curve_2nd = Derive2(f6_curve)
ParametricCurve(f6_curve_2nd; color="b", size=3.5)

f6_curvature = Curvature(f6_curve)
ParametricCurve(f6_curvature; color="y", size=3)

# Should be ~6.5148
f6_arc_length = ArcLength(f6_curve)

f7 = Func((0,pi)) do t
    return Vec2D(cos(t) + 5,sin(t))
end
f7_curve = Curve!(f7)
# Should be pi ~= 3.1416
f7_arc_length = ArcLength(f7_curve)


# Play the animation
slider2 = Slider(0, 0, 2pi; label="Frenet-Serret frame value")
# (1,-2) torus knot
f8 = Func((0,2pi)) do t
    p = 1
    q = -2
    r = cos(q * t) + 2
    return Vec3D(
        r * cos(p * t) - 6,
        r * sin(p * t),
        -sin(q * t))
end
f8_point = f8(slider2)
(f8_curve, ) = Curve!(f8; parametric_curve=true,resolution=1000)

f8_frame = FrenetFrame(f8_curve)

Segment([slider2,f8_frame,f8_point]; color="r") do t,frame,p
    return (p, p + T(frame(t)))
end
Segment([slider2,f8_frame,f8_point]; color="g") do t,frame,p
    return (p, p + N(frame(t)))
end
Segment([slider2,f8_frame,f8_point]; color="b") do t,frame,p
    return (p, p + B(frame(t)))
end


f9 = Func((0,1)) do t
    return Vec2D(t,sin(pi*t))
end
f9_curve = Curve!(f9)
f9_curvature = Curvature(f9_curve)

f10 = Func((0,1)) do t
    return Vec3D(t,sin(pi*t),-2*t)
end
f10_curve = Curve!(f10)
f10_curvature = Curvature(f10_curve)


Juliagebra.Wait()
