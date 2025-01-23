include("Prototype/juliagebra.jl")
using .JuliAgebra


context = App()

#plans = Vector()

cursor = Point!(0,0,5,context)

function wave(xf,yf,zf,cap,cursor)
    p1 = [xf,yf]
    p2 = [x(cursor),y(cursor)]

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
        cap = 2.0
        xf = x * cap
        yf = y * cap
        p = Point!(xf,yf,0,[cursor],cur -> wave(xf,yf,0.0,cap,cur),context)
        #println("($(x),$(y)) = $(string(p))")
        #push!(plans,p)
    end
end



play!(context)

#wtf = 1
#for item in plans
#    println("($(wtf)) = $(string(item))")
#    global wtf+=1
#end