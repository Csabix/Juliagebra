using JuliaGLM
using Juliagebra

P00 = Point( -0.5,  -0.5,  1)
P10 = Point(  0.5,  -0.5,  0)
P01 = Point( -0.5,   0.5,  0)
P11 = Point(  0.5,   0.5,  1)

bezierSurface = ParametricSurface(range(0.0,1.0,100),range(0.0,1.0,100),[P00,P10,P01,P11]; color=(0.329, 0.604, 1)) do u, v, p00, p10, p01, p11
    return  ((1-u)*(1-v)) .* p00 .+ 
            (   u *(1-v)) .* p10 .+
            ((1-u)*   v)  .* p01 .+
            (   u *   v)  .* p11
end

#ParametricCurve(range(0.0,8*pi,1000)) do t
#    return Vec3D(cos(t),0.0,sin(t)) .* Vec3D(t/(2*pi)) .+ Vec3D(0,(t/2-2*pi),0)  
#end

#a = Point(-1.5, 0, 0)
#b = Point(-0.5, 0, 0.5)
#c = Point( 0.5, 0,-2)
#d = Point( 1.5, 0, 0)
#
#ParametricCurve(range(0,1,100), [a,b,c,d]) do t, a, b, c, d
#    ab = (1-t) .* a .+ t .* b
#    bc = (1-t) .* b .+ t .* c
#    cd = (1-t) .* c .+ t .* d
#    abc = (1-t) .* ab .+ t .* bc
#    bcd = (1-t) .* bc .+ t .* cd
#    return (1-t) .* abc .+ t .* bcd
#end


#function ssine(t,offset)
#    return Vec3D(t,offset,sin(t))
#end


#rrange = range(-8*pi,8*pi,1000)

#ParametricCurve(rrange) do t
#    return ssine(t,0.0)
#end

#ParametricCurve(rrange; color=(0.56,0.87,0.12)) do t
#    return ssine(t,1.0)
#end

#ParametricCurve(rrange; color=(0.43,0.23,0.92), type=CURVE_DASHED) do t
#    return ssine(t,2.0)
#end

#ParametricCurve(rrange; color=(0.92,0.56,0.82), type=CURVE_ARROW, width=10.0) do t
#    return ssine(t,3.0)
#end

#ParametricCurve(rrange; color=(0.35,0.43,0.82), type=CURVE_ARROW, width=8.0, reversed=true) do t
#    return ssine(t,4.0)
#end

#ParametricSurface(range(-10,10,100), range(-10,10,100); color=(0.0,0.95,0.0)) do u, v
#    return (u,v,sin(u)+sin(v)+2)    
#end

#ParametricSurface(range(-10,10,100), range(-10,10,100); color=(0.0,0.95,0.0), transparent=true) do u, v
#    return (u,v,sin(u)+sin(v)+5)    
#end

Juliagebra.Wait()
