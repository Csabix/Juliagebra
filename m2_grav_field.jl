include("Prototype/juliagebra.jl")
using .JuliAgebra

App()

cursor = Point(0,0,5)

function wave(xf,yf,zf,cap,cursor)
    xc = cursor[X]
    yc = cursor[Y]
    
    distance = sqrt((xc - xf)^2 + (yc - yf)^2)/ cap * 0.2
    
    if distance > 1
        distance = 1
    end

    zz = cursor[Z] + (zf - cursor[Z]) * distance

    return (xf,yf,zz)
end

for x in -10:10
    for y in -10:10
        cap = 3.0
        xf = x * cap
        yf = y * cap
        Point(xf,yf,0,[cursor]) do cur
            wave(xf,yf,0.0,cap,cur)
        end
    end
end

play!()


