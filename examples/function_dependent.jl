using Juliagebra
using JuliaGLM

f1 = CreateFunction(range(0,1), range(0,2)) do t,s
    return t * 2 + s
end

p1 = Point(0,0,1)
Plane([f1,p1]) do func,point
    value = func(point.z)
    return (Vec3D(0,0,value),Vec3D(0,0,1))
end


Juliagebra.Wait()
