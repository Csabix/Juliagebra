include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

x1 = 1
y1 = 1

cubePoints = [Point(x1,y1,-1)]

for i in 1:3
    x = x1
    global x1 = y1*-1
    global y1 = x

    push!(cubePoints,Point(x1,y1,-1))
end

for i in 1:4
    push!(cubePoints,Point(x1,y1,1))
    
    x = x1
    global x1 = y1*-1
    global y1 = x
end

Point(0,0,0,cubePoints) do points...
    avgCoords = (0.0,0.0,0.0)

    for p in points
        avgCoords = avgCoords .+ p[:x,:y,:z]
    end

    avgCoords = avgCoords ./ length(points)

    return avgCoords
end

play!()