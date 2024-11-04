include("Prototype/juliagebra.jl")
using .JuliAgebra

manager = Manager()

plane = Vector{Vec3T{Float32}}()
push!(plane,Vec3T{Float32}(-1.0,-1.0, 0.0))
push!(plane,Vec3T{Float32}(-1.0, 1.0, 0.0))
push!(plane,Vec3T{Float32}( 1.0,-1.0, 0.0))
push!(plane,Vec3T{Float32}(-1.0, 1.0, 0.0))
push!(plane,Vec3T{Float32}( 1.0, 1.0, 0.0))
push!(plane,Vec3T{Float32}( 1.0,-1.0, 0.0))

submit!(manager,Movable_Limited_Plan(plane))
play!(manager)

