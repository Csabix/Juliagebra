include("Prototype/juliagebra.jl")
using .JuliAgebra

#mutable struct Alma
#    a::Int
#    b::Int
#end
#
#addOne(num::Int) = println(num + 1)
#addTwo(num::Int) = println(num + 2)
#
#
#a = macroexpand(Main,:(@connect Alma b addOne addTwo))
#println(a)
#
#@connect Main.Alma b Main.addOne Main.addTwo
#
#
#
#barack = Alma(5,95)
#
#addOne(barack)
#addTwo(barack)
#addTwo(barack)
#
#println("$(barack.a) <><><> $(barack.b)")
#
##a = Vector{Int}(1:15)
##println(a)
##
##b = view(a,5:10)
##
##println(b)
##
##insert!(a,2,5)
##println(a)
##println(b)
#
#function injects(a::Int,b::Int,c::Int,str::String)
#    println("$a, $b, $c, $str")
#end
#
#injects(a::Int,b::Int,c::Int) = injects(a,b,c,"lolz")
#
#injects(5,6,7)
#injects(50,60,70)
#

abstract type AbstractFruit end

struct Apple <: AbstractFruit
    color::String
end

struct Banana <: AbstractFruit
    length::Int
end

# Approach 1: Without type parameter
function a(alma::AbstractFruit)
    println("Inside a(alma::AbstractFruit)")
    #method1(alma)  # This will dispatch based on the actual type of `alma`
end

# Approach 2: With type parameter
function a(alma::T) where T <: AbstractFruit
    println("Inside a(alma::T) where T <: AbstractFruit")
    #method1(alma)  # This will also dispatch based on the actual type of `alma`
end

function a(alma::AbstractFruit)
    println("Inside a(alma::AbstractFruit)")
    #method1(alma)  # This will dispatch based on the actual type of `alma`
end

apple = Apple("red")
banana = Banana(7)

a(apple)   # Will print "Inside a(...)" and then "This is an apple with color red."
a(banana)  # Will print "Inside a(...)" and then "This is a banana with length 7."

push!(cube,(-1.0, 1.0, -1.0))
push!(cube,(1.0, 1.0, -1.0))
push!(cube,( 1.0, 1.0, 1.0))
push!(cube,(1.0, 1.0, 1.0))
push!(cube,( -1.0, 1.0, 1.0))
push!(cube,( -1.0, 1.0, -1.0))

for i in 0:2
    for j in 1:6
        index = i*6+j
        x = -cube[index].y
        y = cube[index].x
        z = cube[index].z      
        v = (x,y,z)
        push!(cube,v)
    end
end

for i in 1:6
    index = 3*6+i
    x = -cube[index].z 
    y = cube[index].y
    z = cube[index].x  
    v = (x,y,z)
    push!(cube,v)
end

for i in 1:6
    index = 3*6+i  
    x = cube[index].z 
    y = cube[index].y
    z = -cube[index].x  
    v = (x,y,z)
    push!(cube,v)
end