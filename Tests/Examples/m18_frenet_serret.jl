include("../../Prototype/juliagebra.jl")
using .JuliAgebra
using .JuliAgebra.LinearAlgebra
using DifferentialEquations

App()

cursorForwP = Point(3.5,0,0)

# * start coordinate
startP = Point(0,0,0)
# * start forward direction
forwP = Point(1,0,0,[cursorForwP,startP]) do c,s
    xyz = Tuple(normalize(collect(c[:xyz] .- s[:xyz])))
    return xyz .+ s[:xyz]
end

# * start bend direction
bendP = Point(0,1,0,[startP,forwP]) do s,f
    xyz = -normalize(collect(f[:xyz] .- s[:xyz]))
    xyz = Tuple(normalize(cross(xyz,[0,0,1])))
    return xyz .+ s[:xyz]
end
# * start up direction
upP = Point(0,0,1,[startP,forwP,bendP]) do s,f,b 
    forwardDir = collect(f[:xyz] .- s[:xyz])
    bendDir = collect(b[:xyz] .- s[:xyz])
    upDir = Tuple(normalize(cross(forwardDir,bendDir)))
    return upDir .+ s[:xyz]
end

sfS = Segment(startP,forwP,(0.8,0.2,0.2))
sbP = Segment(startP,bendP,(0.2,0.8,0.2))
suP = Segment(startP,upP,(0.2,0.2,0.8))

function FrenetCurve(K,T,tspan,pos0,e0,n0,b0)
    u0 = [pos0;e0;n0;b0]

    posI = 1:3
    eI = 4:6
    nI = 7:9
    bI = 10:12

    function frenetSystem!(du, u, p, t)
        du[posI] =  u[eI] # ! posI az a gorbe egy pontja, a derivaltja, pedig maga "e". posI' = e
        du[eI]   =  K(t) * u[nI]
        du[nI]   = -K(t) * u[eI] + T(t) * u[bI] 
        du[bI]   = -T(t) * u[nI]
    end

    prob = ODEProblem(frenetSystem!,u0,tspan)
    sol = solve(prob)

    return sol
end

frenetSolution = nothing
tspan = (0.0,sqrt(2*pi))

calcFrenetP = Point(-999,-999,-999,[startP,forwP,bendP,upP]) do s,f,b,u

    pos0 = collect(s[:xyz]) 
    e0 = collect(f[:xyz] .- s[:xyz])
    n0 = collect(b[:xyz] .- s[:xyz])
    b0 = collect(u[:xyz] .- s[:xyz])

    println("")
    println("Coords:")
    println("pos0: $(pos0)")
    println("e0: $(e0)")
    println("n0: $(n0)")
    println("b0: $(b0)")
    println("")

    K(t) = t
    #T(t) = cos(t)
    #T(t) = sin(t)
    T(t) = 0


    global frenetSolution = FrenetCurve(K,T,tspan,pos0,e0,n0,b0)

    return (-999,-999,-999)
end

approximatedFrenetCurve = ParametricCurve(tspan[1],tspan[2],500,[calcFrenetP]) do t, cFP
    
    if(isnothing(frenetSolution))
        return nothing
    end
    xyz = frenetSolution(t)
    return (xyz[1],xyz[2],xyz[3])
end

pp = Point(-999,-999,-999,[calcFrenetP]) do cfp
    xyz = frenetSolution(tspan[2])
    return (xyz[1],xyz[2],xyz[3])
end

sussP = Segment(startP,pp)

ppss = Point(-999,-999,-999,[calcFrenetP,pp]) do cfp, ppppp
    xyz = frenetSolution(tspan[2])
    ee = (xyz[4],xyz[5],xyz[6])
    return ee .+ ppppp[:xyz]
end

ssss = Segment(ppss,pp)

play!()