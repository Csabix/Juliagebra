include("Prototype/juliagebra.jl")
using .JuliAgebra

manager = Manager()

tri = Vector{Vec3}()

push!(tri,Vec3(0,0,0))
push!(tri,Vec3(1,0,0))
push!(tri,Vec3(1,1,0))


submit!(manager,ModLimBodyPlan(tri))
play!(manager)

