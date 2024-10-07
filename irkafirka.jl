include("Prototype/juliagebra.jl")
using .JuliAgebra

mutable struct Alma
    a::Int
    b::Int
end

addOne(num::Int) = println(num + 1)
addTwo(num::Int) = println(num + 2)


a = macroexpand(Main,:(@connect Alma b addOne addTwo))
println(a)

@connect Main.Alma b Main.addOne Main.addTwo



barack = Alma(5,95)

addOne(barack)
addTwo(barack)
addTwo(barack)

println("$(barack.a) <><><> $(barack.b)")

#a = Vector{Int}(1:15)
#println(a)
#
b = view(a,5:10)
#
#println(b)
#
#insert!(a,2,5)
#println(a)
#println(b)