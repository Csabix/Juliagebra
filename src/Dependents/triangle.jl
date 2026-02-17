
# ? ---------------------------------
# ! Triangle
# ? ---------------------------------

function Triangle(a::PointPlan,b::PointPlan,c::PointPlan,;transparent=false,color=(0.5,0.6,0.2))
    return ParametricSurface(3,3,0.0,1.0,0.0,1.0,[a,b,c]; transparent=transparent,color=color) do u,v,a,b,c
        
        if (u>=0.5 && v>=0.5)
            u = 0.5
            v = 0.5
        end

        return (1-u-v) .* a .+ u .* b .+ v .* c
    end
end

export Triangle