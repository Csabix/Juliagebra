include("Prototype/juliagebra.jl")
using .JuliAgebra

context = App()

A = Point(0,0,5,context)

slide1(a) = return (x(a) + 5,y(a),z(a))
B1 = Point(0,0,0,[A],slide1,context)

slide2(a) = return (x(a) - 5,y(a),z(a))
B2 = Point(0,0,0,[A],slide2,context)

C3 = Point([B1,B2],context) do b,c
    return ((x(b) + x(c))/2,y(b),z(c)-5)
end

play!(context)


