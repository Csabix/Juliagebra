include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

A = Point(0,0,5)

B1 = Point(0,0,0,[A]) do a 
    return (x(a) + 5,y(a),z(a))
end

B2 = Point(0,0,0,[A]) do a 
    return (x(a) - 5,y(a),z(a))
end

C3 = Point(0,0,0,[B1,B2]) do b,c
    return ((x(b) + x(c))/2,y(b),z(c)-5)
end

play!()


