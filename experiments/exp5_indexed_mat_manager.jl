include("Prototype/juliagebra.jl")
import .JuliAgebra as JLA

manager = JLA.FlatMatrixManager{Int}()

JLA.initMatrix(manager,4,3,1)
JLA.initMatrix(manager,3,2,2)
JLA.initMatrix(manager,5,2,3)
JLA.initMatrix(manager,2,1,4)
JLA.initMatrix(manager,3,1,5)
JLA.initMatrix(manager,3,3,6)

println("length - $(length(manager))")
println("$(manager)")

counter = 1

for i in 1:JLA.layers(manager)
    for v in 1:JLA.height(manager,i)
        for u in 1:JLA.width(manager,i)
            manager[i,u,v] = counter
            global counter += 1
        end
    end
end

println("length - $(JLA.length(manager))")
println("$(manager)")

indexes = Vector{Int}()
JLA.triangulateInto!(indexes,manager,6)
println("$(indexes)")

JLA.triangulateInto!(indexes,manager,3)
println("$(indexes)")

mat = JLA.FlatMatrix{6,Int}(manager)

counter = 50

for v in 1:JLA.height(mat)
    for u in 1:JLA.width(mat)
        mat[u,v] = counter
        global counter += 1
    end
end

println("mat:")
println("$(mat)")

println("manager:")
println("$(manager)")

counter = 0

for triangle in JLA.TrianglesOf(mat)
    a,b,c = triangle
    global counter += 1
    println("$(counter): $(a) - $(b) - $(c)")
    
end

println("$(counter)")