using Juliagebra

App()

A = Point(0,0,5)

B1 = Point(0,0,0,[A]) do a     
    return (a[:x] + 5,a[:y],a[:z])
end

B2 = Point(0,0,0,[A]) do a 
    return (a[:x] - 5,a[:y],a[:z])
end

C3 = Point(0,0,0,[B1,B2]) do b,c
    return ((b[:x] + c[:x])/2,b[:y],c[:z]-5)
end

play!()


