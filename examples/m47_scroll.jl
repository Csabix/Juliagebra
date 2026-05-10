using Juliagebra

function S(u,v,r1,r2)
    c1 = (r2*cos(r1*u)*u,-4,r2*sin(r1*u)*u)
    c2 = (r2*cos(r1*u)*u, 4,r2*sin(r1*u)*u)

    return (1-v)^2 .* c1 .+ v^2 .* c2
end

r1 = Slider(-20,20,20; label="curlyness")
r2 = Slider(0.0,3.3,20; label="size")

ParametricSurface(range(0,1,100),range(0,1,100),[r1,r2],color=(0.204,0.514,0.263,0.5)) do u,v,r1,r2
    return S(u,v,r1,r2)
end

ParametricCurve(range(0,1,100),[r1,r2],color=(0.42,0.318,0.682)) do u,r1,r2
    return S(u,0,r1,r2)
end

ParametricCurve(range(0,1,100),[r1,r2],color=(0.42,0.318,0.682)) do u,r1,r2
    return S(u,1,r1,r2)
end

ParametricCurve(range(0,1,100),[r1,r2],color=(0.42,0.318,0.682)) do v,r1,r2
    return S(0,v,r1,r2)
end

ParametricCurve(range(0,1,100),[r1,r2],color=(0.42,0.318,0.682)) do v,r1,r2
    return S(1,v,r1,r2)
end

Juliagebra.Wait()


