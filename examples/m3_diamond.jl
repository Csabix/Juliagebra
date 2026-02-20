using Juliagebra
using JuliaGLM
println("Available :default threads: $(Threads.nthreads(:default))")
println("Available :interactive threads: $(Threads.nthreads(:interactive))")

Juliagebra.Init() do 
    A = Point(0,0,1)



    B1 = Point([A]) do a     
        return a  + Vec3D(1.0,0.0,0.0) 
    end

    B2 = Point([A]) do a 
        return a - Vec3D(1.0,0.0,0.0)
    end

    C3 = Point([B1,B2]) do b,c
        return ((b.x + c.x)/2,b.y,c.z-1)
    end
end


