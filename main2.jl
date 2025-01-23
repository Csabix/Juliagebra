include("Prototype/juliagebra.jl")
using .JuliAgebra


context = App()

cursor = Point!(0,0,5,context)

function wave(xf,yf,zf,cap,cursor)
    xc = x(cursor)
    yc = y(cursor)
    
    distance = sqrt((xc - xf)^2 + (yc - yf)^2)/ cap * 0.2
    
    if distance > 1
        distance = 1
    end

    zz = z(cursor) + (zf - z(cursor)) * distance

    return (xf,yf,zz)
end

for x in -10:10
    for y in -10:10
        cap = 3.0
        xf = x * cap
        yf = y * cap
        p = Point!(xf,yf,0,[cursor],cur -> wave(xf,yf,0.0,cap,cur),context)
    end
end

play!(context)
