using Juliagebra
using JuliaGLM

f1 = CreateFunction([(0.0,1.0),(-2.0,0.0)]) do a,b
    return a + b + sin(a * pi)
end

p1 = Point(0,3,-1)
# for i in -5:5, j in -5:5
#     Point([f1]; color="w",size=20) do func
#         x = i / 5.0
#         y = j / 5.0
#         value = func(x, y)
#         return (x,y,value)
#     end
# end

f2 = CreateFunction(t -> sin(t),[(0.0,2pi)]; output_count=1)
f3 = CreateFunction(t -> (sin(t),cos(t),t / 4.0),[(0.0,2pi)]; output_count=3)

ParametricCurve(range(0,4pi,100),[f3,p1]) do t,func,point
    return Vec3D(func(t)) + point
end

p4 = Point(3,0,0)
p5 = Point(2.5,1,0)
f5 = CreateFunction(a -> a^2,[(0.0,1.0)])
ParametricCurve(range(0,1.0,100),[f5,p4,p5]) do t,func,a,b
    return func(t) * a + func(1 - t) * b
end

# f4 = CreateFunction([(0.0,1.0)]) do a
#     return a
# end
# p2 = Point(1,0,0)
# p3 = Point(-.5,1,0)
# Curve(f4,[p2,p3]) do t,a,b
#     return t^2 * a + (1.0 - t)^2 * b
# end


Juliagebra.Wait()
