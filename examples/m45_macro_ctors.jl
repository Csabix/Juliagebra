import Juliagebra as JG # no using + renaming to test macro hygiene
using JuliaGLM

JG.App()

p1 = JG.Point(0,0,0)

p2 = JG.@Point () -> p1 .- (0,0,1)

test_global = 1

p3 = let
    test_local = 2

    JG.@Point() do
        global test_global
        println(test_global)
        println(test_local)

        (p1["x"], p1["y"], p2["z"] + 2)
    end
end

# for testing inner macro expansion
macro avg(p, q)
    :(($(esc(p)) .+ $(esc(q))) ./ 2)
end

JG.@ParametricCurve(range(-2pi,2pi,500)) do t
    @avg(p2, p3) .+ (t,0,cos(t))
end

JG.@ParametricCurve(range(-2pi,2pi,500), color=[(0,1,0),(0,0,1)], type=JG.CURVE_ARROW, reversed=true, width=17) do t
    @avg(p2, p3) .+ (t,0,cos(t)) .- (0,0,1)
end

pc1 = JG.@PointCloud() do
    [p .+ (0,1,0) for p in [p1, p2, p3]]
end

pc2 = JG.@PointCloud(color=(1,0,0),width=40) do
    [p .+ (0,1,0) for p in pc1]
end

JG.@SegmentSequence() do
    points = [p1, p2, p3]
    [i % 2 == 0 ? points[Int(ceil(i/2))] : pc1[Int(ceil(i/2))] for i in 1:6]
end

JG.@SegmentSequence(color=[(1,0,0),(0,1,0)],width=8,type=JG.CURVE_ARROW,reversed=true) do
    [i % 2 == 0 ? pc1[Int(ceil(i/2))] : pc2[Int(ceil(i/2))] for i in 1:6]
end

JG.@SegmentSequence(3) do
    [p for p in [p1, p2, p3]]
end

cone_height = JG.Slider(1,10,4)

s1_base = JG.Point(2,2,0)
JG.@ParametricSurface(50, 50, 0, 2pi, 0, 1) do u, v
    x = 3v * sign(cos(u)) * abs(cos(u))^1.85
    y = 2v * sign(sin(u)) * abs(sin(u))^1.85
    z = cone_height * v

    return s1_base .+ (x,y,z)
end

s2_base = JG.Point(-2,2,0)
JG.@ParametricSurface(50, 50, 0, 2pi, 0, 1, color=(0,0,1), transparent=true) do u, v
    x = 3v * sign(cos(u)) * abs(cos(u))^1.85
    y = 2v * sign(sin(u)) * abs(sin(u))^1.85
    z = cone_height * v

    return s2_base .+ (x,y,z)
end

t1 = JG.Toggle()
JG.@Toggle(() -> t1)

JG.@Slider(() -> cone_height, 1, 4)

JG.@TextBox(() -> "Toggle is $(t1 ? "on" : "off"), cone_height slider is at $cone_height")

JG.play!()
