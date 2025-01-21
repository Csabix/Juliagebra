include("Prototype/juliagebra.jl")
using .JuliAgebra

manager = App()



for x in -5:5
    for y in -5:5
        submit!(manager,PointPlan(x,y,0))
    end
end

play!(manager)