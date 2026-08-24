using Juliagebra
using JuliaGLM

f1 = CreateFunction([(0.0,1.0),(-2.0,0.0)]) do a,b
    return a + b + sin(a * pi)
end

p1 = Point(0,0,1)
# Line([f1,p1]) do func,point
#     value = func(point.z, point.x)
#     println("$(typeof(value)): $value")
#     return (Vec3D(0,0,0),Vec3D(1,0,value))
# end
for i in -5:5, j in -5:5
    Point([f1]) do func
        x = i / 5.0
        y = j / 5.0
        value = func(x, y)
        return (x,y,value)
    end
end


f2 = CreateFunction(t -> sin(t),[(0.0,2pi)]; output_count=1)
f3 = CreateFunction(t -> (sin(t),cos(t),t),[(0.0,2pi)]; output_count=3)


Juliagebra.Wait()
