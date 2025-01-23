include("Prototype/juliagebra.jl")
using .JuliAgebra

context = App()

A = Point!(0,0,5,context)

slide1(a) = return (x(a) + 5,y(a),z(a))

B1 = Point!(0,0,0,[A],slide1,context)

slide2(a) = return (x(a) - 5,y(a),z(a))
B2 = Point!(0,0,0,[A],slide2,context)

slide3(b,c) = return ((x(b) + x(c))/2,y(b),z(c)-5)
C3 = Point!(0,0,0,[B1,B2],slide3,context)

play!(context)