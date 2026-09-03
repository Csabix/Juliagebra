using Juliagebra
using JuliaGLM

f1 = Func([(0.0,1),(-2,0.0)]) do a,b
    return a + b + sin(a * pi)
end

for i in -5:5, j in -5:5
    Point([f1]; color="w",size=20) do func
        x = i / 5.0
        y = j / 5.0
        value = func(x, y) / 5.0
        return (x,y,value)
    end
end

f2 = Func(t -> sin(t),(0.0,2pi); output_count=1)
f3 = Func(t -> Vec3D(sin(t),cos(t),t / 4.0),(0.0,4pi); output_count=3)

# Parametric curve dependent on f3's results
ParametricCurve(f3; color="w",size=2)
p1 = Point(0,3,-1)
# Parametric curve dependent on f3's results and point
ParametricCurve(f3,[p1]) do t,func,point
    return func(t) + point
end

b0 = Point(3,0,0)
b1 = Point(2.5,1,.2)
# Parametric curve dependent on a newly created Func
f = ParametricCurve((0.0,1.0),[b0,b1]; resolution=10,node=false,func=true) do t, bb0, bb1
   return bb0 * (1-t)^2 + bb1 * t^2
end
for index in 1:10
    f(index/11)
end

struct NoLengthType text::String end
f4 = Func([(0,1)]) do t
    return NoLengthType("Text returned.")
end

slider = Slider(0, 1, 12; label="Value")
f5 = Func(t -> t * 2, [(0.0,2pi)])
scalar = f5(slider)
point3d = f3(slider)
f6 = Func(t -> (t - 10,t - 5),(0,12))
ParametricCurve(f6; color="w",size=2)
point2d = f6(slider)

scalar_const = f5(.67)
point3d_const = f3(pi)
point3d_2params = f1(.4,-1.1)

Juliagebra.Wait()
