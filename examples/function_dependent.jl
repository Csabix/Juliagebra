using Juliagebra
using JuliaGLM

f1 = CreateFunction([(0.0,1),(-2,0.0)]) do a,b
    return a + b + sin(a * pi)
end

for i in -5:5, j in -5:5
    Point([f1]; color="w",size=20) do func
        x = i / 5.0
        y = j / 5.0
        value = evaluate(func, x, y) / 5.0
        return (x,y,value)
    end
end

f2 = CreateFunction(t -> sin(t),(0.0,2pi); output_count=1)
f3 = CreateFunction(t -> (sin(t),cos(t),t / 4.0),(0.0,2pi); output_count=3)

p1 = Point(0,3,-1)
ParametricCurve(range(0,4pi,100),[f3,p1]) do t,func,point
    return Vec3D(evaluate(func, t)) + point
end

b0 = Point(3,0,0)
b1 = Point(2.5,1,.2)

# ParametricCurve((t,func) -> evaluate(func,t),range(0,1.0,100),[f]; color="w")
f = ParametricCurve((0.0,1.0),[b0,b1]) do t, bb0, bb1
   return bb0 * (1-t)^2 + bb1 * t^2
end
for index in 1:10
    Point([f]; color="w") do func
        return evaluate(func, index/11)
    end
end

struct NoLengthType text::String end
f4 = CreateFunction([(0,1)]) do t
    return NoLengthType("Text returned.")
end

slider = Slider(0, 1, 2; label="Value")
f5 = CreateFunction(t -> t, [(0.0,2pi)])
scalar = f5(slider)



Juliagebra.Wait()
