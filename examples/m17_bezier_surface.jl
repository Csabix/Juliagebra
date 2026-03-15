using Juliagebra

P00 = Point(0, 0, 0)
P10 = Point(5, 0, 0)
P01 = Point(0, 5, 0)
P11 = Point(5, 5, 5)

bezierSurface = ParametricSurface(range(0.0,1.0,50),range(0.0,1.0,50),[P00,P10,P01,P11]) do u, v, p00, p10, p01, p11
    return  ((1-u)*(1-v)) .* p00 .+ 
            (   u *(1-v)) .* p10 .+
            ((1-u)*   v)  .* p01 .+
            (   u *   v)  .* p11
end

Juliagebra.Wait()
