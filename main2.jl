include("Prototype/juliagebra.jl")
using .JuliAgebra


context = App()

#plans = Vector()

cursor = Point!(0,0,5,context)

for x in -5:5
    for y in -5:5
        p = Point!(x,y,0,[cursor],() -> (),context)
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