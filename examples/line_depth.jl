using Juliagebra
using JuliaGLM
using LinearAlgebra

width_front = Slider(0.1,0.5;label="width_front")
width_back = Slider(0.1,0.5;label="width_back")
height = Slider(0.1,0.5;label="height")

O = Point(0,0,0;size=0)
A = @Point() do
    return (O[1]-width_front,O[2]-height,O[3])
end
B = @Point() do
    return (O[1]+width_front,O[2]-height,O[3])
end
C = @Point() do
    return (O[1]-width_back,O[2]+height,O[3])
end
D = @Point() do
    return (O[1]+width_back,O[2]+height,O[3])
end

Triangle(A,B,C,transparent=true)
Triangle(B,D,C,transparent=true)

@ParametricSurface(range(-1.0,1.0,50),range(-1.0,1.0,50),transparent=false) do u,v
    t = (v + 1.0) / 2.0
    width = (1.0 - t) * width_front + t * width_back
    x = u * width
    y = v * height
    z = (1.0 - sqrt(1.0 - u * u)) * width

    return (x,y,-z)
end

u = Slider(0.0,1.0;label="u")
v = Slider(0.0,1.0;label="v")

current = @Point() do
    width = (1.0 - v) * width_front + v * width_back
    return ((u - 0.5) * 2.0 * width, (v - 0.5) * 2.0 * height,O[3])
end

#x_deg = Slider(0.0,360.0,label="degree x")
y_deg = Slider(0.0,180.0,label="degree y")

eye = @Point() do
    rad_x = deg2rad(90.0)
    rad_y = deg2rad(y_deg)

    dx = 5.0 * cos(rad_y) * cos(rad_x)
    dy = 5.0 * cos(rad_y) * sin(rad_x)
    dz = 5.0 * sin(rad_y)
    
    return (current[1] + dx, current[2] + dy, current[3] + dz)
end

Segment(current,eye)

E = @Point() do
    radius = (1.0 - v) * width_front + v * width_back
    uu = u * 2.0 - 1.0
    return (current[1],current[2],current[3] - radius * (1.0 - sqrt(1.0 - uu * uu)))
end

dir_E = @ValueHolder(Vec2D) do
    d_radius = (width_front - width_back) / height
    return Vec2D(0,d_radius)
end

intersection_point = @Point() do
    d1 = [0.0, -1.0, dir_E[2]] 
    d1 = d1 / norm(d1)
    
    d2 = [eye[1] - current[1], eye[2] - current[2], eye[3] - current[3]]
    d2 = d2 / norm(d2)
    
    A = [d1 -d2]
    b = [current[1] - E[1], current[2] - E[2], current[3] - E[3]]

    params = A \ b
    s_val = params[1]
    
    res = [E[1], E[2], E[3]] + s_val * d1
    return (res[1], res[2], res[3])
end

Juliagebra.Wait()