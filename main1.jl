include("Prototype/juliagebra.jl")
using .JuliAgebra


context = App()

x1 = 1
y1 = 1

cube = Vector{PointPlan}()

for i in 1:4
    p = Point!(x1,y1,-1,context)
    
    xx = x1
    global x1 = y1*-1
    global y1 = xx

    push!(cube,p)
end

for i in 1:4
    p = Point!(x1,y1,1,context)
    
    xx = x1
    global x1 = y1*-1
    global y1 = xx
    
    push!(cube,p)
end

function pAvg(points...)
    xa = 0.0
    ya = 0.0
    za = 0.0
    for p in points
        xa+= x(p)
        ya+= y(p)
        za+= z(p)
    end

    xa /= length(points)
    ya /= length(points)
    za /= length(points)

    return (xa,ya,za)

end

Point!(0,0,0,cube,pAvg,context)

play!(context)