include("Prototype/juliagebra.jl")
using .JuliAgebra

manager = App()

cube = Vector{Vec3F}()

push!(cube,Vec3F(-1.0, 1.0, -1.0))
push!(cube,Vec3F(1.0, 1.0, -1.0))
push!(cube,Vec3F( 1.0, 1.0, 1.0))
push!(cube,Vec3F(1.0, 1.0, 1.0))
push!(cube,Vec3F( -1.0, 1.0, 1.0))
push!(cube,Vec3F( -1.0, 1.0, -1.0))

for i in 0:2
    for j in 1:6
        index = i*6+j
        x = -cube[index].y
        y = cube[index].x
        z = cube[index].z      
        v = Vec3F(x,y,z)
        push!(cube,v)
    end
end

for i in 1:6
    index = 3*6+i
    x = -cube[index].z 
    y = cube[index].y
    z = cube[index].x  
    v = Vec3F(x,y,z)
    push!(cube,v)
end

for i in 1:6
    index = 3*6+i  
    x = cube[index].z 
    y = cube[index].y
    z = -cube[index].x  
    v = Vec3F(x,y,z)
    push!(cube,v)
end


submit!(manager,Movable_Limited_Plan(cube))
play!(manager)

