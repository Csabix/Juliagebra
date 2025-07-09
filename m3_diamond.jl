include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

A = Point(0,0,5)

B1 = Point(0,0,0,[A]) do a 
    return (a[X] + 5,a[Y],a[Z])
end

B2 = Point(0,0,0,[A]) do a 
    return (a[X] - 5,a[Y],a[Z])
end

C3 = Point(0,0,0,[B1,B2]) do b,c
    return ((b[X] + c[X])/2,b[Y],c[Z]-5)
end

play!()


