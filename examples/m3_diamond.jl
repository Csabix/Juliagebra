using Juliagebra
using JuliaGLM

App()

A = Point(0,0,1)

B1 = Point(0,0,0,[A]) do a     
    return a  + Vec3D(1.0,0.0,0.0) 
end

B2 = Point(0,0,0,[A]) do a 
    return a - Vec3D(1.0,0.0,0.0)
end

C3 = Point(0,0,0,[B1,B2]) do b,c
    return ((b.x + c.x)/2,b.y,c.z-1)
end

play!()


