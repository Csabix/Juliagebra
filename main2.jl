include("Prototype/juliagebra.jl")
using .JuliAgebra

manager = App()



submit!(manager,PointPlan(0,0,0))
submit!(manager,PointPlan(10,10,10))
submit!(manager,PointPlan(-15,-15,-15))

play!(manager)