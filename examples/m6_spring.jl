using Juliagebra

App()

Center = Point(5,5,0)

tMax = (2*pi)*5

ParametricCurve(0,tMax,55,(0.3,0.8,0.3),[Center]) do t, c
    x = cos(t)
    y = sin(t)
    z = (t/tMax)
    
    return c[:x,:y,:z] .* (x,y,z)
end

play!()



