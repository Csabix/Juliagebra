include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

function giveCube(xtr,ytr,ztr)
    
    vertices = Vector()
    normals  = Vector()
    
    directions = [
        ( 1,  0,  0, 3 ,2),
        (-1,  0,  0, 2, 3),
        ( 0,  1,  0, 1, 3),
        ( 0, -1,  0, 3, 1),
        ( 0,  0,  1, 2, 1),
        ( 0,  0, -1, 1, 2)
    ]

    for direction in directions
        d1,d2,d3,dx,dy = direction
        dn = (d1,d2,d3)
        dd = [d1,d2,d3]

        x = -1
        y = -1
        for i in 1:2
            for j in 1:2         
                dd[dx] = x
                dd[dy] = y
                push!(vertices,(dd[1]+xtr,dd[2]+ytr,dd[3]+ztr))
                push!(normals,dn)
                xx = x
                x = -y
                y = xx
            end
            dd[dx] = x
            dd[dy] = y
            push!(vertices,(dd[1]+xtr,dd[2]+ytr,dd[3]+ztr))
            push!(normals,dn)
        end
    end

    return (vertices,normals)
end

positions = [
    (0.0,0.0,0.0),
    (5.0,5.0,5.0),
    (-5.0,5.0,5.0),
    (5.0,-5.0,5.0),
    (5.0,5.0,-5.0),
    (-5.0,-5.0,5.0),
    (5.0,-5.0,-5.0),
    (-5.0,5.0,-5.0),
    (-5.0,-5.0,-5.0),
]

for position in positions
    x,y,z = position
    vertices,normals = giveCube(x,y,z)
    Mesh(vertices,normals,(0.8,0.0,0.3))
end

play!()

